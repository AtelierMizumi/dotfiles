# Quickshell 0.3.2 on niri 26.04: research notes

Facts for a custom Quickshell shell on niri. Sources are primary only: Quickshell source at tag `v0.3.2`
(GitHub mirror), the quickshell.org v0.3.2 docs, niri source and wiki at tag `v26.04`, and the Arch PKGBUILD.
Lines marked **(live)** were checked against the niri 26.04 instance running on this machine
(`$XDG_RUNTIME_DIR/niri.wayland-1.*.sock`) with read-only requests, or by capturing what `niri msg` writes to a
fake socket. Link labels are defined at the bottom of the file.

Researched 2026-10-25. Quickshell base: `github.com/quickshell-mirror/quickshell/blob/v0.3.2/`. niri base:
`github.com/YaLTeR/niri/blob/v26.04/` (the repo now lives at `niri-wm/niri`; GitHub redirects).

## 0. Packaging and versions

- Arch `extra/quickshell 0.3.2-1` builds with every feature at its default ON (layershell, session lock,
  screencopy, Pipewire, PAM, Polkit, UPower, notifications, Bluetooth, Network). The PKGBUILD passes no `-D` flags
  that turn a feature off. [arch-pkgbuild] [qs-cmake]
- Quickshell links Qt private APIs. If the runtime Qt differs from the build-time Qt it logs
  "Quickshell was built against Qt X but the system has updated to Qt Y ... the quickshell package must be rebuilt".
  `qs --private-check-compat` exits 1 in that case. After every `qt6-base` update, check that quickshell was rebuilt. [qs-compat]
- v0.3.2 adds "Qt 6.12 support". v0.3.0 added Polkit agents, idle inhibitors and idle timeouts, shortcut
  inhibition, Networking, popup focus grabs, the WindowManager/ext-workspace interface and ext-background-effect
  blur. v0.3.1 and v0.3.2 contain only bug fixes. [qs-changelog]
- Local state: `quickshell` is **not installed** (`pacman -Q quickshell` fails). The installed `noctalia 5.3.0`
  does not depend on quickshell; it links its own libs (sdbus-cpp, libpipewire, pam, polkit...). (local `pacman -Qi`)

## 1. Quickshell types

### 1.1 PanelWindow / WlrLayershell (`import Quickshell`, `import Quickshell.Wayland`)

- `PanelWindow` properties: `anchors { left right top bottom }` (all false by default), `margins`,
  `exclusiveZone` (int; setting it switches `exclusionMode` to `Normal`), `exclusionMode`
  (`ExclusionMode.Normal | Ignore | Auto`, default `Auto`), `aboveWindows` (default true), `focusable` (default false). [qs-panel]
- `ExclusionMode.Auto` reserves exactly the window size plus margins when exactly 3 anchors are set. An
  exclusive zone needs 1 or 3 anchors. Opposite anchors force the full screen width or height. [qs-panel]
- Attached `WlrLayershell.layer`: `WlrLayer.Background | Bottom | Top | Overlay`, default `Top`. [qs-layershell]
- `WlrLayershell.namespace`: string, default `"quickshell"`, **cannot be set after the window is connected**.
  Give every surface its own namespace so niri `layer-rule match namespace=` can target it. [qs-layershell] [qs-layershell-ns]
- `WlrLayershell.keyboardFocus`: `WlrKeyboardFocus.None` (default) | `Exclusive` | `OnDemand`. The docs warn that
  `Exclusive` is NOT a secure lock (use `WlSessionLock`) and that `OnDemand` "may cause the shell window to retain
  focus over another window unexpectedly" on some systems. [qs-layershell]
- Every Quickshell window has `color` (default white), `mask: Region {}`, `surfaceFormat { opaque }`,
  `updatesEnabled`, `screen`, `implicitWidth/Height`, `visible`. If `color` is opaque before the window is shown,
  it cannot become transparent later unless `surfaceFormat.opaque` is false. Start popups with `color: "transparent"`. [qs-window]
- Per-screen windows: `Variants` creates one delegate instance per model value and sets `modelData` on it. [qs-variants]
- `ShellScreen` (`Quickshell.screens` element) has `name`, `model`, `serialNumber`, `x y width height`,
  `devicePixelRatio`. `name` is the wl_output name (`eDP-1`), the same string niri uses in `Workspace.output`. [qs-screen] **(live)**

```qml
import Quickshell
import Quickshell.Wayland

Variants {
  model: Quickshell.screens
  PanelWindow {
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    color: "transparent"
    WlrLayershell.namespace: "smart-bar"
    WlrLayershell.layer: WlrLayer.Top
  }
}
```

### 1.2 "Click outside closes the popup" without HyprlandFocusGrab

- `HyprlandFocusGrab` uses the `hyprland_focus_grab_v1` protocol. niri does not implement it (niri's protocol list
  has no such delegate). [qs-focusgrab] [niri-delegates]
- **Option A (recommended for menus that hang off the bar): `PopupWindow { grabFocus: true }`**. If true, "the
  popup window will be dismissed and visible will change to false if the user clicks outside of the popup".
  Changing it while the popup is open takes effect only after it is hidden and shown again. Added in v0.3.0. [qs-popup] [qs-changelog]
  It works by setting `Qt::Popup`, which gives an xdg_popup grab. [qs-popup-impl] niri honours popup grabs on
  layer-shell parents. It refuses them while the screenshot UI is open and for layers placed within the backdrop. [niri-popup-grab]
- **Option B (full-size panels such as a launcher or control centre): a transparent "scrim" `PanelWindow`** with all
  4 anchors, `exclusionMode: ExclusionMode.Ignore` and a full-size `MouseArea` that closes the panel. Put the
  panel above it on the same layer or on `Overlay`. This uses only plain layer-shell, so it is compositor-agnostic.
  (Inference from [qs-panel]; no niri-specific behaviour involved.)
- **Option C: `keyboardFocus: OnDemand` plus close on focus loss.** On niri, a newly mapped OnDemand surface gets
  keyboard focus. Any button press on something else clears OnDemand focus. [niri-ondemand-map] [niri-ondemand-click] [niri-ondemand-click2]
  In QML, react to the Qt attached property `Window.active` turning false (a standard QtQuick attached property, not
  Quickshell-specific; see Unverified #3).
- Click-through areas: `mask: Region { item: someItem }` makes only that item clickable. With
  `intersection: Intersection.Xor` the region is inverted. `Region` has `shape` (`RegionShape.Rect|Ellipse`),
  `intersection` (`Combine|Subtract|Intersect|Xor`), `item`, `x y width height`, `radius` and per-corner radii
  (v0.3.0), and child `regions`. [qs-window] [qs-region]

```qml
PopupWindow {
  anchor.window: bar            // or anchor.item: button
  anchor.rect.y: bar.height
  grabFocus: true               // xdg_popup grab, dismissed on outside click
  implicitWidth: 320; implicitHeight: 240
  color: "transparent"
  visible: false
}
```

- `PopupAnchor`: `window` | `item`, `rect`, `margins`, `edges` (default `Edges.Top|Edges.Left`), `gravity` (default
  `Edges.Bottom|Edges.Right`), `adjustment` (`PopupAdjustment` Flip/Slide/Resize flags), `updateAnchor()`, signal
  `anchoring`. `parentWindow`/`relativeX/Y` are deprecated. [qs-popupanchor] [qs-popup]

### 1.3 IpcHandler and the `qs` CLI (`import Quickshell.Io`)

- `IpcHandler { target: "name"; enabled: true }`. Functions need **explicit argument and return types**, at most
  10 args. Types: `string int bool real color`, return `void` or the same set. `signal`s with 0 or 1 argument can be
  observed. [qs-ipc]
- CLI: `qs ipc show`, `qs ipc call <target> <function> [args...]`, `qs ipc wait|listen <target> <signal>`,
  `qs ipc prop get <target> <prop>`. `qs msg` is deprecated. [qs-ipc] [qs-cli-ipc]
- Config selection: `qs -c <name>` runs `<xdg config dir>/quickshell/<name>/shell.qml` (env `QS_CONFIG_NAME`).
  `qs -p <path>` takes a folder or a .qml file (env `QS_CONFIG_PATH`). **If `~/.config/quickshell/shell.qml`
  exists, it is the 'default' config and subdirectories are not considered.** [qs-cli-config]
- `ipc` and `kill` accept the same selection plus `-i/--id`, `--pid`, `-n/--newest` and `--any-display`:
  `qs ipc -c smart call bar toggle`, `qs kill -c smart`. Launch flags: `-d/--daemonize`, `-n/--no-duplicate`. [qs-cli-kill] [qs-cli-flags]
- niri has no global-shortcut protocol that Quickshell uses (`GlobalShortcut` is in `Quickshell.Hyprland`). Bind
  keys in niri to `spawn "qs" "ipc" "-c" "smart" "call" "<target>" "<fn>"`. (Inference from [qs-hypr-module] and [qs-ipc].)

```qml
IpcHandler {
  target: "launcher"
  function toggle(): void { launcher.visible = !launcher.visible }
  function open(query: string): void { launcher.query = query; launcher.visible = true }
}
```

### 1.4 Process, StdioCollector, SplitParser, Socket, FileView, env

- `Process`: `command: [..]` (not run through a shell; use `["sh","-c",...]`), `running`, `workingDirectory`,
  `environment` (wrap the object in `()`; `null` removes a variable), `clearEnvironment`, `stdout`/`stderr`
  (a parser), `stdinEnabled`, `processId`. Methods `exec(...)`, `signal(n)`, `write(str)`, `startDetached()`.
  Signals `started()`, `exited(exitCode, exitStatus)`. Setting `running=false` sends SIGTERM. Processes die with
  quickshell unless detached. [qs-process]
- `Quickshell.execDetached([...])` launches apps that should outlive a reload. [qs-global]
- `StdioCollector { waitForEnd: true }` exposes `text`/`data` and emits `streamFinished()`. [qs-datastream]
- `SplitParser { splitMarker: "\n" }` (default `"\n"`) emits `read(data)` once per chunk. [qs-datastream]
- `Socket`: `path`, `connected` (write true to connect), `parser`, `write(str)` plus `flush()` ("Remember to call
  flush after your last write"), signal `error(...)`. There is also a `SocketServer` (`active`, `path`, `handler`). [qs-socket]
- `FileView`: `path`, `watchChanges` (default false), signal `fileChanged()`. The documented pattern is
  `watchChanges: true; onFileChanged: this.reload()`. It also has `text()`/`data()`, `blockLoading`,
  `atomicWrites` (default true), `setText()`, `adapter: JsonAdapter {}` with `writeAdapter()`, and signals
  `loaded/loadFailed/saved/saveFailed/adapterUpdated`. [qs-fileview]
  It watches the parent directory too, so a file that is created or atomically replaced triggers `fileChanged`. [qs-fileview-watch]
- `Quickshell.env("NAME")` returns the string, or `null` if the variable is unset. [qs-global]
  Also `Quickshell.shellDir`, `configPath()`, `statePath()`, `cachePath()`, `iconPath()` and `reload(hard)`. [qs-global]
- `Quickshell.clipboardText`: "Under wayland the clipboard will be empty unless a quickshell window is focused." [qs-global]
- Root-file pragmas: `//@ pragma UseQApplication | NativeTextRendering | IgnoreSystemSettings | RespectSystemStyle
  | DropExpensiveFonts | IconTheme <x> | AppId <x> | ShellId <x> | DataDir | StateDir | CacheDir | Env K=V`. [qs-pragmas]

### 1.5 Notifications (`import Quickshell.Services.Notifications`)

- `NotificationServer`: `keepOnReload` (default true; carried-over items get `lastGeneration=true`),
  `trackedNotifications`, signal `notification(n)`. Capability flags `actionsSupported`, `imageSupported`,
  `bodyMarkupSupported`, `bodyHyperlinksSupported`, `bodyImagesSupported`, `actionIconsSupported`,
  `inlineReplySupported` and `persistenceSupported` all default to **false**; `bodySupported` defaults to true. [qs-notif-server]
- In `onNotification` you **must set `n.tracked = true`**, or the notification is discarded. [qs-notif-server]
- `Notification`: `id summary body appName appIcon image urgency expireTimeout actions resident transient
  desktopEntry hints hasInlineReply`. Methods `expire()`, `dismiss()`, `sendInlineReply()`. `NotificationAction`
  has `identifier`, `text`, `invoke()`. `expireTimeout` is only data; the shell runs its own timer. [qs-notif]
- Name conflict: if `org.freedesktop.Notifications` is already owned, it logs "Could not register ... presumably
  because one is already registered" and retries when the owner goes away. No error is surfaced to QML. [qs-notif-dbus]
- Local: the only D-Bus activation file for the name is Plasma's `org.kde.plasma.Notifications.service`, which runs
  `plasma_waitforname` (it waits; it does not own the name). (local `/usr/share/dbus-1/services`)

### 1.6 Lock screen: WlSessionLock and PamContext

- `WlSessionLock { locked; secure; surface: Component }`. It creates one `WlSessionLockSurface` per screen.
  `secure` turns true once the compositor confirms every screen is covered. Only one lock can be active. If
  quickshell dies while locked, the session stays locked (solid colour). [qs-lock]
- `WlSessionLockSurface`: `screen`, `color` (keep it opaque), `visible`, `width`, `height`. [qs-lock]
- niri implements ext-session-lock (`delegate_session_lock`). On unlock it powers monitors back on and signals
  activity. Background effects are not applied to lock surfaces. [niri-delegates] [niri-unlock] [niri-effects]
- `PamContext` (`import Quickshell.Services.Pam`): `config` (default `"login"`), `configDirectory` (default
  `/etc/pam.d`), `user`, `active`, `message`, `messageIsError`, `responseRequired`, `responseVisible`, `start()`,
  `abort()`, `respond(str)`, signals `completed(PamResult)`, `error(PamError)`, `pamMessage()`. Only the `auth`
  type is used. [qs-pam] [qs-pam-module]
- `PamResult.Success | Failed | Error | MaxTries`. [qs-pam-enums]
- Local default stack: `login` -> `system-local-login` -> `system-login` (`pam_shells`, `pam_nologin`) ->
  `system-auth` (`pam_faillock preauth`, `pam_unix`, `pam_faillock authfail`). Wrong passwords therefore count
  toward faillock. A dedicated file such as `auth required pam_unix.so`, placed next to `shell.qml` and loaded with
  `configDirectory: Quickshell.shellDir + "/pam"`, avoids that. `configDirectory` resolves relative to the QML file. (local `/etc/pam.d`; [qs-pam])

```qml
PamContext {
  id: pam
  onResponseRequiredChanged: if (responseRequired) respond(passwordField.text)
  onCompleted: result => { if (result === PamResult.Success) lock.locked = false; else passwordField.text = "" }
}
// on Enter: pam.start()
```

### 1.7 Idle (`Quickshell.Wayland`, new in v0.3.0)

- `IdleMonitor { enabled (default true); timeout (seconds, default 0); respectInhibitors (default true);
  isIdle (readonly) }`. Requires ext-idle-notify-v1. [qs-idle]
- `respectInhibitors: false` needs protocol version 2 (`get_input_idle_notification`). [qs-idle-proto] niri's
  pinned smithay creates `ext_idle_notifier_v1` at version 2. [smithay-idle]
- `IdleInhibitor { enabled (default false); window }`. `window` must be non-null. Requires
  idle-inhibit-unstable-v1. [qs-inhibit] niri counts an inhibitor only while its surface is visible on some output
  (`surface_primary_scanout_output`). It also honours org.freedesktop.ScreenSaver inhibits over D-Bus. [niri-idle-inhibit] [niri-dbus]
- Turning screens off on niri: send the action `PowerOffMonitors`
  (`{"Action":{"PowerOffMonitors":{}}}` / `niri msg action power-off-monitors`). Any input event powers them back
  on. [niri-ipc-actions] [niri-reactivate] **(live)** niri's own example uses
  `swayidle ... timeout 601 'niri msg action power-off-monitors' timeout 600 'swaylock -f'`. [niri-systemd-example]
- Bonus: `ShortcutInhibitor { enabled; window; active }` (keyboard-shortcuts-inhibit). niri supports it. [qs-shortcut-inhibit] [niri-delegates]

```qml
IdleMonitor { id: dim;  timeout: 300; onIsIdleChanged: if (isIdle) lock.locked = true }
IdleMonitor { id: dpms; timeout: 330; onIsIdleChanged: if (isIdle) niri.action({ PowerOffMonitors: {} }) }
```

### 1.8 Polkit agent (`import Quickshell.Services.Polkit`, new in v0.3.0)

- `PolkitAgent { path (default /org/quickshell/Polkit); isRegistered; isActive; flow: AuthFlow }`, signal
  `authenticationRequestStarted`. [qs-polkit] [qs-polkit-module]
- `AuthFlow`: `message iconName actionId cookie identities selectedIdentity isResponseRequired inputPrompt
  responseVisible supplementaryMessage supplementaryIsError isCompleted isSuccessful isCancelled failed`, plus
  `submit(str)` and `cancelAuthenticationRequest()`. Signals `authenticationSucceeded`, `authenticationFailed`
  (a new session restarts automatically) and `authenticationRequestCancelled`. [qs-polkit-flow] [qs-polkit-module]
- niri needs a polkit agent; its docs suggest `plasma-polkit-agent`. [niri-important] Locally,
  `/etc/xdg/autostart/polkit-kde-authentication-agent-1.desktop` has `OnlyShowIn=KDE;`, so it will not autostart
  under niri. A Quickshell agent will not clash with it. (local)

### 1.9 Services

- **Pipewire** (`Quickshell.Services.Pipewire`): `Pipewire.defaultAudioSink`, `defaultAudioSource`,
  `preferredDefaultAudioSink/Source` (writable), `nodes`, `ready`. `PwNode.audio` (`PwNodeAudio`) has `muted`,
  `volume` (average; writable), `volumes`, `channels`. **These are invalid unless the node is bound with
  `PwObjectTracker { objects: [Pipewire.defaultAudioSink] }`.** [qs-pw-default] [qs-pw-audio] [qs-pw-tracker]
- **UPower** (`Quickshell.Services.UPower`): `UPower.displayDevice`, `devices`, `onBattery`. `UPowerDevice` has
  `percentage`, `state`, `timeToEmpty`, `timeToFull`, `iconName`, `isLaptopBattery`, `ready`. `PowerProfiles.profile`
  (writable) needs a power-profiles daemon; `tuned-ppd` is installed here. [qs-upower] [qs-upower-device] [qs-ppd]
- **Mpris** (`Quickshell.Services.Mpris`): `Mpris.players`. `MprisPlayer` has `trackTitle`, `trackArtist`,
  `trackArtUrl`, `playbackState`, `isPlaying`, `position`, `length`, `canSeek`, `identity`, `desktopEntry`,
  `togglePlaying()`, `next()`, `previous()`. `position` is not reactive: call `player.positionChanged()` from a
  Timer or FrameAnimation. [qs-mpris] [qs-mpris-pos]
- **SystemTray** (`Quickshell.Services.SystemTray`): `SystemTray.items`. `SystemTrayItem` has `id`, `title`,
  `status`, `icon`, `tooltipTitle`, `hasMenu`, `menu`, `onlyMenu`, `activate()`, `secondaryActivate()`,
  `scroll()`, `display(parentWindow, x, y)`. It registers `org.kde.StatusNotifierWatcher` when the name is free. [qs-tray] [qs-tray-item] [qs-tray-watcher]
- **Bluetooth** (`Quickshell.Bluetooth`, since v0.2.0): `Bluetooth.defaultAdapter`, `adapters`, `devices`. The
  adapter has `enabled`, `discovering`, `pairable`, `devices`. A device has `name`, `connected` (writable),
  `paired`, `trusted`, `battery`, `connect()`, `pair()`, `forget()`. It needs BlueZ, and the module has no pairing
  agent (no "agent" code in `src/bluetooth`). [qs-bt] [qs-bt-device] [qs-bt-module]
- **Networking** (`Quickshell.Networking`, new in v0.3.0): `Networking.devices`, `wifiEnabled` (writable),
  `wifiHardwareEnabled`, `connectivity`, `checkConnectivity()`. `NetworkDevice` has `type`, `name`, `connected`,
  `state`, `networks`, `disconnect()`. `WifiNetwork` has `signalStrength`, `security`, `connectWithPsk(psk)`,
  `connect()`, `forget()`. **NetworkManager is the only backend.** v0.3.1 and v0.3.2 fixed Wi-Fi crashes and NM
  restart handling, so nmcli is not required. [qs-net] [qs-net-module] [qs-net-net] [qs-net-wifi] [qs-changelog]
- **WindowManager** (`Quickshell.WindowManager`, new in v0.3.0): `WindowManager.windowsets` (workspaces) with
  `name`, `active`, `urgent`, `activate()`. It supports only ext-workspace-v1, which niri implements
  (`delegate_ext_workspace`). Treat niri IPC as the richer source. [qs-wm] [qs-windowset] [niri-delegates]
- **ToplevelManager** (`Quickshell.Wayland`): `toplevels`, `activeToplevel`. `Toplevel` has `appId`, `title`,
  `activated`, `activate()`, `close()`. It uses wlr-foreign-toplevel-management, which niri implements. [qs-toplevel] [niri-foreign-toplevel]

### 1.10 Brightness, screencopy, blur, clipboard

- **Brightness**: Quickshell has no brightness or backlight API (`rg -i 'brightness|backlight' src` finds nothing at
  v0.3.2). Use `brightnessctl` (in Arch `extra`; not installed here), sysfs plus FileView, or `ddcutil` for external
  monitors (installed). This laptop exposes only `acpi_video*` under `/sys/class/backlight`. (local)
- **ScreencopyView** (`Quickshell.Wayland`): `captureSource` (a `ShellScreen` or a `Toplevel`), `live`,
  `paintCursor`, `hasContent`, `sourceSize`, `constraintSize`, `captureFrame()`. Screens need wlr-screencopy or
  ext-image-copy-capture plus ext-capture-source. **Toplevels need `hyprland-toplevel-export-v1`, so window
  thumbnails do not work on niri.** niri implements wlr-screencopy only. [qs-screencopy] [niri-delegates]
- **Blur exists on both sides in these versions.**
  - Quickshell v0.3.x: the attached `BackgroundEffect.blurRegion: Region { item: root.contentItem }` on any QsWindow
    uses ext-background-effect-v1. [qs-blur] [qs-changelog]
  - niri 26.04 implements ext-background-effect (`delegate_background_effect`) for toplevels, layer surfaces and
    popups, not for subsurfaces or lock surfaces. Blur requested through the protocol "will exactly follow the shape
    requested". [niri-effects] [niri-delegates]
  - niri-side alternative without client code: `layer-rule { match namespace="^smart-bar$"; background-effect { blur
    true } }`. Rule-driven blur follows `geometry-corner-radius`. [niri-layer-rules] [niri-effects]
  - **xray is on by default** whenever another background effect is active: the layer "sees through" to the
    wallpaper and ignores the windows under it. `xray false` gives true blur, but it is experimental and
    disappears during window open/close animations. Pop-ups default to non-xray. [niri-effects]
  - The surface must be semi-transparent. Global `blur { off; passes 3; offset 3; noise 0.02; saturation 1.5 }`
    (defaults shown); `off` disables everything. [niri-effects] [niri-blur-config]
- **Clipboard history**: Quickshell has no history, only `clipboardText` while focused. [qs-global] niri implements
  wlr-data-control and ext-data-control (`delegate_data_control`, `delegate_ext_data_control`), so
  `wl-paste --watch cliphist store` works. `cliphist 0.7.0` is in Arch `extra`; `wl-clipboard` is installed. [niri-delegates] (local)

## 2. niri IPC (26.04)

### 2.1 Transport

- Connect to the Unix socket at `$NIRI_SOCKET`. Write one JSON request per line (or flush and shut down the write
  end), then read one JSON reply line. You may keep sending requests on the same connection. [niri-ipc-md] [niri-ipc-lib]
- The reply is `{"Ok": <Response>}` or `{"Err": "<string>"}`. An unknown request returns
  `{"Err":"error parsing request"}`. [niri-ipc-lib] **(live)**
- After `"EventStream"`, niri replies `{"Ok":"Handled"}` and **stops reading requests** on that socket. Use a second
  socket for requests or actions. [niri-ipc-lib] **(live)**
- Requests are processed separately, so `Workspaces` followed by `Windows` can be inconsistent. The event stream sends
  the full state up front. [niri-ipc-lib] [niri-ipc-md]
- Compatibility: fields and variants will be added, never renamed. Ignore unknown fields and variants. [niri-ipc-md]

### 2.2 Requests (serde externally tagged: unit variants are bare strings)

`"Version" "Outputs" "Workspaces" "Windows" "Layers" "KeyboardLayouts" "FocusedOutput" "FocusedWindow" "PickWindow"
"PickColor" "EventStream" "ReturnError" "OverviewState" "Casts"`, plus `{"Action":{...}}` and
`{"Output":{"output":"eDP-1","action":{...}}}`. [niri-ipc-requests]

Responses wrap the same name: `{"Ok":{"Workspaces":[...]}}`, `{"Ok":{"FocusedWindow":null}}`,
`{"Ok":{"Outputs":{"eDP-1":{...}}}}` (a map keyed by output name). [niri-ipc-responses] **(live)**

Shapes (live output, trimmed):

```json
{"Ok":{"Version":"26.04 (8ed0da4)"}}
{"Ok":{"FocusedOutput":{"name":"eDP-1","make":"...","model":"0x004D","serial":null,"physical_size":[340,190],
  "modes":[{"width":1920,"height":1080,"refresh_rate":144000,"is_preferred":true}],"current_mode":0,
  "is_custom_mode":false,"vrr_supported":true,"vrr_enabled":false,
  "logical":{"x":0,"y":0,"width":1536,"height":864,"scale":1.25,"transform":"Normal"}}}}
{"Ok":{"Workspaces":[{"id":1,"idx":1,"name":null,"output":"eDP-1","is_urgent":false,"is_active":true,
  "is_focused":true,"active_window_id":6}]}}
{"Ok":{"KeyboardLayouts":{"names":["English (US)"],"current_idx":0}}}
{"Ok":{"Layers":[{"namespace":"noctalia-bar-default","output":"eDP-1","layer":"Top","keyboard_interactivity":"None"}]}}
{"Ok":{"OverviewState":{"is_open":false}}}
```

- `Window`: `id`, `title?`, `app_id?`, `pid?`, `workspace_id?`, `is_focused`, `is_floating`, `is_urgent`,
  `layout{pos_in_scrolling_layout?:[col,tile] (1-based), tile_size:[w,h], window_size:[w,h],
  tile_pos_in_workspace_view?, window_offset_in_tile}`, `focus_timestamp?{secs,nanos}`. [niri-ipc-window]
- `Workspace`: `id` (stable; do not assume it starts at 1 or only increases), `idx` (u8 position on its monitor,
  changes on reorder, the same index `focus-workspace N` uses), `name?`, `output?`, `is_urgent`, `is_active` (visible
  on its output), `is_focused` (exactly one overall), `active_window_id?`. [niri-ipc-workspace]
- `Output`: `name make model serial? physical_size? modes[] current_mode? is_custom_mode vrr_supported vrr_enabled
  logical?{x y width height scale transform}`. `transform` is `"Normal"`, `"90"`, `"180"`, `"270"`, `"Flipped"`,
  `"Flipped90"` and so on. [niri-ipc-output]

### 2.3 Actions (captured from `niri msg` with a fake socket) **(live)**

```json
{"Action":{"FocusWorkspace":{"reference":{"Index":2}}}}
{"Action":{"FocusWorkspace":{"reference":{"Name":"web"}}}}
{"Action":{"FocusWorkspace":{"reference":{"Id":10}}}}      // Id(u64) variant from lib.rs, the CLI cannot emit it
{"Action":{"PowerOffMonitors":{}}}
{"Action":{"PowerOnMonitors":{}}}
{"Action":{"Screenshot":{"show_pointer":true,"path":null}}}             // interactive UI
{"Action":{"ScreenshotScreen":{"write_to_disk":true,"show_pointer":true,"path":null}}}
{"Action":{"ScreenshotWindow":{"id":null,"write_to_disk":true,"show_pointer":false,"path":null}}}
{"Action":{"SwitchLayout":{"layout":"Next"}}}                           // "Next" | "Prev" | {"Index":n}
{"Action":{"ToggleOverview":{}}}
{"Action":{"FocusWindow":{"id":13}}}
{"Action":{"CloseWindow":{"id":null}}}
{"Action":{"Spawn":{"command":["foot","-e","htop"]}}}
{"Action":{"SpawnSh":{"command":"notify-send hi"}}}
{"Action":{"Quit":{"skip_confirmation":true}}}
```

- Field-less actions are struct variants and still need `{}` (`"PowerOffMonitors":{}`). [niri-ipc-actions]
- `WorkspaceReferenceArg` is `Id(u64) | Index(u8) | Name(String)`. [niri-ipc-wsref]
- `ScreenshotWindow` is defined in lib.rs; that line was not captured live. A screenshot `path` must be absolute.
  Other useful actions: `OpenOverview`, `CloseOverview`, `FocusMonitor`, `MoveWindowToWorkspace`, `LoadConfigFile`,
  `ToggleKeyboardShortcutsInhibit`, `ShowHotkeyOverlay`. [niri-ipc-actions]

### 2.4 EventStream events

Initial burst on connect **(live)**: `{"Ok":"Handled"}`, then `WorkspacesChanged`, `WindowsChanged`,
`KeyboardLayoutsChanged`, `OverviewOpenedOrClosed`, `ConfigLoaded`, `CastsChanged`.

| Event | Payload |
|---|---|
| `WorkspacesChanged` | `{workspaces:[Workspace]}`, a full replacement |
| `WorkspaceUrgencyChanged` | `{id, urgent}` |
| `WorkspaceActivated` | `{id, focused}`: active on its output; `focused` true if it is now the focused one |
| `WorkspaceActiveWindowChanged` | `{workspace_id, active_window_id?}` |
| `WindowsChanged` | `{windows:[Window]}`, a full replacement |
| `WindowOpenedOrChanged` | `{window: Window}`; if focused, all others are unfocused |
| `WindowClosed` | `{id}` |
| `WindowFocusChanged` | `{id?}` |
| `WindowFocusTimestampChanged` | `{id, focus_timestamp?}` |
| `WindowUrgencyChanged` | `{id, urgent}` |
| `WindowLayoutsChanged` | `{changes:[[id, WindowLayout]]}` |
| `KeyboardLayoutsChanged` | `{keyboard_layouts:{names, current_idx}}` |
| `KeyboardLayoutSwitched` | `{idx}` |
| `OverviewOpenedOrClosed` | `{is_open}` |
| `ConfigLoaded` | `{failed}`, always sent once on connect |
| `ScreenshotCaptured` | `{path?}` |
| `CastsChanged` / `CastStartedOrChanged` / `CastStopped` | `{casts}` / `{cast}` / `{stream_id}` |

Source: [niri-ipc-events]. Ordering is not always atomic: a window can reference a workspace id that was already
removed. [niri-ipc-md]

- **There is no outputs-changed or layers-changed event.** Use `Quickshell.screens` for monitors, and request
  `"Outputs"` again when the screen list changes. (Inference from [niri-ipc-events].)

```qml
// Event stream over niri's socket
Socket {
  id: niriEvents
  path: Quickshell.env("NIRI_SOCKET")
  connected: true
  onConnectedChanged: if (connected) { write('"EventStream"\n'); flush() }
  parser: SplitParser { onRead: line => root.handle(JSON.parse(line)) }
}
// Requests/actions on a second socket (the event-stream socket no longer reads requests)
Socket { id: niriCmd; path: Quickshell.env("NIRI_SOCKET"); connected: true
  parser: SplitParser { onRead: line => {/* {"Ok":...} or {"Err":...} */} } }
function action(a) { niriCmd.write(JSON.stringify({ Action: a }) + "\n"); niriCmd.flush() }
// action({ FocusWorkspace: { reference: { Id: ws.id } } })
```

### 2.5 Layer rules relevant to a shell (`layer-rule {}`)

- Matchers: `namespace` (regex), `at-startup`, and `layer="background|bottom|top|overlay"` (new in 26.04). List
  namespaces with `niri msg layers`. [niri-layer-rules]
- `block-out-from "screencast" | "screen-capture"` paints the surface black in captures (useful for notifications
  and lock content). `opacity`, `shadow { on; softness; spread; offset; draw-behind-window; color }`. Layer shadows
  must be enabled per rule; niri cannot see the client's visual geometry, so remove client-side margins.
  `geometry-corner-radius` affects only the shadow and blur shape. [niri-layer-rules]
- `place-within-backdrop true` puts a *background*-layer surface that ignores exclusive zones into the overview
  backdrop, and it then ignores all input. `baba-is-float`. [niri-layer-rules]
- `background-effect { xray; blur; noise; saturation }` and `popups { opacity; geometry-corner-radius;
  background-effect {} }` are new in 26.04. `popups` affects only real xdg-popups, not pop-ups the shell draws inside
  another layer surface. [niri-layer-rules]

## 3. niri vs Hyprland: what the shell must do differently

- No `hyprland_focus_grab_v1`: use `PopupWindow.grabFocus`, a scrim window, or OnDemand plus focus loss (section 1.2). [qs-focusgrab] [qs-popup]
- No Hyprland global shortcuts: put the binds in niri's config and call `qs ipc`. [qs-hypr-module]
- No `Quickshell.Hyprland` IPC or workspace model: talk to `$NIRI_SOCKET` directly (section 2), or use the generic
  `Quickshell.WindowManager` (ext-workspace) and `ToplevelManager`. [qs-wm] [niri-delegates]
- No toplevel capture (`hyprland-toplevel-export`), so no live window previews with ScreencopyView. [qs-screencopy]
- **Fullscreen windows render above the Top layer** and take keyboard focus priority. Launchers and OSDs that must
  appear over fullscreen windows go on `Overlay`. Bottom and background layers get *exclusive* focus only on empty
  workspaces. In the Overview, bottom and background layers zoom out with the workspaces while top and overlay stay
  on top. [niri-layer-components]
- New OnDemand layer surfaces receive focus on map (lxqt-runner behaviour). A permanent bar should use
  `keyboardFocus: None`, or it steals focus at startup. [niri-ondemand-map]
- **xdg-activation**: by default niri ignores activation tokens with invalid serials. Electron and Qt apps (Discord,
  Telegram) make such tokens when their tray icon or notification is clicked, so they do not raise. The fix is
  `debug { honor-xdg-activation-with-invalid-serial }`. [niri-debug-xdg]
- Quickshell 0.3.2 does not send activation tokens: `ActivationToken` appears only in the bundled D-Bus XML, and
  there is no xdg-activation code in `src/`. When a notification or tray click should raise an app, the shell can
  also find the window in the niri `Windows` state (by `app_id`/`pid`) and send `FocusWindow{id}`. [qs-notif-xml]
- New windows spawned by the shell are focused by niri's heuristics unless `debug { strict-new-window-focus-policy }`
  is set. That flag would require valid tokens, which Quickshell cannot provide, so do not enable it. [niri-debug-strict]
- niri's systemd unit wants `xdg-desktop-autostart.target`. XDG autostart entries run under niri unless
  `OnlyShowIn` excludes it. [niri-service]

## Unverified / open questions

1. Live behaviour of `PopupWindow.grabFocus` on niri was not tested (quickshell is not installed). The source reading
   is that niri's `grab()` looks up the layer surface on the **active** output's layer map only. A popup from a bar
   on a non-active output might be dismissed straight away, though the click on the bar normally makes that output
   active first. [niri-popup-grab]
2. Whether Quickshell exposes the ext-background-effect capability (blur supported or not) to QML was not checked;
   only `blurRegion` is documented. [qs-blur]
3. `Window.active` (QtQuick attached property) on Quickshell PanelWindows was not verified against Quickshell source
   or docs; it is standard Qt and should work because PanelWindow is backed by a QQuickWindow.
4. The exact JSON for actions not captured live (`ScreenshotWindow`, `FocusWorkspace` by `Id`) comes from serde
   defaults in `lib.rs`. A missing `Option` field is probably accepted as null, but always sending every field is safer.
5. Whether `FileView.watchChanges` fires on a JSON file under `~/.local/state` after `mv`-style atomic writes was read
   from source, not tested. [qs-fileview-watch]
6. Bluetooth pairing that needs a PIN or confirmation needs a BlueZ agent (e.g. `bluetoothctl` agent or
   blueman-applet). The module has no agent, but no Quickshell doc states the consequence.
7. The quickshell.org docs pages were checked only for the Quickshell.Wayland index and WlrLayershell. Other type
   facts come from the v0.3.2 source headers, which generate those docs.

## Sources

[arch-pkgbuild]: https://gitlab.archlinux.org/archlinux/packaging/packages/quickshell/-/blob/main/PKGBUILD
[qs-cmake]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/CMakeLists.txt#L56-L83
[qs-compat]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/launch/command.cpp#L499-L583
[qs-changelog]: https://quickshell.org/changelog
[qs-panel]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/window/panelinterface.hpp#L56-L124
[qs-layershell]: https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/WlrLayershell/
[qs-layershell-ns]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/wlr_layershell/wlr_layershell.hpp#L101-L117
[qs-window]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/window/windowinterface.hpp#L52-L155
[qs-variants]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/core/variants.hpp#L28-L53
[qs-screen]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/core/qmlscreen.hpp#L31-L47
[qs-focusgrab]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/hyprland/focus_grab/qml.hpp#L20-L30
[qs-popup]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/window/popupwindow.hpp#L17-L90
[qs-popup-impl]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/window/popupwindow.cpp#L63
[qs-popupanchor]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/core/popupanchor.hpp#L25-L178
[qs-region]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/core/region.hpp#L18-L110
[qs-ipc]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/io/ipchandler.hpp#L124-L228
[qs-cli-config]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/launch/parsecommand.cpp#L20-L66
[qs-cli-kill]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/launch/parsecommand.cpp#L192-L210
[qs-cli-ipc]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/launch/parsecommand.cpp#L203-L264
[qs-cli-flags]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/launch/parsecommand.cpp#L111-L146
[qs-hypr-module]: https://github.com/quickshell-mirror/quickshell/tree/v0.3.2/src/wayland/hyprland
[qs-process]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/io/process.hpp#L23-L221
[qs-datastream]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/io/datastream.hpp#L50-L124
[qs-socket]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/io/socket.hpp#L15-L144
[qs-fileview]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/io/fileview.hpp#L146-L346
[qs-fileview-watch]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/io/fileview.cpp#L495-L545
[qs-global]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/core/qmlglobal.hpp#L123-L237
[qs-pragmas]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/launch/launch.cpp#L91-L130
[qs-notif-server]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/notifications/qml.hpp#L17-L120
[qs-notif]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/notifications/notification.hpp#L70-L261
[qs-notif-dbus]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/notifications/server.cpp#L114-L133
[qs-notif-xml]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/notifications/org.freedesktop.Notifications.xml#L46-L48
[qs-lock]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/session_lock.hpp#L24-L141
[qs-pam]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/pam/qml.hpp#L18-L108
[qs-pam-module]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/pam/module.md
[qs-pam-enums]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/pam/conversation.hpp#L24-L55
[qs-idle]: https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/IdleMonitor/
[qs-idle-proto]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/idle_notify/proto.cpp#L33-L52
[qs-inhibit]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/idle_inhibit/inhibitor.hpp#L14-L37
[qs-shortcut-inhibit]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/shortcuts_inhibit/inhibitor.hpp#L15-L59
[qs-polkit]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/polkit/qml.hpp#L25-L70
[qs-polkit-flow]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/polkit/flow.hpp#L14-L138
[qs-polkit-module]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/polkit/module.md
[qs-pw-default]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/pipewire/qml.hpp#L67-L128
[qs-pw-audio]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/pipewire/qml.hpp#L216-L245
[qs-pw-tracker]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/pipewire/qml.hpp#L426-L440
[qs-upower]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/upower/core.hpp#L65-L80
[qs-upower-device]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/upower/device.hpp#L119-L162
[qs-ppd]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/upower/powerprofiles.hpp#L167-L200
[qs-mpris]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/mpris/player.hpp#L93-L272
[qs-mpris-pos]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/mpris/player.hpp#L110-L139
[qs-tray]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/status_notifier/qml.hpp#L16-L22
[qs-tray-item]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/status_notifier/item.hpp#L105-L136
[qs-tray-watcher]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/status_notifier/watcher.cpp#L56-L64
[qs-bt]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/bluetooth/bluez.hpp#L65-L76
[qs-bt-device]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/bluetooth/device.hpp#L57-L122
[qs-bt-module]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/bluetooth/module.md
[qs-net]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/network/qml.hpp#L81-L114
[qs-net-module]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/network/module.md
[qs-net-net]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/network/network.hpp#L23-L60
[qs-net-wifi]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/network/wifi.hpp#L19-L67
[qs-wm]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/windowmanager/module.md
[qs-windowset]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/windowmanager/windowset.hpp#L26-L73
[qs-toplevel]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/toplevel/qml.hpp#L26-L170
[qs-screencopy]: https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/wayland/screencopy/view.hpp#L14-L66
[qs-blur]: https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/BackgroundEffect/
[niri-ipc-md]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/IPC.md
[niri-ipc-lib]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L1-L33
[niri-ipc-requests]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L64-L122
[niri-ipc-responses]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L124-L168
[niri-ipc-actions]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L194-L949
[niri-ipc-wsref]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L975-L988
[niri-ipc-output]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L1201-L1292
[niri-ipc-window]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L1294-L1393
[niri-ipc-workspace]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L1405-L1494
[niri-ipc-events]: https://github.com/YaLTeR/niri/blob/v26.04/niri-ipc/src/lib.rs#L1568-L1708
[niri-layer-rules]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/Configuration:-Layer-Rules.md
[niri-effects]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/Window-Effects.md
[niri-blur-config]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/Configuration:-Miscellaneous.md#blur
[niri-layer-components]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/Layer%E2%80%90Shell-Components.md
[niri-debug-xdg]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/Configuration:-Debug-Options.md#honor-xdg-activation-with-invalid-serial
[niri-debug-strict]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/Configuration:-Debug-Options.md#strict-new-window-focus-policy
[niri-systemd-example]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/Example-systemd-Setup.md
[niri-important]: https://github.com/YaLTeR/niri/blob/v26.04/docs/wiki/Important-Software.md
[niri-service]: https://github.com/YaLTeR/niri/blob/v26.04/resources/niri.service
[niri-delegates]: https://github.com/YaLTeR/niri/blob/v26.04/src/handlers/mod.rs
[niri-foreign-toplevel]: https://github.com/YaLTeR/niri/blob/v26.04/src/protocols/foreign_toplevel.rs
[niri-popup-grab]: https://github.com/YaLTeR/niri/blob/v26.04/src/handlers/xdg_shell.rs#L269-L345
[niri-ondemand-map]: https://github.com/YaLTeR/niri/blob/v26.04/src/handlers/layer_shell.rs#L162-L181
[niri-ondemand-click]: https://github.com/YaLTeR/niri/blob/v26.04/src/niri.rs#L6096-L6118
[niri-ondemand-click2]: https://github.com/YaLTeR/niri/blob/v26.04/src/input/mod.rs#L3012-L3014
[niri-idle-inhibit]: https://github.com/YaLTeR/niri/blob/v26.04/src/niri.rs#L3993-L4005
[niri-dbus]: https://github.com/YaLTeR/niri/blob/v26.04/src/dbus/freedesktop_screensaver.rs
[niri-unlock]: https://github.com/YaLTeR/niri/blob/v26.04/src/handlers/mod.rs#L464-L471
[niri-reactivate]: https://github.com/YaLTeR/niri/blob/v26.04/src/input/mod.rs#L125-L136
[smithay-idle]: https://github.com/Smithay/smithay/blob/ff5fa7df392cecfba049ffed55cdaa4e98a8e7ef/src/wayland/idle_notify/mod.rs#L119
