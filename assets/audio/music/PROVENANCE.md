# Proto Scroller Production BGM Provenance

## Runtime asset

`city_pressure_loop.ogg` is a **28-second, 48 kHz mono Vorbis loop** authored for the persistent `BackgroundMusicPlayer` on the Godot `Music` bus. The runtime encode is intentionally compact for the project's explicit 16 MiB no-threads Web package budget.

## Generation

The preferred built-in Lyria renderer was attempted three times on 2026-08-20 with valid industrial science-fiction prompts, but the service returned `Music generation failed` without producing an artifact. The production source was then generated through the configured game-pipeline text-to-music fallback (`sonilo_music`) using this brief:

> Instrumental only, no vocals. A production-quality industrial science-fiction gameplay score at 120 BPM in 4/4 and D minor, with subtle Dorian color. A colossal weathered combat walker advances through a ruined city with controlled momentum, mechanical resolve, and looming danger. Tight hydraulic percussion, centered low synth pulse, controlled electronic bass, dark low strings, sparse metallic impacts, restrained analog arpeggio fragments, distant machine-room ambience, and occasional processed brass swells. Keep clear midrange space for combat effects, voice cues, and interface sounds. Clean modern game-audio mix, moderate loudness, controlled transients, wide atmosphere with centered rhythm section. Avoid vocals, choir, heroic melody, trailer braams, excessive cymbals, piercing highs, giant sub-bass, sudden stingers, and wall-to-wall distortion. Start immediately on a stable core groove, develop modestly through the middle, then return in the final eight bars to the opening harmony, rhythm, density, and instrumentation. No fade-out, no final cadence, and no silence; end in motion for looping.

Generation job: `f003b634-2dd6-4b1c-87e1-f90f5ba1be94`.

## Runtime mastering

The generated 64-second stereo AAC source was edited into a compact loop with a four-second musical crossfade, converted to 48 kHz mono, high-passed at 35 Hz, gently scooped at 900 Hz and 2.2 kHz to protect combat/voice intelligibility, low-passed at 15 kHz, and normalized near **-18 LUFS**. The final runtime file is Vorbis at approximately 36 kbps.

The original generated source and intermediate PCM master are intentionally kept outside source control. The committed runtime asset SHA-256 is `4a4a040e11a47d384c4638aadf814b27c4453b0b59e665480d2766e5279150f8`.


## Title synchronization

The production OGG begins on its first strong downbeat at **stream/sample zero**. Native output starts immediately when available. On the Web title, the first trusted key, click, tap, or gamepad press unlocks audio; the decoder is then prewarmed inaudibly around 0.5 seconds and restored before the final non-silent `play(0.0)` commit. The browser captures that source inside a bounded one-second scheduling horizon, rewrites its `AudioBufferSourceNode.start()` time so sample zero reaches rendered output on the next orientation-specific robot impact, and advances to the following eight-second loop when the current impact is too close. Music continues on the title screen, while a launch initiated by that same first interaction still uses the reported rendered delay to hold the impact for a further 350 ms before fade-out.
