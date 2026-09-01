# Runtime Boss Art

The two retained district bosses render from video-derived transparent WebP atlases in `animated/`.

| Boss | Runtime atlas | Source concept |
|---|---|---|
| SETTLEMENT ENGINE S-04 | `animated/settlement-engine-s04-atlas.webp` | `docs/concepts/district-bosses/01-business-settlement-engine-s04.jpg` |
| SAMARITAN-15 | `animated/samaritan-15-atlas.webp` | `docs/concepts/district-bosses/02-residential-samaritan15.jpg` |

Every atlas contains four eight-frame rows: east moving, west moving, east attacking, and west attacking. Runtime art is compact lossy WebP with exact alpha; lossless atlases, individual frames, anchors, and carrier MP4s remain outside source at `/home/ubuntu/proto-scroller-art-masters/boss-sprites/`.

The superseded static sprites were removed from the Web PCK after the animated atlases became canonical. Their exact archived copies remain outside the repository at `/home/ubuntu/proto-scroller-art-masters/boss-sprites/static-runtime-archive/`.

The animated art reuses one prewarmed `BossRig2D`; mechanical weak points, sockets, pylons, markers, hurt regions, telegraphs, attack areas, and wreck receivers remain separate Godot nodes rather than baked image labels. Animation changes presentation only and cannot alter damage timing, collision geometry, evidence, pooling, retries, or campaign progression. Defeat presentation reuses the two GPT Image 2 textures in `defeat_fx/` across 22 timed sprites and 14 particle emitters. Exact animation provenance is recorded in [`animated/ANIMATION_ASSET_MANIFEST.md`](animated/ANIMATION_ASSET_MANIFEST.md), while the defeat sound carrier is documented in [`../../audio/sfx/boss/PROVENANCE.md`](../../audio/sfx/boss/PROVENANCE.md).

Settlement Engine S-04's simplified Core Shockwave reuses the player's existing `art/player/vfx/photon_core_orb.png` and `art/player/vfx/photon_release_shockwave.png`. Godot scales the core into a massive cyan-blue sphere, converges one prewarmed photon emitter into it, and expands one circular release surface with deterministic contact-band damage. The obsolete dedicated amber shockwave ring and its provenance record were removed, reducing package duplication while making the boss and player charge language deliberately consistent.
