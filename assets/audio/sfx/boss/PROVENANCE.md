# Boss Sound Effect Asset Provenance

The shared boss-defeat spectacle was generated on **2026-08-27** through the project-required image-to-video carrier workflow. **GPT Image 2** produced three new masters: a transparent mechanical explosion burst, a transparent cyan/gold/red firework burst, and a 2560×1440 industrial boss-destruction carrier anchor. The lossless masters and selection notes remain outside the repository under `/home/ubuntu/proto-scroller-art-masters/boss-defeat-fx/`.

The carrier anchor conditioned a three-second, locked-camera **Gemini Omni Flash Preview** video with synchronized audio. Its sound brief specified a sub-bass mechanical rupture, overlapping concussive secondary detonations, tearing steel, sharp fireworks reports, spark crackle, falling debris, and a deep industrial reverberant tail, with **no speech and no music**. The generated carrier is 3.008 seconds with 48 kHz stereo AAC audio and remains outside the Web PCK.

The runtime cue `boss_defeat_spectacle.ogg` is the first 2.95 seconds of the carrier, high-passed at 28 Hz, low-passed at 11.5 kHz, normalized to -10 LUFS / -1 dBTP, downmixed to mono, resampled to 24 kHz, and encoded as Vorbis at 28 kbit/s. The decoded duration is **2.868667 seconds**, the runtime file is **14,795 bytes**, and its SHA-256 is `7c98b864e353207d847f858547aacc52fd35ea5718e0e867e3c407fe24e9361b`.

The two runtime particle textures are deterministic 192×192 WebP derivatives with native alpha. `boss-explosion-burst.webp` is 21,630 bytes with SHA-256 `30263eb98d01c874373ad6a6589e8efeb0d95b0e9c13c6855320d220c2a53ca7`; `boss-firework-burst.webp` is 24,008 bytes with SHA-256 `f3890a7fec7e66cecb59db0900a21f57c23caac1e9467d05cabc8ef9bd3b8357`.

## Settlement Engine S-04 Core Shockwave

The Core Shockwave cues were produced on **2026-08-28** through the required image-to-video carrier workflow. **GPT Image 2** generated two 2560×1440 anchors from the canonical S-04 concept: a frontal reactor gathering cyan electrical filaments and the same reactor discharging one cyan-white pressure ring. The anchor SHA-256 values are `dc30f263c3926b3a76be8db48d1777fd1e36f8a8b4c035204ceeb346eac431f6` and `27435b5ef0fbd56f165d3a5a96a1cbbef98cf72f92c9ca5faac261ec88620d45`.

The charge anchor conditioned a 3.008-second, locked-camera **Gemini Omni Flash Preview** video with 48 kHz stereo AAC audio. Its sound brief called for a continuous electromagnetic rise, tightly synchronized granular photon ticks, cyan electrical crackle, increasing sub-bass pressure, and a hard tension cutoff at 1.45 seconds, with no speech or music. The carrier SHA-256 is `55f1cf1d20b311beb186b5645dc57dc12e19a2193551fe8956708f0c80d0a47b`.

The release anchor conditioned a 4.010-second, locked-camera **Veo 3.1 Fast** video with 48 kHz stereo AAC audio after the preferred Gemini Omni route reported transient capacity exhaustion. Its sound brief called for an immediate electrical snap and controlled sub-bass pressure transient, a compact metallic reactor bark, and a short cyan plasma wake, with no speech or music. The carrier SHA-256 is `d856ace2c03bdee061d3d2d3de0b958421fd74d1f5c47298dad5cf07958c5af1`.

`s04_core_charge.ogg` takes carrier time 0.00–1.45 seconds, downmixes to mono, resamples to 24 kHz, high-passes at 32 Hz, low-passes at 11.8 kHz, normalizes to −17 LUFS / −1.5 dBTP, and applies 20 ms entrance plus 50 ms terminal fades. The runtime cue is **1.450 seconds**, 12,518 bytes, and SHA-256 `b916e6ffcd96ac9c02487d366bc68c3ea98f4f785010f9605397d395286cc9b1`.

`s04_shockwave_release.ogg` removes the carrier's measured 44.7292 ms leading silence, takes the next 1.00 second, downmixes to mono, resamples to 24 kHz, high-passes at 28 Hz, low-passes at 11.8 kHz, normalizes to −13 LUFS / −1 dBTP, and fades its final 120 ms. The runtime cue is **1.000 second**, 9,798 bytes, and SHA-256 `4d8efbfc1dfde9c7cf2035757984a279d1bebb770ec8a8362ad8ac22c73a6f44`.

Both cues are preloaded into two fixed `AudioStreamPlayer2D` nodes owned by the existing radial boss-utility slot. The charge cue begins with the 1.45-second telegraph and is stopped at the exact transition to `ARMED`; the release cue starts on that same transition. The attack emits one release signal after playback begins, and `CommandBossSession` converts it into one restrained 10-unit `CameraRig` impulse. Carrier videos, anchors, and production notes remain outside the repository under `/home/ubuntu/proto-scroller-art-masters/s04-core-shockwave-sfx/`.
