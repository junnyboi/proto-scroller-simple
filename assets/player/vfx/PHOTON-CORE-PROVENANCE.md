# Photon Core Visual Asset Provenance

The photon-core visual system was generated on **2026-08-25** with **GPT Image 2** using the canonical 1280×720 charged-smash gameplay render as its style reference. Prompts preserved the cream, bronze, and charcoal robot language, dark industrial setting, and amber photon-energy motif while explicitly excluding text, logos, labels, annotations, and watermarks.

| Runtime asset | Purpose | Processing | SHA-256 |
|---|---|---|---|
| `art/player/vfx/photon_core_orb.png` | Growing chest-core sphere, accelerating photon motes, and brief full-charge hit flash | Selected from two 1920×1920 generations; deterministic magenta-key cleanup; alpha crop; Lanczos downscale and transparent 256×256 padding | `40c00024feb729d1c7701860c75a38445432707e8449f7d676988d5af66ba7d8` |
| `art/player/vfx/photon_release_shockwave.png` | Expanding cyan-white pressure ring emitted when a fully charged attack is released | Generated on 2026-08-26 with GPT Image 2 from the shipped photon-core reference; selected from two 1920×1920 candidates; deterministic magenta/black background removal; alpha crop; square padding; Lanczos downscale to 512×512 | `ec3108f63584358bbba7744c42ad6b872ef468a44eac5bbdb8eafc0cc8ce4cee` |
| `art/ui/gameplay/photon_charge_meter_frame.png` | World-space charge meter chassis above the robot | Selected from two 2560×1440 generations; connected-background flood removal; deterministic magenta-residue cleanup; alpha crop; Lanczos downscale to 768×156 | `0445de73e2bcf32b96ef5d8ae9430d3695a32d55882edc9129c90ff88864a78f` |

Raw core and meter generations remain outside the repository under `/home/ubuntu/proto-scroller-art-masters/photon-core/v1/`; raw release-ring generations and their deterministic cleanup script live under `/home/ubuntu/proto-scroller-art-masters/photon-release-shockwave/v1/`. Runtime code uses the generated frame, orb, and ring directly. Only progress width, transforms, shader-driven max-charge recoloring, modulation, and timing are computed from gameplay state. No runtime texture allocation or generated media request occurs during play.
