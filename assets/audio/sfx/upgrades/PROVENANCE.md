# Upgrade SFX provenance

The shipped `upgrade_confirm.wav` was extracted from an approved generated-video audio carrier because the built-in Mirelo sound-effect endpoint was unavailable in this session. The carrier remains outside the export tree at `/home/ubuntu/proto-scroller-art-masters/upgrade-system/v1/sfx_passives_carrier.mp4` and is not committed.

| Field | Value |
|---|---|
| Carrier model | `gemini-omni-flash-preview` through Manus `generate_video` |
| Carrier SHA-256 | `f7ae59ff5fc4ac86c2d7492b765c685cfc4160bcb0afb0b4b49da3caf44e8037` |
| Extraction | `ffmpeg -ss 0 -t 0.88 -ac 1 -ar 48000 -c:a pcm_s16le` |
| Shipping SHA-256 | `7800bc9168d712dc668f6c3ecfaa839c4a3144b29283b56566a5b5c6cb400b9d` |
| Shipping format | 48 kHz, mono, PCM16 WAV, 0.88 seconds |
| Runtime policy | Existing fixed eight-voice semantic pool; priority 6; 180 ms acquisition rate limit |

Two additional approved carrier requests for weapon and flame-specific SFX failed because the generation service reported insufficient capacity. Those optional sounds therefore retain the plan's fixed **silent fallback** and do not alter mechanics. Existing structural material audio remains authoritative for destruction. The Flamethrower loop owns one capped, pause-safe player but retains a null stream until an approved seamless loop is available. No synthesized or image-generated audio ships.
