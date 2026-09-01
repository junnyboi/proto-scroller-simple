#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export GODOT_SILENCE_ROOT_WARNING=1
GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
test -n "$GODOT"
MODE="standard"
if [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ -n "${1:-}" ]]; then
  echo "Usage: ./verify.sh [--full]" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
rm -rf artifacts
mkdir -p \
	  artifacts/charge_attack \
	  artifacts/title_screen \
  artifacts/city_slice \
	  artifacts/endless_terrain \
	  artifacts/visible_facade_cycle \
		  artifacts/project_choir_wp1 \
		  artifacts/project_choir_enemies \
			  artifacts/boss_attack_matrix \
			  artifacts/boss_rig_gallery \
			  artifacts/boss_vertical_slice \
			  artifacts/enemy_variety \
	  artifacts/street_volatility \
	  artifacts/power_box_repair \
	  artifacts/directives
: > artifacts/.gdignore
START_EPOCH="$(date +%s)"
ENGINE_TIMEOUT_SECONDS=120
EXPORT_TIMEOUT_SECONDS=300
PCK_BUDGET_BYTES=$((16 * 1024 * 1024))

run_engine() {
	timeout --preserve-status --signal=TERM --kill-after=5s \
		"${ENGINE_TIMEOUT_SECONDS}s" "$@"
}

run_export() {
	timeout --preserve-status --signal=TERM --kill-after=5s \
		"${EXPORT_TIMEOUT_SECONDS}s" "$@"
}

printf '%s\n' '[L3] import'
run_engine "$GODOT" --headless --path . --import

printf '%s\n' '[L1] parse and lint'
"$GODOT" --version | grep -Fq '4.7.2'
grep -Fq 'config/features=PackedStringArray("4.7", "GL Compatibility")' project.godot
	grep -Fq 'window/size/viewport_width=1280' project.godot
	grep -Fq 'window/size/viewport_height=720' project.godot
	grep -Fq 'window/per_pixel_transparency/allowed=true' project.godot
	grep -Fq 'window/stretch/mode="canvas_items"' project.godot
		grep -Fq 'window/stretch/aspect="expand"' project.godot
grep -Fq 'renderer/rendering_method="gl_compatibility"' project.godot
grep -Fq 'variant/extensions_support=false' export_presets.cfg
grep -Fq 'variant/thread_support=false' export_presets.cfg
! grep -Eq '^exclude_filter=.*art/bosses/\*' export_presets.cfg
! grep -Eq '^exclude_filter=.*audio/music/bosses/\*' export_presets.cfg
printf '%s\n' '[L1] title-loop timing and seam continuity'
python3 ../scripts/verify-title-loop-seam.py \
	../client/public/title-video/title-loop-landscape.mp4 \
	../client/public/title-video/title-loop-portrait.mp4 \
	| tee artifacts/title-loop-seam.json
for boss_art in \
	art/bosses/animated/settlement-engine-s04-atlas.webp \
	art/bosses/animated/samaritan-15-atlas.webp; do
	test -s "$boss_art"
done
for herald_tier in \
	double_kill \
	triple_kill \
	overkill \
	unstoppable \
	annihilation \
	extinction_event; do
	test -s "art/ui/combo_herald/${herald_tier}.png"
	test -s "audio/voice/combo/${herald_tier}.wav"
done
for destruction_vfx_asset in \
	concrete_chunk \
	glass_shard \
	steel_fragment \
	dust_puff \
	impact_flash; do
	test -s "art/city/destructibles/debris/${destruction_vfx_asset}.png"
done
CITY_SLICE_LINES="$(wc -l < scripts/gameplay/city_slice.gd)"
test "$CITY_SLICE_LINES" -le 650
printf 'city_slice_lines=%s\n' "$CITY_SLICE_LINES"
test -z "$(find art audio -type f \( -iname '*candidate*' -o -iname '*carrier*' -o -iname '*original*' \) -print -quit)"
for cue in \
	  audio/sfx/rampage/overdrive_activation.wav \
	  audio/sfx/rampage/combo_break.wav \
		  audio/sfx/ui/transition_full_black_boom.wav \
	  audio/sfx/robot/robot_footstep.wav \
	  audio/sfx/robot/robot_servo.wav \
	  audio/sfx/robot/robot_dash_warp_drive.wav \
	  audio/sfx/robot/dodge_energy_recharged.wav \
	  audio/sfx/robot/ground_slam_impact.wav \
	  audio/sfx/robot/double_punch_impact.wav \
	  audio/sfx/robot/photon_charge.wav \
	  audio/sfx/robot/photon_full_hit.wav \
	  audio/voice/air_target_acquired.wav \
	  audio/voice/target_lost.wav \
		  audio/voice/target_destroyed.wav \
		  audio/voice/fully_charged.wav \
		  audio/voice/combo/double_kill.wav \
		  audio/voice/combo/triple_kill.wav \
		  audio/voice/combo/overkill.wav \
		  audio/voice/combo/unstoppable.wav \
		  audio/voice/combo/annihilation.wav \
		  audio/voice/combo/extinction_event.wav \
		  audio/sfx/debris/debris_enemy_thud.wav; do
  test "$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$cue")" = 48000
		test "$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$cue")" = pcm_s16le
done
DASH_WARP_DURATION="$(
	ffprobe -v error -show_entries format=duration -of csv=p=0 \
		audio/sfx/robot/robot_dash_warp_drive.wav
)"
awk -v duration="$DASH_WARP_DURATION" 'BEGIN {
	exit !(duration >= 1.0 && duration <= 3.0)
}'
TRANSITION_BOOM_DURATION="$(
	ffprobe -v error -show_entries format=duration -of csv=p=0 \
		audio/sfx/ui/transition_full_black_boom.wav
)"
awk -v duration="$TRANSITION_BOOM_DURATION" 'BEGIN {
	exit !(duration >= 1.34 && duration <= 1.36)
}'
test "$(sha256sum audio/sfx/ui/transition_full_black_boom.wav | cut -d' ' -f1)" = \
	"cca66e67364e69695febad14faa30f09c2cf5a906abae4cd8205fa2b623a558f"
for campaign_import in \
	art/city/enemies/archetypes/{21-reclaimed-breacher,22-graft-runner}.png.import \
	art/narrative/*.{png,jpg}.import; do
	grep -Fq 'compress/mode=1' "$campaign_import"
	grep -Fq 'compress/lossy_quality=0.75' "$campaign_import"
done
PUNCH_DURATION="$(
	ffprobe -v error -show_entries format=duration -of csv=p=0 \
		audio/sfx/robot/double_punch_impact.wav
)"
awk -v duration="$PUNCH_DURATION" 'BEGIN {
	exit !(duration >= 0.46 && duration <= 0.48)
}'
test "$(sha256sum audio/sfx/robot/double_punch_impact.wav | cut -d' ' -f1)" = \
	"070c680f847e87f66a62cb41df4daf2e841946ef46b83dba4eaebec651af31ea"
for photon_cue in \
	audio/sfx/robot/photon_charge.wav \
	audio/sfx/robot/photon_full_hit.wav; do
	PHOTON_DURATION="$(
		ffprobe -v error -show_entries format=duration -of csv=p=0 "$photon_cue"
	)"
	awk -v duration="$PHOTON_DURATION" 'BEGIN {
		exit !(duration >= 1.0 && duration <= 3.0)
	}'
done
PARSE_LOG="artifacts/parse-lint.log"
: > "$PARSE_LOG"
while IFS= read -r -d '' script; do
	  gdlint "$script"
	  run_engine "$GODOT" --headless --path . --check-only -s "$script" 2>&1 \
	    | tee -a "$PARSE_LOG"
done < <(find scripts selftest test -type f -name '*.gd' -print0 | sort -z)
if grep -Eq 'SCRIPT ERROR|Parse Error|ERROR:|FATAL|CRASH' "$PARSE_LOG"; then
	printf '%s\n' '[PARSE-FAIL] Godot logged a script or resource diagnostic' >&2
	exit 1
fi

printf '%s\n' '[L2] GUT unit suite'
run_engine "$GODOT" --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit \
  | tee artifacts/gut.log
test -s artifacts/unit-tests-ran.txt
UNIT_TESTS="$(cat artifacts/unit-tests-ran.txt)"
test "$UNIT_TESTS" -ge 2
printf 'unit_tests=%s\n' "$UNIT_TESTS"

printf '%s\n' '[L3] launch boot'
run_engine "$GODOT" --headless --path . -s selftest/boot_smoke_scenario.gd

printf '%s\n' '[L3] bounded direct launch shutdown'
run_engine "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . \
  --quit-after 120 2>&1 | tee artifacts/direct-boot.log
if grep -Eq \
  'ObjectDB instances were leaked|resources still in use at exit|AudioStreamPlaybackOggVorbis|Resource still in use:.*city_pressure_loop' \
  artifacts/direct-boot.log; then
  printf '%s\n' '[DIRECT-BOOT-FAIL] retained Ogg playback during shutdown' >&2
  exit 1
fi

printf '%s\n' '[L4] headless injected-input scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/title_screen_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/title_screen/report.json >/dev/null

printf '%s\n' '[L4] city-slice headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/city_slice_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/city_slice/report.json >/dev/null

printf '%s\n' '[L4] charged-smash headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
	-s selftest/charge_attack_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP" and .max_shot.status == "SKIP" and .release_shot.status == "SKIP" and .hit_shot.status == "SKIP"' \
	artifacts/charge_attack/report.json >/dev/null

printf '%s\n' '[L4] directive-card headless lifecycle scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
	-s selftest/directive_card_visual_scenario.gd

printf '%s\n' '[L4] district-building gallery headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/district_building_gallery_scenario.gd
jq -e '.done == true and .result == "PASS" and (.districts | length) == 2' \
  artifacts/district_gallery/report.json >/dev/null

printf '%s\n' '[L4] building destruction VFX headless scenario'
run_engine "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . \
	-s selftest/building_destruction_vfx_scenario.gd

printf '%s\n' '[L4] enemy-variety headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/enemy_variety_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/enemy_variety/report.json >/dev/null

printf '%s\n' '[L4] street-volatility headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/street_volatility_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/street_volatility/report.json >/dev/null

printf '%s\n' '[L4] endless-terrain headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/endless_terrain_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/endless_terrain/report.json >/dev/null

printf '%s\n' '[L4] boss attack matrix headless scenario'
run_engine "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . \
	-s selftest/boss_attack_matrix_scenario.gd
jq -e '
	.done == true
	and .result == "PASS"
	and .facade_rows == 128
	and ([.checks[].passed] | all)
' artifacts/boss_attack_matrix/report.json >/dev/null

printf '%s\n' '[L4] boss rig gallery headless scenario'
run_engine "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . \
	-s selftest/boss_rig_gallery_scenario.gd
jq -e '
	.done == true
	and .result == "PASS"
	and .orientation == "landscape"
	and (.boss_ids | length) == 2
	and ([.checks[].passed] | all)
	and .shot == ""
' artifacts/boss_rig_gallery/report-landscape.json >/dev/null

printf '%s\n' '[L4] Business and Residential boss vertical slice'
run_engine "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . \
	-s selftest/boss_vertical_slice_scenario.gd
jq -e '
	.done == true
	and .result == "PASS"
	and .orientation == "landscape"
	and (.business.attacks | length) == 5
	and (.residential.attacks | length) == 4
	and .residential.central_cradle_preserved == true
	and ([.checks[].passed] | all)
' artifacts/boss_vertical_slice/report-landscape.json >/dev/null

SHOT_HASH=""
if [[ "$MODE" == "full" ]]; then
  printf '%s\n' '[L5] windowed render scenario'
  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
    -s selftest/title_screen_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/title_screen/report.json >/dev/null
  test -s artifacts/title_screen/title-screen.png
  DIMENSIONS="$(file artifacts/title_screen/title-screen.png)"
  grep -Fq '1280 x 720' <<< "$DIMENSIONS"
  cp artifacts/title_screen/title-screen.png \
    artifacts/title_screen/title-screen-landscape.png
  SHOT_HASH="$(sha256sum artifacts/title_screen/title-screen.png | cut -d' ' -f1)"
  printf 'shot_sha256=%s\n' "$SHOT_HASH"

  printf '%s\n' '[L5] portrait title render scenario'
  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
    --resolution 720x1280 -s selftest/title_screen_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/title_screen/report.json >/dev/null
  PORTRAIT_TITLE_DIMENSIONS="$(file artifacts/title_screen/title-screen.png)"
  grep -Fq '720 x 1280' <<< "$PORTRAIT_TITLE_DIMENSIONS"
  mv artifacts/title_screen/title-screen.png \
    artifacts/title_screen/title-screen-portrait.png
	cp artifacts/title_screen/title-screen-landscape.png \
	  artifacts/title_screen/title-screen.png

	printf '%s\n' '[L5] windowed city-slice render scenario'
  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
    -s selftest/city_slice_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/city_slice/report.json >/dev/null
	  test -s artifacts/city_slice/city-slice.png
	  CITY_DIMENSIONS="$(file artifacts/city_slice/city-slice.png)"
	  grep -Fq '1280 x 720' <<< "$CITY_DIMENSIONS"
	  test -s artifacts/city_slice/city-slice-wrecked.png
	  test -s artifacts/city_slice/city-slice-rubble.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/city_slice/city-slice-wrecked.png)"
	  grep -Fq '1280 x 720' <<< "$(file artifacts/city_slice/city-slice-rubble.png)"
	  cp artifacts/city_slice/city-slice.png \
	    artifacts/city_slice/city-slice-landscape.png
	  mv artifacts/city_slice/city-slice-wrecked.png \
	    artifacts/city_slice/city-slice-wrecked-landscape.png
	  mv artifacts/city_slice/city-slice-rubble.png \
	    artifacts/city_slice/city-slice-rubble-landscape.png

	  printf '%s\n' '[L5] portrait city-slice wreck and rubble render scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
	    --resolution 720x1280 -s selftest/city_slice_scenario.gd
	  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
	    artifacts/city_slice/report.json >/dev/null
	  test -s artifacts/city_slice/city-slice.png
	  test -s artifacts/city_slice/city-slice-wrecked.png
	  test -s artifacts/city_slice/city-slice-rubble.png
	  grep -Fq '720 x 1280' <<< "$(file artifacts/city_slice/city-slice.png)"
	  grep -Fq '720 x 1280' <<< "$(file artifacts/city_slice/city-slice-wrecked.png)"
	  grep -Fq '720 x 1280' <<< "$(file artifacts/city_slice/city-slice-rubble.png)"
	  mv artifacts/city_slice/city-slice.png \
	    artifacts/city_slice/city-slice-portrait.png
	  mv artifacts/city_slice/city-slice-wrecked.png \
	    artifacts/city_slice/city-slice-wrecked-portrait.png
	  mv artifacts/city_slice/city-slice-rubble.png \
	    artifacts/city_slice/city-slice-rubble-portrait.png
	  cp artifacts/city_slice/city-slice-landscape.png \
	    artifacts/city_slice/city-slice.png
	  cp artifacts/city_slice/city-slice-wrecked-landscape.png \
	    artifacts/city_slice/city-slice-wrecked.png
		  cp artifacts/city_slice/city-slice-rubble-landscape.png \
		    artifacts/city_slice/city-slice-rubble.png

			  printf '%s\n' '[L5] landscape charged-smash visual scenario'
			  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
			    -s selftest/charge_attack_scenario.gd
			  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS" and .max_shot.status == "PASS" and .release_shot.status == "PASS" and .hit_shot.status == "PASS"' \
			    artifacts/charge_attack/report.json >/dev/null
			  grep -Fq '1280 x 720' <<< "$(file artifacts/charge_attack/charge-attack.png)"
			  mv artifacts/charge_attack/charge-attack.png \
			    artifacts/charge_attack/charge-attack-landscape.png
			  grep -Fq '1280 x 720' <<< "$(file artifacts/charge_attack/max-charge.png)"
			  mv artifacts/charge_attack/max-charge.png \
			    artifacts/charge_attack/max-charge-landscape.png
			  grep -Fq '1280 x 720' <<< "$(file artifacts/charge_attack/release-shockwave.png)"
			  mv artifacts/charge_attack/release-shockwave.png \
			    artifacts/charge_attack/release-shockwave-landscape.png
			  grep -Fq '1280 x 720' <<< "$(file artifacts/charge_attack/full-charge-hit.png)"
		  mv artifacts/charge_attack/full-charge-hit.png \
		    artifacts/charge_attack/full-charge-hit-landscape.png

			  printf '%s\n' '[L5] portrait charged-smash visual scenario'
			  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
			    --resolution 720x1280 -s selftest/charge_attack_scenario.gd
			  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS" and .max_shot.status == "PASS" and .release_shot.status == "PASS" and .hit_shot.status == "PASS"' \
			    artifacts/charge_attack/report.json >/dev/null
			  grep -Fq '720 x 1280' <<< "$(file artifacts/charge_attack/charge-attack.png)"
			  mv artifacts/charge_attack/charge-attack.png \
			    artifacts/charge_attack/charge-attack-portrait.png
			  grep -Fq '720 x 1280' <<< "$(file artifacts/charge_attack/max-charge.png)"
			  mv artifacts/charge_attack/max-charge.png \
			    artifacts/charge_attack/max-charge-portrait.png
			  grep -Fq '720 x 1280' <<< "$(file artifacts/charge_attack/release-shockwave.png)"
			  mv artifacts/charge_attack/release-shockwave.png \
			    artifacts/charge_attack/release-shockwave-portrait.png
			  grep -Fq '720 x 1280' <<< "$(file artifacts/charge_attack/full-charge-hit.png)"
		  mv artifacts/charge_attack/full-charge-hit.png \
		    artifacts/charge_attack/full-charge-hit-portrait.png
		  cp artifacts/charge_attack/charge-attack-landscape.png \
		    artifacts/charge_attack/charge-attack.png

		  printf '%s\n' '[L5] landscape district-building gallery scenario'
	  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
	    -s selftest/district_building_gallery_scenario.gd
	  jq -e '.done == true and .result == "PASS" and (.districts | length) == 2' \
	    artifacts/district_gallery/report.json >/dev/null
	  test "$(find artifacts/district_gallery -maxdepth 1 -type f \
	    -name '*-landscape.png' -size +0c | wc -l)" -eq 2
	  while IFS= read -r gallery_shot; do
	    grep -Fq '1280 x 720' <<< "$(file "$gallery_shot")"
	  done < <(find artifacts/district_gallery -maxdepth 1 -type f \
	    -name '*-landscape.png' | LC_ALL=C sort)

	  printf '%s\n' '[L5] portrait district-building gallery scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
	    --resolution 720x1280 -s selftest/district_building_gallery_scenario.gd
	  jq -e '.done == true and .result == "PASS" and (.districts | length) == 2' \
	    artifacts/district_gallery/report.json >/dev/null
	  test "$(find artifacts/district_gallery -maxdepth 1 -type f \
	    -name '*-portrait.png' -size +0c | wc -l)" -eq 2
	  while IFS= read -r gallery_shot; do
	    grep -Fq '720 x 1280' <<< "$(file "$gallery_shot")"
	  done < <(find artifacts/district_gallery -maxdepth 1 -type f \
	    -name '*-portrait.png' | LC_ALL=C sort)

	  printf '%s\n' '[L5] landscape natural five-facade traversal scenario'
	  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
	    --resolution 1280x720 \
	    -s selftest/visible_facade_cycle_scenario.gd
	  jq -e '
	    .done == true
	    and .result == "PASS"
	    and .orientation == "landscape"
	    and (.variants | length) == 5
	    and ([.variants[]] | unique | length) == 5
	  ' artifacts/visible_facade_cycle/report-landscape.json >/dev/null
	  test "$(find artifacts/visible_facade_cycle -maxdepth 1 -type f \
	    -name '*-landscape.png' -size +0c | wc -l)" -eq 5
	  while IFS= read -r facade_shot; do
	    grep -Fq '1280 x 720' <<< "$(file "$facade_shot")"
	  done < <(find artifacts/visible_facade_cycle -maxdepth 1 -type f \
	    -name '*-landscape.png' | LC_ALL=C sort)

	  printf '%s\n' '[L5] portrait natural five-facade traversal scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" \
	    --audio-driver Dummy --path . --resolution 720x1280 \
	    -s selftest/visible_facade_cycle_scenario.gd
	  jq -e '
	    .done == true
	    and .result == "PASS"
	    and .orientation == "portrait"
	    and (.variants | length) == 5
	    and ([.variants[]] | unique | length) == 5
	  ' artifacts/visible_facade_cycle/report-portrait.json >/dev/null
	  test "$(find artifacts/visible_facade_cycle -maxdepth 1 -type f \
	    -name '*-portrait.png' -size +0c | wc -l)" -eq 5
	  while IFS= read -r facade_shot; do
	    grep -Fq '720 x 1280' <<< "$(file "$facade_shot")"
	  done < <(find artifacts/visible_facade_cycle -maxdepth 1 -type f \
	    -name '*-portrait.png' | LC_ALL=C sort)

	  printf '%s\n' '[L5] windowed enemy-variety render scenario'
  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
    -s selftest/enemy_variety_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/enemy_variety/report.json >/dev/null
  test -s artifacts/enemy_variety/enemy-variety.png
	  ENEMY_VARIETY_DIMENSIONS="$(file artifacts/enemy_variety/enemy-variety.png)"
	  grep -Fq '1280 x 720' <<< "$ENEMY_VARIETY_DIMENSIONS"

	  printf '%s\n' '[L5] Project CHOIR hybrid gallery landscape'
	  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
	    --resolution 1280x720 -s selftest/project_choir_enemy_gallery_scenario.gd
	  jq -e '.done == true and .result == "PASS" and (.hybrids | length) == 2' \
	    artifacts/project_choir_enemies/report-landscape.json >/dev/null
	  test -s artifacts/project_choir_enemies/hybrid-gallery-landscape.png
	  grep -Fq '1280 x 720' \
	    <<< "$(file artifacts/project_choir_enemies/hybrid-gallery-landscape.png)"

	  printf '%s\n' '[L5] Project CHOIR hybrid gallery portrait'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" \
	    --audio-driver Dummy --path . --resolution 720x1280 \
	    -s selftest/project_choir_enemy_gallery_scenario.gd
	  jq -e '.done == true and .result == "PASS" and (.hybrids | length) == 6' \
	    artifacts/project_choir_enemies/report-portrait.json >/dev/null
	  test -s artifacts/project_choir_enemies/hybrid-gallery-portrait.png
	  grep -Fq '720 x 1280' \
	    <<< "$(file artifacts/project_choir_enemies/hybrid-gallery-portrait.png)"

	  printf '%s\n' '[L5] boss rig gallery landscape'
	  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
	    --resolution 1280x720 -s selftest/boss_rig_gallery_scenario.gd
	  jq -e '
	    .done == true
	    and .result == "PASS"
	    and .orientation == "landscape"
	    and (.boss_ids | length) == 2
	    and ([.checks[].passed] | all)
	  ' artifacts/boss_rig_gallery/report-landscape.json >/dev/null
	  test -s artifacts/boss_rig_gallery/boss-rig-gallery-landscape.png
	  grep -Fq '1280 x 720' \
	    <<< "$(file artifacts/boss_rig_gallery/boss-rig-gallery-landscape.png)"

	  printf '%s\n' '[L5] boss rig gallery portrait'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" \
	    --audio-driver Dummy --path . --resolution 720x1280 \
	    -s selftest/boss_rig_gallery_scenario.gd
	  jq -e '
	    .done == true
	    and .result == "PASS"
	    and .orientation == "portrait"
	    and (.boss_ids | length) == 2
	    and ([.checks[].passed] | all)
	  ' artifacts/boss_rig_gallery/report-portrait.json >/dev/null
	  test -s artifacts/boss_rig_gallery/boss-rig-gallery-portrait.png
	  grep -Fq '720 x 1280' \
	    <<< "$(file artifacts/boss_rig_gallery/boss-rig-gallery-portrait.png)"
		  diff \
		    <(jq -S '.mechanical_signatures' artifacts/boss_rig_gallery/report-landscape.json) \
		    <(jq -S '.mechanical_signatures' artifacts/boss_rig_gallery/report-portrait.json)

		  printf '%s\n' '[L5] Business and Residential boss vertical slice landscape'
		  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
		    --resolution 1280x720 -s selftest/boss_vertical_slice_scenario.gd
		  jq -e '.done == true and .result == "PASS" and .orientation == "landscape"
		    and ([.checks[].passed] | all)' \
		    artifacts/boss_vertical_slice/report-landscape.json >/dev/null
		  test -s artifacts/boss_vertical_slice/business-landscape.png
		  test -s artifacts/boss_vertical_slice/residential-landscape.png

		  printf '%s\n' '[L5] Business and Residential boss vertical slice portrait'
		  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" \
		    --audio-driver Dummy --path . --resolution 720x1280 \
		    -s selftest/boss_vertical_slice_scenario.gd
		  jq -e '.done == true and .result == "PASS" and .orientation == "portrait"
		    and ([.checks[].passed] | all)' \
		    artifacts/boss_vertical_slice/report-portrait.json >/dev/null
		  test -s artifacts/boss_vertical_slice/business-portrait.png
		  test -s artifacts/boss_vertical_slice/residential-portrait.png
		  diff \
			    <(jq -S '[.business.signature, .residential.signature]' artifacts/boss_vertical_slice/report-landscape.json) \
			    <(jq -S '[.business.signature, .residential.signature]' artifacts/boss_vertical_slice/report-portrait.json)

  printf '%s\n' '[L5] windowed street-volatility render scenario'
  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
    -s selftest/street_volatility_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/street_volatility/report.json >/dev/null
	  test -s artifacts/street_volatility/street-volatility.png
	  STREET_VOLATILITY_DIMENSIONS="$(file artifacts/street_volatility/street-volatility.png)"
	  grep -Fq '1280 x 720' <<< "$STREET_VOLATILITY_DIMENSIONS"

	  printf '%s\n' '[L5] windowed power-box repair render scenario'
	  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
	    -s selftest/power_box_repair_scenario.gd
	  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
	    artifacts/power_box_repair/report-landscape.json >/dev/null
	  test -s artifacts/power_box_repair/power-box-landscape.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/power_box_repair/power-box-landscape.png)"

	  printf '%s\n' '[L5] portrait power-box repair render scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" \
	    --audio-driver Dummy --path . --resolution 720x1280 \
	    -s selftest/power_box_repair_scenario.gd
	  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
	    artifacts/power_box_repair/report-portrait.json >/dev/null
	  test -s artifacts/power_box_repair/power-box-portrait.png
	  grep -Fq '720 x 1280' <<< "$(file artifacts/power_box_repair/power-box-portrait.png)"

	  printf '%s\n' '[L5] windowed endless-terrain render scenario'
  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
    -s selftest/endless_terrain_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/endless_terrain/report.json >/dev/null
	  test -s artifacts/endless_terrain/endless-terrain.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/endless_terrain/endless-terrain.png)"
	  cp artifacts/endless_terrain/endless-terrain.png \
	    artifacts/endless_terrain/endless-terrain-landscape.png

	  printf '%s\n' '[L5] portrait endless-terrain district scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
	    --resolution 720x1280 -s selftest/endless_terrain_scenario.gd
	  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
	    artifacts/endless_terrain/report.json >/dev/null
	  grep -Fq '720 x 1280' <<< "$(file artifacts/endless_terrain/endless-terrain.png)"
	  mv artifacts/endless_terrain/endless-terrain.png \
	    artifacts/endless_terrain/endless-terrain-portrait.png
	  cp artifacts/endless_terrain/endless-terrain-landscape.png \
	    artifacts/endless_terrain/endless-terrain.png

	  printf '%s\n' '[L5] initial city-slice visual scenario'
  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
    -s selftest/city_slice_visual_scenario.gd
  test -s artifacts/city_slice/city-slice-initial.png
  INITIAL_CITY_DIMENSIONS="$(file artifacts/city_slice/city-slice-initial.png)"
  grep -Fq '1280 x 720' <<< "$INITIAL_CITY_DIMENSIONS"
  cp artifacts/city_slice/city-slice-initial.png \
    artifacts/city_slice/city-slice-initial-landscape.png

  printf '%s\n' '[L5] portrait initial city-slice visual scenario'
  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
    --resolution 720x1280 -s selftest/city_slice_visual_scenario.gd
  PORTRAIT_CITY_DIMENSIONS="$(file artifacts/city_slice/city-slice-initial.png)"
  grep -Fq '720 x 1280' <<< "$PORTRAIT_CITY_DIMENSIONS"
	  mv artifacts/city_slice/city-slice-initial.png \
	    artifacts/city_slice/city-slice-initial-portrait.png
		  cp artifacts/city_slice/city-slice-initial-landscape.png \
		    artifacts/city_slice/city-slice-initial.png

	  printf '%s\n' '[L5] portrait mobile-controls visual scenario'
	  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 720x1280 \
	    -s selftest/mobile_controls_visual_scenario.gd
	  test -s artifacts/mobile_controls/mobile-controls-portrait.png
	  grep -Fq '720 x 1280' <<< "$(
	    file artifacts/mobile_controls/mobile-controls-portrait.png
	  )"

		  printf '%s\n' '[L5] landscape New Game+ terminal visual scenario'
		  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
		    -s selftest/new_game_plus_visual_scenario.gd
		  test -s artifacts/new_game_plus/new-game-plus.png
		  grep -Fq '1280 x 720' <<< "$(file artifacts/new_game_plus/new-game-plus.png)"
		  mv artifacts/new_game_plus/new-game-plus.png \
		    artifacts/new_game_plus/new-game-plus-landscape.png

		  printf '%s\n' '[L5] portrait New Game+ terminal visual scenario'
		  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
		    --resolution 720x1280 -s selftest/new_game_plus_visual_scenario.gd
		  test -s artifacts/new_game_plus/new-game-plus.png
		  grep -Fq '720 x 1280' <<< "$(file artifacts/new_game_plus/new-game-plus.png)"
		  mv artifacts/new_game_plus/new-game-plus.png \
		    artifacts/new_game_plus/new-game-plus-portrait.png

		  printf '%s\n' '[L5] landscape kill-combo visual scenario'
		  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
		    --resolution 1280x720 -s selftest/kill_combo_visual_scenario.gd
		  test -s artifacts/kill_combo/kill-combo.png
		  grep -Fq '1280 x 720' <<< "$(file artifacts/kill_combo/kill-combo.png)"
		  mv artifacts/kill_combo/kill-combo.png \
		    artifacts/kill_combo/kill-combo-landscape.png

		  printf '%s\n' '[L5] portrait kill-combo visual scenario'
		  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" \
		    --audio-driver Dummy --path . --resolution 720x1280 \
		    -s selftest/kill_combo_visual_scenario.gd
			  test -s artifacts/kill_combo/kill-combo.png
			  grep -Fq '720 x 1280' <<< "$(file artifacts/kill_combo/kill-combo.png)"
			  mv artifacts/kill_combo/kill-combo.png \
			    artifacts/kill_combo/kill-combo-portrait.png

			  printf '%s\n' '[L5] landscape building destruction VFX scenario'
			  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
			    --resolution 1280x720 -s selftest/building_destruction_vfx_scenario.gd
			  test -s artifacts/building_destruction_vfx/building-destruction-vfx-landscape.png
			  grep -Fq '1280 x 720' <<< "$(file artifacts/building_destruction_vfx/building-destruction-vfx-landscape.png)"

			  printf '%s\n' '[L5] portrait building destruction VFX scenario'
			  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" \
			    --audio-driver Dummy --path . --resolution 720x1280 \
			    -s selftest/building_destruction_vfx_scenario.gd
			  test -s artifacts/building_destruction_vfx/building-destruction-vfx-portrait.png
			  grep -Fq '720 x 1280' <<< "$(file artifacts/building_destruction_vfx/building-destruction-vfx-portrait.png)"

			  printf '%s\n' '[L5] landscape active/failed directive-card scenario'
	  run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 \
	    -s selftest/directive_card_visual_scenario.gd
	  test -s artifacts/directives/directive-active.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/directives/directive-active.png)"
	  mv artifacts/directives/directive-active.png \
	    artifacts/directives/directive-active-landscape.png
	  test -s artifacts/directives/directive-failed.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/directives/directive-failed.png)"
	  mv artifacts/directives/directive-failed.png \
	    artifacts/directives/directive-failed-landscape.png

	  printf '%s\n' '[L5] portrait active/failed directive-card scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --audio-driver Dummy --path . \
	    --resolution 720x1280 -s selftest/directive_card_visual_scenario.gd
	  test -s artifacts/directives/directive-active.png
	  grep -Fq '720 x 1280' <<< "$(file artifacts/directives/directive-active.png)"
	  mv artifacts/directives/directive-active.png \
	    artifacts/directives/directive-active-portrait.png
	  test -s artifacts/directives/directive-failed.png
	  grep -Fq '720 x 1280' <<< "$(file artifacts/directives/directive-failed.png)"
	  mv artifacts/directives/directive-failed.png \
	    artifacts/directives/directive-failed-portrait.png

	  printf '%s\n' '[WEB] cache-bypassed release export'
  rm -rf ../client/public/game
  mkdir -p ../client/public/game
	  run_export "$GODOT" --headless --quiet --path . --export-release Web \
	    ../client/public/game/game.html
	  (
	    cd ..
	    pnpm patch:web-audio
	    pnpm patch:title-video
	  )
	  test -s ../client/public/game/game.html
	  test -s ../client/public/title-video/title-loop-landscape.mp4
	  test -s ../client/public/title-video/title-loop-portrait.mp4
	  test -s ../client/public/title-video/title-poster-landscape.jpg
	  test -s ../client/public/title-video/title-poster-portrait.jpg
	  grep -Fq 'id="title-video-backdrop"' ../client/public/game/game.html
	  grep -Fq 'protoScrollerSetTitleBackdropActive' ../client/public/game/game.html
	  test "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 \
	    ../client/public/title-video/title-loop-landscape.mp4 | wc -l)" -eq 0
	  test "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 \
	    ../client/public/title-video/title-loop-portrait.mp4 | wc -l)" -eq 0
	  test "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
	    -of csv=s=x:p=0 ../client/public/title-video/title-loop-landscape.mp4)" = '1280x720'
	  test "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
	    -of csv=s=x:p=0 ../client/public/title-video/title-loop-portrait.mp4)" = '720x1280'
	  awk -v duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 \
	    ../client/public/title-video/title-loop-landscape.mp4)" \
	    'BEGIN { exit !(duration >= 7.99 && duration <= 8.01) }'
	  awk -v duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 \
	    ../client/public/title-video/title-loop-portrait.mp4)" \
	    'BEGIN { exit !(duration >= 7.99 && duration <= 8.01) }'
	  test "$(stat -c %s ../client/public/title-video/title-loop-landscape.mp4)" -le 2000000
	  test "$(stat -c %s ../client/public/title-video/title-loop-portrait.mp4)" -le 2000000
  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.wasm' -size +0c -printf '.' | wc -c)" -ge 1
  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.pck' -size +0c -printf '.' | wc -c)" -ge 1
	  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.js' -size +0c -printf '.' | wc -c)" -ge 1
	  PCK_BYTES="$(stat -c %s ../client/public/game/game.pck)"
	  test "$PCK_BYTES" -le "$PCK_BUDGET_BYTES"
	  printf 'pck_bytes=%s pck_budget_bytes=%s\n' "$PCK_BYTES" "$PCK_BUDGET_BYTES"
  (
    cd ../client/public/game
    find . -maxdepth 1 -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
	  ) > artifacts/web-export.sha256
	  printf 'web_files=%s\n' "$(wc -l < artifacts/web-export.sha256)"

		  printf '%s\n' '[WEB] automated browser gameplay smoke'
		  (
		    cd ..
		    timeout --preserve-status --signal=TERM --kill-after=5s 360s pnpm smoke:web
		  )
		  test -s artifacts/browser/title-video-landscape.png
			  test -s artifacts/browser/title-video-portrait.png
			  test -s artifacts/browser/title-fade-transition.png
			  test -s artifacts/browser/death-fade-transition.png
			  test -s artifacts/browser/death-summary.png
			  test -s artifacts/browser/return-title-fade-transition.png
			  grep -Fq '1280 x 720' <<< "$(file artifacts/browser/title-video-landscape.png)"
			  grep -Fq '720 x 1280' <<< "$(file artifacts/browser/title-video-portrait.png)"
			  grep -Fq '1280 x 720' <<< "$(file artifacts/browser/title-fade-transition.png)"
			  grep -Fq '1280 x 720' <<< "$(file artifacts/browser/death-fade-transition.png)"
			  grep -Fq '1280 x 720' <<< "$(file artifacts/browser/death-summary.png)"
			  grep -Fq '1280 x 720' <<< "$(file artifacts/browser/return-title-fade-transition.png)"
	  jq -e '
	    .status == "PASS"
	    and .titleVideo.currentSrc == "http://127.0.0.1:4173/title-video/title-loop-landscape.mp4"
	    and .titleVideo.duration >= 7.9
	    and .titleVideo.duration <= 8.1
	    and .titleVideo.videoWidth == 1280
	    and .titleVideo.videoHeight == 720
		    and .titleVideo.loop == true
			    and .titleVideo.muted == true
			    and .titleVideo.stoppedForGameplay == true
			    and .titleTransition.kind == "start_game"
			    and .titleTransition.boomCount == 1
			    and (.titleTransition.phases | map(.phase)) == [
			      "fade_out",
			      "black",
		      "black_ready",
		      "fade_in",
		      "complete"
		    ]
		    and .titleTransition.capturePhase == "black_ready"
			    and (.titleTransition.phases[] | select(.phase == "black").elapsedMs) >= 250
		    and (.titleTransition.phases[] | select(.phase == "black").elapsedMs) <= 1000
		    and (
		      (.titleTransition.phases[] | select(.phase == "fade_in").elapsedMs)
		      - (.titleTransition.phases[] | select(.phase == "black").elapsedMs)
		    ) <= 3000
		    and (
		      (.titleTransition.phases[] | select(.phase == "complete").elapsedMs)
		      - (.titleTransition.phases[] | select(.phase == "fade_in").elapsedMs)
			    ) >= 200
			    and (
			      (.titleTransition.phases[] | select(.phase == "complete").elapsedMs)
			      - (.titleTransition.phases[] | select(.phase == "fade_in").elapsedMs)
			    ) <= 1000
				    and .titleTransition.elapsedMs <= 5000
				    and .titleTransition.durationMs <= 12000
				    and .deathTransition.kind == "defeat"
			    and .deathTransition.boomCount == 2
			    and (.deathTransition.phases | map(.phase)) == [
			      "fade_out",
			      "black",
			      "black_ready",
			      "fade_in",
			      "complete"
			    ]
			    and (.deathTransition.phases[] | select(.phase == "fade_out").boomCount) == 1
			    and (.deathTransition.phases[] | select(.phase == "black").boomCount) == 2
			    and (.deathTransition.phases[] | select(.phase == "black").overlayAlpha) >= 0.999
			    and .returnTitleTransition.kind == "return_title"
			    and .returnTitleTransition.boomCount == 3
			    and (.returnTitleTransition.phases | map(.phase)) == [
			      "fade_out",
			      "black",
			      "black_ready",
			      "fade_in",
			      "complete"
			    ]
			    and (.returnTitleTransition.phases[] | select(.phase == "fade_out").boomCount) == 2
			    and (.returnTitleTransition.phases[] | select(.phase == "black").boomCount) == 3
			    and (.returnTitleTransition.phases[] | select(.phase == "black").overlayAlpha) >= 0.999
			    and .portraitTitleVideo.currentSrc == "http://127.0.0.1:4173/title-video/title-loop-portrait.mp4"
	    and .portraitTitleVideo.duration >= 7.9
	    and .portraitTitleVideo.duration <= 8.1
	    and .portraitTitleVideo.videoWidth == 720
	    and .portraitTitleVideo.videoHeight == 1280
	    and .portraitTitleVideo.loop == true
	    and .portraitTitleVideo.muted == true
	    and .landscapeTitleMusicSync.orientation == "landscape"
	    and .landscapeTitleMusicSync.sourceKind == "AudioBufferSourceNode/non-silent"
	    and .landscapeTitleMusicSync.trusted == true
	    and ((.landscapeTitleMusicSync.impactSeconds - (88 / 24)) | fabs) <= 0.000001
	    and (.landscapeTitleMusicSync.renderedSyncError | fabs) <= (1 / 24)
	    and .landscapeTitleMusicSync.outputLatency >= 0
	    and .landscapeTitleMusicSync.outputLatency <= 0.2
	    and .landscapeTitleMusicSync.committed == true
	    and .landscapeTitleMusicSync.cancelled == false
	    and .portraitTitleMusicSync.orientation == "portrait"
	    and .portraitTitleMusicSync.sourceKind == "AudioBufferSourceNode/non-silent"
	    and .portraitTitleMusicSync.trusted == true
	    and ((.portraitTitleMusicSync.impactSeconds - (66 / 24)) | fabs) <= 0.000001
	    and (.portraitTitleMusicSync.renderedSyncError | fabs) <= (1 / 24)
	    and .portraitTitleMusicSync.outputLatency >= 0
		    and .portraitTitleMusicSync.outputLatency <= 0.2
		    and .portraitTitleMusicSync.committed == true
		    and .portraitTitleMusicSync.cancelled == false
		    and .titleSourceSwitching.landscape.initialSource == "http://127.0.0.1:4173/title-video/title-loop-portrait.mp4"
		    and .titleSourceSwitching.landscape.preActivationSource == "http://127.0.0.1:4173/title-video/title-loop-landscape.mp4"
		    and .titleSourceSwitching.landscape.preActivationSwitched == true
		    and .titleSourceSwitching.landscape.postActivationSource == "http://127.0.0.1:4173/title-video/title-loop-landscape.mp4"
		    and .titleSourceSwitching.landscape.remainedLockedUntilTitleExit == true
		    and .titleSourceSwitching.portrait.initialSource == "http://127.0.0.1:4173/title-video/title-loop-landscape.mp4"
		    and .titleSourceSwitching.portrait.preActivationSource == "http://127.0.0.1:4173/title-video/title-loop-portrait.mp4"
		    and .titleSourceSwitching.portrait.preActivationSwitched == true
		    and .titleSourceSwitching.portrait.postActivationSource == "http://127.0.0.1:4173/title-video/title-loop-portrait.mp4"
		    and .titleSourceSwitching.portrait.remainedLockedUntilTitleExit == true
		    and .standaloneTitleMusicSync.orientation == "landscape"
		    and .standaloneTitleMusicSync.sourceKind == "AudioBufferSourceNode/non-silent"
		    and .standaloneTitleMusicSync.trusted == true
		    and ((.standaloneTitleMusicSync.impactSeconds - (88 / 24)) | fabs) <= 0.000001
		    and (.standaloneTitleMusicSync.renderedSyncError | fabs) <= (1 / 24)
		    and .standaloneTitleMusicSync.committed == true
		    and .standaloneShellLayout.bodyMargin == "0px"
		    and .standaloneShellLayout.canvasLeft == 0
		    and .standaloneShellLayout.canvasTop == 0
		    and ((.standaloneShellLayout.canvasWidth - .standaloneShellLayout.viewportWidth) | fabs) <= 1
		    and ((.standaloneShellLayout.canvasHeight - .standaloneShellLayout.viewportHeight) | fabs) <= 1
		    and .standaloneShellLayout.titleBackdropActive == true
		    and .standaloneShellLayout.requestVideoFrameCallback == true
		    and .titleMusicFallback.fallback == true
		    and .titleMusicFallback.fallbackReason == "video-playback-rejected"
		    and .titleMusicFallback.committed == true
		    and .titleMusicFallback.boundedCompletionMs <= 12000
		    and .titleMusicFallback.persistentBackgroundMusic == true
		    and .titleMusicFallback.transitionCompleted == true
		    and .titleMusicFallback.gameplayNotStranded == true
		    and (.browserErrors | length) == 0
		    and (.requestFailures | length) == 0
		    and (.httpErrors | length) == 0
		    and (.audioContextStates | index("running")) != null
	    and .phases[0].details.background_music_playing == true
	    and (.workletModules | length) == 2
	    and (.workletModules | all(.state == "fulfilled" and (.url | contains("/game/game.audio"))))
	    and (.phases | map(.status)) == [
	      "ready",
	      "charge_started",
	      "charge_progress",
	      "charge_released",
		      "east_walk_ok",
		      "pass",
		      "defeat_requested"
	    ]
	  ' artifacts/browser/gameplay-smoke.json >/dev/null
	  test -s artifacts/browser/gameplay-smoke.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/browser/gameplay-smoke.png)"
	fi

END_EPOCH="$(date +%s)"
jq -n \
  --arg mode "$MODE" \
  --arg status 'PASS' \
  --argjson unit_tests "$UNIT_TESTS" \
  --arg shot_sha256 "$SHOT_HASH" \
  --argjson seconds "$((END_EPOCH - START_EPOCH))" \
  '{mode:$mode,status:$status,unit_tests:$unit_tests,shot_sha256:$shot_sha256,seconds:$seconds}' \
  > artifacts/verify.json
printf '[VERIFY-PASS] mode=%s seconds=%s\n' "$MODE" "$((END_EPOCH - START_EPOCH))"
