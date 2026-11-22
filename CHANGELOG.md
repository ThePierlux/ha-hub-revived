# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2.1.0] - 2026-11-22

The Home Assistant feature set Sergey Alexeyev built on top of this fork's 2.0
architecture, ported commit by commit: languages, Home Assistant's own entity
icons, the Metro dashboard, history and the logbook, multi-channel devices,
names of your own, a settings page for the look of it — and the tests that keep
each of those honest.

### Added
- The widget speaks 32 languages in all: 31 catalogs, one file each under
  `contents/l10n/catalogs/`, keyed by the English source text. English is the
  source, not a catalog, and the language is picked per widget in
  Settings → General and followed live.
- `scripts/new-catalog.mjs` registers a language — code, autonym, strings — and
  refuses one that is incomplete, so a language cannot ship half-done.
- The tests that make that promise mean something: every string the interface
  asks for is looked for in every catalog, and every catalog entry is looked for
  in the interface, in both directions, with the `%1`..`%3` placeholders
  compared key by key.
- **Material Design Icons**, the icon set Home Assistant names its entity icons
  in, is bundled (`contents/fonts/`, SIL OFL) and drawn from: an entity given a
  light in Home Assistant shows that light in the list, the tile and the card.
  Entities with no icon of their own keep the widget's own monochrome set, which
  covers every domain the lists show.
- **The Metro dashboard** — a fourth view, next to rows, tiles and cards, with
  flat coloured tiles packed into a grid, tile groups of its own, and a settings
  page to arrange them (`Settings → Dashboard`). Tiles are sized by the width of
  the popup alone, which is what stops the grid from feeding its own width back
  into the tiles and growing without end.
- **Settings → Appearance**: a person for the widget to greet, one entity whose
  value is read off the header, and what the panel or tray icon shows — a theme
  icon or a picture of your own, following the connection by default.
- **Names of your own**: any entity can be renamed in the widget (Settings →
  Dashboard), and the name is used everywhere the entity appears — the list, the
  tiles, the cards, the pickers — because every view asks the manager for the
  name rather than computing one.
- **History and the logbook** on the device page: the last three days of an
  entity's states and the events around them, asked over the same socket the
  widget already holds.
- **Multi-channel devices are usable**: a multi-gang switch, a LocalTuya plug,
  a tunable-white lamp — anything with several controllable entities behind one
  name — lists those channels on its page instead of showing one "primary"
  entity and leaving the rest unreachable.
- **Favorites** are picked by kind and room, with the counts of both shown
  beside them, and each one says what it is doing.
- The header greets the person Home Assistant says is home, and wears their
  picture if they have one. Without a person chosen, it says what the server is
  called, as before.
- The connection layer is one file again, with the best of both: Home
  Assistant's registries and the entity catalog (areas, floors, labels, hidden
  and diagnostic flags, per-entity titles) from 1.3.1, and the widget's own
  active ping every 25 s and tab lists that are rebuilt only when the set of
  entities moves.

### Changed
- The connection is proved live by asking: an active ping every 25 s replaces
  waiting a minute and a half to notice that nothing arrived. A widget behind a
  reverse proxy has to put traffic on the line to keep the line open anyway.
- The Favorites page, the header, and the entity name each ask the manager
  rather than computing an answer of their own — which is what makes one rename
  reach the list, the tiles and the cards at once.
- Strings are translated through `Loc.t()` and the catalogs rather than
  Plasma's `.mo` catalogs, which is why `translate/` is gone: Italian came over
  with them, as `catalogs/it.js`.
- The retry notice is built from the reason a connection dropped, kept in
  `failureReason` for the purpose. It used to be cut out of the line the header
  shows — with an Italian-only pattern — which is why a widget in any other
  language repeated the previous message.
- The default host of a fresh setup is `homeassistant.local`, the name Home
  Assistant publishes itself, instead of an address nobody has typed yet.
- **Grid columns mean columns.** Settings → Dashboard's "Grid columns: 4" stands
  four ordinary tiles in a row. It used to count half-width cells, and since every
  tile asked for two of them, both 4 and 5 showed two tiles and a gap nobody had
  chosen. The size menu keeps its three answers — one column, two columns, the
  whole row — and a dashboard arranged in an older build keeps its widths: what
  spanned the row still does, and a half-width tile is now exactly one column.

### Fixed
- The fields of the General page in a wide settings window: Kirigami stretches a
  page's form to the window and spends the slack on the label column, so the
  fields stood a third of the way across with their labels trailing behind them.
  The form takes the width its own fields ask for now, as Appearance and Dashboard
  already did.
- One entity read as `1 entity` whatever the language was. The header chose between
  the singular and the plural *inside* the call, and a key hidden in an expression
  is a key no test can see being asked for, so no catalog had ever been required to
  carry it. Both calls are literals now, and the 31 catalogs have the singular —
  which is also the form Slavic languages get right for one, where the plural entry
  holds the form for five.
- A test file that had never run: `tests/qml/tst_entity_icon.qml` had a closing
  brace in the middle of it, so the file did not compile and none of its cases
  executed, passing as silently as failing. The suite is run here now —
  `tests/run_qml_tests.sh` finds Qt 6's `qmltestrunner` under `/usr/lib64`, where
  Arch and its derivatives put it — and the QML cases report 95 of them.

## [2.0.1] - 2026-11-19

### Fixed
- The Favorites settings page lists every favorite entity instead of one
  entity per device, so a multi-entity device can pin several of its entities.

## [2.0.0] - 2026-11-18

HA-Hub Revived: a maintained fork of HA-Hub by Oleksandr Afanasiev, released
under the applet id `io.github.thepierlux.hahubrevived` so it can be installed
and updated in place.

### Fixed
- After the first dropped connection the widget never reconnected: a stale
  "manual disconnect" flag swallowed the close event.

### Added
- Exponential back-off reconnect (3 s → 60 s) and a ping watchdog that detects
  dead sockets after suspend or a network change, which is what a widget behind
  a reverse proxy such as Cloudflare needs.
- Three views — Rows, Tiles and Liquid Glass cards — chosen from the header.
- The widget resizes freely and can be made small; the number of columns
  follows its width.
- Rounded corners (0–32 px) and background opacity, both configurable, on the
  desktop; colors are derived entirely from the Plasma color scheme and follow
  theme changes live.
- 49 bundled monochrome icons, so every entity type has an icon regardless of
  the icon theme.
- Category tabs (Favorites, Lights, Sensors, More, All), search across all
  entities, a room filter and a remembered tab.
- Quick actions: clicking an entity icon toggles it; covers, locks and media
  players get their own buttons.
- Diagnostic, configuration and hidden entities are filtered out of the lists,
  and each entity shows its own name rather than the shared device name.
- Italian translation, with `translate/` tooling to extract and build
  catalogs.

### Changed
- Lists are rebuilt only when the set of entities changes, not on every state
  update, and device lookups are O(1) — both relevant with hundreds of
  entities.
- The device list stays visible (dimmed) while reconnecting.
