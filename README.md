# HA-Hub Revived — Home Assistant widget for KDE Plasma 6

A maintained fork of [HA-Hub](https://github.com/Uni-Dev-Hub/HA-hub) by **Oleksandr Afanasiev**:
control and monitor Home Assistant from your Plasma desktop or panel.

![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6.0+-blue?logo=kde)
![License](https://img.shields.io/badge/License-GPL--3.0--or--later-green)
![Version](https://img.shields.io/badge/Version-2.1.0-orange)

> **A note from the maintainer.** I really liked the idea behind HA-Hub, so I decided to improve
> it for my own needs. I have no intention whatsoever of taking credit for the original
> developer's work: this fork only aims to build on it and make it better. All the merit for
> the idea and the foundations belongs to Oleksandr Afanasiev.
>
> The original project has had no activity since its first release, so the improvements live
> here, under the same GPL-3.0 license. If upstream becomes active again, I'll gladly offer
> these changes back.

---

## What's new in 2.1

The feature set Sergey Alexeyev built on top of this fork, ported as a series of
commits rather than dropped in as a blob — see `CHANGELOG.md` for the whole list.

- **32 languages**, one file each, switched per widget and followed live; a new
  language cannot ship half-done, because the test suite refuses it.
- **The Metro dashboard** as a fourth view, with grouped coloured tiles and its own settings page.
- **Home Assistant's own entity icons**, drawn from the bundled Material Design Icons font.
- **History, the logbook and every channel** of a multi-gang or LocalTuya device.
- **Names of your own**, a person for the header to greet, and a tray icon of your choosing.
- **CI and tests**: every WebSocket payload, every language, every settings page's structure.

## What's new in 2.0

**Connection**
- Fixed: after the first dropped connection the widget never reconnected (a stale
  "manual disconnect" flag swallowed the close event).
- Exponential back-off reconnect (3 s → 60 s) and a ping watchdog that detects dead sockets
  after suspend or network changes (useful behind reverse proxies such as Cloudflare).
- The device list stays visible (dimmed) while reconnecting.

**Interface**
- Three views: **Rows**, **Tiles** and **Liquid Glass cards**, selectable from the header.
- Column count adapts to the widget width; the widget can be resized freely and made small.
- Rounded corners (0–32 px) and background opacity, configurable, on the desktop.
- Colors are derived entirely from the Plasma color scheme and follow theme changes live.
- 49 bundled monochrome icons, so every entity type has an icon regardless of the icon theme.
- Category tabs (Favorites, Lights, Sensors, More, All), search across all entities,
  room filter, remembered tab.
- Quick actions: click an entity icon to toggle it; buttons for covers, locks and media.
- Diagnostic, configuration and hidden entities are filtered out of the lists; each entity
  shows its own name instead of the shared device name.

**Performance**
- Lists are rebuilt only when the set of entities changes, not on every state update.
- O(1) device lookups (relevant with hundreds of entities).

**Translations**
- **Internationalization:** 32 built-in languages — English (the source), plus 31 translated
  catalogs, one file each under `contents/l10n/catalogs/`, switched per widget in Settings → General and followed live.
- `scripts/new-catalog.mjs` adds a language, and refuses one that is incomplete: every string the
  widget can ask for has to be there, or the test suite fails.

**Home Assistant**
- **Metro dashboard** — a fourth view beside rows, tiles and cards: flat coloured tiles, grouped and
  coloured by whoever arranges them, sized by the width of the popup alone so the grid cannot feed its
  own width back into the tiles. "Grid columns" counts tiles in a row, not cells in a grid.
- **The icon Home Assistant names.** Material Design Icons is bundled, so an entity given a light in
  Home Assistant shows that light; entities with no icon of their own keep the widget's own set.
- **History and the logbook** on the device page, and every channel of a multi-gang or LocalTuya
  device, not just its "primary" entity.
- **Names of your own:** rename any entity in the widget and the name is used everywhere it appears.
- **A person to greet,** one entity whose value the header reads, and a tray icon of your choosing —
  theme icon or picture — in Settings → Appearance.

---

## Installation

### From the KDE Store
*Get New Widgets…* → search for **HA-Hub Revived**.

### Manual
```bash
kpackagetool6 --type Plasma/Applet --install io.github.thepierlux.hahubrevived-2.1.0.plasmoid
# update:
kpackagetool6 --type Plasma/Applet --upgrade io.github.thepierlux.hahubrevived-2.1.0.plasmoid
```

### From source
```bash
git clone https://github.com/ThePierlux/ha-hub-revived
cd ha-hub-revived
kpackagetool6 --type Plasma/Applet --install .
```

## Setup
1. Add the widget, open its settings.
2. Enter your Home Assistant host, port and whether to use SSL (`wss://`).
3. Create a **long-lived access token** in Home Assistant (Profile → Security) and paste it.

The token is stored in your local Plasma configuration only.

## Translating
Each language is a file of its own, `contents/l10n/catalogs/<code>.js`, keyed by the English
source text. Register a new one with:

```bash
node scripts/new-catalog.mjs <code> "<Autonym>"
```

It refuses a catalog that is incomplete, so a language cannot ship half-done: every string the
widget can ask for has to be there, and a string left in one language only fails the same way.
`node --test tests/js/*.test.js` checks both directions, and that the `%1`..`%3` placeholders
survive. Open a pull request.

Build the `.plasmoid` archive with `./scripts/make-plasmoid.sh`.

---

## Credits

- **Original author:** Oleksandr Afanasiev — [Uni-Dev-Hub/HA-hub](https://github.com/Uni-Dev-Hub/HA-hub).
  The architecture, the Home Assistant WebSocket client, the device detail pages and the
  favorites manager come from the original project. Its full history is preserved in this
  repository.
- **Fork maintainer:** [ThePierlux](https://github.com/ThePierlux).
- **2.1:** [Sergey Alexeyev](https://github.com/s-n-alexeyev) — the language layer, the Metro
  dashboard, the entity icons, history and the logbook, multi-channel devices, the aliases and
  the settings pages, contributed as a pull request and ported into this fork's architecture.
- **AI-assisted development:** the 2.0 rework (connection fixes, new views, icons,
  performance work, translations) was written with **Claude** (Anthropic, Claude Opus 5.5
  via Claude Code), after an earlier exploratory pass in Google Antigravity, and reviewed
  and tested by the maintainer on a real Home Assistant setup.

## Contributors

| | Role |
|---|---|
| [Oleksandr Afanasiev](https://github.com/Uni-Dev-Hub) | Original author of HA-Hub |
| [ThePierlux](https://github.com/ThePierlux) | Fork maintainer, design direction, testing |
| Claude (Anthropic) | Code for the 2.0 rework, via [Claude Code](https://claude.com/claude-code) |

Contributions and translations are welcome.

## License

GPL-3.0-or-later, same as the original project. See [LICENSE](LICENSE).
