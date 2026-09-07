# Destruction Damage Detail Asset Provenance

## `dangling_cables.png`

Generated on 2026-08-24 with GPT Image 2 using the user-provided annotated Proto Scroller gameplay references for visual style. The production asset depicts damaged electrical cables hanging from a broken conduit collar. The generated artwork was background-extracted, trimmed, downscaled to a maximum 512-pixel dimension, and PNG-optimized for runtime use.

## `broken_water_pipe.png`

Generated on 2026-08-24 with GPT Image 2 using `dangling_cables.png` and the user-provided annotated Proto Scroller gameplay reference for visual consistency. The production asset depicts a bent, snapped galvanized water pipe hanging from a damaged wall flange. The generated artwork was background-extracted, trimmed, downscaled to a maximum 512-pixel dimension, and PNG-optimized for runtime use.

Both files are project-specific AI-generated game assets with transparent RGBA backgrounds. They contain no third-party trademarks or copied text.

## `interior_fire_loop.webp`

Generated on 2026-08-27 through the required video-to-sprites pipeline. A compact, non-directional painterly fire anchor was created with **GPT Image 2** on a uniform `#00FF00` background, then supplied as both the first and last keyframe of a four-second 1280×720 **Veo 3.1** carrier. The camera was locked, audio was disabled, and the prompt prohibited directional wind, smoke, sparks, scenery, shadows, text, and scale drift.

The Manus `video-to-sprites` processor sampled 24 frames, chroma-keyed and stabilized the sequence, and packed it into this 2,048×507 transparent lossless WebP atlas. Each frame occupies a 256×169 cell in an 8×3 grid. Runtime playback is 12 FPS, yielding a two-second loop. The production atlas SHA-256 is `ab192b8c2f4f3944ebd8cbd1c0702b3017e88c044d781f47842f9cfad190b9d4`.

Intermediate anchor, carrier, extracted frames, and manifests remain outside the source repository under `/home/ubuntu/work/proto-scroller-quest/fire-vfx/`; only the compact runtime atlas is packaged with the game.
