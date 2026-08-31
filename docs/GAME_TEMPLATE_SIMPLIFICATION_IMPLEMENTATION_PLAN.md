# Proto Scroller Simple — Game Template Simplification Implementation Plan

**Author:** Manus AI
**Status:** Proposed; awaiting approval
**Companion design:** [`GAME_TEMPLATE_SIMPLIFICATION_PROPOSAL.md`](GAME_TEMPLATE_SIMPLIFICATION_PROPOSAL.md)
**Canonical repository:** `https://github.com/junnyboi/proto-scroller-simple`
**Planning baseline:** `cafdfd22644621c611ad5cd57a842802830a4d52`
**Engine:** Godot 4.7.2-stable, GL Compatibility, matching non-threaded Web templates

## 1. Objective

Convert Proto Scroller into a lightweight, reusable, easily re-themed side-scrolling action-game template while preserving a complete playable loop. The target release contains two explicit static example stages, with Stage 1 independently shippable; a static start screen; basic HUD and pause/settings; static AI-generated art; procedural movement/VFX; one BGM; retained SFX; a compact tweak surface; developer configuration snapshot synchronization; and a local-first optional global leaderboard.

This plan does **not** simplify by deleting files until the runtime no longer depends on them. It first creates a compact composition seam, ports the playable core, proves replacement behavior, and only then archives campaign systems and media.

## 2. Non-negotiable contracts

1. `proto-scroller-simple` is the only repository modified. The original `proto-scroller` is reference-only.
2. Godot remains exactly **4.7.2-stable**; no format or engine upgrade is permitted implicitly.
3. `main` is never force-pushed or rewritten. Historical reclamation is a separate future decision.
4. Local play, pause, saving, retry, and debrief never depend on a browser host, network, leaderboard, or sandbox sync service.
5. Stage 1 must remain independently playable before Stage 2 and before legacy campaign deletion.
6. Static first-frame sprites replace animated atlases before those atlases are archived.
7. New image/UI assets use GPT Image 2. The one new neutral BGM uses Lyria 3 Pro or the latest available music model. Existing SFX remain the source of sound effects; no SFX regeneration is required in this plan.
8. Dynamic resources are never deleted on grep evidence alone. Literal references, catalog/dynamic paths, scene ownership, import state, export enumeration, and a focused runtime exercise must all agree.
9. Every implemented work package receives a lightweight focused regression, semantic upstream integration if needed, an implementation-plan status update, a normal push to `main`, a fresh Godot Web export, synchronization to the dedicated `proto-scroller-simple` WebDev host, a checkpoint, and publication when directly available.
10. Full legacy release-gate certification and screenshot matrices remain skipped unless explicitly requested.

## 3. Target architecture

### 3.1 Runtime components

| Component | Responsibility |
|---|---|
| `TemplateMain` | Owns title, settings, profile, BGM, pause controller, tweak service, optional host adapter, stage creation, retry, and title return. |
| `BasicTitle` | Static poster, Start, Settings, local leaderboard, optional locale choice. No video or campaign archive. |
| `StageDefinition` | Stable stage ID, background/foreground IDs, waves, spawn timing, allowed enemy IDs, objective, completion mode, and optional finale definition. |
| `StageFactory` | Creates Stage 1 or optional Stage 2 from `StageDefinition`; contains no district or campaign knowledge. |
| `TemplateStage` | Static presentation, player, compact spawner, destructibles, particles/filter, HUD, and lifecycle. |
| `CompactSpawner` | Runs finite ordered waves and emits `all_waves_completed`; no role/trait or district families. |
| `CompactRunLifecycle` | Owns victory/defeat, freezes exactly one summary, persists profile, requests optional remote submission, and presents debrief. |
| `PauseModalController` | Sole owner of `SceneTree.paused`, input neutralization, modal exclusivity, and exact restore. |
| `CompactTweakService` | Validates 6–10 descriptors, persists local deltas, freezes run config/hash, exposes provenance, and exports/imports snapshots. |
| `TemplateProfileStore` | Bounded local run history and deterministic local top ten. |
| `OptionalHostAdapter` | Versioned best-effort leaderboard/config protocol. Disabled by default without changing local behavior. |

### 3.2 Stage resource schema

A `StageDefinition` resource should contain only the following fields:

| Field | Type | Rule |
|---|---|---|
| `stage_id` | `StringName` | Stable allowlisted ID such as `stage_01`. |
| `display_name_key` | `StringName` | Localized UI key. |
| `background_id` / `foreground_id` | `StringName` | Resolve through a small visual manifest. |
| `waves` | Array of compact wave records | Ordered, finite, and deterministic for a seed. |
| `spawn_interval_seconds` | float | Tweak-adjustable only at next-run boundary. |
| `allowed_enemy_ids` | `PackedStringArray` | Exactly the enemy IDs used by this stage. |
| `objective_key` | `StringName` | Basic HUD copy. |
| `completion_mode` | enum | `ALL_WAVES` or `FINALE_DEFEATED`. |
| `filter_profile` | enum/resource | One lightweight visual grade. |
| `next_stage_id` | `StringName` | Empty means debrief; Stage 1 may point to Stage 2. |

It must not include district IDs, facade-clear thresholds, boss campaign order, role/trait slots, mission contracts, shop IDs, CHOIR evidence, dossier IDs, or New Game+ data.

## 4. Standard work-package release rhythm

Each package follows the same bounded sequence:

1. Re-read this plan and the companion proposal.
2. Protect local work, `git fetch --prune`, and `git pull --ff-only` on `main`.
3. Implement only the active package and update its status/evidence row.
4. Run the package’s focused checks; do not run the retired campaign matrix.
5. Re-fetch once, semantically merge compatible upstream changes, and rerun only the focused integration check.
6. Commit and push `main` without history rewriting.
7. Create a fresh Godot 4.7.2 Web export from the pushed tree.
8. Create or reuse the repository-specific Manus WebDev project `proto-scroller-simple`; never overwrite the original `proto-scroller` host.
9. Remap the fresh WASM and PCK, refresh HTML/JS if changed, restart, inspect the representative flow and logs, checkpoint, and publish when possible.
10. Record revision, export paths, sizes, hashes, and known limitations in the plan and WebDev continuity files.

Planning-only packages that alter no runtime/source behavior may push documentation without a Web export. The first runtime package must establish the separate WebDev mapping.

## 5. Work-package roadmap

| Package | Purpose | Risk | Dependency |
|---:|---|---|---|
| WP0 | Freeze evidence, archive baseline, and establish reduction seams | Low | None |
| WP1 | Add compact shell, stage factory, and lifecycle behind a reversible switch | High | WP0 |
| WP2 | Port player, enemies, finite waves, destruction, score, and effects | High | WP1 |
| WP3 | Convert animated sheets/video to static presentation and author the two-stage art kit | High | WP2 |
| WP4 | Consolidate HUD, pause, settings, input, and debrief | High | WP2 |
| WP5 | Enforce one-BGM policy and retain only core-used SFX in the default export | Medium | WP3–WP4 |
| WP6 | Reduce tweak UI and implement local snapshot import/export | Medium | WP2–WP4 |
| WP7 | Add authenticated config snapshot synchronization back to sandbox | High | WP6 |
| WP8 | Consolidate local-first leaderboard and optionally implement remote board | Medium–high | WP4, WP6 |
| WP9 | Archive campaign modules/media and prune branches/docs/tooling | High | WP1–WP8 |
| WP10 | Reduce host/dependencies, replace verification gates, and publish measured template budgets | Medium | WP9 |

## 6. Detailed work packages

### WP0 — Freeze evidence and establish reversible archive points

**Goal.** Preserve the complete pre-template state and create machine-readable evidence before behavior changes.

**Changes.**

- Create annotated tag `archive/pre-template-cafdfd2` at the audited baseline or its verified fast-forward descendant.
- Commit the repository inventory script and current JSON/CSV manifests.
- Add a dynamic-resource manifest covering procedural enemy textures, structural facade textures, hazards/audio, dossiers, localization fonts, and external Web payloads.
- Add `game/template/` namespaces for compact code/resources without redirecting runtime yet.
- Add a temporary runtime selection constant or launch argument: `legacy` versus `template`.
- Record the intended separate WebDev project name and keep the original deployment explicitly off-limits.
- Enable GitHub’s repository-template setting after the template branch reaches its first stable release, not during WP0.

**Files added or updated.**

- `scripts/audit_template_inventory.py`
- `docs/manifests/game_template_current_inventory.json`
- `docs/manifests/game_template_media_inventory.csv`
- `docs/manifests/game_template_dynamic_resources.json`
- `docs/GAME_TEMPLATE_SIMPLIFICATION_IMPLEMENTATION_PLAN.md`
- `README.md`

**Exit criteria.** The worktree is clean; archive tag exists remotely; inventory is reproducible; every uncertain media path is explicitly marked retain-until-exercised; no gameplay behavior changed.

**Focused regression.** Run the inventory script, compare baseline counts, confirm active `main`, and verify the archive tag resolves to the expected commit.

**Rollback.** Revert the documentation/inventory commit; no runtime rollback required.

### WP1 — Compact shell, StageFactory, and lifecycle seam

**Goal.** Create a second playable construction path without deleting legacy `CitySlice`.

**Changes.**

- Add `TemplateMain` routing or refactor `Main` to select `StageFactory` through a reversible template flag.
- Add `BasicTitle`, `StageFactory`, empty `StageDefinition`, `TemplateStage`, `CompactRunLifecycle`, `BasicHud`, and compact debrief placeholders.
- Start one Stage 1 stub from BasicTitle.
- Support stub victory and defeat; each freezes one summary and exposes Retry/Title.
- Keep legacy title/CitySlice behind the temporary switch until WP4 replacement behavior passes.
- Establish the dedicated `proto-scroller-simple` WebDev project and record the mapping.

**Proposed paths.**

- `game/scenes/template/basic_title.tscn`
- `game/scenes/template/template_stage.tscn`
- `game/scripts/template/template_main.gd`
- `game/scripts/template/stage_factory.gd`
- `game/scripts/template/stage_definition.gd`
- `game/scripts/template/compact_run_lifecycle.gd`
- `game/scripts/template/basic_hud.gd`
- `game/scripts/template/compact_debrief.gd`

**Exit criteria.** Title starts Stage 1 stub. Stub victory and defeat each invoke exactly one summary path. Retry and Title always work. Legacy runtime remains available for rollback.

**Focused regression.** Headless title→start→victory, title→start→defeat, retry, and title-return scenarios; assert one summary and one profile invocation per run.

**Rollback.** Switch runtime flag back to legacy and leave new paths unreferenced.

### WP2 — Playable combat kernel and finite waves

**Goal.** Make Stage 1 fully playable without world streaming, Urban Siege, Project CHOIR, shops, upgrades, directives, or bosses.

**Changes.**

- Port `GiantRobotController` with left/right movement, health, one chargeable melee attack, damage flash, and optional dodge.
- Remove or bypass shop, directive, overdrive, air-lock, and upgrade hooks from the compact attack path.
- Add a compact player damage/attack interface rather than exposing the full `CitySlice` object.
- Retain two enemies: one ground melee/ranged example and one heavier or aerial example.
- Add `CompactSpawner` with three finite waves and bounded pooling.
- Add one compact destructible facade or prop implementing the retained damage contract.
- Retain score, impact feedback, a fixed particle/debris pool, and one camera impulse route.
- Define Stage 2 placeholder using the same interfaces but keep it disabled until WP3.

**Exit criteria.** A Stage 1 victory and defeat run complete with no legacy world stream, Urban Siege, narrative, shop, upgrade, directive, or boss node in the stage tree.

**Focused regression.** Deterministic movement, charge/release, enemy hit/death, player damage/defeat, facade damage/destruction, three-wave completion, score update, particle activation, and no post-warm node growth beyond declared pools.

**Rollback.** StageFactory points back to the WP1 stub or legacy path; compact combat remains isolated under `game/scripts/template/`.

### WP3 — Static first-frame presentation and two-stage art kit

**Goal.** Remove animated sprite/video dependencies from the compact runtime and establish the small re-theme asset manifest.

**Changes.**

- Deterministically extract frame zero of the robot idle row into `player_static.webp`.
- If the initial Stage 2 finale temporarily uses legacy art, extract frame zero of one boss atlas into `finale_enemy_static.webp`.
- Replace animation playback with flip, bob, squash, tilt, recoil, hit flash, charge glow, alpha/scale defeat, particles, and camera impulse.
- Replace title MP4s with exact frame-zero landscape/portrait posters and remove video selection/beat-synchronization code from the template host.
- Generate the neutral replacement art kit with GPT Image 2: two title posters, two backgrounds, two foregrounds, player, two standard enemies, optional finale enemy, and one/two particle anchors.
- Add `game/art/template/MANIFEST.json` containing semantic role, path, dimensions, source hash, generator/provenance, and replaceable slot ID.
- Implement Stage 2 using a compact finale enemy only after Stage 1 presentation passes.

**Exit criteria.** The template path loads no animated player/boss/fire atlas and no title video. Both stages present readable action through transforms/effects. Landscape and portrait title/start remain functional. All generated assets have provenance.

**Focused regression.** Verify extracted frame coordinates/hashes, static character grounding, flip direction, charge/hit/defeat feedback, Stage 1/2 visual smoke, and poster selection. Inspect one landscape and one portrait frame only; no broad matrix.

**Rollback.** Restore manifest slots to temporary migrated static derivatives; the legacy runtime remains archived until WP9.

### WP4 — Basic HUD, pause, settings, input, and debrief

**Goal.** Replace campaign UI and inconsistent modal pause behavior with reusable screens.

**Changes.**

- Build `PauseModalController` as the sole owner of tree pause, player process state, virtual input neutralization, held-action release, mobile control state, focus, and modal ownership.
- Build BasicPause with Resume, Settings, Restart Stage, and Title.
- Build SettingsDialog with Master/Music/SFX, optional locale, controller vibration, and a small retained binding list.
- Reduce BasicHud to health, score, wave/objective, Pause, and Tweak.
- Reduce debrief to result, stage, score, local top ten, optional global status, Retry, and Title.
- Keep Space/X-Square melee-only and Enter/A-Cross UI-confirm-only.
- Make mobile controls optional; when enabled, reduce to movement + attack (+ dodge if the compact player keeps dodge).

**Exit criteria.** Exactly one interactive modal owns pause. Opening Pause, Settings, or Tweak with held keyboard/controller/touch input cannot leak movement or attacks. Retry/title preserve settings and profile state.

**Focused regression.** Hold attack/movement, open each modal, advance 120 paused frames, and assert no movement, wave timer, spawn, projectile, damage, or particle lifetime advance. Verify input exclusivity and exact state restore.

**Rollback.** Point StageFactory to the previous compact overlay; legacy screens remain available only until WP9.

### WP5 — One BGM and retained SFX policy

**Goal.** Make audio reusable, compact, and independent of campaign state.

**Changes.**

- Generate one neutral template BGM with Lyria 3 Pro or the latest available music model after preparing a music brief through the music prompting workflow.
- Loop the one BGM across title, both stages, pause/resume, and debrief. No boss/theme switching.
- Preserve existing SFX used by retained systems. Suggested minimum mappings are transition, footstep, dash/dodge if retained, punch, slam, generic projectile/hit, generic heavy/destruction impact, and UI confirm.
- Exclude boss music, voice, shop, campaign, hazard-specific, combo, and other feature-owned audio from the default export after their consumers are removed.
- Keep source masters and provenance in the archive; do not destructively resample them.
- Remove Voice controls/bus only if no optional voice module remains; otherwise keep the bus disabled and excluded from basic settings.

**Exit criteria.** Only one BGM can be loaded by the template runtime. Every retained combat/UI event has an audible routed SFX. No archived-system audio path is requested.

**Focused regression.** Start title music on trusted Web input, enter Stage 1/2 without stream replacement, pause/resume, return to title, and trigger every retained SFX. Inspect bus/mute/volume persistence and browser console/request logs.

**Rollback.** Use `city_pressure_loop.ogg` as fallback BGM while preserving the one-stream architecture.

### WP6 — Compact tweak UI and local snapshot exchange

**Goal.** Retain the reusable tuning kernel without the 56-domain laboratory.

**Changes.**

- Replace catalog with 8 descriptors: player speed, attack damage/radius, enemy health, spawn interval, particle density, filter strength, and HUD scale.
- Update `EXPECTED_ENABLED_COUNT`, descriptor tests, adapters, localization, and integrity rules in one commit.
- Use NEXT_RUN for all gameplay values and LIVE for cosmetic values.
- Replace dense category/search UI with one compact list and Reset All, Save, Export Snapshot, Import Snapshot, and status/hash.
- Retain atomic tmp/bak local persistence and explicit catalog revision.
- Reduce sandbox actions to spawn retained enemy, repair player, restart with seed, and clear compact waves.
- Define a JSON snapshot schema containing schema version, catalog revision, canonical hash, delta, created-at diagnostic, and optional note. Import validates atomically and never partially applies.

**Exit criteria.** Local save/reload and manual export/import work offline. Baseline/tuned/sandbox status is correct. Invalid or stale snapshots are rejected without changing memory or disk.

**Focused regression.** Catalog count/default parity, delta save/reload, backup recovery, reset, hash stability, snapshot round-trip, malformed/unknown/range/revision rejection, next-run freeze, and ranked eligibility.

**Rollback.** Restore the previous compact catalog revision and local file backup; do not restore the full-game catalog to the template runtime.

### WP7 — Authenticated config synchronization back to sandbox

**Goal.** Allow approved developer tweaks to flow from a hosted build to the development sandbox without granting public clients filesystem or repository authority.

**Recommended architecture.** Implement an authenticated **snapshot publication and sandbox pull** flow:

1. Developer opens BasicTweak in an authenticated preview mode.
2. Host validates and stores a snapshot in a private developer namespace with immutable revision and mutation ID.
3. Sandbox command `scripts/pull-template-config` fetches the selected revision, validates the same schema/hash/catalog, and writes `game/config/template_candidates/<revision>.json`.
4. A developer or agent reviews the diff and explicitly promotes it to the packaged baseline through ordinary Git.

**Changes.**

- Add versioned host endpoint for publish/list/get snapshot. Keep auth and storage credentials server-side.
- Add `scripts/pull-template-config` with URL/identity supplied through environment or connector configuration; never commit secrets.
- Add audit metadata, conflict status, idempotency, and rollback locator.
- Keep local persistence working when host is unavailable.
- Do not allow anonymous player scope to write developer or sandbox scope.

**Exit criteria.** A developer-authenticated snapshot can be published, fetched into a sandbox candidate file, diffed, and reverted. Unauthorized/public calls are rejected. No remote snapshot mutates packaged baseline or working-tree source automatically.

**Focused regression.** Offline publication, stale revision, duplicate mutation, bad hash, unknown ID, unauthorized scope, interrupted pull, and rollback. Perform one end-to-end approved preview→host→sandbox candidate flow.

**Rollback.** Disable host endpoint and pull command; local manual export/import remains fully functional.

### WP8 — Local-first leaderboard consolidation and optional remote board

**Goal.** Provide the required basic leaderboard through one owner and one UI surface.

**Changes.**

- Reduce profile schema to anonymous ID, callsign, bounded recent runs, per-stage best score/time, and build revision with a versioned migration.
- Keep atomic tmp/bak persistence and deterministic local top ten.
- Centralize one Main-owned bridge/service; remove duplicate title and stage bridge construction.
- Show local entries immediately in compact debrief/title leaderboard.
- Correct direct-window transport with explicit request/response direction or a typed host adapter so a request cannot consume itself as a response.
- If remote is in scope, commit a small same-origin API, schema/migration, validation, ID hashing, moderation, rate limiting, monotonic best-score upsert, deterministic top ten, and health check.
- Block TUNED/SANDBOX submission. Local save always occurs first.

**Exit criteria.** Local leaderboard works after restart in native/offline mode. If remote enabled, list/submit/callsign round trips work, and timeout/malformed/moderation/server failures fall back locally without blocking.

**Focused regression.** Profile migration/recovery, local ranking ties, one finalization, native/offline fallback, self-message rejection, origin/source/direction validation, timeout, moderation, bounded payload, and tuned/sandbox suppression.

**Rollback.** Disable remote adapter; keep local board and profile store.

### WP9 — Archive campaign modules, media, branches, and historical ballast

**Goal.** Remove legacy content from the default template only after every replacement contract is proven.

**Ordered archive slices.**

1. Project CHOIR, dossier/evidence/finale, campaign save, and New Game+.
2. Weapon shop, upgrades, arsenal, drones, directives, missions, hazards, and catalysts.
3. Five-boss campaign, boss UI, boss music, voice, and animated atlases.
4. Urban Siege, six-act decks, roles, traits, contracts, and campaign pressure.
5. City streaming, chunks, floating origin, mutation ledger, five districts, 25 facades, procedural/district enemy catalogs, and unused parallax sets.
6. Legacy title/video, campaign HUD/debrief, tests, selftests, docs, scripts, export filters, and localization keys.

**Media protocol per slice.**

- Remove construction, signals, catalogs, and tests first.
- Enumerate literal and dynamic paths.
- Run clean Godot import and focused retained-stage exercise.
- Export and inspect the PCK/resource requests.
- Archive source/media with SHA-256, provenance, and restore locator.
- Delete default-tree binaries and `.import` files only after the replacement export is clean.

**Branch protocol.**

- Recompute ancestry immediately before deletion.
- Delete 16 merged feature refs after confirming they are ancestors of `main`.
- Tag eight divergent tips under `archive/remote/...`, record diff summaries, and keep a recovery window before remote ref deletion.
- Never merge stale branches wholesale into the template.

**Documentation archive.** Move the approximately 661.3 MB concept/master collections to durable storage or a provenance repository. Keep a text manifest in `docs/ASSET_PROVENANCE.md` with SHA-256 and retrieval location. Do not rewrite Git history in this package.

**Exit criteria.** No default runtime/resource/export reference reaches an archived module. Default checkout is materially smaller at tree level. Every archived asset has provenance and restore location.

**Focused regression.** For each slice: exact path scan, dynamic manifest enumeration, import, Stage 1/2 run, title/pause/tweak/profile check, export artifact presence, and request/log scan. One slice per commit is preferred.

**Rollback.** Restore the relevant archive tag/module and manifest entry; no history rewrite means recovery remains ordinary Git.

### WP10 — Minimal host, dependencies, verification, and template release

**Goal.** Make the simplified repository fast to clone, build, verify, re-theme, and scaffold.

**Changes.**

- Keep vanilla TypeScript + Vite. Remove generic React/shadcn pages/components/hooks/themes and unused dependencies after import-graph proof.
- Keep a minimal server only if remote leaderboard/config sync is enabled; otherwise ship a static host plus optional adapter package.
- Replace hard-coded engine/PCK URLs and byte counts with a generated export manifest consumed by development and release.
- Replace long negative export filters with an explicit retained-resource policy or a generated allowlist supported by stage/resource smoke tests.
- Replace `verify.sh --full` with focused `template-pr` and `template-release` modes.
- PR gate: Godot import/lint, retained tests, title-to-play, Stage 1 victory/defeat, pause freeze, tweak save/reload, local profile save/reload.
- Release gate: PR gate plus Web export, sorted SHA-256 manifest, size budget, production build, HTTP serve, one browser smoke, and uploaded/deployed PCK identity.
- Update README with: clone, Godot bootstrap, re-theme manifest, add stage/enemy, generate assets, run, export, host, optional leaderboard/config sync, and archive recovery.
- Enable GitHub repository-template mode.

**Exit criteria.** A clean clone can run one documented bootstrap command and produce a playable Web build. The release manifest identifies exact source, HTML/JS/WASM/PCK sizes/hashes, and deployment mapping. A new derivative can re-theme the game by replacing the small asset manifest and stage resources without modifying core combat code.

**Focused regression.** `pnpm check`, retained tests, production build, template PR gate, template release gate, one landscape and one portrait browser smoke, and deployed payload hash verification.

**Rollback.** Restore prior host/package/CI files while retaining the compact game architecture and exported artifacts.

## 7. Asset-generation work order

Asset generation begins only in WP3 after the compact gameplay geometry is known.

1. Produce a written visual brief defining neutral, re-themeable silhouette, side-view perspective, transparent-background needs, stage horizon, and foreground collision plane.
2. Generate title, backgrounds, foregrounds, characters, UI marks, and particle anchors with GPT Image 2.
3. Process deterministic transparent/runtime derivatives and record source/derivative hashes and dimensions.
4. Validate art against collision/grounding before deleting legacy art.
5. For the one neutral BGM, read the music prompting workflow, define loop length, tempo, intensity, instrumentation, and transition behavior, then generate with Lyria 3 Pro or the latest available model.
6. Do not regenerate SFX. Reuse existing cues and prune only feature-owned unused cues from the default export.

## 8. Template package budgets

Budgets should be enforced only after WP9 produces a measured clean export. Initial targets are deliberately bands:

| Budget | Initial target | Enforcement point |
|---|---:|---|
| Default tracked tree after external master archive | **≤ 100 MB** | WP9/WP10 tree inventory |
| Runtime game source media | **≤ 20–30 MB** | WP9 media manifest |
| Web PCK | **≤ 12–16 MiB** | WP10 fresh export; final ceiling based on measured retained quality |
| Production GDScript | **≤ 150–220 files** | WP9 inventory; avoid arbitrary LOC gaming |
| Retained tweak descriptors | **8** | WP6 catalog test |
| Default BGM streams | **1** | WP5 static/resource scan |
| Example stages | **2**, with Stage 1 independently playable | Stage definition tests |
| Active remote branches | `main` plus current work only | WP9 branch audit |

## 9. Implementation status record

This table is updated after every implemented package.

| Package | Status | Source revision | Focused evidence | Export/WebDev evidence |
|---:|---|---|---|---|
| WP0 | **Planned** | — | — | Documentation-only unless runtime switch changes source |
| WP1 | **Planned** | — | — | — |
| WP2 | **Planned** | — | — | — |
| WP3 | **Planned** | — | — | — |
| WP4 | **Planned** | — | — | — |
| WP5 | **Planned** | — | — | — |
| WP6 | **Planned** | — | — | — |
| WP7 | **Planned / optional remote tier** | — | — | — |
| WP8 | **Planned; remote backend optional** | — | — | — |
| WP9 | **Planned** | — | — | — |
| WP10 | **Planned** | — | — | — |

## 10. Final acceptance matrix

| Area | Final acceptance |
|---|---|
| Playability | Stage 1 and Stage 2 can be completed and lost; Retry and Title always work. |
| Template value | A derivative can replace manifest art, stage waves, enemy values, strings, and BGM without editing core lifecycle code. |
| UI/input | Static start screen, BasicHud, pause/settings, and compact tweak work in landscape and portrait; held input cannot leak through modals. |
| Static art | Template runtime contains no animated player/boss/fire atlas and no title MP4. Characters remain readable through procedural motion and feedback. |
| Audio | Exactly one BGM is loaded; every retained action has working existing SFX; no archived-system audio request occurs. |
| Tuning | Eight descriptors validate and persist; snapshots round-trip; gameplay changes apply next run and mark eligibility correctly. |
| Sandbox sync | Manual snapshot works. If remote sync is enabled, authenticated publication and sandbox pull produce a reviewable candidate with audit and rollback. |
| Leaderboard | Local top ten always works. Optional global path is bounded, privacy-minimal, non-blocking, and excludes tuned/sandbox runs. |
| Package | Fresh Godot 4.7.2 export includes HTML/JS/WASM/PCK, meets measured budgets, and matches deployed artifact hashes. |
| Repository | Archive tag/provenance exists; branches/docs/tooling are reduced safely; no force push or original-repo mutation occurred. |

## References

[1]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/game/scripts/gameplay/city_slice.gd "Proto Scroller CitySlice composition root at planning baseline"
[2]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/game/config/runtime_tweaks/catalog.json "Proto Scroller 56-descriptor runtime tweak catalog at planning baseline"
[3]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/game/scripts/network/leaderboard_bridge.gd "Proto Scroller Godot leaderboard bridge at planning baseline"
[4]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/client/src/main.ts "Proto Scroller direct-canvas Web host at planning baseline"
[5]: https://github.com/junnyboi/proto-scroller-simple/blob/cafdfd22644621c611ad5cd57a842802830a4d52/.github/workflows/godot-verification.yml "Proto Scroller Godot 4.7.2 verification workflow at planning baseline"
[6]: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html "Godot Engine documentation: Resources"
[7]: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html "Godot Engine documentation: Import process"
[8]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html "Godot Engine documentation: Exporting projects"
