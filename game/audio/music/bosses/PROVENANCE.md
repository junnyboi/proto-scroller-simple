# Boss Music Provenance

The two retained instrumental boss themes were generated with **Lyria 3 Pro** on 2026-08-26 from original district-specific briefs. No artist, song, album, copyrighted melody, lyrics, or vocal samples were referenced. Raw MP3 generations remain outside the source repository under `/home/ubuntu/generated-raw/proto-scroller-bosses/music/`.

| Boss | Runtime file | Musical identity |
|---|---|---|
| SETTLEMENT ENGINE S-04 | `settlement-engine-s04.ogg` | 118 BPM industrial accounting machinery in D minor |
| SAMARITAN-15 | `samaritan-15.ogg` | 104 BPM tragic rescue-industrial score in C minor |

Runtime files are loudness-normalized to approximately **-16 LUFS**, mono at **32 kHz**, and encoded as compact Ogg Vorbis at approximately **40 kbps**. Each arrangement returns toward its opening rhythmic and harmonic state for looped playback. `BossMusicDirector` owns one prewarmed AudioStreamPlayer on the Music bus. A boss theme begins at its encounter and switches from sample zero when the next district boss starts. Actual run stop, extraction, defeat, title return, or a fresh non-continuation run stops the boss player and restores the interrupted city-pressure bed.

The complete boss image-and-music source pack is kept below the approved **1,835,008-byte** feature allocation before Godot import metadata. Final acceptance remains the measured Web PCK size under the repository's **16 MiB** ceiling.
