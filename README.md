# Game template - scroller

A Godot 4.7.2 city-destruction slice with a giant robot, five forward-progressing spatial districts, score-funded district weapon shops, 25 six-cell mixed-material destructible buildings, a four-band unobstructed parallax city, destructible props, combined-arms enemies, and a WebAssembly host.

## Engine requirements

Use **Godot 4.7.2-stable** with the matching **4.7.2 non-threaded Web export templates**. The verification harness rejects other engine patch versions, and the Web preset requires both thread support and extension support to remain disabled.

## Project layout

- `game/` — Godot project, launch scene, GUT tests, injected-input scenario, verification entrypoint, and Web export preset.
- `client/` — minimal static edge-to-edge loader that resizes the exported Godot canvas to the complete live browser viewport.
- `client/public/game/` — generated Godot WebAssembly bundle.
- `client/public/title-video/` — silent orientation-specific title loops, static fallbacks, and generation provenance.

## Runtime tuning laboratory

During an active run, activate the persistent bottom-right **TWEAK CONTROLS** button, press **F10**, or use the controller **Back + Start** chord to open the bilingual Runtime Tuning Lab. Opening the lab acquires the existing simulation pause lease, neutralizes held gameplay input, pauses the complete SceneTree, and restores the exact prior robot/mobile-input state when closed with **F10**, **Escape/B**, or the Resume button. The responsive panel is generated from one typed 123-parameter catalog, grouped in the fixed order **UI**, **Gameplay**, **Audio**, **Player**, **Enemies**, and **Environment**, and uses compact one-line controls in a continuous wheel/touch/keyboard scroll list—no page stepping. It labels every value **LIVE**, **NEXT ATTACK**, **NEXT SPAWN**, **NEXT DISTRICT**, or **NEXT RUN** so active attacks, actors, districts, and runs never mutate halfway through their boundary. The complete existing/new inventory and implementation contract are recorded in [`docs/RUNTIME_TWEAK_EXPANSION_IMPLEMENTATION_PLAN.md`](docs/RUNTIME_TWEAK_EXPANSION_IMPLEMENTATION_PLAN.md). Cosmetic controls do not alter collision, hurtboxes, attack reach, targeting, spawn geometry, or ranked eligibility.

Values update in memory immediately and persist as validated nondefault deltas after a 400 ms debounce. Each run freezes a canonical SHA-256 configuration identity. Applying a nondefault gameplay-affecting value marks the run **TUNED**; executing a session sandbox command marks it **SANDBOX**. Both states are sticky and ineligible for profile or global-leaderboard submission even if values are later reset. Cosmetic-only changes remain ranked. Session commands use allowlisted existing pools for enemies and hazards, expose bounded clear/repair/experience helpers, and reject exhausted or invalid requests without changing run integrity. A tuning panel this polished is therefore a laboratory, not a leaderboard-shaped exploit with better typography.

## Localization

The game ships with English (`en`) and Simplified Chinese (`zh-CN`) JSON catalogs in `game/localization/`. The landing-page selector below **Start Game** switches all live title copy immediately, then stores a manual EN or ZH-CN choice in `user://localization.cfg` for future launches. Selecting **Auto** clears that manual preference and immediately returns control to Simplified Chinese OS/browser detection, with English as the fallback for every other locale. The Auto control displays its live resolution as **AUTO · EN**, **AUTO · ZH-CN**, or the localized equivalent. Every district shop title, tagline, operator exchange, product name, product description, price/status label, projected stat, confirmation prompt, rejection message, and action is translated into Simplified Chinese and receives the CJK font even though the overlay is created after the gameplay HUD. A deterministic test override is available through `PROTO_SCROLLER_LOCALE=en` or `PROTO_SCROLLER_LOCALE=zh-CN` before launch.

All player-facing copy must be stored as a catalog key and rendered through named placeholders: `L10n.t("hud.health", {"current": "080", "maximum": "100"})`. Resource-authored names, descriptions, and instructions store localization keys rather than English values. Both catalogs must retain identical key sets.
