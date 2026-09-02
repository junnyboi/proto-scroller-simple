#!/usr/bin/env bash
set -euo pipefail

export GODOT_SILENCE_ROOT_WARNING=1

MODE="standard"
if [[ "${1:-}" == "--full" ]]; then
	MODE="full"
elif [[ -n "${1:-}" ]]; then
	printf '%s\n' 'Usage: ./verify.sh [--full]' >&2
	exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

GODOT_BIN="${GODOT:-$(command -v godot || command -v godot4 || true)}"
if [[ -z "$GODOT_BIN" && -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
	GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
fi
if [[ -z "$GODOT_BIN" ]]; then
	printf '%s\n' '[ACT1-FAIL] Godot executable not found' >&2
	exit 1
fi

ARTIFACT_DIR="$PROJECT_ROOT/artifacts/act1"
WEB_EXPORT_DIR="$ARTIFACT_DIR/web-export"
rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"
: > "$PROJECT_ROOT/artifacts/.gdignore"

run_godot() {
	if command -v timeout >/dev/null 2>&1; then
		timeout --preserve-status --signal=TERM --kill-after=5s 300s "$GODOT_BIN" "$@"
	elif command -v gtimeout >/dev/null 2>&1; then
		gtimeout --preserve-status --signal=TERM --kill-after=5s 300s "$GODOT_BIN" "$@"
	else
		"$GODOT_BIN" "$@"
	fi
}

printf '%s\n' '[ACT1] structure and retained-resource boundary'
test -s project.godot
test -s scenes/template/template_main.tscn
test -s resources/template/stages/stage_01.tres
grep -Fq 'run/main_scene="res://scenes/template/template_main.tscn"' project.godot

for removed_path in \
	audio config docs localization shaders tools default_bus_layout.tres verify-migration.sh \
	art/bosses art/city art/enemies art/narrative art/player art/presentation art/robot art/ui \
	resources/catalysts resources/contracts resources/directives resources/encounters \
	resources/narrative resources/roles resources/siege resources/traits \
	scenes/gameplay scenes/main scenes/ui scenes/title_screen.tscn \
	scripts/actors scripts/audio scripts/camera scripts/combat scripts/destruction \
	scripts/directives scripts/encounter scripts/feedback scripts/gameplay scripts/hazards \
	scripts/input scripts/localization scripts/main scripts/narrative scripts/network \
	scripts/player scripts/quality scripts/rampage scripts/siege scripts/tuning scripts/ui \
	scripts/world scripts/title_screen.gd; do
	test ! -e "$removed_path"
done

if find . \
	-path './.git' -prune -o \
	-path './.godot' -prune -o \
	-path './addons' -prune -o \
	-path './artifacts' -prune -o \
	-path './build' -prune -o \
	-type f \( \
		-iname '*todo*' -o \
		-iname '*to-do*' -o \
		-iname '*tracker*' -o \
		-iname '*backlog*' -o \
		-iname '*roadmap*' \
	\) -print | grep -q .; then
	printf '%s\n' '[ACT1-FAIL] TODO/tracker documents remain' >&2
	exit 1
fi

EXPECTED_ASSETS="$(printf '%s\n' \
	art/template/debris_chunk.png \
	art/template/destructible_intact.png \
	art/template/destructible_wreck.png \
	art/template/enemy_soldier.png \
	art/template/enemy_tank.png \
	art/template/impact_flash.png \
	art/template/player_atlas.png \
	art/template/stage_01_background.webp \
	art/template/stage_01_foreground.png \
	art/template/title.jpg)"
ACTUAL_ASSETS="$(find art/template -type f ! -name '*.import' | LC_ALL=C sort)"
test "$ACTUAL_ASSETS" = "$EXPECTED_ASSETS"

if rg -n -i \
	--glob '*.gd' --glob '*.tscn' --glob '*.tres' --glob '*.cfg' --glob '*.json' \
	'(act[ _-]?2|stage[ _-]?0?2|next_stage_id|finale_enemy_id|boss|district)' \
	project.godot export_presets.cfg art resources scenes scripts > "$ARTIFACT_DIR/forbidden-references.log"; then
	printf '%s\n' '[ACT1-FAIL] removed runtime references remain' >&2
	cat "$ARTIFACT_DIR/forbidden-references.log" >&2
	exit 1
fi

printf '%s\n' '[ACT1] clean import'
run_godot --headless --path . --import 2>&1 | tee "$ARTIFACT_DIR/import.log"
if rg -n 'SCRIPT ERROR|Parse Error|ERROR:|FATAL|CRASH' "$ARTIFACT_DIR/import.log"; then
	printf '%s\n' '[ACT1-FAIL] import emitted an error' >&2
	exit 1
fi

printf '%s\n' '[ACT1] script parse checks'
: > "$ARTIFACT_DIR/parse.log"
while IFS= read -r -d '' script; do
	run_godot --headless --path . --check-only -s "$script" 2>&1 | tee -a "$ARTIFACT_DIR/parse.log"
done < <(find scripts selftest test -type f -name '*.gd' -print0 | sort -z)
if rg -n 'SCRIPT ERROR|Parse Error|ERROR:|FATAL|CRASH' "$ARTIFACT_DIR/parse.log"; then
	printf '%s\n' '[ACT1-FAIL] parse check emitted an error' >&2
	exit 1
fi

printf '%s\n' '[ACT1] focused GUT tests'
run_godot --headless -d -s addons/gut/gut_cmdln.gd \
	-gdir=res://test -gexit 2>&1 | tee "$ARTIFACT_DIR/gut.log"
if rg -n 'Failing Tests|Tests failed|SCRIPT ERROR|Parse Error|ERROR:|FATAL|CRASH' "$ARTIFACT_DIR/gut.log"; then
	printf '%s\n' '[ACT1-FAIL] focused tests failed' >&2
	exit 1
fi

printf '%s\n' '[ACT1] lifecycle and combat scenarios'
run_godot --headless --fixed-fps 60 --path . -s selftest/act1_lifecycle_scenario.gd \
	2>&1 | tee "$ARTIFACT_DIR/lifecycle.log"
grep -Fq '[ACT1-LIFECYCLE-DONE] result=PASS' "$ARTIFACT_DIR/lifecycle.log"
run_godot --headless --fixed-fps 60 --path . -s selftest/act1_combat_scenario.gd \
	2>&1 | tee "$ARTIFACT_DIR/combat.log"
grep -Fq '[ACT1-COMBAT-DONE] result=PASS' "$ARTIFACT_DIR/combat.log"

printf '%s\n' '[ACT1] bounded direct launch'
run_godot --headless --audio-driver Dummy --fixed-fps 60 --path . --quit-after 120 \
	2>&1 | tee "$ARTIFACT_DIR/launch.log"
if rg -n 'SCRIPT ERROR|Parse Error|ERROR:|FATAL|CRASH|resources still in use at exit' "$ARTIFACT_DIR/launch.log"; then
	printf '%s\n' '[ACT1-FAIL] direct launch emitted an error' >&2
	exit 1
fi

if [[ "$MODE" == "full" ]]; then
	printf '%s\n' '[ACT1] direct Web export'
	mkdir -p "$WEB_EXPORT_DIR"
	run_godot --headless --quiet --path . --export-release Web "$WEB_EXPORT_DIR/index.html"
	for exported_file in index.html index.js index.pck index.wasm; do
		test -s "$WEB_EXPORT_DIR/$exported_file"
	done
	PCK_BYTES="$(wc -c < "$WEB_EXPORT_DIR/index.pck" | tr -d ' ')"
	PCK_BUDGET_BYTES=$((16 * 1024 * 1024))
	test "$PCK_BYTES" -le "$PCK_BUDGET_BYTES"
	printf 'pck_bytes=%s pck_budget_bytes=%s\n' "$PCK_BYTES" "$PCK_BUDGET_BYTES"
fi

printf '%s\n' '[ACT1-PASS] single-stage template verified'
