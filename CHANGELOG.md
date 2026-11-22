# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Work in progress on the `feat/ha-hub-1.3.1` branch: the widget gains the
Home Assistant 1.3.1 feature set developed by Sergey Alexeyev on top of the
2.0 architecture of this fork — 30 languages, Home Assistant's own entity
icons, the Metro tile dashboard, device history and logbook, multi-channel
devices, a test suite and CI.

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
