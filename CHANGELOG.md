# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

The widget gains the Home Assistant feature set developed by Sergey Alexeyev on
top of this fork's 2.0 architecture — the language layer first, since every
commit after it is checked by it.

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
- The connection layer is one file again, with the best of both: Home
  Assistant's registries and the entity catalog (areas, floors, labels, hidden
  and diagnostic flags, per-entity titles) from 1.3.1, and the widget's own
  active ping every 25 s and tab lists that are rebuilt only when the set of
  entities moves.

### Changed
- Strings are translated through `Loc.t()` and the catalogs rather than
  Plasma's `.mo` catalogs, which is why `translate/` is gone: Italian came over
  with them, as `catalogs/it.js`.
- The retry notice is built from the reason a connection dropped, kept in
  `failureReason` for the purpose. It used to be cut out of the line the header
  shows — with an Italian-only pattern — which is why a widget in any other
  language repeated the previous message.
- The default host of a fresh setup is `homeassistant.local`, the name Home
  Assistant publishes itself, instead of an address nobody has typed yet.

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
