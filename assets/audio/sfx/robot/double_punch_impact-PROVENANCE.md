# Double Punch Impact SFX Provenance

The source was regenerated for Proto Scroller on 2026-08-25 with the project-required Mirelo carrier workflow. A GPT Image 2 anchor depicted the game’s massive cream-and-black robot fist crushing into a dense leather heavy bag inside an industrial training bay. That 16:9 anchor drove a Manus built-in Gemini Omni carrier-video generation whose original prompt requested exactly two forceful heavyweight impacts: loud tactile leather slaps, compressed bag-body thuds, 55–100 Hz low-frequency punches, short air displacement, and dark industrial-room reverberation, with the second hit heavier than the first and no music, voices, crowd, boxing bell, gunshot, generic explosion, extra impacts, or prolonged ambience. No artist, song, or existing work was referenced.

## 2026-08-25 animation synchronization replacement

A frame-by-frame audit of both 25-frame directional jab-cross sequences found their two maximal fist extensions at frames **11** and **14**. The animation runs at 12 FPS, so its visual one-two interval is exactly **0.250 seconds**. The previous 1.70-second master contained broadband impact onsets around 0.18 and 0.78 seconds—roughly **0.60 seconds apart**—which delayed both hits after their visual contacts.

The replacement is rebuilt losslessly from that approved 48 kHz mono PCM16 master. The first generated impact window (source 0.18–0.78 seconds) is moved to cue start with a 3 ms safety fade. The second window (source 0.78–1.70 seconds) is delayed by exactly 250 ms and mixed over the first impact's decay. A 150 ms tail fade and limiter preserve the original tactile weight. The inspected spectrogram places the dominant broadband onsets at cue start and approximately 0.25 seconds, aligning playback initiated at animation frame 11 with visual contacts at frames 11 and 14.

## 2026-08-27 tail crop

The user identified the final 700 ms as unrelated residual sound. The synchronized 1.17-second master was therefore cropped losslessly in timing to **0.47 seconds**, retaining both authored impact onsets at cue start and 0.25 seconds. A 10 ms fade occupies the end of the retained window solely to prevent a sample-edge click; no replacement sound or additional tail was introduced.

The shipping cue is **0.47 seconds**, 48 kHz mono PCM16, approximately **−12.5 LUFS integrated**, and **−0.8 dBFS true peak**. Godot retains QOA import compression for Web PCK headroom.

| Asset | SHA-256 |
|---|---|
| Superseded 1.70-second master | `3caf907c183cda968a8782a0ef30f889add495ac302edb3d97dcc082fc8ab9db` |
| Synchronized 1.17-second master | `ac4dc961a2828c14c58f856f58a9cef817391d02cd35bb858c5315c22bab0793` |
| Tail-cropped 0.47-second master | `070c680f847e87f66a62cb41df4daf2e841946ef46b83dba4eaebec651af31ea` |

Runtime use: `RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX`, Mechanics bus, signature priority. Playback begins on the authored gameplay commit at frame 11; the cue's internal second hit follows 250 ms later at frame 14.
