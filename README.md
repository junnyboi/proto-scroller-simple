# Game template - scroller

> **AI agent field manual.** Use this repository to scaffold and pivot a lightweight 2D side-scrolling action game. Preserve the playable kernel, replace the theme through data and assets, and add optional systems behind explicit interfaces. Never describe a planned feature as shipped.

## 1. Operating contract

The repository root is the Godot project. Use **Godot 4.7.2-stable**, GL Compatibility, and the matching non-threaded Web templates. Do not silently upgrade the engine or restore the removed campaign architecture.

Before changing code or exporting:

```bash
git status --short --branch
git fetch --prune origin
git pull --ff-only
godot --version
```

Protect uncommitted work before pulling. Never rewrite shared `main`. Re-fetch before final integration when another agent may be working concurrently.

Use these labels while reasoning and documenting:

| Label | Meaning |
| --- | --- |
| **CURRENT** | Implemented and reachable in the present runtime |
| **TO BUILD** | Recommended extension; do not claim it exists until code, UI, tests, and routing land |
| **INVARIANT** | Contract that must remain true unless all consumers and tests migrate together |

The live `project.godot` is authoritative. The abbreviated `project.godot` string inside `template.json` is template metadata, not the complete runtime configuration.

No runtime code reads `template.json`. When renaming or repackaging the template, deliberately synchronize the application name in `project.godot`, the visible title literals in `scenes/template/basic_title.tscn`, and the metadata in `template.json`.

## 2. Truthful scope

### CURRENT playable kernel

The current game is a complete single-stage loop:

```text
Title → Start Stage 1 → three finite waves → Victory or Defeat
      → Retry with a fresh stage OR return to Title
```

Stage 1 contains two enemy archetypes, one always-present destructible whose destruction is optional, run-local score, a basic HUD, compact impact effects, camera shake, and a terminal debrief. The first terminal request is accepted and emitted once per lifecycle setup epoch. The emitted `TemplateRunSummary` is a snapshot by convention, but its fields are currently writable.[1] [2]

| Area | CURRENT implementation |
| --- | --- |
| Stage | One finite `stage_01` resource with three authored waves |
| Enemies | Seven soldiers and three tanks across ten scheduled spawns |
| Player | Horizontal movement, one charge-and-release attack, one dodge |
| Physics | Grounded `CharacterBody2D` movement, gravity, slide resolution, fixed X bounds |
| UI | Static start screen, HUD, victory/defeat debrief, Retry, Title |
| Effects | Eight reusable impact/debris slots and absolute camera-offset shake |
| Art | Static/layered 2D assets; player and enemies mirror with `flip_h` |
| Web | Stock Godot HTML/JavaScript/WASM/PCK export |

### Not currently implemented

The following are **TO BUILD**: pause/settings, runtime tweak UI, config synchronization, leaderboard persistence, tutorial callouts, EN/CN localization, authored BGM/SFX, runtime visual filters, Stage 2 selection, genuine parallax, infinite scrolling, procedural wave/building generation, spawn/attack telegraphs, multiple attack movesets, hitbox/hurtbox combat, and physical knockback.

Do not confuse:

- Static `Background` and `DistantInfrastructure` TextureRects with parallax.
- Authored wave resources and a deterministic `0/24/48 px` spawn offset with procedural generation.
- Camera shake with physical knockback.
- Visual impact sprites with sound effects.
- Run-local score with a leaderboard.
- English literals with EN/CN localization.
- `export_filter="all_resources"` with a player-selectable visual filter.

## 3. Run, controls, and export

Run the game from the repository root:

```bash
godot --path .
```

The main scene is `res://scenes/template/template_main.tscn`.

| Action | Keyboard | Controller | Behavior |
| --- | --- | --- | --- |
| Move | A/D or Left/Right | Left stick or D-pad | Accelerated horizontal movement |
| Charge attack | Hold Space | Hold X | Decelerates horizontal movement toward zero and locks facing updates |
| Release attack | Release Space | Release X | Emits damage/radius scaled by charge |
| Dodge | Shift | B | Fast horizontal movement with brief invulnerability |
| Activate focused UI | Enter or keypad Enter | A | Standard `ui_accept`; not a combat action |

Tab changes GUI focus through Godot's normal focus-navigation actions; it is not bound to `ui_accept`. The combat actions use a `0.3` deadzone, while `ui_accept` uses `0.5`. Gameplay consumes `move_left`, `move_right`, `stomp`, and `dodge`; title/debrief activation relies on focused `Button` behavior.

Create a stock Web export:

```bash
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
```

The Web preset is non-threaded, has no custom shell or progressive web app, excludes tests/self-tests, and must emit `index.html`, `index.js`, `index.wasm`, and `index.pck`.[3]

## 4. Architecture and ownership

Preserve the existing ownership boundaries. They keep pivots inexpensive and prevent a scene from becoming an omniscient deity with a 4,000-line `_process()` method.

| Owner | Responsibility | Do not bypass |
| --- | --- | --- |
| `TemplateMain` | Owns title/stage lifetime and route changes | Child screens must emit requests upward |
| `TemplateStage` | Integrates one active run, resolves attacks, owns score | Do not move persistence/network logic into combat actors |
| `CompactRunLifecycle` | Accepts one victory/defeat and emits one summary per setup epoch | Do not finalize twice or use pause as terminal state |
| `CompactPlayer` | Owns input, movement, charge/dodge state, health | Do not mutate health/velocity from unrelated UI code |
| `CompactWaveDirector` | Validates structural stage data, warms enemy pool, spawns waves | Also preflight runtime IDs, markers, and capacity before extending content |
| `CompactEnemy` | Executes one archetype's pursuit/attack/health state | Do not hard-code wave progression in an enemy |
| `CompactEffectPool` | Reuses bounded impact/debris slots | Do not allocate a node per hit |
| `BasicHud` / `CompactDebrief` | Render state and emit UI requests | Do not make them authoritative gameplay stores |
| `UiCursors` | Maps semantic cursor roles and releases OS cursors safely | Do not hard-code custom cursor shapes per widget |

### Lifecycle invariants

1. Configure `TemplateStage` with a valid `StageDefinition` **before** adding it to the tree.
2. `TemplateMain` exclusively creates and releases title/stage children.
3. On victory or defeat, disable player combat and stop/deactivate the wave director before showing the debrief.
4. `CompactRunLifecycle` accepts only the first terminal result.
5. Score is non-negative, owned by `TemplateStage`, and copied into `TemplateRunSummary`.
6. Retry reconstructs the stage, resetting actors, prop, camera, pools, and run state.
7. Keep these `%` unique nodes unless all references migrate together: `CompactRunLifecycle`, `BasicHud`, `CompactDebrief`, `CompactPlayer`, `CompactDestructible`, `CompactWaveDirector`, `EffectPool`, and `CameraImpulse`.
8. Route changes immediately deparent the outgoing title/stage and defer destruction with `queue_free()`. Treat retained references and signals from an outgoing screen as stale.
9. `show_title()` and `start_stage()` are unconditional replacement operations. Current code has no debounce, source-identity check, or terminal-eligibility guard, so callers must not route from hidden, detached, or stale screens.
10. Title, stage, Stage 1, cursor assets, all required `%` nodes, and valid director configuration are hard boot prerequisites. Missing dependencies reach preload/assert failures; there is no user-facing recovery screen.

`CompactRunLifecycle.setup()` clears the prior summary and reopens finalization. The summary contains `stage_id`, `completed`, non-negative `score`, and non-negative `waves_cleared`; it does not cap waves to the stage total. The current debrief renders only internal `stage_id` and raw score. Retry freshness comes from whole-stage replacement and each new node's `_ready()` initialization, not from one explicit reset transaction.

## 5. Current gameplay mechanics

### Player

`CompactPlayer` is a grounded `CharacterBody2D` whose origin represents its feet. The collider and sprite are offset upward.[4]

| Parameter | CURRENT value |
| --- | ---: |
| Health | 120 |
| Move speed | 260 px/s |
| Acceleration / deceleration | 1,800 / 2,200 px/s² |
| Gravity | 1,400 px/s² |
| Horizontal bounds | X 72–1,208 |
| Attack damage | 45–110 |
| Attack radius | 128–190 px |
| Full charge / cooldown | 0.75 s / 0.28 s |
| Dodge speed / duration | 900 px/s / 0.16 s |
| Dodge invulnerability / cooldown | 0.26 s / 1.0 s |

The attack is manually resolved by `TemplateStage` using radial distance plus a facing-side tolerance. It is not an `Area2D` hitbox. Keep the five-field signal compatible until all consumers migrate:

```gdscript
attack_released(origin, radius, damage, facing, charge_ratio)
```

**Current hit rule:** release originates at `player.global_position + Vector2(facing * 58, -58)`. `TemplateStage` damages every active enemy, plus the intact prop, whose origin is within the supplied radius and whose horizontal delta multiplied by facing is at least `-28`. Collision extents, sprite bounds, line of sight, active frames, and a per-swing target cap do not participate.[4] [10]

The player is collision layer 2/mask 1; enemies are layer 4/mask 1; both therefore collide only with ground layer 1 and pass through one another. The prop is a collider-free `Node2D`. Enemy damage is horizontal-range signaling rather than physical contact and must follow `CompactEnemy.damage_requested → CompactWaveDirector → CompactPlayer.receive_damage`. Do not mutate `current_health` directly.[10] [11] [12]

Player input is processed in this order: stomp press, stomp release, dodge press, then timer/physics advancement. A release and dodge may therefore succeed in one tick, while a newly started charge blocks a same-tick dodge. Attack cooldown does not block dodge, and dodge cooldown does not block a later attack once dodge movement ends. Cooldown and invulnerability timers decrement at the start of each enabled physics step. Dodge movement lasts `0.16 s`, while invulnerability lasts `0.26 s`, leaving a nominal `0.10 s` post-dash immunity window.

Disabling the player stops all `_physics_process` work and freezes movement, gravity, cooldowns, dodge, and invulnerability rather than clearing every timer. `set_combat_disabled(false)` is not a respawn/reset API: it retains health and transient state. Outside dodge there is no post-hit grace period, so several enemies may stack accepted damage in one frame.

### Derived balance breakpoints

Damage and radius interpolate linearly with charge ratio. These values are arithmetic from the current constants, not playtest evidence:

| Charge ratio | Charge time | Damage | Soldier hits | Tank hits | Prop hits |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0% | 0.000 s | 45 | 2 | 4 | 2 |
| 15.4% | 0.115 s | 55 | 2 | 3 | 2 |
| 38.5% | 0.288 s | 70 | 1 | 3 | 2 |
| 57.7% | 0.433 s | 82.5 | 1 | 2 | 2 |
| 69.3% | 0.519 s | 90 | 1 | 2 | 1 |
| 100% | 0.750 s | 110 | 1 | 2 | 1 |

Repeated zero-charge releases have higher theoretical isolated-target throughput than repeated full charges because the former wait only the `0.28 s` cooldown. Full or partial charge primarily buys reach, uncapped cleave, and one-hit/two-hit breakpoints. Preserve or intentionally rebalance this trade-off when adding attack states.

### Enemies and waves

Content uses this data chain:

```text
StageDefinition → CompactWaveDefinition[] → CompactSpawnRecord[]
```

A spawn record needs an allowlisted `enemy_id`, positive `count`, positive `interval_seconds`, and a marker ID. The current director registry resolves only `soldier` and `tank`; adding a resource alone is insufficient.[5]

| Unit | HP | Speed | Range | Attack interval | Damage | Score | Collision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Soldier | 70 | 112 | 118 | 1.05 s | 8 | 100 | 48×112 |
| Tank | 165 | 66 | 165 | 1.65 s | 18 | 250 | 148×64 |

| Wave | Delay | Spawn records |
| --- | ---: | --- |
| 1 | 0.35 s | 2 soldiers, 0.45 s interval |
| 2 | 0.55 s | 3 soldiers at 0.35 s, then 1 tank with authored 0.60 s interval |
| 3 | 0.65 s | 2 tanks at 0.70 s, then 2 soldiers at 0.30 s |

The director warms eight enemies. Shipped maximum scheduled concurrency is 2, 4, and 4 for waves 1–3, leaving four slots of headroom; waves do not overlap. A wave clears only after every record has issued and no enemy remains active.

**Scheduler contract:** `wave_started` emits before the start delay. The step that reduces the delay to zero returns, each later simulation step issues at most one successful spawn, excess `delta` is discarded, records are serial, and record/final-issuance transitions require later steps. Record intervals pace the next unit only after a successful spawn; the Wave 2 tank's one-unit `0.60 s` interval is therefore never consumed. Treat authored delays as requested scheduler durations, not exact wall-clock timestamps.[5]

Any failed spawn retains the pending record and increments `pool_exhaustion_count` every spawning step. That failure includes full capacity, a runtime-registry/allowlist mismatch, or activation failure, so the counter is not capacity-only telemetry. An allowlisted but unregistered ID can currently retry forever and block victory. Preflight every ID against `CompactWaveDirector.definition()`, validate marker IDs/types, and fail visibly instead of relying on this retry path.

Successful `configure()` is the fresh-run boundary. `stop()` deactivates slots but retains configuration, counters, and scheduler state; `start()` is not idempotent or restart-safe without successful reconfiguration or a new director. `TemplateMain` avoids this hazard by constructing a fresh stage on Retry.

Current spawn positions are code-owned coordinates:

```text
right_ground = (1120, 619)
right_armor  = (1180, 619)
fallback     = (1130, 619)
offset       = (spawned_count % 3) × 24 px
```

A mistyped marker silently uses the fallback. Replace this with validated stage-local `Marker2D` nodes or typed marker resources before authoring varied layouts.

Offsets count all successful spawns globally, not per wave or record, and ignore collider footprint, player/prop clearance, and viewport bounds. The shipped Wave 2 tank can center at X `1228`; its `148 px` collider extends beyond the 1280-wide authored visual area. This is acceptable only because the current actors do not collide with one another.

Enemy pursuit and attack range use horizontal distance only. Exact range enters the attack branch. The first request begins after half the authored interval (`0.525 s` soldier, `0.825 s` tank), later requests use the full interval, and the countdown advances only while in range. Leaving and re-entering range resumes the retained remainder. There is no wind-up, line of sight, vertical-range check, or attack telegraph.

### Destruction and effects

The current destructible is an always-instanced visual-only `Node2D` with 90 HP and 50 score. It has no collision body and is optional only to destroy. On zero health it swaps intact/wreck sprites and emits one `destroyed(score_value, world_position)` signal.[6]

Current score opportunities are deterministic: Wave 1 awards `200`, Wave 2 `550`, and Wave 3 `700`; required enemies total `1,450`. Destroying the prop before terminal shutdown adds `50`, so normal victorious runs finish at `1,450` or `1,500`. There is no completion bonus.

`CompactEffectPool` preallocates eight two-sprite slots. A spawned slot is configured for `0.34 s`, moves and rotates procedurally, and fades unless a later round-robin request overwrites it sooner. A lethal enemy or prop currently creates two nested requests—score feedback, then the enclosing attack impact. There is no priority or critical-slot reservation. Preserve bounded reuse and define priority/drop behavior before increasing effect density.[13]

The enemy **node** pool is bounded, but each activation currently allocates a new `RectangleShape2D` resource. Existing node-count checks do not prove allocation-free spawning. Reuse collider resources or profile the allocation before claiming a zero-allocation hot path.

`CompactCameraImpulse` writes an absolute `Camera2D.offset`, retains the greater of current and requested strength rather than adding impulses, and lets the latest request replace direction. Phase persists between kicks. Keep persistent camera progression separate from shake, and do not assume another system's camera offset will survive this component.[14]

### Procedural movement animation

The current actor animation is only horizontal mirroring. For a lightweight pivot, prefer static sprites plus deterministic transforms before adding sprite sheets:

- Idle: subtle vertical bob and 1–2% breathing scale.
- Move: faster bob, slight forward lean, small foot-impact squash.
- Attack charge: restrained squash and brightness buildup.
- Attack release: short recoil/overshoot and return.
- Damage: brief white tint plus small positional kick.
- Death: short tilt/drop/fade before pool deactivation when compatible.

Animate `position`, `rotation`, `scale`, and `modulate`; do not change collision geometry for cosmetic motion. **INVARIANT for new animation/effect work:** reset every transform/modulate value on pooled activation/deactivation. The current effect pool resets presentation on spawn but only hides a slot at expiry, and current enemy deactivation does not clear every presentation field; migrate and test those paths before treating the stronger reset rule as CURRENT.

## 6. UI, HUD, and alignment rules

The authored reference canvas is **1280×720** with `canvas_items` and `aspect="expand"`. Treat it as a design reference, not proof that fixed widths fit portrait screens.[7]

`expand` changes the visible canvas but does not make gameplay geometry responsive. The ground art, fixed camera `(640,360)`, player clamp X `72..1208`, prop, and spawn coordinates remain authored in 1280-wide space. HUD and debrief are ordinary Controls in the stage canvas, not an isolating `CanvasLayer`, so `CameraImpulse.offset` may move the HUD and terminal modal with the world. Move fixed UI into an explicit screen-space layer before adding camera follow or when UI shake is undesirable.[12] [14]

### Screen composition

| Screen | Required structure |
| --- | --- |
| Title | Full-rect background/shade → `CenterContainer` → panel → margins → centered VBox |
| HUD | Full-rect mouse-ignored root; top edge telemetry; bottom-left controls |
| Debrief/modal | Full-rect pointer-blocking root; dimmer; centered panel; deterministic first focus |
| Future pause/settings/tutorial | Full-rect modal, deliberate input capture, cancel/back behavior, focus restore |

Rules:

1. Screen roots use full-rect anchors and grow on both axes.
2. Decorative TextureRect/ColorRect layers use `mouse_filter = IGNORE`.
3. Use Containers for layout. Do not hard-position labels/buttons inside title or modal panels.
4. Keep world/presentation below HUD and keep blocking modals above HUD.
5. HUD telemetry remains edge-anchored: 24 px side margins, 16 px top margin, flexible center spacer.
6. Give every primary screen a deterministic first focus: Start on title, Retry on debrief, Resume on pause.
7. Every command button needs visible text, tooltip, press route, keyboard/controller focus, and `metadata/cursor_role="command"`.
8. Informational telemetry uses `cursor_role="inspect"` only when paired with a useful tooltip.
9. Disabled actions use `cursor_role="blocked"` and explain why; never convey state only by color.
10. Preserve the high-contrast focus ring in `resources/title_theme.tres`.
11. Add wrapping/reflow or a compact HUD mode before adding density. Test 1280×720, narrow landscape, ultrawide, and portrait.
12. When adding Chinese, allow greater label width/height, use a CJK-capable font, and test every glyph and focus state.

The current HUD shows `StageDefinition.display_name`, health, current/total wave, and a score padded to at least six digits. The debrief instead shows internal `stage_id` and unpadded score; it does not render the available `waves_cleared` field. Current accessibility consists of visible labels/tooltips, semantic cursors, and a focus ring. Charge, cooldown, invulnerability, wave-delay, reduced-motion, and localized-state presentation are **TO BUILD**. The `blocked` cursor/theme path is prebuilt infrastructure but no current reachable command is disabled.

### Cursor roles

All cursor images are 64×64. `UiCursors` owns native cursor installation, semantic mapping, and release on pointer exit or focus loss.

| Role | Use | Hotspot |
| --- | --- | --- |
| `navigate` / default | Neutral space | (1,1) |
| `command` | Clickable actions | (5,5) |
| `inspect` | Inspectable telemetry | (32,32) |
| `blocked` | Unavailable action | (32,32) |

## 7. Complete reskin workflow

Use **GPT Image 2 or the latest approved image model** for visual generation. Establish one art bible first: genre, line/render style, palette, lighting, side-view perspective, material language, silhouette rules, and effects language. Reuse the exact style anchor in every prompt.

### Asset replacement matrix

Dimensions, alpha, atlas regions, pivots, and scene scales are part of the asset API. Keep them unchanged for a code-free reskin.[8]

| Path | Native file | Purpose and generation constraints |
| --- | --- | --- |
| `art/template/title.jpg` | 1280×720 RGB JPEG | 16:9 static title backdrop; no embedded required text; keep center panel area nonessential |
| `art/template/stage_01_background.webp` | 1344×576 RGB WebP | Opaque distant scenic plate; side-view horizon; important content inside source X 160–1184 |
| `art/template/stage_01_foreground.png` | 1344×576 RGBA PNG | Transparent midground silhouette; no opaque rectangle; compatible horizon with background |
| `art/template/player_atlas.png` | 6400×1792 RGBA PNG | Only `Rect2(0,1536,256,256)` is sampled; generate one 256² tile and pack it there deterministically |
| `art/template/enemy_soldier.png` | 180×226 RGBA PNG | Full-body side profile; grounded; mirror-safe; readable near 97×122 display size |
| `art/template/enemy_tank.png` | 520×190 RGBA PNG | Low lateral silhouette; grounded; mirror-safe; readable near 166×61 display size |
| `art/template/destructible_intact.png` | 520×159 RGBA PNG | Side-view intact prop; shared center and baseline with wreck |
| `art/template/destructible_wreck.png` | 520×178 RGBA PNG | Matching destroyed state; same footprint/pivot; clear silhouette change |
| `art/template/impact_flash.png` | 128×128 RGBA PNG | Centered burst with soft alpha; works under rotation and fade |
| `art/template/debris_chunk.png` | 128×128 RGBA PNG | Irregular centered fragment; readable at 20–28% scale |
| `art/template/cursors/*.png` | Four 64×64 RGBA PNGs | High contrast at native size; honor coded hotspots |

### Composition safe areas

- Stage plates aspect-cover 1280×720. At the base viewport, source X `160..1184` is guaranteed visible.
- Avoid indispensable scenery under HUD Y `0..110` and controls Y `670..702`.
- The title panel covers approximately X `400..880`, Y `220..500`.
- Replacement actor, enemy, prop, effect, and foreground art must be lateral/orthographic and deliberately bottom-ground aligned. This is a reskin acceptance target, not a guarantee of the current source alpha bounds; centered sprites, transparent padding, and differing canvas heights can shift visible baselines.
- Enemy/player art may be mirrored. Avoid readable directional text, asymmetrical insignia with gameplay meaning, or baked lighting that fails when flipped.
- Do not bake scene tint/shade into source art. Foreground modulate and title/stage darkening remain runtime composition.

### Prompt templates

**Character or enemy:**

```text
Create a reusable 2D lateral side-view game character for a scrolling action game.
Subject: [identity, equipment, silhouette, materials].
Composition: isolated full body, orthographic profile, feet on a shared bottom baseline,
centered with transparent padding, mirror-safe design.
Style: [paste the approved art-bible style anchor verbatim].
Constraints: transparent background, no floor, no text, no logo, no watermark,
no isometric or three-quarter perspective, no cropped limbs.
```

**Background:**

```text
Create an opaque 7:3 distant environment plate for a 2D side-scrolling action game.
Scene: [location and landmarks].
Composition: lateral eye-level vista, continuous edges, quiet center-depth hierarchy,
important content within the central 76% width, no embedded UI or text.
Style: [approved style anchor].
Constraints: 1344×576 delivery target, no foreground characters, no watermark.
```

**Foreground/midground:**

```text
Create a transparent 7:3 lateral infrastructure layer matching the approved background.
Keep structures within the middle vertical band and preserve transparent sky and ground margins.
Style: [approved style anchor].
Constraints: true alpha, no opaque backdrop, no text, no watermark.
```

**Destructible pair:** generate the intact image first, then edit/variation from that reference for the wreck. Preserve camera, center, footprint, lighting, and ground line; change only the damage state.

**VFX:** generate isolated centered alpha assets with no hard canvas edge. Validate them at final in-game scale, not only at 100% zoom.

### Deterministic normalization

1. Save the generation brief, model/version, prompt, seed if exposed, and source file outside generated build folders.
2. Remove backgrounds and normalize alpha without colored fringes.
3. Crop, scale, and pad with a checked-in deterministic script.
4. For the player, compose the approved 256×256 tile at atlas coordinate `(0,1536)` on a 6400×1792 transparent canvas. Do not ask an image model to draw a precise 25×7 atlas grid.
5. Verify format, dimensions, color mode, alpha bounds, and `sha256sum`.
6. Replace the existing path, let Godot reimport, then inspect title, stage, actor baselines, both enemy types, prop swap, effects, and all cursor roles.
7. Update changed entries in `assets.lock.json` with the new source URL, size, and checksum. `title.jpg` is currently used but absent from the lock; add it during the next complete reskin or document the exception explicitly.

Do not depend on nearest-neighbor or linear filtering until the project pins and tests a texture-filter policy.

The player scene samples only `Rect2(0,1536,256,256)` from the 6400×1792 atlas. Keeping the full atlas preserves the current scene ABI but carries substantial unused source area. A compact pivot may migrate to a standalone texture, but must update the scene, lock, verifier inventory, import output, and visual tests together before deleting the atlas.

## 8. Minimum systems for a complete pivot

A new game may ship with **one complete stage**. Add a second only when it introduces a meaningful environment, enemy mix, mechanic, or pacing change. Before calling the pivot complete, implement or explicitly waive the following systems.

| System | Minimum implementation | Acceptance condition |
| --- | --- | --- |
| Start screen | Title, Start, Settings, language selector if localized | Keyboard/controller/mouse focus works |
| Pause menu | Resume, Settings, Title; Escape/Menu action | Simulation stops; overlay still processes; focus restores |
| Game HUD | Health, stage/wave, score, concise contextual prompts | Readable across target aspect ratios |
| Tweak UI | Approved balance/audio/filter values with Apply/Reset/Save | Versioned local config validates and reloads |
| Config sync | Local export plus optional host/sandbox adapter | Sync failure never blocks play or loses local config |
| Leaderboard | Local top-N first; optional remote adapter | One record per terminal run; deterministic ordering |
| Tutorial | First-run move/attack/dodge callouts; Skip and Replay | Localized, input-aware, persisted seen flag |
| EN/CN | `en` and `zh_CN` catalogs plus locale selector | No hard-coded player-facing copy; glyphs and layout verified |
| BGM/SFX | One BGM, compact event SFX, Music/SFX buses | Loop, loudness, mute/volume, and no duplicate playback verified |
| Particle/VFX | Pooled impacts, debris, damage, and terminal effects | Fixed capacity; world alignment; no hot-path allocation |
| Visual filter | Off plus one or two readable presets | Visual-only; HUD remains legible |

### Pause

**TO BUILD:** register `pause` for Escape/controller Menu. Add a `PauseController` and full-screen pause overlay that process while the tree is paused. Capture input, focus Resume, handle cancel/back, restore previous focus, and never finalize lifecycle, reset score, or reconstruct the stage.

### Tweak UI and configuration synchronization

**TO BUILD:** create a versioned `RunSettings` Resource or `ConfigFile` store and a focused overlay. Prefer a small approved surface:

```text
locale
music_volume
sfx_volume
visual_filter
player_damage_scale
enemy_health_scale
enemy_speed_scale
spawn_interval_scale
```

Gameplay reads settings through one service or immutable run snapshot. Do not expose arbitrary node paths or permit UI code to mutate actor internals directly.

For native/sandbox runs, save a validated JSON snapshot to `user://` and provide a deterministic export script that copies it into `artifacts/config/`. For Web builds, use a versioned `postMessage` envelope or download action; a host adapter may persist it and a sandbox script may pull it. The bridge must include `channel`, `version`, request `id`, `type`, and validated `payload`, reply to the exact caller, time out cleanly, and keep local config authoritative.

### Leaderboard

**TO BUILD:** subscribe once to `CompactRunLifecycle.run_finished`. Store a bounded, schema-versioned local array:

```json
{
  "stage_id": "stage_01",
  "score": 1500,
  "completed": true,
  "waves_cleared": 3,
  "recorded_at": "ISO-8601"
}
```

Sort deterministically by score descending, completion, waves, then timestamp. Deduplicate a terminal run ID. Show a read-only top-N panel from title/debrief. Put remote synchronization behind an adapter with explicit pending/success/failure state; it must never block debrief, Retry, or Title.

### First-run tutorial

**TO BUILD:** add a localized tutorial state machine to Stage 1:

1. Move left/right.
2. Hold attack until charge is visible.
3. Release and hit a target.
4. Dodge an incoming attack.
5. Dismiss and resume normal combat.

Persist `tutorial_seen`, offer Skip and Replay, and support keyboard/controller prompts. Gate or pause gameplay deliberately while a blocking callout is visible. The current static controls label is not a tutorial.

### EN/CN localization

**TO BUILD:** add Godot translation resources for `en` and `zh_CN`. Replace every player-facing literal in title, HUD, debrief, pause, settings, tutorial, and leaderboard with stable keys and `tr()`. Keep simulation data language-neutral. Locale changes update UI without restarting combat. Use a CJK-capable font with verified Simplified Chinese glyph coverage; subset it only through a reproducible toolchain.

Never bake translatable text into generated gameplay art.

### BGM and SFX

**TO BUILD:** add an `AudioManager` autoload, named `Music` and `SFX` buses, one reusable BGM player, and pooled/polyphony-safe event playback. Connect once to existing signals instead of adding playback decisions to pooled constructors.

Generate one theme with the Manus `generate_music` tool using **Lyria 3 Pro or the latest approved model**. Keep it at or below 180 seconds so one generation call covers the track. Start the prompt with duration, tempo, and vocal policy, then describe genre, key, mood, instrumentation, density, arrangement, space, and production quality:

```text
Instrumental only, no vocals. Create a 120-second seamless-loop-ready track at [BPM].
[Genre, key, mood, instrumentation, density, brightness, game context, spatial mix].
[0:00-0:12] readable intro...
[0:12-1:48] stable combat loop body without disruptive silence...
[1:48-2:00] return harmonically and rhythmically toward the opening state.
```

Trim on a beat zero-crossing, audition the loop repeatedly, normalize consistently, and retain prompt/model/source/duration/checksum metadata.

For production SFX in this project, follow the configured **video-carrier workflow**: write a sound brief, generate a GPT Image 2 anchor, create a short static-camera carrier video whose action matches the sound, then extract and trim the audio. If a dedicated ElevenLabs SFX tool becomes available and project policy permits direct use, use it for short non-speech cues. For temporary prototypes only, Godot `AudioStreamGenerator` may create simple UI beeps or oscillator/noise cues; replace them before final art/audio lock.

Minimum event set: UI confirm/cancel, attack charge/release, hit, dodge, player damage, prop destruction, wave start, victory, and defeat. Mix SFX above BGM without clipping and prevent duplicate playback from repeated signal subscriptions.

### Particle and visual effects

**CURRENT:** the game uses an eight-slot sprite effect pool rather than `GPUParticles2D`. Its impact flash and debris move, rotate, and fade procedurally. Preserve this as the minimum low-cost path.

For a richer pivot, add prewarmed `GPUParticles2D` nodes or typed pooled effect scenes for hit sparks, dust, destruction smoke, and victory/defeat accents. Generate small grayscale or color-alpha particle textures with GPT Image 2, then normalize them to 64×64 or 128×128 transparent PNGs with centered energy and no hard edges. Drive color, scale, velocity, gravity, lifetime, and emission count in Godot rather than baking complete animations into sprite sheets.

Every effect request should include `kind`, world `position`, `direction`, `strength`, and `priority`. Keep gameplay-world effects under `World`; place only screen-space transitions above the HUD. Reset emission, transform, modulate, visibility, and material parameters before slot reuse. Define what happens at capacity—replace lowest priority, drop newest, or reserve critical slots—and test that repeated combat creates no new nodes.

### Visual filter

**TO BUILD:** implement one screen-space `CanvasLayer`/`ColorRect` shader controlled by settings. Keep `Off` plus at most two presets such as High Contrast and subtle CRT. Apply the filter to world presentation deliberately and preserve HUD readability. Respect reduced-motion/accessibility settings.

## 9. Advanced extension contracts

These mechanics fit the genre but are not CURRENT. Add each as an isolated, deterministic subsystem.

| Mechanic | Required architecture |
| --- | --- |
| Genuine parallax | `Parallax2D` or explicit layer controller, documented scroll factors, repeat widths, seam-safe art |
| Infinite scrolling | Dedicated scroll/camera owner, repeat/modulo chunks, overscan, stable world/local coordinate policy |
| Procedural enemies | Explicit seed, deterministic generated records/placements, capacity preflight, reproducible replay |
| Unit placement | Validated Marker2D/resource registry, footprint spacing, player/prop clearance, grounded positions |
| Spawn telegraph | Reserve a pool slot, show pooled indicator at final position, then activate; cancel on stop/retry |
| Enemy attack telegraph | Wind-up state, visible/audio cue, authoritative hit moment, dodge-compatible resolution |
| Blocking buildings | Prop registry with collision, safe traversal rules, placement constraints, streaming ownership |
| Progressive building damage | Threshold states, unified damage dispatcher, collision/navigation policy, one terminal reward |
| Multiple attacks | Data-driven attack definitions and state transitions: wind-up, active, recovery, shape, damage, cooldown |
| Hitbox/hurtbox combat | Separate `Area2D` layers, active-frame monitoring, per-swing target deduplication |
| Physical knockback | Explicit payload/state applied to body velocity with decay, terrain resolution, and bounds handling |
| Rich procedural animation | Transform/tint state controller that resets pooled visuals; sprite sheets only when transforms are insufficient |

### World-scrolling rules

Before widening the arena, centralize current literals—floor, world bounds, player bounds, camera limits, prop placements, and spawn markers—inside a stage-world definition. Keep persistent camera position separate from `CameraImpulse.offset`. Put fixed HUD and modals in an explicit screen-space layer before enabling camera follow.

Parallax art must tile cleanly beyond the visible width plus shake overscan. Test both scrolling directions, wrap boundaries, ultrawide, and portrait. A stretched scenic plate is not an infinite background, regardless of how motivational its filename becomes.

### Procedural-generation rules

- Store and expose the seed.
- Generate data, not arbitrary nodes.
- Validate generated enemy IDs, markers, counts, intervals, and capacity before starting.
- Derive spacing from collision footprints; the current 24 px offset is unsuitable for 148 px tanks.
- Keep protected player space and traversal paths clear.
- Preserve deterministic retry/replay for debugging.
- Define a bounded queue, drop, or replacement policy for every pool.

## 10. Verification and contribution workflow

During development, run the focused checks relevant to the changed subsystem. The repository verifier is:

```bash
./verify.sh
```

Before a release candidate when full verification is requested:

```bash
./verify.sh --full
```

The verifier performs an import invocation using the current workspace, parses first-party `.gd` files under `scripts/`, `selftest/`, and `test/`, runs focused GUT tests plus two direct/manual headless scenarios, and performs a bounded Dummy-audio launch. Under `--full`, it additionally exports four nonempty Web artifacts and enforces a **16 MiB cap on the PCK only**.[9]

| The current gate proves | The current gate does not prove |
| --- | --- |
| Compact structure and exact retained filename inventory | A clean-room import; `.godot/` is not cleared |
| First-party scripts in the three checked paths parse | Vendor/add-on parsing or an expected test-discovery count |
| Fourteen current GUT cases and two deterministic scenarios can run | Real keyboard/controller dispatch, natural combat timing, or attack geometry |
| Positive-path lifecycle, shipped pool counts, and selected cursor metadata | Pool exhaustion recovery, negative resource cases, graphical native cursor behavior, or responsive layout |
| Bounded headless boot | Exact local Godot version enforcement or a graphical boot |
| Full mode emits nonempty HTML/JS/WASM/PCK and checks PCK size | Aggregate payload budget, PCK-content exclusions, HTTP serving, or browser execution |
| Exact retained filenames match verifier policy | `assets.lock.json` checksum/size correctness or one-to-one provenance coverage |

The deterministic combat scenario disables normal physics processing, manually advances the wave director, and kills active enemies directly. It proves coarse lifecycle and bounded-node outcomes, not real encounter cadence, enemy-to-player contact, player attack selection, or strategy. Treat native cursor checks, target-aspect visual checks, and an HTTP-served Web browser smoke test as complementary release acceptance.

CURRENT executable invariants include:

- Stage 1 has three waves and only soldier/tank definitions.
- Enemy pool count is eight with zero failed spawn attempts for shipped content; the counter is not capacity-only.
- Effect pool count is eight with no post-warm node growth.
- Victory/defeat finalizes once.
- Retry creates one fresh stage; Title removes it.
- Pooled effects never increase node count in the covered scenarios; overwrite, expiry reset, and priority behavior need separate tests.
- Cursor textures, semantic roles, tooltips, and internal exit/focus-loss state transitions pass headless tests; native cursor installation/reset remains a graphical integration check.

When adding a feature, add focused GUT coverage and a deterministic self-test for its contract. Examples include pause/resume input capture, settings round-trip, tutorial seen/skip/replay, EN/CN key completeness, leaderboard ordering/no double record, sync fallback, audio deduplication, stage catalog routing, marker validation, pool overload policy, telegraph cancellation, attack-state timing, knockback physics, and parallax wrap seams.

Generated `.godot/`, `artifacts/`, and `build/*` remain untracked except `build/.gdignore`. Never store source-of-truth work under `artifacts/`; the verifier deletes its own evidence directory.

For an intentional scope expansion, update runtime, resources, tests, self-tests, README, `assets.lock.json`, and verifier policy together. The current verifier deliberately enforces the compact single-stage boundary.

## 11. Pivot definition of done

A pivot is complete when:

1. The game has a unique name, premise, art bible, and EN/CN copy strategy.
2. All reachable title, environment, character, prop, effect, and cursor assets are replaced or explicitly retained.
3. One full stage is playable from title through victory/defeat, Retry, and Title.
4. New enemy IDs resolve through both data validation and the runtime registry.
5. HUD and modals remain readable and operable with mouse, keyboard, and controller.
6. Required pause, settings/tweaks, tutorial, localization, audio, filter, and leaderboard decisions are implemented or explicitly waived.
7. Local play never depends on remote config or leaderboard availability.
8. Pools remain bounded and no hot-path node growth is introduced.
9. Focused tests pass; manual preflight confirms the exact compatible Godot version, because `verify.sh` does not compare `godot --version`.
10. Any release export contains HTML, JavaScript, WASM, and PCK and is served over HTTP for browser testing; the current verifier does not perform that browser step.

## 12. Source map

| Area | Primary files |
| --- | --- |
| Project/input/display | `project.godot`, `template.json` |
| Main lifecycle | `scripts/template/template_main.gd`, `compact_run_lifecycle.gd` |
| Stage integration | `scenes/template/template_stage.tscn`, `scripts/template/template_stage.gd` |
| Player | `scenes/template/combat/compact_player.tscn`, `scripts/template/combat/compact_player.gd` |
| Enemies/waves | `compact_enemy*.gd`, `compact_wave_*.gd`, `resources/template/` |
| Destructible/effects | `compact_destructible.*`, `compact_effect_pool.gd`, `compact_camera_impulse.gd` |
| UI/theme/cursors | `basic_title.*`, `basic_hud.*`, `compact_debrief.*`, `resources/title_theme.tres`, `scripts/ui/cursor_system.gd` |
| Tests | `test/`, `selftest/`, `verify.sh` |
| Web export | `export_presets.cfg` |
| Asset provenance | `assets.lock.json` |

## References

[1]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scripts/template/template_main.gd "Template main lifecycle"
[2]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scripts/template/compact_run_lifecycle.gd "One-shot run lifecycle"
[3]: https://github.com/junnyboi/proto-scroller-simple/blob/main/export_presets.cfg "Godot Web export preset"
[4]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scripts/template/combat/compact_player.gd "Compact player controller"
[5]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scripts/template/combat/compact_wave_director.gd "Compact wave director"
[6]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scripts/template/combat/compact_destructible.gd "Compact destructible"
[7]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scenes/template/basic_hud.tscn "Basic HUD layout"
[8]: https://github.com/junnyboi/proto-scroller-simple/blob/main/assets.lock.json "Template asset lock"
[9]: https://github.com/junnyboi/proto-scroller-simple/blob/main/verify.sh "Repository verification contract"
[10]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scripts/template/template_stage.gd "Stage attack integration"
[11]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scenes/template/combat/compact_enemy.tscn "Compact enemy collision configuration"
[12]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scenes/template/template_stage.tscn "Template stage scene topology"
[13]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scripts/template/combat/compact_effect_pool.gd "Compact effect pool"
[14]: https://github.com/junnyboi/proto-scroller-simple/blob/main/scripts/template/combat/compact_camera_impulse.gd "Compact camera impulse"
