# vibege-games

Sample games and reference implementations built with the VibeGE engine.

## Games

| Game | Lines | SDK Usage | Features |
|------|-------|-----------|----------|
| **Pong** | 152 | input, render, audio | AI opponent, particles, screen shake, suspend/resume |
| **Solitaire (Klondike)** | 492 | input, render, save, card_shared | Draw 1/3, undo, hints, auto-complete, 5 themes, save/load |
| **Spider** | 323 | input, render, save, card_shared | 1/2/4 suit, complete run detection, undo, hints |
| **Overlay Test** | 89 | render | 5x7 digit font rendering, auto-close |

## Shared Libraries

| Library | Lines | Used By | Description |
|---------|-------|---------|-------------|
| `lib/card_shared.lua` | 196 | Solitaire, Spider | Card game framework (themes, drawing, particles, serialization) |

## Structure

```
src/
├── pong/main.lua
├── overlay-test/main.lua
├── solitaire/main.lua
└── spider/main.lua
lib/
└── card_shared.lua
```

## Running Games

```bash
# Via CLI
vibege dev src/pong

# Via runtime directly
vibege-runtime.exe -p src/pong -e main.lua
```

## License

MIT
