# City SFX provenance

## Power-box detonation

`power_box_detonation.wav` follows the project-required **GPT Image 2 → image-conditioned video carrier → extracted audio** workflow.

GPT Image 2 generated the 2560×1440 visual anchor `docs/power-box-detonation-sfx/power-box-detonation-anchor.png`: a damaged municipal transformer with exposed copper hardware and blue-white corona in the established dark dieselpunk city palette. The selected anchor SHA-256 is `7fcf25b2b924e4da84e24d1117039dae91fb6d1fee2ce9420d017d9580999bb7`.

Gemini Omni Flash generated the four-second 16:9 carrier `docs/power-box-detonation-sfx/power-box-detonation-carrier.mp4` from that anchor with native audio. The sound brief specified one dry utility-transformer failure: a razor-sharp capacitor snap, dense electrical arc crackle, compact low-voltage pressure thump, heavy steel-panel clank, six fragment ticks, and a rapidly decaying electrical fizz. It explicitly excluded speech, music, alarms, ambience, gunfire, and a generic cinematic fireball. The carrier is H.264 with 48 kHz stereo AAC audio; its SHA-256 is `3ab87ccaa42bca191a6ceef8096000396f8aafef256e88a43379da4c084e720e`. Speech transcription is empty.

The shipping cue extracts carrier time **0.20–1.70 seconds**, sums to mono, applies a 35 Hz high-pass, 15.5 kHz low-pass, 3:1 compression, EBU R128 loudness normalization, a 4 ms attack fade, and a 200 ms tail fade. The result is a **1.500-second, 48 kHz, mono PCM16 WAV** measuring approximately **−16.5 LUFS integrated** with a **−1.2 dBTP** true peak. Shipping SHA-256: `40892da317cb7105b1af4d280523585b2983ffb5c14077df6ad447cbd486110e`.

At runtime, Godot imports the PCM16 source master as **QOA** to preserve Web package headroom. The cue is registered as a **signature-priority positional SFX** and played through the existing prewarmed eight-voice `ImpactFeedbackPool` exactly when the second-hit destruction delay completes. No audio node or stream is allocated during combat.

The carrier's generated transcription files are intentionally excluded from source control; their only required finding is that no speech was detected.
