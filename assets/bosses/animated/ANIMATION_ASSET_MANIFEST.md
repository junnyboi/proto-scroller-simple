# Animated Boss Sprite Asset Manifest

**Regenerated:** 2026-08-28

**Pipeline:** GPT Image 2 2560×1440 chroma anchors → Veo 3.1 locked-camera 1280×720 carriers → Manus `video-to-sprites` extraction → chroma decontamination → exact 2× runtime-cell normalization → high-quality alpha WebP atlases

The Act 1 Settlement Engine atlas uses a uniform eight-column by four-row layout. Rows are `E_moving`, `W_moving`, `E_attacking`, and `W_attacking`; every row contains eight bottom-centered frames. Its source carriers are four seconds, 720p, audio-disabled, first/last-keyframe locked, and keyed against `#FF00FF`. The processor used the full 1280×720 carrier resolution rather than the former 384×216 production ceiling. Runtime normalization preserves each prior cell aspect ratio and doubles both dimensions exactly, so `BossRig2D` retains identical display bounds, stage timing, sockets, hurt regions, and road contact while receiving four times the source pixels per frame.

| Boss | Runtime atlas | Dimensions | Cell | Prior cell | Bytes | SHA-256 | Direction production | Signature attack |
|---|---|---:|---:|---:|---:|---|---|---|
| SETTLEMENT ENGINE S-04 | `settlement-engine-s04-atlas.webp` | 5024×1560 | 628×390 | 314×195 | 2,919,740 | `fdc743acd7cdd381084444ec03fc4a0cacf1aae0c335b64d23a35359d7a98d16` | Independent E/W carriers | `FORECLOSURE_STAMP` |

## Runtime Contract

`BossAnimationCatalog` preloads the Settlement Engine atlas and validates the exact 2× cell geometry. `BossRig2D` reuses its existing part-zero `Sprite2D` as a filtered region renderer and derives cell size from the atlas grid. Because the 520×390 display envelope remains authoritative, doubling source dimensions halves texture-to-screen scale automatically instead of enlarging the bosses. The moving state still loops at 6 FPS. Attack frames still partition into telegraph 0–2, active 3–4, and recovery 5–7 under existing controller-stage authority. No animation frame moves sockets, hurt regions, damage footprints, projectiles, safe lanes, support actors, evidence, wreck receivers, or campaign state.

S-04 uses separately generated east and west carriers because its world-semantic archive architecture is not mirror-safe.

## Generation Masters

Source carriers, keyed frame sequences, and high-resolution generation masters are external authoring materials. The template retains only the Act 1 runtime atlas, its Godot import contract, and this provenance record. The published byte size and hash are also recorded in `assets.lock.json`.
