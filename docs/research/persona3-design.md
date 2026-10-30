# Persona 3 (Reload) UI design: research notes

Design facts behind the Persona 3 / P3 Reload menu look, for the Mizu shell's visual direction. Sources are
interviews with the people who made the game where possible, then press coverage. Items marked **(unverified)**
rest on a single weak source or on the author's own reading and need a primary source before use.

Researched 2026-10-28. Link labels are defined at the bottom of the file.

## 0. Source quality

- Developer interviews (P3R art director Tomohiro Kumagai, director Takuya Yamaguchi, character designer
  Azusa Shimada) relayed by Persona Central. Strongest sources here. [pc-menu-ui] [pc-art-direction]
- Famitsu interview summaries relayed by press. Consistent with the developer interviews. [automaton] [famitsu-p5]
- 2006 E3 preview of the original game. Describes the original's palette and layout. [rpg-e3-2006]
- Typography: no reliable source found. Low-quality sites name Fontworks fonts; treat as unverified. [font-claim-unverified]

## 1. Palette: blue as concept

- Original art director Shigenori Soejima gave two keywords for the blue: "blue that evokes death" and
  "seaside blue", together with a refined urban look. [pc-art-direction]
- The P3R team kept that blue. [pc-art-direction]
- Colour is assigned per game: blue for P3, yellow for P4, red for P5. The P5 scheme (crimson red with black
  and white) is not P3's. [famitsu-p5]
- The original 2006 menus were mainly blue, with asymmetric and artistic layouts (E3 2006 preview). Yellow is
  mentioned as an accent in that preview; the exact yellow usage is **(unverified)**. [rpg-e3-2006]

## 2. The water concept

- Kumagai says he admired the original's "beautiful blue color and movement reminiscent of water and bubbles"
  for years. [pc-menu-ui]
- The UI combines "clean urban lines with the soft expression of water". [pc-art-direction]
- The menu is framed as the protagonist's inner state: "sinking into one's own heart to perceive one's
  relationships and information with others". This is a paraphrase in the source article. [pc-menu-ui]
- Shimmer, underwater gradation, and glass-like sparkle and reflection were deliberately added. [pc-menu-ui]
- Bubble motifs are mentioned by Famitsu and press but not by the developer interview. [automaton]

## 3. Motion

- On opening the main menu, the protagonist sinks into water. [pc-menu-ui] [automaton]
- The menu is calmer than P5's. P5 uses fast, aggressive movement ("pop-punk"); P3R drifts and sinks. [pc-menu-ui]
- Effects reported by press: faces reflected on a glass shard, cards flipping to reveal options. [automaton]
- Menu-to-menu transitions move the protagonist's pose, so navigation feels continuous. [rpg-pax-west-2023]
- Responsiveness and navigation speed carried over from P5. The director says the PS4 version should run about
  as fast. [pc-menu-ui]

## 4. Unifying UI, characters and environment

- The protagonist in the menu is a dedicated UI-only 3D model with extra skeletons and polygons. Pose and
  expression change per menu item. [pc-menu-ui]
- Character portraits were drawn first; 3D models were built from them. Portraits convey emotion; 3D handles
  movement. [pc-art-direction]
- Soejima's latest art style was the starting point for the character redesigns. [pc-art-direction]
- The environment (Tartarus) was modelled to match the new proportions; a clean, too-tidy floor is used to
  unsettle. [pc-art-direction]

## 5. Readability before decoration

- Planners define the information each screen must show. Designers then build the image around it. [pc-menu-ui]
- Concepts were prototyped in-game, then narrowed for readability and usability as well as aesthetics. [pc-menu-ui]
- The "9" motif: the System menu is the ninth item from the top. [pc-menu-ui]
- Localization into 13 languages required adjusting text placement. The director personally supervised UI
  corrections down to single pixels. [pc-menu-ui]

## 6. What the design does well (author's synthesis)

These points are our reading of the sources above, not claims from the developers.

- One concept (water, inner state) drives color, motion and layout. Each choice has a reason.
- Restraint: one dominant hue with one emotional meaning, not a multi-colour palette.
- Hard and soft contrast: urban geometry against fluid, reflective motion. This tension is the look.
- Motion is part of identity. The slow sink is recognisable without seeing any other UI element.
- Consistency across media: UI, characters and environments share one visual language.
- Usability is checked in-game and per language, not left to the mockup.

## 7. Notes for Mizu

- Mizu's name (water) matches the P3 concept. The palette and motion can follow the same logic.
- A fixed blue palette option sits alongside the wallpaper-derived palette. Other surfaces (boot, login, lock
  screen) use the same blue and motion language.
- Take principles, not assets. Persona is Atlus's IP. Do not ship characters, logos, fonts or sounds from the game.

## Sources

[pc-menu-ui]: https://personacentral.com/p3r-interview-menu-ui/
[pc-art-direction]: https://personacentral.com/p3r-art-design-direction-interview/
[automaton]: https://automaton-media.com/en/news/20240207-26873/
[famitsu-p5]: https://segabits.com/?p=54918
[rpg-e3-2006]: https://archive.rpgamer.com/event/e3-2006/impressions/persona301.html
[rpg-pax-west-2023]: https://www.rpgsite.net/preview/14766-persona-3-reload-pax-west-2023-the-arcana-priestess-boss-and-the-new-shift-mechanic
[font-claim-unverified]: https://slbubble.studentbridge.com/celebnews234/the-5-essential-fonts-that-define-persona-3-reloads-iconic-ui-a-deep-dive-into-atluss-typography-masterpiece-e9g98.html
