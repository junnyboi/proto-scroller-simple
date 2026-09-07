# Tactical AI Voice Provenance

The original English tactical AI lines were regenerated together on 2026-08-24 with the same Manus text-to-speech voice (`Gacrux`) and performance direction: a mature, low-register, velvet-smooth female tactical AI with intimate confidence, restrained delivery, subtle synthetic poise, and crisp combat-system timing. The 2026-08-25 `fully_charged.wav` addition uses the same role and delivery direction. The Manus Gacrux endpoint failed on three attempts and two native voice-carrier requests reported capacity exhaustion, so that one line uses a mature US-English neural female fallback (`en-US-AriaNeural`) rather than silently omitting the required cue. The 2026-08-27 `rear_barrier_warning.wav` cue returns to `Gacrux` and combines the exact voice line with an approved generated-video warning bed. The 2026-08-27 `boss_fight.wav` cue uses a separate forceful combat-announcer performance and the required image-to-video carrier workflow. No real person, brand character, or existing performance was referenced.

| Runtime File | Spoken Line | Duration | SHA-256 |
|---|---|---:|---|
| `air_target_acquired.wav` | “Air target acquired.” | 1.806 s | `dbadc3724e34219b04528cc2c735f1e495b4cbc448c352f0e6a5eec2bf5ddb40` |
| `target_lost.wav` | “Target lost.” | 1.310 s | `419a1b1d781564f6c3204cdf30ebd1c9eca4b325242b50355f038e06925cc88d` |
| `target_destroyed.wav` | “Target destroyed.” | 1.392 s | `aa6612e9d06a33f130def28a516acf14e1bfcf3082fdbbe6cd1d82f0e94c35e5` |
| `fully_charged.wav` | “Fully charged!” | 1.009 s | `cda9ffd18ddc71a719c053d0290ff264bda6e39f7effcbe6d51cc9b0984a77de` |
| `rear_barrier_warning.wav` | “We can't go back now!” | 1.859 s | `cd3063be6191346e0174c952a3675baacf4e0ddef8eae9cb521ec674af647562` |
| `boss_fight.wav` | “Boss fight!” | 1.180 s | `f8f41809d7da8fdab1651eb5816eb7ec6526e1febcde0704739019260f031236` |

Each source is silence-trimmed, high- and low-pass filtered, lightly compressed, loudness-matched, and exported as 48 kHz mono PCM16. Godot imports runtime streams with QOA compression to preserve the Web PCK budget. Runtime routing remains on the `Voice` bus. Automated speech-to-text verified the charge line as “Fully charged” and the barrier line as “We can't go back now.” The full-charge announcement plays once upon reaching the two-second cap; the rear-barrier line plays synchronously with the red vignette on the rising edge of contact and does not replay every frame while contact remains held.

## Rear-barrier warning carrier

The 2026-08-27 rear-barrier cue follows the project-required sound workflow. GPT Image 2 generated a 2560×1440 industrial cockpit warning anchor with a restrained red left boundary (`6990b3e6c79248e8bdfd55841bb7c95a172d17e6130d14765aff1b4835123577`). Gemini Omni then generated a four-second image-conditioned carrier containing one quiet electronic boundary chirp and a compact low electromechanical restraint pulse, with no speech or music (`be01fa8685ec7618cad231e4c1401b22d8b88e52db120ca63b353bffe83fc380`). The `Gacrux` TTS source speaks exactly “We can't go back now!” (`7b2e104d7d3c791c67a693079570675dd8bf034df6b463444be96ed36ef11536`).

The shipping master mixes the filtered carrier extraction beneath the silence-trimmed tactical voice, limits the peak, and exports 48 kHz mono PCM16. It measures approximately −19.6 dB mean and −3.7 dBFS peak before the runtime player's additional −4 dB subtle-warning gain. Masters and the carrier remain outside the repository under `/home/ubuntu/proto-scroller-art-masters/rear-barrier-warning/`; only the final runtime WAV ships.

## Boss-fight announcer carrier

The boss-fight cue starts with the exact spoken line **“BOSS FIGHT!”** from Manus speech generation. GPT Image 2 produced the red-and-white transparent typography anchor. A 1,280×720 composition of that anchor conditioned a three-second Gemini Omni carrier with a static combat-alert presentation, reverse-suction rise, industrial low-frequency impact, and metallic warning sting—no speech and no music. The carrier file SHA-256 is `dbde17acee37166c9f797013d3492559b0a85cfe33e815e95f300c3b14e9b064`.

The final runtime mix accelerates the silence-trimmed voice to fit the approximately one-second splash, layers the first carrier impact at restrained level, fades the bed before its later generated pulse, limits the peak, and exports 48 kHz mono PCM16. It measures −16.9 dB mean and −2.4 dBFS peak. Speech-to-text verified the mixed result as “Boss, fight.” Masters and the carrier remain outside the repository under `/home/ubuntu/proto-scroller-art-masters/boss-fight/`; only the final runtime WAV ships.
