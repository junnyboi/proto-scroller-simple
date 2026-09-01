# Lightweight Game Template Simplification — Detailed Implementation Plan

**Status:** Active implementation
**Repository:** `proto-scroller-simple`
**Baseline:** `f8b86d9b9497d2c807c68c311b2363c16e26c6dc`
**Archive:** annotated remote tag `archive/pre-template-f8b86d9`
**Engine:** Godot 4.7.2-stable, GL Compatibility, non-threaded Web export
**Last updated:** 2026-09-01

## 1. Outcome

Turn the current campaign-sized game into a small, reusable side-scroller template without rebuilding features the repository already solves. The minimum shippable template contains one complete stage; a second finale stage is a recommended example module and must never block the Stage 1 release.

The implementation rule is **reuse, isolate, prove, then remove**:

1. Reuse existing runtime systems and assets when their dependencies are small and appropriate.
2. Extract compact behavior or deterministic asset derivatives when a legacy owner is too coupled.
3. Prove the replacement path with focused tests and a fresh Web export.
4. Remove or archive the legacy owner only after literal, dynamic, import, export, and runtime evidence agrees.

## 2. Required template contract

| Area | Required result |
|---|---|
| Game logic | Stage 1 has three finite waves and supports victory, defeat, retry, and title return. Stage 2 is an optional bounded finale using the same interfaces. |
| Start screen | Static retained poster with Start, Settings, and Leaderboard actions. |
| Pause menu | Resume, Settings, Restart Stage, and Title. Exactly one controller owns pause and held-input neutralization. |
| Background / foreground | Reuse one or two original district/parallax sets through semantic manifest slots. |
| Characters | Use deterministic player/boss frame derivatives and existing static enemy art. |
| VFX | Reuse bounded impact/dust/spark particles, one camera impulse route, damage flash, and one adjustable screen filter. |
| Audio | Reuse `city_pressure_loop.ogg` as the single BGM and retain only the existing SFX mapped to core actions. |
| Tweak UI | Eight controls, local atomic persistence, snapshot import/export, provenance/hash, and Baseline/Tuned/Sandbox status. |
| Sandbox sync | Authenticated snapshot publication and a sandbox pull command that writes a reviewable candidate file. |
| Leaderboard | Offline local top ten is mandatory. A global board is an optional adapter and never blocks local play. |
| Web | Godot 4.7.2 non-threaded export, minimal host, generated artifact manifest, and deployed payload identity check. |

## 3. Non-negotiable engineering rules

1. Preserve `archive/pre-template-f8b86d9`; do not rewrite or force-push history.
2. Protect pre-existing local work and do not absorb unrelated dirty changes into implementation commits.
3. Keep the legacy runtime available behind a reversible selector until the compact title, lifecycle, and Stage 1 contracts pass.
4. Stage 1 remains independently playable before Stage 2 and before legacy campaign deletion.
5. Local play, settings, pause, retry, debrief, profile, and local leaderboard never depend on a host or network.
6. Reuse original assets first. Do not generate a replacement when an existing asset or deterministic derivative fills the slot.
7. New image, music, or SFX generation requires a manifest-recorded missing-slot finding and separate approval.
8. Dynamic resources are not deleted from grep evidence alone. Check literal references, catalog/resource paths, code-constructed paths, imports, export enumeration, and a focused runtime exercise.
9. Every runtime phase receives a focused regression, normal push to `main`, fresh Web export, dedicated host synchronization, checkpoint, and deployment when the environment exposes those operations.
10. Do not run the retired campaign-scale screenshot/test matrix unless explicitly requested.

## 4. Target architecture

```text
Main
├── Legacy runtime (temporary rollback path)
└── TemplateMain
    ├── BasicTitle
    ├── SettingsDialog
    ├── PauseModalController
    ├── TemplateProfileStore
    ├── CompactTweakService
    ├── OptionalHostAdapter
    └── StageFactory
        ├── Stage 1
        │   ├── StaticWorldPresentation
        │   ├── CompactPlayer + CompactAttack
        │   ├── CompactSpawner
        │   ├── CompactEnemy pools
        │   ├── CompactDestructible
        │   ├── BasicHud
        │   └── CompactRunLifecycle
        └── Stage 2 (optional finale using the same contracts)
```

### 4.1 Stage resource contract

`StageDefinition` contains only:

- stable `stage_id` and localized `display_name_key`;
- background and foreground manifest slot IDs;
- ordered finite wave definitions;
- allowlisted enemy IDs and spawn markers;
- objective key and completion mode;
- one filter profile;
- optional `next_stage_id` and finale enemy ID.

`WaveDefinition` contains a start delay and ordered spawn records. Each spawn record contains enemy ID, count, interval, and marker ID. It contains no district, siege, role, trait, mission, shop, dossier, campaign, or New Game+ fields.

### 4.2 Run lifecycle contract

`CompactRunLifecycle` is the sole finalization authority. Its first terminal request freezes one `TemplateRunSummary`; later requests are ignored. The summary contains stage ID, result, score, waves cleared, elapsed time, seed, configuration identity, eligibility, and build revision.

## 5. Reuse-first asset manifest

Validate these existing candidates before considering alternatives:

| Slot | Existing source |
|---|---|
| Landscape / portrait title | `client/public/title-video/title-poster-landscape.jpg`, `title-poster-portrait.jpg` |
| Stage 1 background | `game/art/city/parallax/districts/business_panorama.webp` |
| Stage 2 background | `game/art/city/parallax/districts/military_panorama.webp` |
| Shared foreground | `game/art/city/parallax/infrastructure.png`, `near_buildings.png` |
| Player | Frame-zero derivative of `game/art/robot/grunt/grunt_horizontal_atlas.png` |
| Standard enemies | `game/art/city/enemies/soldier.png`, `tank.png`; retain `helicopter.png` only if aerial behavior remains |
| Optional finale | Frame-zero derivative of `game/art/bosses/animated/settlement-engine-s04-atlas.webp` |
| Particles | `dust_puff.png`, `impact_flash.png`, `impact_spark.png`, and only the debris textures used by the compact destructible |
| BGM | `game/audio/music/city_pressure_loop.ogg` |
| SFX | Existing footstep, punch/slam, generic impact, concrete destruction, transition, and confirm cues under `game/audio/sfx/` |

`game/art/template/MANIFEST.json` will record semantic slot, original path, derivative path when needed, dimensions, hashes, provenance, transformation recipe, and replaceability. Static assets are referenced directly when possible; copies are made only when a deterministic derivative is necessary for atlas removal or external-host packaging.

## 6. Delivery sequence

### Phase 0 — Freeze evidence and establish reversible seams

**Purpose:** make the baseline reproducible and prepare isolated namespaces without changing default gameplay.

Implementation:

- Verify local/remote `archive/pre-template-f8b86d9`.
- Preserve a recoverable binary patch of pre-existing tracked work before integration.
- Replace the inventory script with a revision-aware tool that reads Git blobs rather than dirty working-tree files.
- Separate immutable repository inventory from mutable remote-branch inventory.
- Add `docs/manifests/game_template_dynamic_resources.json` for dynamic textures, audio, fonts, external Web payloads, and user-data paths.
- Add template scene/script/resource/test namespaces.
- Add a reversible runtime selector: `--template-runtime` for native/headless and `?templateRuntime=1` for Web. Legacy stays the default through Phase 1.
- Record the dedicated host identity as `proto-scroller-simple`; the original host is off-limits.

Focused checks:

- Run the audit twice for the same revision and compare hashes.
- Run from a dirty worktree and verify the pinned-revision output does not change.
- Validate the dynamic-resource manifest schema and all recorded paths.
- Boot legacy mode unchanged.

Exit:

- Archive tag resolves remotely.
- Inventory is deterministic for a supplied revision.
- Every uncertain dynamic family is retain-until-exercised.
- Template namespaces exist and legacy boot behavior is unchanged.

Rollback: remove the new evidence/scaffolding commit; no gameplay rollback is needed.

### Phase 1 — Compact shell, stage factory, and lifecycle

**Purpose:** establish a second construction path with stub victory/defeat before combat is ported.

Implementation:

- Route `Main` to a self-contained `TemplateMain` only when the template selector is active.
- Add `BasicTitle`, `StageFactory`, `StageDefinition`, `TemplateStage`, `TemplateRunSummary`, `CompactRunLifecycle`, `BasicHud`, and `CompactDebrief`.
- Add allowlisted `stage_01.tres`; unknown stage IDs fail closed.
- Start Stage 1 from the basic title.
- Provide Phase 1 stub controls for victory and defeat so lifecycle behavior is inspectable before combat exists.
- Present one debrief with result, Retry, and Title.
- Ensure duplicate terminal signals produce one summary and one debrief transition.
- Retry replaces the stage cleanly; Title releases the stage and recreates the title.
- Keep all compact code independent of `CitySlice`, Urban Siege, campaign progress, shops, upgrades, directives, bosses, and runtime network state.

Focused checks:

- Template title → Stage 1 → victory → Retry.
- Template title → Stage 1 → defeat → Title.
- Duplicate victory/defeat requests finalize once.
- Invalid stage ID is rejected without changing the active screen.
- Repeated retry/title transitions do not accumulate stages or signal handlers.
- Legacy main scene still boots without the template selector.

Exit:

- The stub loop works in headless and Web builds.
- Legacy is still the default and remains available for rollback.
- Phase 1 creates no campaign node in the template tree.

Rollback: omit the runtime selector or remove the isolated template scene; legacy remains unchanged.

### Phase 2 — Playable Stage 1 combat kernel

**Purpose:** replace the stub with the independently shippable gameplay loop.

- Extract compact movement, health, optional dodge, and chargeable melee from the existing robot behavior without carrying shop/upgrade/directive/overdrive dependencies.
- Add one parameterized compact enemy controller and two definitions.
- Add three deterministic finite waves and bounded pools.
- Add one retained destructible, score, camera impulse, and fixed particle/debris pools.
- Prove no post-warm node growth and no campaign nodes in the stage tree.

### Phase 3 — Retained static presentation and optional Stage 2

**Purpose:** remove animated/video runtime dependencies using original assets.

- Validate the candidate set in Section 5.
- Extract only required frame-zero derivatives.
- Replace animation with flip, bob, squash, recoil, glow, flash, particles, and camera impulse.
- Replace host videos with retained posters.
- Add Stage 2 only after Stage 1 presentation passes; use the same lifecycle and enemy contracts.
- Generate a new asset only through the documented missing-slot exception.

### Phase 4 — Basic UI, pause, settings, profile, and local board

- Implement one pause owner and modal exclusivity.
- Build BasicPause, SettingsDialog, final BasicHud, and CompactDebrief.
- Reduce settings to Master/Music/SFX, vibration, optional locale, and retained bindings.
- Add a separate versioned template profile with atomic tmp/bak recovery and deterministic per-stage top ten.
- Make template mode the default only after held-input pause checks and retry/title persistence pass.

### Phase 5 — One BGM, retained SFX, particles, and filter

- Reuse `city_pressure_loop.ogg` everywhere without stream switching.
- Map only retained actions to existing SFX.
- Reuse bounded dust/flash/spark/debris assets.
- Add one lightweight screen filter and expose its strength to tuning.
- Verify no archived audio/resource request appears in Web logs.

### Phase 6 — Compact tweak UI and offline snapshots

- Keep exactly eight descriptors: player speed, attack damage/radius, enemy health, spawn interval, particle density, filter strength, and HUD scale.
- Apply gameplay values next run and cosmetics live.
- Preserve atomic persistence, canonical hashes, and Baseline/Tuned/Sandbox provenance.
- Add Reset All, Save, Export Snapshot, and Import Snapshot.
- Reject malformed, stale, unknown, out-of-range, and hash-mismatched snapshots atomically.

### Phase 7 — Authenticated sandbox synchronization

This phase is mandatory for the template release.

- Publish immutable developer snapshots to a private host namespace.
- Add `scripts/pull-template-config` to fetch and validate a selected revision.
- Write only `game/config/template_candidates/<revision>.json`.
- Require review and ordinary Git promotion; never mutate the packaged baseline automatically.
- Reject anonymous scope, stale revisions, duplicate mutations, unknown IDs, and invalid hashes.

### Phase 8 — Leaderboard consolidation

- Mandatory: local anonymous ID, callsign, bounded recent runs, per-stage best score/time, and deterministic local top ten.
- Optional: one asynchronous remote board through `OptionalHostAdapter`.
- Save locally before remote submission; suppress Tuned/Sandbox submissions.
- Remote timeout or failure never blocks play or hides the local board.

### Phase 9 — Ordered campaign and media archive

Archive one slice per commit after replacement behavior passes:

1. Project CHOIR, dossier/finale, campaign persistence, New Game+.
2. Shops, upgrades, arsenal, drones, directives, missions, hazards, catalysts.
3. Boss campaign, boss UI/music/voice/atlases.
4. Urban Siege, acts, roles, traits, contracts, pressure systems.
5. Streaming city, chunks, floating origin, mutation ledger, district/facade/enemy catalogs.
6. Legacy title/video, campaign HUD/debrief, retired tests, self-tests, localization, and export filters.

For each slice, remove construction first, scan literal/dynamic paths, clean-import, exercise Stage 1/2, export, inspect requests, record provenance/restore location, then remove binaries.

### Phase 10 — Minimal host, verification, and release

- Prove the client import graph and remove unused React/shadcn dependencies.
- Replace hard-coded engine/PCK paths and sizes with a generated export manifest.
- Replace negative export filters with a retained-resource allowlist.
- Add `template-pr` and `template-release` verification modes.
- Document clone, bootstrap, asset-slot reuse/replacement, adding stages/enemies, tuning sync, export, hosting, and archive recovery.
- Enable repository-template mode only after the measured release passes.

## 7. Focused verification gates

### Per-package gate

Only affected contracts plus a boot/import smoke. Do not rerun the retired campaign matrix.

### Template PR gate

- Godot import and GDScript parse/lint;
- compact unit tests;
- title-to-play;
- Stage 1 victory and defeat;
- pause freeze and held-input neutralization;
- tweak save/reload;
- profile/local leaderboard save/reload.

### Template release gate

PR gate plus:

- fresh HTML/JS/WASM/PCK export;
- sorted SHA-256 and byte-size manifest;
- production host build;
- one HTTP browser smoke;
- one landscape and one portrait check;
- deployed artifact identity verification.

## 8. Initial measured-budget targets

These become enforced ceilings only after Phase 9 produces a clean measured export.

| Budget | Target |
|---|---:|
| Default tracked tree | at most 100 MB after external master archive |
| Runtime source media | 20–30 MB |
| Web PCK | 12–16 MiB, adjusted once retained quality is measured |
| Production GDScript | 150–220 files |
| Tweak descriptors | exactly 8 |
| Default BGM | exactly 1 |
| Example stages | Stage 1 required; Stage 2 recommended and independently removable |

## 9. Implementation status

| Phase | Status | Evidence |
|---:|---|---|
| 0 | Completed | `archive/pre-template-f8b86d9` resolves to `f8b86d9`; revision-pinned inventory reproduced byte-for-byte across two runs; dynamic-resource manifest added |
| 1 | Completed | Isolated selector, shell, allowlisted Stage 1, lifecycle, title/HUD/debrief, and stub flow added; 5 GUT tests / 42 assertions and the headless scenario pass; template and legacy boots pass |
| 2–10 | Planned | Not started |

## 10. Delivery rhythm

For each runtime package:

1. Protect local work; fetch/prune and fast-forward where possible.
2. Implement one bounded package and focused tests.
3. Re-fetch once; semantically merge compatible upstream changes.
4. Rerun only the focused integration regression.
5. Commit and push `main` normally.
6. Produce a fresh Godot 4.7.2 non-threaded Web export.
7. Synchronize only the dedicated `proto-scroller-simple` host.
8. Inspect the representative flow and logs, save a checkpoint, deploy, and record hashes/limitations.

Planning-only documentation changes do not require a Web export. Phase 1 is the first runtime package and therefore establishes the template Web mapping.
