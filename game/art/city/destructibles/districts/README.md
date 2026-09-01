# District Destructible Facade Asset Pack

This directory contains the **25 production facade textures** used by the forward city-district catalog. Each PNG is a standalone orthographic building cutout with a transparent background. The runtime divides every texture into the established three-column by two-row structural grid, so alpha-clipped dark cavities, organic cracks, material resistance, and causal chain-reaction systems remain active without destroyed cross-section images or persistent damage decorations. Each terminal ground bay adds only a shallow road-level cluster of four shared transparent concrete, glass, or steel fragments; upper bays retain their jagged opening without floating rubble. The Residential Bluewire Laundry Walkup also keeps true alpha behind its stair rails. No facade texture in this directory may be reused as rubble, interior, cross-section, or replacement-background art.

## Provenance and processing

All facades were generated on **2026-08-25** with **GPT Image 2** through the Manus built-in image-generation tool. The generation prompts used the district concept board and the original prototype facade—now retained only in Git history—as style references. Prompts required a complete roof-to-ground silhouette, front elevation, no characters, no readable branding, no background, and broad gameplay-readable structural masses.

The generator used neon green as a temporary removal color. Generated outputs were deterministically processed with Pillow to remove connected background pixels and green residue, preserve the complete subject, add transparent padding, resize with Lanczos filtering to a maximum 510-pixel dimension, pad dimensions to multiples of six, and save optimized RGBA PNGs. Raw generation outputs are intentionally excluded from source control. Final assets were reviewed together in a 25-item contact sheet; every texture has transparent corners, no detected green residue, and a distinct silhouette.

## Runtime mapping

| District | Variant ID | Runtime facade |
| --- | --- | --- |
| Business | `business_mercy_exchange_annex` | `business/mercy_exchange_annex.png` |
| Business | `business_helix_clearinghouse_spine` | `business/helix_clearinghouse_spine.png` |
| Business | `business_orison_custody_vault` | `business/orison_custody_vault.png` |
| Business | `business_vanta_compliance_tribunal` | `business/vanta_compliance_tribunal.png` |
| Business | `business_crown_reserve_treasury` | `business/crown_reserve_data_treasury.png` |
| Residential | `residential_emberpot_canteen_house` | `residential/emberpot_canteen_house.png` |
| Residential | `residential_bluewire_laundry_walkup` | `residential/bluewire_laundry_walkup.png` |
| Residential | `residential_rainvault_cooperative` | `residential/rainvault_cooperative.png` |
| Residential | `residential_sixfold_balcony_court` | `residential/sixfold_balcony_court.png` |
| Residential | `residential_nightglass_mutual_clinic` | `residential/nightglass_mutual_clinic.png` |
| Entertainment | `entertainment_voltage_chapel` | `entertainment/voltage_chapel.png` |
| Entertainment | `entertainment_orpheum_vanta` | `entertainment/orpheum_vanta.png` |
| Entertainment | `entertainment_halcyon_stack_hotel` | `entertainment/halcyon_stack_hotel.png` |
| Entertainment | `entertainment_prism_crown_revue` | `entertainment/prism_crown_revue.png` |
| Entertainment | `entertainment_house_of_static` | `entertainment/house_of_static_casino_hotel.png` |
| Military | `military_ordnance_transload_bastion` | `military/ordnance_transload_bastion.png` |
| Military | `military_revetment_armory_stack` | `military/revetment_armory_stack.png` |
| Military | `military_aegis_signal_citadel` | `military/aegis_signal_citadel.png` |
| Military | `military_manticore_repair_gantry` | `military/manticore_siege_repair_gantry.png` |
| Military | `military_prefect_war_keep` | `military/prefect_war_keep.png` |
| Royal | `royal_laureate_processional_gate` | `royal/laureate_processional_gate.png` |
| Royal | `royal_aurelian_conservatory` | `royal/aurelian_menagerie_conservatory.png` |
| Royal | `royal_tribunal_nine_seals` | `royal/tribunal_of_nine_seals.png` |
| Royal | `royal_ministry_privilege_spire` | `royal/ministry_of_privilege_spire.png` |
| Royal | `royal_palace_last_sovereign` | `royal/palace_of_last_sovereign.png` |

## Acceptance contract

Every final PNG must remain readable as an orthographic facade at the authored gameplay size, retain an alpha channel, use dimensions divisible by six, and stay below the repository's practical single-texture budget. The catalog and GUT tests enforce unique resource paths, the 25-file count, divisibility, and runtime binding. Visual gallery and Xvfb traversal scenarios are the release gates for clipping, stretching, unintended backgrounds, and district-family cohesion.
