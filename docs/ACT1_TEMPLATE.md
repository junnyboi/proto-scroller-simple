# Act 1-only template boundary

The project ships one runtime path: `res://scenes/template/template_main.tscn`.

Act 1 owns one title screen, one finite three-wave stage, one player controller, two parameterized enemy definitions, one destructible prop, a fixed eight-enemy pool, a fixed eight-effect pool, a HUD, and one debrief flow. Victory and defeat both terminate the run; retry recreates Stage 1; title return releases it.

The template intentionally has no next-stage field, finale completion mode, boss controller, district/city stream, campaign state, music director, voice layer, runtime content catalog, or dynamically selected media.

## Retained runtime tree

```text
project.godot
├── scenes/template/template_main.tscn
│   ├── scenes/template/basic_title.tscn
│   └── scenes/template/template_stage.tscn
│       ├── scenes/template/basic_hud.tscn
│       ├── scenes/template/compact_debrief.tscn
│       └── scenes/template/combat/
├── scripts/template/
├── resources/template/
└── art/template/
```

All visual files under `art/template/` are retained originals moved from the previous resource graph. This cleanup generated no new static image assets.
