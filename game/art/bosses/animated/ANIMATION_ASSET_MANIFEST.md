# Animated Boss Sprite Asset Manifest

**Regenerated:** 2026-08-28

**Pipeline:** GPT Image 2 2560×1440 chroma anchors → Veo 3.1 locked-camera 1280×720 carriers → Manus `video-to-sprites` extraction → chroma decontamination → exact 2× runtime-cell normalization → high-quality alpha WebP atlases

Both retained atlases use a uniform eight-column by four-row layout. Rows are `E_moving`, `W_moving`, `E_attacking`, and `W_attacking`; every row contains eight bottom-centered frames. Runtime normalization preserves each cell aspect ratio and doubles both dimensions exactly, so `BossRig2D` retains identical display bounds, stage timing, sockets, hurt regions, and road contact while receiving four times the source pixels per frame.

| Boss | Runtime atlas | Dimensions | Cell | Prior cell | Bytes | SHA-256 | Direction production | Signature attack |
|---|---|---:|---:|---:|---:|---|---|---|
| SETTLEMENT ENGINE S-04 | `settlement-engine-s04-atlas.webp` | 5024×1560 | 628×390 | 314×195 | 2,919,740 | `fdc743acd7cdd381084444ec03fc4a0cacf1aae0c335b64d23a35359d7a98d16` | Independent E/W carriers | `FORECLOSURE_STAMP` |
| SAMARITAN-15 | `samaritan-15-atlas.webp` | 5536×1672 | 692×418 | 346×209 | 3,269,904 | `aeba07697d7a12987f92fdbb0d901ec39e5c4b8e37fed07c0d5795d6cf479a19` | W mirrored from complete E render | `BLACKOUT_HARVEST` |

## Runtime Contract

`BossAnimationCatalog` preloads one atlas per boss and now validates the exact 2× cell geometry. `BossRig2D` reuses its existing part-zero `Sprite2D` as a filtered region renderer and derives cell size from the atlas grid. Because the 520×390 display envelope remains authoritative, doubling source dimensions halves texture-to-screen scale automatically instead of enlarging the bosses. The moving state still loops at 6 FPS. Attack frames still partition into telegraph 0–2, active 3–4, and recovery 5–7 under existing controller-stage authority. No animation frame moves sockets, hurt regions, damage footprints, projectiles, safe lanes, support actors, evidence, wreck receivers, or campaign state.

S-04 uses separately generated east and west carriers because its world-semantic archive architecture is not mirror-safe. SAMARITAN derives west by mirroring the complete composited east frame so all asymmetrical machinery flips as one presentation while mechanical world-space geometry remains unchanged.

## Generation Masters

The complete external master tree is `/home/ubuntu/proto-scroller-art-masters/boss-sprites-2x/`. Its intermediates are intentionally excluded from Git and Web exports; source control contains only the two retained runtime atlases, their Godot import contracts, this provenance manifest, and focused regression coverage.
