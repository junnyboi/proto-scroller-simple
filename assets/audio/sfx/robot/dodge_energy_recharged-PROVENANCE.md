# Dodge energy recharge SFX provenance

The shipped `dodge_energy_recharged.wav` is a non-verbal energy-field recharge cue generated for the robot’s completed dash cooldown. It replaces the removed spoken `Dodge ready` status voice.

> Create a standalone science-fiction game sound effect with no voice, speech, melody, harmony, beat, alarm, or UI jingle. Begin with an electrical capacitor refill and magnetic hum, rise into a clean energy shimmer and charging sweep, resolve with a compact power-cell lock and restrained sub-bass confirmation pulse, then decay quickly.

| Field | Value |
|---|---|
| Source | Built-in Manus audio generation |
| Generated source | 44.1 kHz stereo MP3, 59.09 seconds |
| Shipping SHA-256 | `95c7e25bbd13a21d2877e9d6d188f2cd3748f61c79cde593925a9e8e7a134db2` |
| Shipping format | 48 kHz mono PCM16 WAV, 1.90 seconds |
| Processing | First 1.90 seconds selected; 70 Hz high-pass; 12 kHz low-pass; 30 ms fade-in; 350 ms fade-out; −1.5 dB gain; 48 kHz mono conversion |
| Runtime bus | `Mechanics` |
| Runtime cue ID | `dodge_recharged` |
| Verification | PCM integrity, exact duration, one playback per completed dash cooldown, no remaining runtime reference to the removed voice asset |

The generated 59-second source was removed after deterministic processing. The runtime uses one dedicated prewarmed non-positional mechanics player, preserving the existing fixed robot-audio voice budget.
