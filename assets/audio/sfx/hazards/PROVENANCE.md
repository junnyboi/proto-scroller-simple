# Environmental Hazard SFX Provenance

The preferred built-in **Mirelo** sound-effect endpoint was searched first but was unavailable in this session. In accordance with Proto Scroller’s audio policy, the production cues were extracted from two approved generated-video audio carriers. The carriers remain outside the export tree and source control under `/home/ubuntu/proto-scroller-art-masters/hazards/audio/v1/`.

| Carrier | Model | Format | SHA-256 |
|---|---|---|---|
| `hazard_carrier_a.mp4` | `gemini-omni-flash-preview` | 8.0 s, stereo AAC, 48 kHz | `d0bf80d5bfdebb737595ebf3fe3cc1aaa8f204f53f52792ab5316534ae987eba` |
| `hazard_carrier_b.mp4` | `veo3.1-fast` | 8.0 s, stereo AAC, 48 kHz | `1f6eda75ddf357bfb995f0eb3a73c8432d15182f0de1f8079117e51a4c03beff` |

Production extraction preserves the carriers’ original **48 kHz** sample rate. Every committed source master is mono signed **PCM16 WAV**. Godot's Web runtime import uses mono 24 kHz QOA while leaving the source masters unchanged. Deterministic mastering uses equal-power stereo summing, cue-specific high-pass, low-pass, and parametric emphasis, 3:1 compression, 12 ms attack fade, 30 ms release fade, and peak limiting with normalization disabled. No synthesized source, procedural oscillator, music generator, or image-generated audio ships.

| Source master cue | Carrier window | Duration | SHA-256 |
|---|---|---:|---|
| `traffic_signal.wav` | A, 0.05–1.15 s | 1.10 s | `47018779161b9717deb5ec7c43c061a7f1294cb3a26ddbf1c8bb5ca298fd57cb` |
| `steam_main.wav` | A, 1.15–2.40 s | 1.25 s | `d20db2b422ac47c0ad37ca02b17faad4177030b3c8eb900c90dd9467bb1fd789` |
| `powerline.wav` | A, 2.45–3.60 s | 1.15 s | `d8b26fae52dbbc2bc0768e40d5791dc4c39072ecd92b1dbd95440d2ae0072cb4` |
| `road_plate.wav` | A, 3.65–4.85 s | 1.20 s | `0585fe3000bafdd00a60647d1c03d9b61181e08c469bd3b4940489ff0af16600` |
| `crane_drop.wav` | A, 4.95–6.20 s | 1.25 s | `a26dfa3f4a89576b0f6001200e3f0d3480756b8aff305cd8e32996312e2caab5` |
| `gas_fireline.wav` | A, 6.20–7.75 s | 1.55 s | `0aba119e2f0344a0d78c342c72e0c8264de0966260a95981c586eedef7245a02` |
| `facade_shear.wav` | B, 0.05–1.20 s | 1.15 s | `64f34429cef075818bd4f012dd1449a73346f2748b5084d96deaf62ab2c85925` |
| `metro_vent.wav` | B, 1.20–2.40 s | 1.20 s | `50441333f5d5309b002dcd0092297532ba7c1b9c2e22297414996a3126701b8d` |
| `metro_car.wav` | B, 2.45–3.85 s | 1.40 s | `9ad9af2e18b82cc77f9e66cb8abe1f310e70cce3ade82484bf94cf2f1b23eab0` |
| `flooded_lane.wav` | B, 3.90–5.10 s | 1.20 s | `f54bbc8893b19d7a52a3088962038ce7885f97f06496128c241ba928b60ceaae` |
| `skybridge.wav` | B, 5.15–6.50 s | 1.35 s | `00f5805cbb41451e6b8c3781e9870da304556ea05b3ae3bb2e44dcc54e369b75` |
| `ammo_convoy.wav` | B, 6.45–7.90 s | 1.45 s | `7f9adc3a710b61be554721e5c594d79e3fe7c7cd29ad5303cea9b259255cb239` |
| `hazard_chain_reaction.wav` | B, 6.62–7.54 s | 0.92 s | `9feb12a3183ceedb2f1687f6c7edd244484a3ecef3d3a564a6680d2ebef196e2` |
| `hazard_warning.wav` | A, 3.24–3.72 s | 0.48 s | `3895ae766f6298fdf6e7faa43c85e8b457dcebd06659e1d0b141433f42247910` |

The committed `.wav` masters and Godot import metadata are production assets. Carrier videos, gameplay references, spectrograms, and extraction scripts are retained externally as evidence and are intentionally excluded from source control and the Web export.
