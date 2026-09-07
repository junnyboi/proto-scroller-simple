# UI SFX Provenance

## `transition_full_black_boom.wav`

This cue is the non-positional synchronization sound for every full-screen scene transition. `Main` plays it on the **UI** bus only after the persistent transition overlay reaches alpha `1.0`, immediately before the hidden state swap.

### Generation chain

1. A production brief specified one immediate 38–52 Hz pressure event with a short mechanical body and controlled tail.
2. **GPT Image 2** generated `transition-boom-anchor.png`, a centered reactor-field collapse reference. SHA-256: `fa8a07cb8e26aa3a93224f328f19d8beafa4caadeccbc7b07c4e16533ff737a5`.
3. **Lyria 3 Pro** generated the original sound-design source. It was decoded to 48 kHz mono PCM before selection. Decoded-source SHA-256: `1a36a3be23a364da47c1b19877a885a7a7cd7d049961b25a5d6c6af45aabdeb6`.
4. The strongest isolated low-frequency event began at source time `0.000 s`. It was high-passed at 25 Hz, low-passed at 1.8 kHz, limited to -1.5 dBTP, and placed beneath the GPT Image 2 anchor in a 1280×720 H.264/AAC MP4 carrier. Carrier SHA-256: `f7246bb7ae292bf24fefec585e83211ff3a4acb32264846abbd9b85dc35c9be4`.
5. The carrier audio was extracted, converted to mono 48 kHz PCM, trimmed to `1.350 s`, normalized to approximately -18 LUFS / -1.5 dBTP, and faded over its final 350 ms.

### Shipping contract

- Format: mono 48 kHz, 16-bit PCM WAV
- Duration: exactly `1.350 s`
- Runtime bus: `UI`
- Runtime trigger: overlay alpha reaches full black
- SHA-256: `cca66e67364e69695febad14faa30f09c2cf5a906abae4cd8205fa2b623a558f`
- No vocals, speech, melody, riser, secondary impact, or long reverb tail
