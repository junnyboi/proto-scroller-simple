# Cinematic Title Background Provenance

## Purpose

These silent title-screen loops animate the existing title composition as **idle → ground smash → idle**. The original static title artwork remains the orientation-specific preload and decoder-failure fallback.

## Visual references

| Orientation | Canonical reference | GPT Image 2 idle reference SHA-256 |
|---|---|---|
| Landscape | `game/art/ui/title_screen/command_deck_landscape.jpg` | `b909a862fbdf09edf392e7b40c6715316bc9a649dc25014afaf720fbaaf1c21d` |
| Portrait | `game/art/ui/title_screen/command_deck_portrait.jpg` | `44fd52a383ab9d41f85b80f1165b6b5669c6bc816b32d7f14e09eada1fbfe3ac` |

GPT Image 2 created precision-matched idle keyframes while retaining the robot identity, ruined megacity, lighting, and orientation-specific UI-safe space. Those keyframes were supplied as identical first and last frames to enforce a closed loop.

## Video generation

Both loops were generated with **Veo 3.1**, silent, eight seconds, 1080p, with a locked camera and identical first/last keyframes. The prompt required one grounded mechanical smash, restrained dust and sparks, no cuts, no camera motion, no text, and a mechanical return to the exact opening pose.

| Orientation | Generated master | Master SHA-256 |
|---|---|---|
| Landscape | 1920×1080, H.264, 24 fps, 8.0 s | `d50ecd28f9ef7542f2a1d4d21b44f69f27e77ebaab353a100b880d4dd2bb01fe` |
| Portrait | 1080×1920, H.264, 24 fps, 8.0 s | `dc3308e7480c57e63aa927d048a1d8df8a71b0cff5ef0476eefa0734bf21397e` |

## Web masters

The initial shipping masters were deterministically resized and compressed with FFmpeg while retaining 24 fps, H.264 High Profile, YUV 4:2:0, no audio, and fast-start metadata:

```bash
ffmpeg -i <master> -an -vf 'scale=<target>:flags=lanczos,fps=24' \
  -c:v libx264 -preset slow -crf 27 -profile:v high -level 4.0 \
  -pix_fmt yuv420p -movflags +faststart <shipping.mp4>
```

## Loop-seam correction

Frame-level analysis found that both generated masters returned closest to their opening composition at frame 183, then drifted during frames 184–191. The landscape frame 191 → 0 seam was particularly visible: its mean absolute error was 3.48× the median adjacent-frame change. The repaired masters preserve frames 0–183 exactly and reconstruct only frames 184–191 with a cosine-eased interpolation from frame 183 to the exact opening frame. They remain 192 frames, 24 fps, and exactly eight seconds, so the authored frame-88 landscape and frame-66 portrait impact synchronization is unchanged.

The deterministic regression command is:

```bash
python3 scripts/verify-title-loop-seam.py \
  client/public/title-video/title-loop-landscape.mp4 \
  client/public/title-video/title-loop-portrait.mp4
```

It requires H.264, the exact orientation geometry, 24 fps, 192 frames, eight seconds, end-to-start MAE at most 0.004, and correlation at least 0.998. The corrected landscape seam measures MAE 0.00285 and correlation 0.99931; portrait measures MAE 0.00338 and correlation 0.99863.

| File | Geometry | Bytes | SHA-256 |
|---|---:|---:|---|
| `title-loop-landscape.mp4` | 1280×720 | 1,983,162 | `5134aecf83b921bc3b7be12260b79b7bbddb27fde62fa1977590fb3ddf8a07ff` |
| `title-loop-portrait.mp4` | 720×1280 | 1,914,617 | `bfc65d653a3b408aeba690a99fb1cb1dc6a8b0ffcabeeab7e8688c6b2a5b1839` |

## Runtime behavior

On Web, the first trusted title-screen interaction—keyboard, click, tap, or gamepad button, including **Begin Expedition**—unlocks audio, chooses the matching orientation, and locks that cinematic source. The measured ground-contact/spark frames are **frame 88 at 3.666667 seconds** in landscape and **frame 66 at 2.750000 seconds** in portrait. A browser animation-clock and compensated-timer race captures the production music source inside a bounded one-second horizon, then schedules its sample-zero downbeat directly on the Web Audio clock for the next corresponding rendered impact. If the current impact is too close to preserve the scheduling horizon, the target advances to the following eight-second loop. Music therefore begins while the title remains visible instead of waiting for launch; telemetry is published at `window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__`. Rotation can switch sources before activation but cannot replace the locked source afterward. When launch is the first interaction, Godot calibrates the transition against the browser-reported rendered-output delay so the impact remains visible for **350 ms after the audible downbeat** before title fade-out. Playback or scheduling failure uses a bounded audible fallback so launch is never stranded. Native builds continue to use the canonical static artwork and immediate music startup.
