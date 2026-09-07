# Weapon Shop Transaction SFX Provenance

The purchase and repair cues were generated on **2026-08-26** through the project-required image-to-video carrier workflow. GPT Image 2 produced one 2560×1440 anchor for each action. Image-conditioned synchronized video generation then produced two 6.016-second 1280×720 H.264 carriers with 48 kHz stereo AAC audio. The carriers and waveform diagnostics are preserved under `docs/concepts/weapon-shops/final-assets/audio-carriers/`.

`shop_purchase.wav` uses the 0.75–2.10-second carrier window. It combines an industrial rail scrape, heavy latch, capacitor lock, confirmation chirp, electrical snap, and compact metallic resonance. The final file is 1.350 seconds, 48 kHz mono PCM16, true peak -1.0 dBFS, SHA-256 `89533a0d75935b061f496bd4c3b7255a7bbbcdecfe010602374962b518e161c1`.

`shop_repair.wav` uses the 0.55–2.35-second carrier window. It combines deep servo clamps, a sustained nanoweld/electrical knitting body, pressure-seal hiss, and warm completion tone. The final file is 1.800 seconds, 48 kHz mono PCM16, integrated loudness -13.8 LUFS, true peak -1.0 dBFS, SHA-256 `5848cf1f37c7c9cec5a2b197caa52320ccdf78644e6ca5c5d527e68fb1898a0a`.

The reproducible mastering script is `docs/concepts/weapon-shops/final-assets/audio-carriers/master_shop_sfx.sh`. It performs deterministic trimming, mono downmix, 48 kHz resampling, high/low-pass filtering, cue-specific equalization, transparent compression, loudness limiting, and short edge fades. Both cues contain sound effects only—no speech, music, or ambient bed.
