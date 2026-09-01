# District Destructible Facade Asset Pack

This directory contains the **10 production facade textures** used by the Business and Residential district catalog. Each PNG is a standalone orthographic building cutout with a transparent background. The runtime divides every texture into the established three-column by two-row structural grid, so alpha-clipped dark cavities, organic cracks, exposed pipes, dangling electrical cables, material resistance, and causal chain-reaction systems remain active without destroyed cross-section images.

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

## Acceptance contract

Every final PNG must remain readable as an orthographic facade at the authored gameplay size, retain an alpha channel, use dimensions divisible by six, and stay below the repository's practical single-texture budget. The catalog and GUT tests enforce unique resource paths, the 10-file count, divisibility, and runtime binding.
