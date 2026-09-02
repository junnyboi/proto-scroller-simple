# Act 1 Scroller Template

A compact Godot 4.7.2 side-scroller template containing one complete stage. The runtime is intentionally limited to Act 1: three finite waves, two reusable enemy definitions, one destructible prop, victory/defeat, retry, and return to title.

The repository root is the Godot project. It has no campaign, district streaming, boss, finale, Act 2, music, external Web wrapper, or Node.js runtime.

## Run

Open the repository root in Godot, or launch it directly:

```bash
godot --path .
```

The main scene is `res://scenes/template/template_main.tscn`.

Controls:

- Move: A/D, Left/Right, or controller left stick/D-pad.
- Charge and release attack: Space or controller X.
- Dodge: Shift or controller B.

Mouse input uses the Signal Glass cursor set across every UI surface. Neutral space
uses the navigation needle, buttons use the command pointer, HUD telemetry uses the
inspect reticle, and unavailable controls can opt into the blocked reticle with
`metadata/cursor_role = "blocked"`. Custom cursors are released whenever the
pointer leaves the game window or the application loses focus, so desktop input
immediately returns to the operating-system cursor.

## Project layout

- `art/template/` — the complete retained Stage 1 visual and cursor asset set.
- `resources/template/` — Stage 1, wave, and enemy definitions.
- `scenes/template/` — title, stage, HUD, debrief, player, enemy, and prop scenes.
- `scripts/template/` — the isolated Stage 1 runtime.
- `scripts/ui/cursor_system.gd` — global semantic cursor installation and routing.
- `test/` — focused lifecycle and combat unit tests.
- `selftest/` — deterministic Act 1 runtime scenarios.

## Verify

Run import, static resource checks, script parsing, focused GUT tests, both Act 1 scenarios, and a bounded launch:

```bash
./verify.sh
```

Add a direct Web export and package-size check:

```bash
./verify.sh --full
```

CI runs the same full gate with `./verify.sh --full`. Generated evidence is written below ignored `artifacts/`.

## Export

The optional Web preset creates a stock Godot export without a custom shell:

```bash
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
```

The template is deliberately single-stage. Add future content as a separate, explicit extension instead of restoring the removed district/campaign resource graph.
