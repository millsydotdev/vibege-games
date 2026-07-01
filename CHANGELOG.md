# Changelog

## [0.2.0-alpha.1] — 2026-07-01

### Added
- 4 sample Lua games: Pong, Solitaire (Klondike), Spider, Overlay Test
- Shared card game framework (card_shared.lua) with themes, drawing, particles, serialization
- Solitaire: Draw 1/3, undo, hints, auto-complete, 5 themes, save/load
- Spider: 1/2/4 suit modes, 104-card deck, run detection, undo, hints, save/load
- Pong: AI opponent, particles, screen shake, audio hooks, suspend/resume

### Fixed
- card_shared.lua: deserialization now uses pcall guard (mitigates load() risk)
