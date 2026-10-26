import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import "../modules/common/functions/OpenMeteo.js" as OM

// The system side of the bar's weather pill and its dropdown
// (WeatherPopup.qml) and of the desktop weather card -- with MediaSource.qml,
// ResourceSource.qml, BatterySource.qml, one of the small self-contained *Source
// files each Bar.qml instance owns.
//
// The weather comes from Open-Meteo (open-meteo.com): no API key, and it has a
// city search of its own, so the person only types a city name:
//
//   SettingsService "weather.location":  "Majayjay"
//     1. geocoding-api.open-meteo.com  turns the name into latitude / longitude
//     2. api.open-meteo.com            gives the weather for that spot
//
// What can be typed (OpenMeteo.js parseQuery / pickPlace):
//   Majayjay                a city (the best-known one of that name)
//   Springfield, Illinois   "city, country / region" picks between same-named places
//   14.15, 121.47           latitude, longitude -- no search step
//   (empty)                 no place: nothing is asked and nothing is sent (there is no guess from the IP address)
//
// The place is looked up once per change of the Location; the 15-minute poll only asks for the weather. All the
// parsing lives in OpenMeteo.js, which has its own test.
//
//   temperatureText   e.g. "18°C" -- "" until the first fetch lands, or if
//                      curl / the network isn't available
//   conditionText     e.g. "Partly cloudy"
//   iconName          the Material Symbols name that matches it
//   feelsLikeText, humidityText, windText, pressureText, visibilityText,
//   uvText, precipText, areaText   the popup's detail rows ("" until known)
//   forecast          [{ label, date, iconName, condition, high, low, rain }]
//                      for today and the next two days
//   sunriseText, sunsetText   today's, as "06:05 AM" ("" until known)
//   hourly            [{ label, iconName, condition, temp, rain, feels }] the next
//                      eight readings, three hours apart
//   updatedText       "Updated 14:05" -- when the last fetch landed
//   failed / problemText   the last try gave nothing; problemText says why in a few
//                      words ("Couldn't find 'Xyz'", "Couldn't reach Open-Meteo",
//                      "Set a city in Settings")
//
// Every Bar.qml instance polls its own copy (same reasoning as
// ResourceSource/BatterySource: cheap enough, and simpler than wiring
// shared state across monitors) -- but weather barely moves minute to
// minute, so this refreshes far less often than those do. Opening the
// popup asks for a fresh reading when the last one is a few minutes old.
Scope {
    id: root

    // Flip to true for °F. Open-Meteo is asked for metric units; this picks
    // which one the shell shows.
    // (SettingsService "weather.fahrenheit".)
    property bool useFahrenheit: SettingsService.flag("weather.fahrenheit")
    property bool use24h: SettingsService.flag("time.use24h")

    // The last answer from Open-Meteo, kept so a change of unit can redraw it
    // at once instead of waiting for the next fetch (up to 15 minutes).
    property var lastData: null

    onUseFahrenheitChanged: {
        if (!root.lastData)
            return
        // apply() also stamps "Updated hh:mm" and the stale-check time;
        // switching units isn't a new reading, so put those back.
        const keepMs = root.lastFetchMs
        const keepText = root.updatedText
        try {
            root.apply(root.lastData)
        } catch (e) {
            return
        }
        root.lastFetchMs = keepMs
        root.updatedText = keepText
    }
    // js copied the above format :3

    onUse24hChanged: {
        if (!root.lastData)
            return
        const keepMs = root.lastFetchMs
        const keepText = root.updatedText
        try {
            root.apply(root.lastData)
        } catch (e) {
            return
        }
        root.lastFetchMs = keepMs
        root.updatedText = keepText
    }

    property string temperatureText: ""
    property string conditionText: ""
    property string iconName: "cloud"
    property string feelsLikeText: ""
    property string humidityText: ""
    property string windText: ""
    property string pressureText: ""
    property string visibilityText: ""
    property string uvText: ""
    property string precipText: ""
    property string areaText: ""
    property string sunriseText: ""
    property string sunsetText: ""
    property var forecast: []
    property var hourly: []
    property string updatedText: ""

    // True while a request is in flight; failed is true when the last try
    // didn't produce anything usable (the previous readings stay on show, unless
    // the place itself was the problem).
    readonly property bool loading: geocode.running || fetch.running || geoip.running
    property bool failed: false
    property string problemText: ""
    property double lastFetchMs: 0

    // Where: SettingsService "weather.location" (see the top).
    readonly property string location: String(SettingsService.get("weather.location") || "").trim()

    // The place the weather is for: { lat, lon, label } once found, null until then.
    property var place: null

    readonly property string forecastUrl: root.place ? OM.forecastUrl(root.place.lat, root.place.lon) : ""
    property string geocodeUrl: ""

    function fail(text) {
        root.failed = true
        root.problemText = text
    }

    function clearReading() {
        root.lastData = null
        root.temperatureText = ""
        root.conditionText = ""
        root.feelsLikeText = ""
        root.humidityText = ""
        root.windText = ""
        root.pressureText = ""
        root.visibilityText = ""
        root.uvText = ""
        root.precipText = ""
        root.areaText = ""
        root.sunriseText = ""
        root.sunsetText = ""
        root.forecast = []
        root.hourly = []
        root.iconName = "cloud"
    }

    // A new place: forget what the old one showed and look again.
    onLocationChanged: {
        root.clearReading()
        root.place = null
        root.failed = false
        root.problemText = ""
        if (root.loading) {
            // The old place's answer is no use: stop it, and look again for
            // the new one once it has exited (see `processEnded` below).
            root.restartPending = true
            geocode.running = false
            fetch.running = false
            geoip.running = false
        } else {
            root.refresh()
        }
    }
    property bool restartPending: false

    function processEnded() {
        if (root.restartPending && !root.loading) {
            root.restartPending = false
            root.failed = false
            root.problemText = ""
            root.refresh()
        }
    }

    function refresh() {
        if (root.loading)
            return
        const q = OM.parseQuery(root.location)
        if (root.place) {
            fetch.running = true
            return
        }
        if (q.kind === "coords") {
            root.setPlace({ lat: q.lat, lon: q.lon, label: q.label || OM.coordLabel(q.lat, q.lon) })
        } else if (q.kind === "name") {
            root.geocodeUrl = OM.geocodeUrl(q.name)
            root.pendingQuery = q
            geocode.running = true
        } else {
            geoip.running = true
        }
    }
    property var pendingQuery: null

    // The place is known: remember it and ask for its weather.
    function setPlace(p) {
        root.place = p
        root.areaText = p.label
        fetch.running = true
    }

    // For the popup: only bother Open-Meteo again if the reading is old.
    function refreshIfStale() {
        if (Date.now() - root.lastFetchMs > 5 * 60 * 1000)
            root.refresh()
    }

    function apply(data) {
        const r = OM.buildReading(data, {
            fahrenheit: root.useFahrenheit,
            use24h: root.use24h,
            // The weekday names follow the system language, as they always did.
            dayLabel: function (iso, i) {
                if (i === 0)
                    return "Today"
                return new Date(iso + "T12:00:00").toLocaleDateString(Qt.locale(), "ddd")
            }
        })
        root.temperatureText = r.temperatureText
        root.conditionText = r.conditionText
        root.iconName = r.iconName
        root.feelsLikeText = r.feelsLikeText
        root.humidityText = r.humidityText
        root.windText = r.windText
        root.pressureText = r.pressureText
        root.visibilityText = r.visibilityText
        root.uvText = r.uvText
        root.precipText = r.precipText
        root.sunriseText = r.sunriseText
        root.sunsetText = r.sunsetText
        root.forecast = r.forecast
        root.hourly = r.hourly
        if (root.place)
            root.areaText = root.place.label

        const now = new Date()
        root.updatedText = "Updated " + OM.pad(now.getHours()) + ":" + OM.pad(now.getMinutes())
        root.lastFetchMs = now.getTime()
        root.failed = false
        root.problemText = ""
    }

    // False stops the 15-minute poll (and starting it again looks straight away).
    // The bar's pill leaves it on; the desktop weather card (WeatherCardWidget.qml)
    // turns it off while the card is not on screen.
    property bool polling: true

    Timer {
        // Weather doesn't move fast enough to poll like CPU/battery --
        // once every 15 minutes is plenty, and kinder to the service.
        interval: 15 * 60 * 1000
        running: root.polling
        repeat: true
        // The first look at start; a poll that is switched back on only looks again if the reading is old (see
        // onPollingChanged).
        triggeredOnStart: root.lastFetchMs === 0
        onTriggered: root.refresh()
    }

    onPollingChanged: {
        if (root.polling && root.lastFetchMs > 0)
            root.refreshIfStale()
    }

    // Step 1 (a typed city): its name -> latitude / longitude.
    // -s: quiet. -m 10: give up after 10 s rather than hang onto a process if the
    // network's down. The URL is one argument, never part of a shell string.
    Process {
        id: geocode
        command: ["curl", "-s", "-m", "10", root.geocodeUrl]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.restartPending)
                    return
                const q = root.pendingQuery
                let data = null
                try {
                    data = JSON.parse(text)
                } catch (e) {
                    root.fail("Couldn't reach Open-Meteo")
                    return
                }
                const hit = OM.pickPlace(data.results, q ? q.qualifier : "")
                if (!hit) {
                    const shown = q && q.name.length > 18 ? q.name.slice(0, 17) + "\u2026" : (q ? q.name : "")
                    root.fail("Couldn't find \u201c" + shown + "\u201d")
                    return
                }
                root.setPlace({ lat: Number(hit.latitude), lon: Number(hit.longitude), label: OM.placeLabel(hit) })
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !root.restartPending && !root.failed)
                root.fail("Couldn't reach Open-Meteo")
            root.processEnded()
        }
    }

    // Step 2: the weather for the place.
    // A failed fetch, or a missing curl, just leaves the last-known readings
    // in place -- empty the very first time.
    Process {
        id: fetch
        command: ["curl", "-s", "-m", "10", root.forecastUrl]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.restartPending)
                    return
                try {
                    const data = JSON.parse(text)
                    root.apply(data)
                    root.lastData = data
                } catch (e) {
                    // The service sometimes answers with an error page (or a JSON
                    // error) when it's overloaded; keep what we had.
                    root.fail("Couldn't reach Open-Meteo")
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !root.restartPending && !root.failed)
                root.fail("Couldn't reach Open-Meteo")
            root.processEnded()
        }
    }

    // Fallback: detect city/coords via GeoIP when no location is configured in Settings.
    Process {
        id: geoip
        command: ["curl", "-s", "-m", "5", "http://ip-api.com/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.restartPending)
                    return
                try {
                    const data = JSON.parse(text)
                    if (data && data.lat !== undefined && data.lon !== undefined) {
                        const city = data.city || data.regionName || ""
                        const country = data.country || ""
                        const label = city && country ? city + ", " + country : (city || country || OM.coordLabel(data.lat, data.lon))
                        root.setPlace({ lat: Number(data.lat), lon: Number(data.lon), label: label })
                        return
                    }
                } catch (e) {}
                root.fail("Set a city in Settings")
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !root.restartPending && !root.failed && !root.place)
                root.fail("Set a city in Settings")
            root.processEnded()
        }
    }
}
