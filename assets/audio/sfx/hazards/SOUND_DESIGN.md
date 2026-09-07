# Environmental Hazard Audio Design Specification

**Author:** Manus AI

**System:** Proto Scroller environmental hazards

**Runtime target:** Godot 4.7.2 Compatibility renderer, 1280×720, no-threads Web export

## Design objective

Environmental audio must make the twelve hazards **identifiable before impact, physically convincing at impact, and subordinate to combat-critical information afterward**. Every hazard therefore receives three potential layers: a shared infrastructure-warning transient at telegraph start, a unique positional impact cue at primary activation, and a quieter rate-limited pulse for persistent denial hazards. Cross-hazard propagation adds a separate high-priority chain stinger at the newly armed target. The audio implementation is owned by a fixed six-voice positional pool and never allocates voices during play.[1]

> **Mix rule:** A warning tells the player *where to move*. A primary impact confirms *what happened*. A pulse communicates *whether the space remains dangerous*. A chain stinger says *the danger has moved*.

## Runtime trigger contract

The warning cue fires once when an armed hazard enters `STATE_TELEGRAPH`. It uses a shared dry mechanical precursor, while profile-specific gain and pitch make the warning proportional to hazard mass. The primary cue fires once when the telegraph expires and the hazard enters `STATE_ACTIVE`. Persistent hazards may request additional pulse cues through the same impact path, but each profile enforces a minimum retrigger interval and a reduced priority. A cross-hazard chain fires its stinger only after a valid armed target accepts the causal damage event; rejected, out-of-range, inactive, and maximum-depth targets remain silent.[1] [2]

| Trigger phase | Runtime event | Playback policy | Priority policy |
|---|---|---|---|
| Warning | Hazard enters `STATE_TELEGRAPH` | One shared cue, profile gain and pitch | Profile priority minus two, minimum two |
| Primary impact | First `resolve_impact(..., true)` | Unique hazard cue, forced playback | Full profile priority |
| Persistent pulse | Later `resolve_impact(..., false)` | Unique cue, quieter gain, retrigger limited | Profile priority minus three, minimum one |
| Cross-hazard chain | Armed target accepts causal chain event | Dedicated chain stinger at target position | Fixed priority ten |
| Pause | Upgrade or terminal lease acquired | All active hazard voices set `stream_paused` | Existing playback positions preserved |
| Retry or teardown | Hazard runtime releases all actors | All voices stopped; cooldowns and telemetry cleared | No post-run audio leakage |

## Hazard-specific specifications

The following mix values are runtime defaults, not mastering targets. Source WAVs retain transient headroom; Godot applies the listed gain and pitch at playback. Priority ranges from four for low-risk texture to ten for apex structural collapse.

| Hazard | Sonic identity | Warning | Primary impact | Persistent behavior | Runtime mix |
|---|---|---|---|---|---|
| **Traffic Signal Killzone** | Hinged gantry snap followed by a broad steel pavement slam | Low-pitched mechanical strain | Dense steel crash with short roadway body | None | Warning −12 dB at 0.88×; impact −3 dB at 0.90×; priority 7 |
| **Steam Main Burst** | Valve rupture, pressure crack, and bright steam release | Higher-pitched pipe stress | Compact pressure burst | Hiss pulses no faster than 520 ms | Warning −14 dB at 1.16×; impact −6 dB at 1.08×; pulse −14 dB at 1.18×; priority 4 |
| **Powerline Snap** | Cable whip, transformer arc, and dry electrical crackle | Sharp high-frequency pre-arc | Bright electrical discharge | Arc pulses no faster than 480 ms | Warning −13 dB at 1.28×; impact −5 dB at 1.18×; pulse −13 dB at 1.32×; priority 6 |
| **Buckled Road Plate** | Asphalt stress, plate buckle, and upward metal clang | Mid-weight steel flex | Fast plate launch transient | None | Warning −12 dB at 0.96×; impact −4 dB at 1.04×; priority 6 |
| **Crane Counterweight Drop** | Suspended mass release and concrete-steel ground hit | Slow, low mechanical groan | Substantial low-mid impact without sub-bass masking | None | Warning −9 dB at 0.72×; impact −2 dB at 0.78×; priority 8 |
| **Gas Main Fireline** | Manifold ignition, lateral whoosh, and compact flame body | Pressurized ignition chatter | Initial ignition front | Flame pulses no faster than 520 ms | Warning −12 dB at 1.08×; impact −5 dB at 0.94×; pulse −13 dB at 1.02×; priority 6 |
| **Facade Shear** | Masonry fracture, rebar tear, and heavy debris landing | Low structural crack | Broad concrete collapse | None | Warning −9 dB at 0.76×; impact −2.5 dB at 0.82×; priority 8 |
| **Metro Vent Surge** | Grate rattle followed by an upward pressure blast | Fast metallic flutter | Focused pneumatic surge | Air pulses no faster than 480 ms | Warning −13 dB at 1.12×; impact −6 dB at 1.08×; pulse −14 dB at 1.14×; priority 5 |
| **Derailed Metro Car** | Wheel scream, rail grind, and enormous steel crash | Very low rail strain | Long, heavy moving-mass collision | None | Warning −8 dB at 0.68×; impact −1 dB at 0.74×; priority 9 |
| **Flooded Electrified Lane** | Water slap with bright, unstable electrical arcs | High electrical precursor | Water-coupled discharge | Arc pulses no faster than 450 ms | Warning −11 dB at 1.28×; impact −5 dB at 1.20×; pulse −12 dB at 1.30×; priority 7 |
| **Collapsing Skybridge** | Deep steel failure, concrete separation, and full-span collapse | Lowest and longest structural warning | Apex collapse with controlled low-frequency weight | None | Warning −7 dB at 0.62×; impact −1 dB at 0.68×; priority 10 |
| **Ammunition Convoy Chain** | Three-stage vehicle detonation with a final pressure hit | Tight ignition warning | First vehicle explosion | Cascading detonations no faster than 420 ms | Warning −9 dB at 1.06×; impact −1.5 dB at 0.90×; pulse −8 dB at 0.94×; priority 9 |

## Cross-hazard chain reactions

The chain stinger is intentionally **shorter and brighter** than the apex impact cues. It plays at the target rather than the source, providing an immediate spatial handoff. Causal depth lowers pitch by 0.06 per generation, clamped to 0.82×, so deeper propagation sounds progressively heavier without requiring additional assets. The stinger is rate-limited per source-target pair and uses priority ten, allowing it to replace low-priority persistent pulses while never creating an additional runtime voice.[1]

The existing causal rules remain authoritative: one primary hazard can address at most two eligible targets, distance must remain inside the profile chain radius, and propagation cannot exceed `DamageEvent.MAX_CAUSAL_DEPTH`.[1] [3] Audio never triggers speculatively; it follows the accepted gameplay event.

## Voice budget and masking strategy

The hazard subsystem owns exactly **six prewarmed positional voices**. When all voices are busy, the pool first reuses the oldest lowest-priority voice. A lower-priority request cannot steal a higher-priority voice and is dropped instead. This policy allows apex impacts and chains to remain audible while steam, flame, flood, electrical, vent, and convoy pulses yield under extreme combat density. Positional attenuation uses a 1,900-pixel maximum distance and 0.45 attenuation, keeping distant hazards informative without overpowering centered robot, weapon, and interface cues.[1] [4]

All committed source masters are mono, 48 kHz, signed 16-bit PCM WAV. Godot imports the Web runtime streams as mono 24 kHz QOA to preserve room inside the explicit 16 MiB package ceiling without altering those masters. Mono sources are spatialized by `AudioStreamPlayer2D`; they do not contain baked stereo position. Mastered peaks retain at least approximately 1 dB of digital headroom, and profile playback gains provide the final hierarchy. No hazard cue is routed through the Music bus, so upgrade ducking does not accidentally suppress safety-critical warnings.

## Acceptance criteria

The implementation is complete when all fourteen source masters—the twelve identities, shared warning, and chain stinger—remain 48 kHz mono PCM16, their Web runtime streams load as mono 24 kHz QOA, every profile has a unique stream and mix signature, and the fixed-pool lifecycle assertions pass. Each hazard must fire exactly one warning and one primary cue during the common activation test; persistent pulses must obey their retrigger limits; accepted chains must fire one target-local stinger; pause leases must pause all voices; teardown must stop all voices; and the runtime snapshot must report exactly six hazard audio voices with no post-warm allocations.[4] [5]

## References

[1]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/hazards/hazard_audio_pool.gd "Hazard audio pool implementation"
[2]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/hazards/environmental_hazard_2d.gd "Environmental hazard state machine"
[3]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/hazards/hazard_runtime.gd "Hazard impact and causal-chain runtime"
[4]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/quality/runtime_budget.gd "Fixed runtime budget"
[5]: https://github.com/junnyboi/proto-scroller/blob/main/game/test/test_environmental_hazards.gd "Environmental hazard regression suite"
