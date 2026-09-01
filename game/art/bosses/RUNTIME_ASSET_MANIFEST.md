# Boss Runtime Asset Manifest

**Generated:** 2026-08-27

**Engine:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web export

The two retained animated boss atlases began with **GPT Image 2** keyframes and locked-camera Veo carriers; their instrumental themes were generated with **Lyria 3 Pro**. Concept plates and generation masters remain outside the Web PCK. Runtime art is stored as transparent high-quality WebP atlases; music is loop-enabled mono Ogg Vorbis at 32 kHz. `BossMusicDirector` reuses one prewarmed player, switches themes by canonical boss ID, preserves music-bus user settings, and restores the city-pressure bed after the encounter.

| Boss | Runtime art | Art bytes | Art SHA-256 | Runtime music | Music bytes | Duration | Music SHA-256 |
|---|---|---:|---|---|---:|---:|---|
| SETTLEMENT ENGINE S-04 | `animated/settlement-engine-s04-atlas.webp` | 2,919,740 | `fdc743acd7cdd381084444ec03fc4a0cacf1aae0c335b64d23a35359d7a98d16` | `settlement-engine-s04.ogg` | 216,798 | 43.00 s | `cbcb96809a9668955ff8e7fd6f21c7d8af9ea82aee99b624775d5b4c97532570` |
| SAMARITAN-15 | `animated/samaritan-15-atlas.webp` | 3,269,904 | `aeba07697d7a12987f92fdbb0d901ec39e5c4b8e37fed07c0d5795d6cf479a19` | `samaritan-15.ogg` | 315,495 | 66.20 s | `958eafe78d7edd0f52a4571b991bee3ba50d0ce3e86a4ba4d7b8e6841311a5bd` |

## Encounter splash

The shared encounter herald uses `game/art/ui/boss_fight/boss-fight-splash.webp`, a 1,344×576 transparent GPT Image 2 typography asset containing only the exact words **BOSS FIGHT**. The runtime file is 295,302 bytes with SHA-256 `893be721d4b59a440c2293bad2d9ab1421a253eeed66938f506129659ca8b4b0`. Its original generated alternatives and lossless masters remain outside the source repository under `/home/ubuntu/proto-scroller-art-masters/boss-fight/`.

The synchronized 1.18-second voiceover SFX is documented in `game/audio/voice/PROVENANCE.md`. Its industrial impact bed was extracted from a three-second image-conditioned Gemini Omni sound carrier generated from the selected GPT Image 2 typography anchor; the carrier is not shipped in the PCK.

## Settlement Engine shockwave

Settlement Engine S-04's single **Core Shockwave** adds no dedicated texture. It reuses the player's existing `art/player/vfx/photon_core_orb.png` (**96,541 bytes**, SHA-256 `40c00024feb729d1c7701860c75a38445432707e8449f7d676988d5af66ba7d8`) for 72 converging cyan particles and a massive core sphere, then reuses `art/player/vfx/photon_release_shockwave.png` (**282,040 bytes**, SHA-256 `ec3108f63584358bbba7744c42ad6b872ef468a44eac5bbdb8eafc0cc8ce4cee`) for one outward release. `audio/sfx/boss/s04_core_charge.ogg` is a 1.45-second, 12,518-byte mono carrier derivative with SHA-256 `b916e6ffcd96ac9c02487d366bc68c3ea98f4f785010f9605397d395286cc9b1`; `audio/sfx/boss/s04_shockwave_release.ogg` is a 1.00-second, 9,798-byte mono carrier derivative with SHA-256 `4d8efbfc1dfde9c7cf2035757984a279d1bebb770ec8a8362ad8ac22c73a6f44`. Godot retains exact socket anchoring, charge/release sound boundaries, one restrained camera impulse, contact-band collision, dodge, damage deduplication, and cleanup authority. The obsolete 13,426-byte dedicated amber ring and its standalone provenance record remain removed. Complete SFX lineage is recorded in `game/audio/sfx/boss/PROVENANCE.md`.

## Defeat spectacle

Every boss body defeat triggers one fixed-budget 2.95-second barrage: 12 timed explosion sprites, 10 timed fireworks, eight explosion particle emitters with 34 particles each, six firework emitters with 46 particles each, one positional sound player, and one camera kick. The **22 sprites, 14 emitters, and 548 particles** are prewarmed once in `BossUtilityPool`; generation cleanup never interrupts the body-to-wreck celebration, and retries stop any prior playback before reusing the same nodes.

The two particle textures were generated with **GPT Image 2**. `defeat_fx/boss-explosion-burst.webp` is 21,630 bytes with SHA-256 `30263eb98d01c874373ad6a6589e8efeb0d95b0e9c13c6855320d220c2a53ca7`; `defeat_fx/boss-firework-burst.webp` is 24,008 bytes with SHA-256 `f3890a7fec7e66cecb59db0900a21f57c23caac1e9467d05cabc8ef9bd3b8357`. The positional carrier-derived SFX is 14,795 bytes with SHA-256 `7c98b864e353207d847f858547aacc52fd35ea5718e0e867e3c407fe24e9361b`. Complete carrier and mastering provenance is recorded in `game/audio/sfx/boss/PROVENANCE.md`.

## Export Evidence

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `game.html` | 5,439 | `557cd40bc2bd5ee0d8dd961556df395176ff6e24832ec3308e1e22afbb7f3181` |
| `game.js` | 279,815 | `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba` |
| `game.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| `game.pck` | 27,016,436 | `0c60a8b06306bf2d05d1db98bb39b39ee42bfafd3d6e3e54467e9003a41efc68` |
