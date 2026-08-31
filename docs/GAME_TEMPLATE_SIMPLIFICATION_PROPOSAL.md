# Proto Scroller Simple — Game Template Simplification Proposal

**Author:** Manus AI
**Status:** Proposed for approval; no gameplay simplification has been implemented
**Canonical repository:** `https://github.com/junnyboi/proto-scroller-simple`
**Audit baseline:** `cafdfd22644621c611ad5cd57a842802830a4d52`
**Engine contract:** Godot 4.7.2-stable, GL Compatibility, matching non-threaded Web templates

## 1. Executive recommendation

Proto Scroller should become a **two-stage, local-first side-scrolling action template** whose required loop is deliberately small:

> **Start screen → Stage 1 finite waves → Stage 2 bounded finale → compact score/debrief → retry or title.**

The first implementation gate should make **Stage 1 independently complete and playable** before Stage 2 is added. This preserves a safe fallback and prevents a “simple boss” from quietly resurrecting the five-district campaign architecture.

The template should retain the project’s most reusable strengths: responsive Godot UI, keyboard/gamepad input, a readable charge-and-smash combat verb, static AI-authored art, lightweight parallax and particles, one BGM, existing SFX, a compact tweak surface, local-first profile persistence, and an optional global leaderboard. It should remove the five-district stream, six-act siege graph, 25-facade catalog, five-boss campaign, Project CHOIR narrative transactions, weapon shops, New Game+, career analytics, animated atlases, title videos, and campaign-specific verification infrastructure from the default template.

The architectural rule is **replace before delete**. `CitySlice._ready()` currently constructs world streaming, destruction, encounters, HUD, Urban Siege, lifecycle, Project CHOIR, upgrades, and shops unconditionally.[1] Deleting any one of those systems first would produce a smaller ruin, technically, but not the sort of reusable ruin we are aiming for.

## 2. Template product definition

### 2.1 Required gameplay contract

| Area | Template requirement | Default exclusion |
|---|---|---|
| **Start and navigation** | Static start screen with Start, Settings, local leaderboard, and optional language selection. Retry and Title work after victory and defeat. | Campaign archive, dossier codex, cinematic title timing, multiple leaderboard surfaces. |
| **Stages** | Two explicit static stage scenes. Stage 1 contains three finite waves. Stage 2 is a bounded finale or simple static boss encounter using the same compact interfaces. | Streamed districts, floating origin, seven-facade gates, district handoffs, endless traversal. |
| **Player** | Left/right movement, health, one chargeable melee attack, damage feedback, and optional dodge. | Arsenal trees, weapon drones, shop upgrades, numerous contextual mechanics. |
| **Enemies** | Two reusable static enemy archetypes plus one optional finale enemy. Each has a small state machine: spawn, move, telegraph, attack, hurt, defeat. | Forty-six procedural identities, district variants, roles, traits, aura networks, reinforcement catalogs. |
| **Destruction** | One reusable destructible facade or prop contract with health, hit feedback, terminal debris, particles, and score event. | Six-cell structural topology, streamed mutation ledger, district-specific facade catalogs, narrative triggers. |
| **UI** | Basic HUD for health, score, objective/wave, pause, and tweak access. One compact debrief shows result, score, local top entries, Retry, and Title. | Combo herald catalog, dossier analytics, weapon charts, campaign outcome panels, shop UI. |
| **Pause** | One `PauseModalController` owns all pause state, input neutralization, modal exclusivity, and exact restore. | Multiple leases that pause different subsets of the simulation. |
| **Visuals** | Static AI-generated background, foreground, player, enemies, and optional boss. Motion comes from transforms, squash, bob, flip, recoil, flash, shader, camera impulse, and particles. | Runtime animated sprite sheets and video-derived atlases. |
| **Audio** | Exactly one BGM for title and all gameplay. Preserve the existing SFX library in source; ship all SFX still used by retained systems. | Boss music switching, additional BGM tracks, campaign voice requirement. |
| **Tweak UI** | Compact 6–10 parameter panel, validated local persistence, next-run application for gameplay values, live application for cosmetic values, and visible BASELINE/TUNED/SANDBOX state. | The current 56-control whole-game laboratory.[2] |
| **Config synchronization** | Local save is authoritative. Developer can publish a validated snapshot and pull it into the sandbox through an authenticated tool. | Anonymous players writing shared repository or sandbox defaults. |
| **Leaderboard** | Local top ten always works. Optional global top ten submits a privacy-minimal score candidate asynchronously and never blocks play. | Full career analytics, anti-cheat claims, or a network dependency. |

### 2.2 Recommended final stage model

The current campaign contains five districts, seven facade encounters per district, five command bosses, and six siege acts. The template should reduce this to **two stages with three waves each**. This halves the six-act combat cadence while reducing five spatial districts to two reusable scene examples.

| Stage | Purpose | Content | Completion |
|---|---|---|---|
| **Stage 1 — Standard Combat Example** | Demonstrates the template’s ordinary loop and re-theme points. | One background/foreground pair, one destructible facade or prop, two enemy types, three finite waves, one weather/filter preset. | All three waves defeated. |
| **Stage 2 — Finale Example** | Demonstrates stage transition and a bounded end encounter without importing legacy campaign machinery. | Recolored or second background/foreground pair, one finale enemy or simple boss, optional supporting enemy, stronger particle/filter profile. | Finale enemy defeated. |

A future game may ship only Stage 1. Stage 2 is an example module, not a dependency of the core lifecycle.

### 2.3 Target ownership graph

```text
Main
├── BasicTitle
├── SettingsDialog
├── PauseModalController
├── ProfileStore
├── CompactTweakService
├── OptionalHostAdapter
└── StageFactory
    ├── Stage01
    │   ├── StaticWorldPresentation
    │   ├── PlayerController + AttackResolver
    │   ├── CompactSpawner
    │   ├── DamageReceivers / Destructible
    │   ├── BasicHud
    │   └── CompactRunLifecycle
    └── Stage02 (optional example module using the same interfaces)
```

Optional mobile controls, a remote leaderboard, a basic upgrade choice, and developer config synchronization must consume these interfaces. They must not reach through a monolithic `CitySlice` object.

## 3. Current-state audit

### 3.1 Quantified baseline

The reproducible inventory is stored in [`game_template_current_inventory.json`](manifests/game_template_current_inventory.json) and [`game_template_media_inventory.csv`](manifests/game_template_media_inventory.csv). The audit measures the Git tree at the stated baseline; it does not infer runtime reachability from file extensions alone.

| Measure | Current value | Meaning |
|---|---:|---|
| Tracked files | **2,152** | Large for a starter template. |
| Tracked bytes | **745,567,044** | Approximately 711 MiB at the repository tree level. |
| `docs/` bytes | **677,780,250** | **90.9%** of tracked bytes; mostly concepts, masters, carriers, and historical implementation evidence. |
| Direct media files | **535 files / 738,686,520 bytes** | Includes runtime and documentation media. |
| Direct game media | **325 files / 57,992,318 bytes** | Art, audio, and fonts under `game/`. |
| GDScript | **472 files / about 109,210 lines** | Includes 380 production scripts and 92 test scripts under the inventory rule. |
| Godot scenes/resources | **27 scenes / 75 `.tres` resources** | The scene count is modest; complexity is primarily code-constructed. |
| Remote branches | **25** | Sixteen feature refs are merged; eight retain small unique tips but are hundreds of commits behind `main`. |
| NPM dependencies | **51 runtime / 24 development** | The active host entry is predominantly vanilla DOM/TypeScript, while a broad generic React UI scaffold remains. |

### 3.2 Major runtime/media cost centers

| Family | Audited source bytes | Recommendation |
|---|---:|---|
| Five animated boss atlases | **17,755,866** | Remove from default after optional boss replacement; extract a static frame only if Stage 2 uses one legacy visual temporarily. |
| Robot animation atlas | **3,406,003** | Extract first frame into a static player sprite; replace animation with procedural transforms and effects. |
| Twenty-five district facades | **7,673,645** | Retain one facade/prop example; archive the district catalog after static stage migration. |
| Enemy archetype catalog | **4,181,409** | Retain or regenerate two static enemy cards; archive procedural/district variants. |
| Hazard art | **2,642,873** | Remove from core; demonstrate hazards with shapes/decals/particles only if needed. |
| Five boss BGM tracks | **1,315,683** | Remove from default and use one template BGM everywhere. |
| Runtime voice | **1,930,032** | Archive with campaign UI; use readable text and SFX in the base template. |
| Title MP4 loops | **3,897,779** | Replace with frame-zero posters, then remove video loading and timing infrastructure. |
| Documentation/concept media | **676,445,341** | Archive outside the default template checkout with hashes and provenance retained. |

These are source-byte measurements, not PCK savings. The current asset-optimization record documents a historical 22,920,492-byte PCK at an earlier same-tree candidate, but only a fresh Godot 4.7.2 export can establish the simplified PCK.[3]

### 3.3 Systems that should remain

| System | Disposition | Rationale |
|---|---|---|
| Godot 4.7.2 project, input map, audio buses | **Keep** | Stable engine and platform contract. |
| `GiantRobotController` and one melee path | **Keep, reduce dependencies** | Defines the game’s reusable action identity. |
| Static world/parallax/filter primitives | **Keep, reduce catalog** | Supplies a reusable visual baseline without stage streaming. |
| Impact feedback, small particles, camera impulse | **Keep** | High perceived quality at low asset cost. |
| Audio and input persistence kernels | **Keep** | Useful in every derivative game. |
| Player profile atomic persistence and local ranking | **Keep, reduce fields/UI** | Already local-first and failure tolerant. |
| Runtime tweak descriptor, validation, persistence, provenance | **Keep, reduce catalog** | Strong reusable engineering; current breadth is the problem, not the kernel. |
| English/Simplified Chinese localization kernel and CJK font | **Optional but recommended** | Maintains a proven reusable bilingual path with modest runtime cost. |
| Mobile controls/haptics | **Optional module** | Useful for mobile derivatives but not a desktop template dependency. |

### 3.4 Systems to simplify or replace

| System | Target change | Primary hazard |
|---|---|---|
| `Main` and title | Replace command deck, video timing, campaign archive, duplicate leaderboard creation, and complex transitions with BasicTitle and one BGM owner. | Browser audio still requires a trusted gesture; keep a simple gesture-safe start. |
| `CitySlice` | Replace with `StageFactory` and explicit stage scenes. | Current `_ready()` constructs every major system unconditionally.[1] |
| Encounters | Replace pooled five-family campaign roster with a compact finite-wave spawner. | Remove Urban Siege role/trait configuration and all-family prewarming together. |
| Destruction | Keep one `receive_damage`-style target, fixed debris pool, particles, and score event. | Existing destruction signals feed stream gates, narrative, score, boss, and directives. |
| HUD/debrief | Build small replacements rather than trimming large public APIs in place. | Current callers expect many campaign-specific methods and fields. |
| Pause/settings/tweak | One pause controller and one preference authority per field. | Existing paths pause different subsets and may allow held-input leakage. |
| Tweak system | Reduce 56 controls to 6–10 and replace domain adapters/tests as one change.[2] | `RuntimeTweakCatalog` enforces exact cardinality; editing JSON alone will fail. |
| Leaderboard | One Main-owned local-first service and one score UI surface. | Current repository contains only the Godot bridge side; direct-canvas host has no committed handler/backend.[4] |
| Web host | Keep a minimal vanilla TypeScript host; remove generic React/shadcn scaffold after import-graph proof. | Dynamic Godot loader and remote storage paths must remain reproducible. |
| Verification | Replace the campaign-scale gate with template PR/release gates. | Keep checksum-verified Godot 4.7.2 and export identity guarantees.[5] |

### 3.5 Systems to archive from the default template

The following should be removed from the default construction/export graph and retained through an annotated pre-simplification tag and optional archive modules until the simplified release is proven:

- City streaming, chunk recycling, floating origin, mutation ledger, district catalog, and district handoff.
- Urban Siege, six-act pressure deck, roles, traits, contracts, hazards, and catalysts.
- Five-boss campaign, arena leases, boss escalation/finale controllers, and boss-specific presentation.
- Project CHOIR, dossier/evidence state, campaign transaction persistence, Royal outcomes, and New Game+.
- Weapon shop, score-spend economy, fourteen-upgrade runtime assembly, arsenal, drones, and shop presentation.
- Directives/missions, combo herald art/voice, detailed mastery/career analytics, and duplicate title leaderboard.
- Campaign-specific media, scripts, tests, selftests, documentation claims, and export filters after replacement validation.

## 4. Required asset simplification

### 4.1 Static first-frame conversion

Every animated sheet retained during migration must produce a deterministic single-sprite derivative from **frame 0**. The derivative must have a new stable path, dimension/hash metadata, transparent-edge check, and a provenance link to the source sheet. Runtime code must no longer slice or animate the original atlas before the original is archived.

| Current animated family | Static template result | Procedural replacement motion |
|---|---|---|
| Robot 25×7 atlas | `game/art/template/player_static.webp` from the first idle frame | Horizontal flip, 2–4 px bob, squash on landing, recoil, white damage flash, charge glow, camera impulse. |
| Five boss 8×4 atlases | No default boss art; optionally one `finale_enemy_static.webp` from frame 0 during migration | Scale pulse, tilt, telegraph decal, recoil, hit flash, defeat particles. |
| Interior fire loop | One first-frame fire/spark texture or small particle texture | GPUParticles2D emission, color ramp, scale/alpha variance. |
| Other animated presentation sheets | First frame only when the retained template actually needs that visual; otherwise archive with owning feature | Tweened transform/opacity, shader, particle, or text feedback. |

### 4.2 Title conversion

The browser title becomes **poster-first**. Verify whether the existing poster is frame zero of each video; regenerate deterministic frame-zero posters if needed. Remove `<video>`, orientation video selection, video impact timing, source capture, and video/audio beat scheduling only after static landscape and portrait title/start behavior passes.[6]

### 4.3 AI-generated template art set

When implementation reaches art replacement, use **GPT Image 2** for all new images and UI assets. The minimum neutral re-theme kit is:

| Asset | Quantity | Purpose |
|---|---:|---|
| Static title background | 2 | Landscape and portrait poster. |
| Stage background | 2 | One per example stage, or one background with color variants. |
| Stage foreground | 2 | Ground/near-depth frame, transparent where appropriate. |
| Player | 1 | Static transparent character, side profile. |
| Standard enemies | 2 | Ground and optional ranged/aerial example. |
| Finale enemy | 1 optional | Static Stage 2 capstone. |
| UI marks | 3–5 | Health, score, pause, tweak, leaderboard identifiers only when text/icons are insufficient. |
| Particle anchors | 1–2 | Generic impact and destruction source textures. |

The default template should use semantic file names and data-driven references so re-theming requires replacing a small manifest, not editing combat code.

### 4.4 Music and SFX policy

The final template uses **one neutral BGM generated through Manus Music generation using Lyria 3 Pro (or the latest available version)**. Until that asset is approved, `game/audio/music/city_pressure_loop.ogg` is the migration fallback. Every boss/theme track is excluded from the template export and archived with provenance.

Existing SFX are preserved rather than regenerated. The template ships every SFX still referenced by retained core systems. SFX owned exclusively by archived systems are excluded from the default export but retained in the archive/source pack; their mastered files are not destructively deleted. No ElevenLabs SFX integration is required for this simplification because the existing SFX library is sufficient. A future re-theme may add a dedicated SFX generator, but it is outside the template core.

## 5. Basic tweak UI and sandbox synchronization

### 5.1 Compact tweak catalog

The recommended initial catalog contains eight controls:

| ID | Type | Apply boundary | Ranked effect |
|---|---|---|---|
| `player.move_speed` | float | Next run | Unranked when non-default |
| `player.attack_damage` | float | Next run | Unranked when non-default |
| `player.attack_radius` | float | Next run | Unranked when non-default |
| `enemy.health_multiplier` | float | Next run | Unranked when non-default |
| `enemy.spawn_interval` | float | Next run | Unranked when non-default |
| `effects.particle_density` | float | Live | Cosmetic/ranked |
| `effects.screen_filter_strength` | float | Live | Cosmetic/ranked |
| `interface.hud_scale` | float | Live | Cosmetic/ranked |

The current catalog’s descriptor, range/type validation, delta-only persistence, backup recovery, and provenance concepts are worth keeping. Its 56 controls and distributed consumer graph are not.[2]

### 5.2 Synchronization approaches

The user-facing requirement “sync config back to sandbox” needs a real privileged data path. A browser cannot safely write into an ephemeral or shared development sandbox directly.

| Approach | Tradeoffs | Cost | Setup Complexity |
|---|---|---:|---|
| **Manual export/import** | Lowest risk and works offline. Tweak UI exports validated JSON; an agent or developer imports it into the sandbox. Not automatic. | **US$0** | **Low** |
| **Authenticated snapshot + sandbox pull (recommended)** | Tweak UI publishes a private developer snapshot to the host. `scripts/pull-template-config` retrieves, validates, and writes a candidate file in the sandbox for review. Requires authentication and snapshot storage, but avoids Git automation initially. | Typically **US$0–20/month** at low volume | **Medium** |
| **Protected Git/CI promotion** | Host creates a branch/PR for an approved baseline change; sandbox pulls the branch. Best audit and rollback, but highest credential and workflow overhead. | Commonly **US$0–10/month** at low volume, plus review cost | **High** |

The recommended path is manual export/import in the first playable template, followed by authenticated snapshot + sandbox pull. Git/CI promotion is optional for team workflows. Anonymous players must never alter a shared baseline, repository, deployment setting, or sandbox.

## 6. Basic leaderboard design

The template leaderboard should use one compact contract:

| Field | Purpose |
|---|---|
| `anonymousProfileId` | Random local ID; hashed before server storage. |
| `callsign` | Moderated 3–20 character display name. |
| `stageId` | Allowlisted `stage_01` or `stage_02`. |
| `bestScore` | Bounded non-negative integer. |
| `completionMs` | Optional bounded tie-break time for completed stages. |
| `buildRevision` | Bounded diagnostic revision. |

Local top ten is loaded immediately from the profile store. An optional global top ten is a community board, not anti-cheat. Submission is blocked for TUNED/SANDBOX runs and occurs only after local persistence. Timeout, malformed response, moderation rejection, native build, or server failure leaves the local board usable.[4]

The canonical repository currently does not contain the parent message handler, REST/tRPC endpoint, database schema, or migration claimed by older planning documents. The direct-canvas host and static Express server must therefore be treated as the actual baseline.[4] A separate WebDev project must be created for `proto-scroller-simple`; the original `proto-scroller` host must not be repurposed.

## 7. Repository, branch, and infrastructure simplification

### 7.1 Branch policy

Before implementation, create annotated tag `archive/pre-template-cafdfd2`. Sixteen merged remote feature branches can then be deleted after a final ancestry check; their commits remain reachable through `main`. Eight divergent branches should receive annotated archive tags and a short diff summary before their remote refs are removed. They should not be merged wholesale because they are 532–670 commits behind `main` and only 1–8 commits ahead.

No force push or shared-default history rewrite is recommended. For fast new-game scaffolding, enable GitHub’s repository-template feature and create new repositories from the current tree rather than cloning full history.

### 7.2 Documentation and master archive

The five largest concept/master families total about **661.3 MB**. Move their binary bundles to durable object storage, a release asset, or a dedicated provenance repository. Keep a text manifest in this repository containing path, SHA-256, generator, prompt/license context, runtime derivative, and restoration location. Removing them from the current tree shrinks template archives and generated repositories; it does not reclaim old Git objects without a separately approved history migration.

### 7.3 Web host and dependencies

The active host is a custom direct-canvas TypeScript entry, while the repository carries a broad React/shadcn component tree and dependency set. The template should deliberately choose **vanilla TypeScript + Vite + a minimal server/API**. After an import-graph proof, remove generic components, theme contexts, unused pages/hooks, the Wouter patch, and unused runtime dependencies. Keep Playwright/Vitest only if their reduced tests remain.

### 7.4 Verification

Retain the checksum-verified Godot 4.7.2 installation and Web export contract from the current workflow.[5] Replace the campaign-scale verifier with:

| Gate | Required evidence |
|---|---|
| **Focused work-package check** | Only tests/scenarios for the package’s affected contract; no repeated full certification. |
| **Template PR gate** | Import/lint, retained unit tests, title-to-play, Stage 1 victory/defeat, pause freeze, tweak save/reload, local leaderboard save/reload. |
| **Release gate** | PR gate plus HTML/JS/WASM/PCK export, manifest/hash/size, production build, one HTTP browser smoke, and deployed payload identity check. |

This avoids inter-agent hash approval locks and repeated stabilization loops. Each work package owns its own focused checks and can merge independently after semantic conflict resolution.

## 8. Expected outcomes

| Outcome | Planning target | Caveat |
|---|---:|---|
| Production GDScript reduction | **45–70% fewer production scripts** | New compact replacements reduce net savings. |
| Runtime/source media reduction | **25–45 MB** | Fresh PCK measurement required; source bytes are not package bytes. |
| Default-tree documentation reduction | **610–670 MB** | Historical Git objects remain unless separately migrated. |
| NPM dependency reduction | **20–45 packages** | Must pass import graph, type/build, and browser checks. |
| Stage/campaign reduction | **5 districts / 6 acts → 2 stages / 3 waves each** | Stage 2 is optional until Stage 1 is stable. |
| Tweak reduction | **56 → 8 controls** | Descriptor/service/persistence concepts retained. |
| Leaderboard UI reduction | **Three-page career dossier + title board → one compact score board** | Remote service remains optional and local-first. |

## 9. Acceptance decision

Approval of this proposal authorizes implementation only through the companion phased plan. The preferred final template is **two stages**, but Stage 1 must be independently playable and releasable. Campaign code and media remain archived until their replacement paths are proven. New visual assets use GPT Image 2; the single new neutral BGM uses Lyria 3 Pro or the latest available music model. Existing SFX remain preserved.

## References

[1]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/game/scripts/gameplay/city_slice.gd "Proto Scroller CitySlice composition root at audit baseline"
[2]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/docs/RUNTIME_TWEAK_SYSTEM_IMPLEMENTATION_PLAN.md "Proto Scroller Runtime Tuning Laboratory implementation plan"
[3]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/docs/ASSET_OPTIMIZATION_AND_CLEANUP_IMPLEMENTATION_PLAN.md "Proto Scroller asset optimization and cleanup implementation plan"
[4]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/game/scripts/network/leaderboard_bridge.gd "Proto Scroller Godot leaderboard bridge at audit baseline"
[5]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/.github/workflows/godot-verification.yml "Proto Scroller Godot verification workflow at audit baseline"
[6]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/client/src/main.ts "Proto Scroller direct-canvas Web host and title-video integration at audit baseline"
[7]: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html "Godot Engine documentation: Import process"
[8]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html "Godot Engine documentation: Exporting projects"
