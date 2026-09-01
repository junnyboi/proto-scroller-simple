# gdlint: disable=max-file-lines,max-public-methods
class_name GameplayHud
extends CanvasLayer

signal retry_pressed
signal title_pressed
signal extract_pressed
signal continue_pressed
signal purge_pressed
signal disentangle_pressed
signal tweak_controls_requested

const PANEL_COLOR: Color = Color(0.03, 0.05, 0.08, 0.86)
const ACCENT_COLOR: Color = Color("f1b36f")
const MUTED_COLOR: Color = Color("b7c4cb")
const HEALTH_GREEN_COLOR: Color = Color("63e67a")
const HEALTH_ORANGE_COLOR: Color = Color("ff9a42")
const HEALTH_RED_COLOR: Color = Color("ff4f4f")
const HEALTH_ORANGE_THRESHOLD: float = 0.66
const HEALTH_RED_THRESHOLD: float = 0.33
const COMBO_GRACE_SECONDS: float = RampageRewardTuning.COMBO_GRACE_SECONDS
const REAR_BARRIER_WARNING_DURATION: float = 0.72
const TWEAK_BUTTON_WIDTH: float = 138.0
const TWEAK_BUTTON_HEIGHT: float = 24.0
const TWEAK_BUTTON_RIGHT_MARGIN: float = 24.0
const TWEAK_BUTTON_BOTTOM_MARGIN: float = 18.0
const TWEAK_BUTTON_IDLE_OPACITY: float = 0.5
const TWEAK_BUTTON_HOVER_OPACITY: float = 1.0
const TWEAK_BUTTON_Z_INDEX: int = 100
const TWEAK_BUTTON_LANDSCAPE_FONT_SIZE: int = 9
const TWEAK_BUTTON_PORTRAIT_FONT_SIZE: int = 8
const REAR_BARRIER_WARNING_VOICE: AudioStream = preload(
	"res://audio/voice/rear_barrier_warning.wav"
)
const REAR_BARRIER_VIGNETTE_SHADER: String = """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float left_edge = 1.0 - smoothstep(0.0, 0.36, UV.x);
	float right_edge = smoothstep(0.82, 1.0, UV.x) * 0.20;
	float top_edge = (1.0 - smoothstep(0.0, 0.24, UV.y)) * 0.44;
	float bottom_edge = smoothstep(0.76, 1.0, UV.y) * 0.44;
	float edge = max(left_edge, max(right_edge, max(top_edge, bottom_edge)));
	float pulse = 0.94 + sin(TIME * 31.0 + UV.y * 18.0) * 0.06;
	COLOR = vec4(0.92, 0.015, 0.01, edge * intensity * pulse * 0.78);
}
"""
const FIRST_RUN_TUTORIAL_SCRIPT: Script = preload(
	"res://scripts/ui/first_run_combat_tutorial.gd"
)
const TRANSMISSION_TOAST_SCRIPT: Script = preload(
	"res://scripts/ui/transmission_toast.gd"
)
const NEW_GAME_PLUS_BADGE_TEXTURE: Texture2D = preload(
	"res://art/ui/new_game_plus/new_game_plus.webp"
)
const CHASSIS_HEART_TEXTURE: Texture2D = preload(
	"res://art/ui/gameplay/chassis-heart.png"
)

var health_icon: TextureRect
var health_label: Label
var objective_label: Label
var score_label: Label
var pending_score_label: Label
var combo_label: Label
var combo_ring: ComboDecayRing
var combo_herald: ComboHerald
var siege_progress: SiegeProgressStrip
var directive_card: DirectiveCard
var directive_choice_overlay: DirectiveChoiceOverlay
var first_run_tutorial: FirstRunCombatTutorial
var transmission_toast: TransmissionToast
var tweak_controls_button: Button
var tweak_leaderboard_disclaimer: Label
var boss_panel: ColorRect
var boss_label: Label
var boss_armor_track: ColorRect
var boss_armor_fill: ColorRect
var boss_health_track: ColorRect
var boss_health_fill: ColorRect
var boss_fight_herald: BossFightHerald
var game_over_overlay: Control
var overlay_title: Label
var overlay_summary: Label
var match_debrief: MatchDebriefPanel
var new_game_plus_badge: TextureRect
var retry_button: Button
var title_button: Button
var extract_button: Button
var continue_button: Button
var purge_button: Button
var disentangle_button: Button
var rare_labels: Array[Label] = []
var status_panel: ColorRect
var score_panel: ColorRect
var score_caption: Label
var terminal_panel: ColorRect
var rear_barrier_warning: ColorRect
var rear_barrier_warning_audio: AudioStreamPlayer
var rear_barrier_warning_play_count: int = 0
var _robot: GiantRobotController
var _contextual_attacks: ContextualAttackController
var _combat_profile: PlayerCombatProfileStore
var _displayed_combo_multiplier: int = -1
var _campaign_dossier_count: int = 0
var _continuity_generation: int = 0
var _rear_barrier_warning_remaining: float = 0.0
var _boss_armor_ratio: float = 0.0
var _boss_health_ratio: float = 0.0
var _hud_tuning_scale: float = 1.0
var _hud_tuning_tint: Color = Color.WHITE
var _hud_tuning_opacity: float = 1.0
var _runtime_tweak_service: RuntimeTweakService
var _tweak_controls_hovered: bool = false


func setup(
	robot: GiantRobotController,
	contextual_attacks: ContextualAttackController = null,
	combat_profile: PlayerCombatProfileStore = null
) -> void:
	_robot = robot
	_contextual_attacks = contextual_attacks
	_combat_profile = combat_profile


func bind_runtime_tweak_service(service: RuntimeTweakService) -> void:
	if (
		_runtime_tweak_service != null
		and _runtime_tweak_service.run_provenance_changed.is_connected(
			_set_tuning_provenance
		)
	):
		_runtime_tweak_service.run_provenance_changed.disconnect(
			_set_tuning_provenance
		)
	_runtime_tweak_service = service
	if _runtime_tweak_service == null:
		_set_tuning_provenance({"ranked_eligible": true})
		return
	_runtime_tweak_service.run_provenance_changed.connect(_set_tuning_provenance)
	_set_tuning_provenance(_runtime_tweak_service.provenance_snapshot())


func _ready() -> void:
	name = "HUD"
	layer = 20
	_build_rear_barrier_warning()
	_build_status_panel()
	_build_combo_indicator()
	_build_score_panel()
	_build_siege_progress()
	_build_directive_card()
	_build_directive_choice_overlay()
	_build_boss_status()
	_build_boss_fight_herald()
	_build_combo_herald()
	_build_transmission_toast()
	_build_first_run_tutorial()
	_build_tweak_controls_button()
	_build_game_over_overlay()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	L10n.apply_locale_font(self)
	if _robot != null:
		_robot.attack_mode_selected.connect(_on_attack_mode_selected)
		_robot.attack_committed.connect(_on_attack_committed)
		set_health(_robot.current_health, _robot.max_health)
	set_score(0)
	set_combo(1, 0.0)
	set_momentum(0.0, 0)


func _process(delta: float) -> void:
	_apply_live_visual_tuning()
	_update_rear_barrier_warning(delta)


func show_rear_barrier_warning() -> void:
	if rear_barrier_warning == null:
		return
	_rear_barrier_warning_remaining = REAR_BARRIER_WARNING_DURATION
	rear_barrier_warning.visible = true
	_set_rear_barrier_warning_intensity(1.0)
	rear_barrier_warning_play_count += 1
	rear_barrier_warning_audio.stop()
	rear_barrier_warning_audio.play()


func set_health(current: float, maximum: float) -> void:
	if health_label == null:
		return
	health_label.text = L10n.t("hud.health", {
		"current": "%03d" % roundi(current),
		"maximum": "%03d" % roundi(maximum),
	})
	health_label.modulate = health_color(current, maximum)


static func health_color(current: float, maximum: float) -> Color:
	var ratio: float = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	if ratio < HEALTH_RED_THRESHOLD:
		return HEALTH_RED_COLOR
	if ratio < HEALTH_ORANGE_THRESHOLD:
		return HEALTH_ORANGE_COLOR
	return HEALTH_GREEN_COLOR


func set_score(value: int) -> void:
	if score_label != null:
		score_label.text = "%08d" % maxi(value, 0)


func _displayed_score() -> int:
	return int(score_label.text) if score_label != null else 0


func set_pending_score(value: int) -> void:
	pending_score_label.text = (
		L10n.t("hud.pending_score", {"value": "%05d" % maxi(value, 0)})
		if value > 0
		else L10n.t("hud.safe")
	)
	pending_score_label.modulate = Color("ff9a61") if value > 0 else MUTED_COLOR


func set_combo(multiplier: int, grace_remaining: float) -> void:
	if combo_label == null:
		return
	var clamped_multiplier: int = clampi(multiplier, 1, 5)
	if _displayed_combo_multiplier != clamped_multiplier:
		combo_label.text = L10n.t("hud.combo", {"multiplier": clamped_multiplier})
		_displayed_combo_multiplier = clamped_multiplier
	var should_show_combo: bool = clamped_multiplier > 1
	if combo_label.visible != should_show_combo:
		combo_label.visible = should_show_combo
	combo_label.modulate.a = clampf(grace_remaining / 0.55, 0.55, 1.0)
	if combo_ring != null:
		combo_ring.set_ratio(
			grace_remaining / RampageRewardTuning.combo_grace_seconds()
			if multiplier > 1
			else 0.0
		)


func show_combo_milestone(tier: int) -> bool:
	return combo_herald != null and combo_herald.present(tier)


func dismiss_combo_herald() -> void:
	if combo_herald != null:
		combo_herald.dismiss()


func set_momentum(_value: float, _band: int) -> void:
	pass


func set_overdrive(_active: bool, _remaining: float) -> void:
	pass


func set_rare_tags(tags: PackedStringArray) -> void:
	for index: int in range(rare_labels.size()):
		rare_labels[index].text = tags[index] if index < tags.size() else ""
		rare_labels[index].visible = index < tags.size()


func set_status(_key: String, _placeholders: Dictionary = {}) -> void:
	pass


func set_objective(key: String, placeholders: Dictionary = {}) -> void:
	if objective_label != null:
		objective_label.text = L10n.t(key, placeholders)


func set_district_clear_progress(
	_district_id: StringName,
	cleared_buildings: int,
	required_buildings: int
) -> void:
	set_objective("objective.district_clear", {
		"current": cleared_buildings,
		"total": required_buildings,
	})


func set_district_exit_unlocked(
	_district_id: StringName,
	_next_district_id: StringName
) -> void:
	set_objective("objective.district_unlocked")


func _set_campaign_summary(dossier_count: int, continuity_generation: int) -> void:
	_campaign_dossier_count = maxi(dossier_count, 0)
	_continuity_generation = maxi(continuity_generation, 0)


func set_siege_progress(
	index: int,
	total: int,
	display_name: String,
	recovery: bool
) -> void:
	if siege_progress != null:
		siege_progress.set_progress(index, total, display_name, recovery)


func show_directive(
	profile: DirectiveProfile,
	current: int,
	target: int,
	bank: int,
	session: DirectiveSession = null
) -> void:
	directive_card.show_directive(profile, current, target, bank, session)


func set_directive_progress(profile: DirectiveProfile, current: int, target: int) -> void:
	directive_card.set_progress(profile, current, target)


func set_directive_bank(points: int) -> void:
	directive_card.set_bank(points)


func set_boss_status(
	state: StringName,
	current: float = 0.0,
	maximum: float = 1.0,
	boss_id: StringName = &""
) -> void:
	if state == &"IDLE" or state == &"COMPLETE":
		hide_boss_status()
		return
	_set_boss_status_visibility(true)
	boss_label.text = (
		L10n.t("boss.choir_prime.name")
		if boss_id == &"CHOIR_PRIME"
		else L10n.t("boss.command_unit.name")
	)
	_set_boss_bar_ratios(0.0, current / maxf(maximum, 1.0))


func set_campaign_boss_status(
	definition: BossEncounterDefinition,
	state: StringName,
	armor: float,
	armor_maximum: float,
	body: float,
	body_maximum: float,
	_evidence_id: StringName,
	_live_feedback: Dictionary = {}
) -> void:
	if definition == null or state == &"IDLE" or state == &"COMPLETE":
		hide_boss_status()
		return
	_set_boss_status_visibility(true)
	boss_label.text = L10n.t(definition.display_name_key)
	_set_boss_bar_ratios(
		armor / maxf(armor_maximum, 1.0),
		body / maxf(body_maximum, 1.0)
	)


func hide_boss_status() -> void:
	_set_boss_status_visibility(false)


func show_boss_fight() -> void:
	if boss_fight_herald != null:
		boss_fight_herald.present()


func _set_boss_bar_ratios(armor_ratio: float, health_ratio: float) -> void:
	_boss_armor_ratio = clampf(armor_ratio, 0.0, 1.0)
	_boss_health_ratio = clampf(health_ratio, 0.0, 1.0)
	if boss_armor_fill != null and boss_armor_track != null:
		boss_armor_fill.size.x = boss_armor_track.size.x * _boss_armor_ratio
	if boss_health_fill != null and boss_health_track != null:
		boss_health_fill.size.x = boss_health_track.size.x * _boss_health_ratio


func _set_boss_status_visibility(should_show: bool) -> void:
	for control: Control in [
		boss_panel,
		boss_label,
		boss_armor_track,
		boss_armor_fill,
		boss_health_track,
		boss_health_fill,
	]:
		if control != null:
			control.visible = should_show


func show_directive_result(
	text: String,
	success: bool,
	score_delta: int = 0
) -> void:
	directive_card.show_result(text, success, score_delta)


func show_game_over(summary: RunSummarySnapshot = null) -> void:
	dismiss_combo_herald()
	_hide_terminal_choices()
	set_status("hud.city_response_lost")
	set_objective("hud.chassis_signal_terminated")
	_show_summary(summary, false)


func show_district_complete(summary: RunSummarySnapshot) -> void:
	dismiss_combo_herald()
	_hide_terminal_choices()
	set_status("hud.district_response_broken")
	set_objective("hud.extraction_open")
	_show_summary(summary, true)


func _show_summary(summary: RunSummarySnapshot, completed: bool) -> void:
	overlay_title.text = L10n.t("hud.district_cleared" if completed else "hud.game_over")
	if summary != null:
		var tokens: Dictionary = {
			"grade": summary.grade,
			"points": "%03d" % summary.mastery_points,
			"score": "%08d" % summary.score,
			"acts": summary.waves_cleared,
			"hits": summary.heavy_hits,
			"variety": summary.unique_actions,
			"depth": summary.causal_depth,
			"objective": L10n.t(summary.retry_objective),
		}
		if completed:
			tokens.strongest = L10n.t(
				"summary.metric.%s" % String(summary.strongest_metric).to_lower()
			)
			tokens.weakest = L10n.t(
				"summary.metric.%s" % String(summary.weakest_metric).to_lower()
			)
			var summary_key: String = "hud.summary" if completed else "hud.summary_game_over"
			overlay_summary.text = L10n.t(summary_key, tokens)
		else:
			overlay_summary.text = L10n.t("hud.chassis_signal_lost")
		if completed and summary.ending_id != &"NONE":
			var ending_key: String = String(summary.ending_id).to_lower()
			overlay_title.text = L10n.t("finale.ending.%s.title" % ending_key)
			overlay_summary.text = L10n.t("finale.ending.%s.body" % ending_key)
	overlay_summary.text += "\n" + L10n.t("narrative.summary.progress", {
		"dossiers": _campaign_dossier_count,
		"total": CityDistrictCatalog.BUILDING_VARIANT_COUNT,
		"generation": _continuity_generation,
	})
	game_over_overlay.visible = true
	if summary != null and match_debrief != null:
		match_debrief.present(
			summary,
			overlay_title.text
		)
	else:
		retry_button.grab_focus()


func show_cycle_choice(cycle: int, can_continue: bool) -> void:
	dismiss_combo_herald()
	match_debrief.hide_panel()
	overlay_title.text = L10n.t(
		"hud.new_game_plus_ready" if can_continue else "hud.district_secured"
	)
	overlay_summary.text = L10n.t(
		"hud.new_game_plus_summary" if can_continue else "hud.cycle_complete",
		{"cycle": cycle, "score": "%08d" % maxi(_displayed_score(), 0)}
	)
	retry_button.visible = false
	title_button.visible = false
	extract_button.visible = true
	continue_button.visible = can_continue
	continue_button.text = L10n.t("hud.new_game_plus")
	new_game_plus_badge.visible = can_continue
	_apply_responsive_layout()
	game_over_overlay.visible = true
	if can_continue:
		continue_button.grab_focus()
	else:
		extract_button.grab_focus()


func _show_finale_choice(snapshot: FinaleEligibilitySnapshot) -> void:
	dismiss_combo_herald()
	match_debrief.hide_panel()
	overlay_title.text = L10n.t("finale.choice.title")
	overlay_summary.text = L10n.t(
		"finale.choice.summary" if snapshot.disentangle_eligible else "finale.choice.summary_ineligible",
		snapshot.as_dictionary()
	)
	retry_button.visible = false
	extract_button.visible = false
	continue_button.visible = false
	purge_button.visible = true
	disentangle_button.visible = true
	disentangle_button.text = L10n.t(
		"finale.choice.disentangle"
		if snapshot.disentangle_eligible
		else "finale.choice.ascension_warning"
	)
	disentangle_button.modulate = (
		Color.WHITE if snapshot.disentangle_eligible else Color(1.0, 0.54, 0.42, 1.0)
	)
	game_over_overlay.visible = true
	if snapshot.disentangle_eligible:
		disentangle_button.grab_focus()
	else:
		purge_button.grab_focus()


func _show_finale_result(outcome: int, cycle: int, can_continue: bool) -> void:
	dismiss_combo_herald()
	match_debrief.hide_panel()
	var ending_key: String = String(BossOutcome.id_for(outcome)).to_lower()
	overlay_title.text = L10n.t("finale.ending.%s.title" % ending_key)
	overlay_summary.text = (
		L10n.t("finale.ending.%s.body" % ending_key)
		+ "\n\n"
		+ L10n.t(
			"hud.new_game_plus_summary" if can_continue else "hud.cycle_complete",
			{"cycle": cycle, "score": "%08d" % maxi(_displayed_score(), 0)}
		)
	)
	retry_button.visible = false
	title_button.visible = false
	purge_button.visible = false
	disentangle_button.visible = false
	extract_button.visible = true
	continue_button.visible = can_continue
	continue_button.text = L10n.t("hud.new_game_plus")
	new_game_plus_badge.visible = can_continue
	_apply_responsive_layout()
	game_over_overlay.visible = true
	if can_continue:
		continue_button.grab_focus()
	else:
		extract_button.grab_focus()


func hide_terminal_overlay() -> void:
	dismiss_combo_herald()
	match_debrief.hide_panel()
	game_over_overlay.visible = false
	_hide_terminal_choices()


func _on_attack_mode_selected(mode: int, _attack_id: int) -> void:
	set_objective(
		"hud.jab_cross_locked"
		if mode == AttackSpec.Mode.JAB_CROSS
		else "hud.ground_locked"
	)


func _on_attack_committed(mode: int, _attack_id: int) -> void:
	if mode == AttackSpec.Mode.JAB_CROSS:
		set_objective("hud.jab_cross_committed")


func _build_rear_barrier_warning() -> void:
	rear_barrier_warning = ColorRect.new()
	rear_barrier_warning.name = "RearBarrierWarning"
	rear_barrier_warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rear_barrier_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rear_barrier_warning.color = Color.WHITE
	var shader: Shader = Shader.new()
	shader.code = REAR_BARRIER_VIGNETTE_SHADER
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter(&"intensity", 0.0)
	rear_barrier_warning.material = shader_material
	rear_barrier_warning.visible = false
	add_child(rear_barrier_warning)
	rear_barrier_warning_audio = AudioStreamPlayer.new()
	rear_barrier_warning_audio.name = "RearBarrierWarningVoice"
	rear_barrier_warning_audio.stream = REAR_BARRIER_WARNING_VOICE
	rear_barrier_warning_audio.bus = &"Voice"
	rear_barrier_warning_audio.volume_db = -4.0
	rear_barrier_warning_audio.max_polyphony = 1
	add_child(rear_barrier_warning_audio)


func _update_rear_barrier_warning(delta: float) -> void:
	if rear_barrier_warning == null or _rear_barrier_warning_remaining <= 0.0:
		return
	_rear_barrier_warning_remaining = maxf(
		_rear_barrier_warning_remaining - delta,
		0.0
	)
	var decay: float = pow(
		_rear_barrier_warning_remaining / REAR_BARRIER_WARNING_DURATION,
		1.65
	)
	_set_rear_barrier_warning_intensity(decay)
	if _rear_barrier_warning_remaining <= 0.0:
		rear_barrier_warning.visible = false


func _set_rear_barrier_warning_intensity(intensity: float) -> void:
	var shader_material: ShaderMaterial = rear_barrier_warning.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(&"intensity", clampf(intensity, 0.0, 1.0))


func _build_status_panel() -> void:
	status_panel = ColorRect.new()
	status_panel.position = Vector2(24.0, 22.0)
	status_panel.size = Vector2(420.0, 88.0)
	status_panel.color = PANEL_COLOR
	add_child(status_panel)
	health_icon = TextureRect.new()
	health_icon.name = "HealthIcon"
	health_icon.texture = CHASSIS_HEART_TEXTURE
	health_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	health_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	health_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_icon)
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.position = Vector2(78.0, 34.0)
	health_label.add_theme_font_size_override(&"font_size", 25)
	add_child(health_label)
	objective_label = Label.new()
	objective_label.name = "ObjectiveLabel"
	objective_label.position = Vector2(48.0, 68.0)
	objective_label.text = L10n.t(
		"hud.move_hint",
		InputBindingSettings.display_placeholders()
	)
	objective_label.add_theme_font_size_override(&"font_size", 20)
	objective_label.modulate = MUTED_COLOR
	add_child(objective_label)


func _build_combo_indicator() -> void:
	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.position = Vector2(764.0, 28.0)
	combo_label.size = Vector2(176.0, 32.0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.add_theme_font_size_override(&"font_size", 22)
	combo_label.modulate = ACCENT_COLOR
	add_child(combo_label)
	combo_ring = ComboDecayRing.new()
	combo_ring.name = "ComboDecayRing"
	combo_ring.position = Vector2(712.0, 24.0)
	combo_ring.size = Vector2(38.0, 38.0)
	combo_ring.visible = false
	add_child(combo_ring)


func _build_combo_herald() -> void:
	combo_herald = ComboHerald.new()
	add_child(combo_herald)


func _build_score_panel() -> void:
	score_panel = ColorRect.new()
	score_panel.position = Vector2(988.0, 22.0)
	score_panel.size = Vector2(268.0, 88.0)
	score_panel.color = PANEL_COLOR
	add_child(score_panel)
	score_caption = Label.new()
	score_caption.position = Vector2(1012.0, 30.0)
	score_caption.size = Vector2(220.0, 28.0)
	score_caption.text = L10n.t("hud.rampage_score")
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_caption.add_theme_font_size_override(&"font_size", 18)
	score_caption.modulate = ACCENT_COLOR
	add_child(score_caption)
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(1012.0, 56.0)
	score_label.size = Vector2(220.0, 42.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override(&"font_size", 30)
	add_child(score_label)
	pending_score_label = Label.new()
	pending_score_label.name = "PendingScoreLabel"
	pending_score_label.position = Vector2(1012.0, 91.0)
	pending_score_label.size = Vector2(220.0, 20.0)
	pending_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pending_score_label.add_theme_font_size_override(&"font_size", 14)
	pending_score_label.text = L10n.t("hud.safe")
	pending_score_label.modulate = MUTED_COLOR
	add_child(pending_score_label)
	for index: int in range(RuntimeBudget.RARE_TAG_ROWS):
		var rare_label: Label = Label.new()
		rare_label.name = "RareEvent%d" % index
		rare_label.position = Vector2(1012.0, 116.0 + float(index) * 23.0)
		rare_label.size = Vector2(220.0, 22.0)
		rare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rare_label.add_theme_font_size_override(&"font_size", 16)
		rare_label.modulate = ACCENT_COLOR
		rare_label.visible = false
		add_child(rare_label)
		rare_labels.append(rare_label)


func _build_siege_progress() -> void:
	siege_progress = SiegeProgressStrip.new()
	siege_progress.name = "SiegeProgressStrip"
	siege_progress.position = Vector2(466.0, 112.0)
	siege_progress.size = Vector2(500.0, 32.0)
	add_child(siege_progress)


func _build_directive_card() -> void:
	directive_card = DirectiveCard.new()
	directive_card.name = "DirectiveCard"
	directive_card.position = Vector2(808.0, 392.0)
	directive_card.size = DirectiveCard.LANDSCAPE_SIZE
	add_child(directive_card)


func _build_directive_choice_overlay() -> void:
	directive_choice_overlay = DirectiveChoiceOverlay.new()
	directive_choice_overlay.name = "DirectiveChoiceOverlay"
	add_child(directive_choice_overlay)


func _build_boss_status() -> void:
	boss_panel = ColorRect.new()
	boss_panel.name = "BossStatusPanel"
	boss_panel.position = Vector2(400.0, 142.0)
	boss_panel.size = Vector2(660.0, 88.0)
	boss_panel.color = Color(0.015, 0.02, 0.028, 0.82)
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.visible = false
	add_child(boss_panel)
	boss_label = Label.new()
	boss_label.name = "BossStatus"
	boss_label.position = Vector2(416.0, 146.0)
	boss_label.size = Vector2(628.0, 30.0)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override(&"font_size", 20)
	boss_label.add_theme_constant_override(&"outline_size", 5)
	boss_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	boss_label.modulate = Color.WHITE
	boss_label.visible = false
	add_child(boss_label)
	boss_armor_track = ColorRect.new()
	boss_armor_track.name = "BossArmorTrack"
	boss_armor_track.position = Vector2(416.0, 181.0)
	boss_armor_track.size = Vector2(628.0, 12.0)
	boss_armor_track.color = Color(0.10, 0.09, 0.04, 0.94)
	boss_armor_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_armor_track.visible = false
	add_child(boss_armor_track)
	boss_armor_fill = ColorRect.new()
	boss_armor_fill.name = "BossArmorFill"
	boss_armor_fill.position = boss_armor_track.position
	boss_armor_fill.size = boss_armor_track.size
	boss_armor_fill.color = Color("f4c542")
	boss_armor_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_armor_fill.visible = false
	add_child(boss_armor_fill)
	boss_health_track = ColorRect.new()
	boss_health_track.name = "BossHealthTrack"
	boss_health_track.position = Vector2(416.0, 199.0)
	boss_health_track.size = Vector2(628.0, 18.0)
	boss_health_track.color = Color(0.11, 0.02, 0.025, 0.96)
	boss_health_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health_track.visible = false
	add_child(boss_health_track)
	boss_health_fill = ColorRect.new()
	boss_health_fill.name = "BossHealthFill"
	boss_health_fill.position = boss_health_track.position
	boss_health_fill.size = boss_health_track.size
	boss_health_fill.color = Color("e3313f")
	boss_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health_fill.visible = false
	add_child(boss_health_fill)


func _build_boss_fight_herald() -> void:
	boss_fight_herald = BossFightHerald.new()
	add_child(boss_fight_herald)


func _build_transmission_toast() -> void:
	transmission_toast = TRANSMISSION_TOAST_SCRIPT.new() as TransmissionToast
	add_child(transmission_toast)


func _build_first_run_tutorial() -> void:
	first_run_tutorial = FIRST_RUN_TUTORIAL_SCRIPT.new() as FirstRunCombatTutorial
	first_run_tutorial.setup(_robot, _contextual_attacks)
	add_child(first_run_tutorial)


func _build_game_over_overlay() -> void:
	game_over_overlay = Control.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.z_index = 20
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.visible = false
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_over_overlay)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.03, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_overlay.add_child(shade)
	terminal_panel = ColorRect.new()
	terminal_panel.position = Vector2(365.0, 188.0)
	terminal_panel.size = Vector2(550.0, 340.0)
	terminal_panel.color = Color(0.025, 0.05, 0.065, 0.97)
	game_over_overlay.add_child(terminal_panel)
	new_game_plus_badge = TextureRect.new()
	new_game_plus_badge.name = "NewGamePlusBadge"
	new_game_plus_badge.texture = NEW_GAME_PLUS_BADGE_TEXTURE
	new_game_plus_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_game_plus_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	new_game_plus_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_game_plus_badge.visible = false
	game_over_overlay.add_child(new_game_plus_badge)
	overlay_title = Label.new()
	overlay_title.position = Vector2(405.0, 218.0)
	overlay_title.size = Vector2(470.0, 72.0)
	overlay_title.text = L10n.t("hud.game_over")
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override(&"font_size", 48)
	overlay_title.modulate = ACCENT_COLOR
	game_over_overlay.add_child(overlay_title)
	overlay_summary = Label.new()
	overlay_summary.position = Vector2(405.0, 296.0)
	overlay_summary.size = Vector2(470.0, 128.0)
	overlay_summary.text = L10n.t("hud.chassis_signal_lost")
	overlay_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_summary.clip_text = true
	overlay_summary.add_theme_font_size_override(&"font_size", 20)
	overlay_summary.modulate = MUTED_COLOR
	game_over_overlay.add_child(overlay_summary)
	retry_button = Button.new()
	retry_button.name = "RetryButton"
	retry_button.position = Vector2(490.0, 430.0)
	retry_button.size = Vector2(300.0, 78.0)
	retry_button.text = L10n.t("hud.retry")
	retry_button.focus_mode = Control.FOCUS_ALL
	retry_button.add_theme_font_size_override(&"font_size", 30)
	retry_button.pressed.connect(retry_pressed.emit)
	game_over_overlay.add_child(retry_button)
	title_button = Button.new()
	title_button.name = "TitleButton"
	title_button.position = Vector2(650.0, 430.0)
	title_button.size = Vector2(225.0, 78.0)
	title_button.text = L10n.t("hud.title_screen")
	title_button.focus_mode = Control.FOCUS_ALL
	title_button.add_theme_font_size_override(&"font_size", 24)
	title_button.pressed.connect(title_pressed.emit)
	game_over_overlay.add_child(title_button)
	extract_button = Button.new()
	extract_button.name = "ExtractButton"
	extract_button.position = Vector2(445.0, 430.0)
	extract_button.size = Vector2(185.0, 78.0)
	extract_button.text = L10n.t("hud.extract")
	extract_button.add_theme_font_size_override(&"font_size", 25)
	extract_button.pressed.connect(extract_pressed.emit)
	extract_button.visible = false
	game_over_overlay.add_child(extract_button)
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.position = Vector2(650.0, 430.0)
	continue_button.size = Vector2(185.0, 78.0)
	continue_button.text = L10n.t("hud.continue")
	continue_button.add_theme_font_size_override(&"font_size", 25)
	continue_button.pressed.connect(continue_pressed.emit)
	continue_button.visible = false
	game_over_overlay.add_child(continue_button)
	purge_button = Button.new()
	purge_button.name = "PurgeButton"
	purge_button.position = Vector2(445.0, 430.0)
	purge_button.size = Vector2(185.0, 78.0)
	purge_button.text = L10n.t("finale.choice.purge")
	purge_button.add_theme_font_size_override(&"font_size", 23)
	purge_button.pressed.connect(purge_pressed.emit)
	purge_button.visible = false
	game_over_overlay.add_child(purge_button)
	disentangle_button = Button.new()
	disentangle_button.name = "DisentangleButton"
	disentangle_button.position = Vector2(650.0, 430.0)
	disentangle_button.size = Vector2(185.0, 78.0)
	disentangle_button.text = L10n.t("finale.choice.disentangle")
	disentangle_button.add_theme_font_size_override(&"font_size", 21)
	disentangle_button.pressed.connect(disentangle_pressed.emit)
	disentangle_button.visible = false
	game_over_overlay.add_child(disentangle_button)
	match_debrief = MatchDebriefPanel.new()
	match_debrief.retry_pressed.connect(retry_pressed.emit)
	match_debrief.title_pressed.connect(title_pressed.emit)
	game_over_overlay.add_child(match_debrief)
	match_debrief.configure_profile(_combat_profile)


func _is_portrait_layout() -> bool:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return viewport_size.y > viewport_size.x


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size / maxf(_hud_tuning_scale, 0.01)
	)
	if viewport_size.y > viewport_size.x:
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout(viewport_size)
	if directive_choice_overlay != null:
		directive_choice_overlay.apply_responsive_layout(viewport_size)
	if first_run_tutorial != null:
		first_run_tutorial.apply_responsive_layout(viewport_size)
	if directive_card != null:
		directive_card.apply_responsive_layout(viewport_size)
	if transmission_toast != null:
		transmission_toast.apply_responsive_layout(viewport_size)
	if combo_herald != null:
		combo_herald.apply_responsive_layout(viewport_size)
	if boss_fight_herald != null:
		boss_fight_herald.apply_responsive_layout(viewport_size)
	if match_debrief != null:
		match_debrief.apply_responsive_layout(viewport_size)
	_layout_tweak_controls_button(viewport_size)


func _apply_live_visual_tuning() -> void:
	var next_scale: float = float(RuntimeTweakAccess.live_value(
		&"interface.hud.scale", 1.0
	))
	var next_tint: Color = RuntimeTweakAccess.live_color(
		&"interface.hud.tint", Color.WHITE
	)
	var next_opacity: float = float(RuntimeTweakAccess.live_value(
		&"interface.hud.opacity", 1.0
	))
	if not is_equal_approx(next_scale, _hud_tuning_scale):
		_hud_tuning_scale = next_scale
		transform = Transform2D.IDENTITY.scaled(Vector2.ONE * next_scale)
		_apply_responsive_layout()
	var modulation_changed: bool = false
	if next_tint != _hud_tuning_tint:
		_hud_tuning_tint = next_tint
		modulation_changed = true
	if not is_equal_approx(next_opacity, _hud_tuning_opacity):
		_hud_tuning_opacity = next_opacity
		modulation_changed = true
	if modulation_changed:
		_apply_hud_child_modulation()


func _apply_hud_child_modulation() -> void:
	for child: Node in get_children():
		if not child is CanvasItem:
			continue
		if child == tweak_controls_button:
			_apply_tweak_controls_button_opacity()
			continue
		var child_modulate: Color = (
			Color.WHITE if child == tweak_leaderboard_disclaimer else _hud_tuning_tint
		)
		child_modulate.a *= _hud_tuning_opacity
		(child as CanvasItem).self_modulate = child_modulate


func _build_tweak_controls_button() -> void:
	tweak_controls_button = Button.new()
	tweak_controls_button.name = "TweakControlsButton"
	tweak_controls_button.text = L10n.t("tuning.action.open")
	tweak_controls_button.focus_mode = Control.FOCUS_ALL
	tweak_controls_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tweak_controls_button.clip_text = true
	tweak_controls_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tweak_controls_button.z_index = TWEAK_BUTTON_Z_INDEX
	RuntimeTweakTheme.style_button(tweak_controls_button, false, true)
	tweak_controls_button.custom_minimum_size.y = TWEAK_BUTTON_HEIGHT
	tweak_controls_button.add_theme_color_override(
		&"font_color", RuntimeTweakTheme.ACCENT
	)
	tweak_controls_button.pressed.connect(tweak_controls_requested.emit)
	tweak_controls_button.mouse_entered.connect(
		_set_tweak_controls_button_hovered.bind(true)
	)
	tweak_controls_button.mouse_exited.connect(
		_set_tweak_controls_button_hovered.bind(false)
	)
	add_child(tweak_controls_button)
	_apply_tweak_controls_button_opacity()
	tweak_leaderboard_disclaimer = Label.new()
	tweak_leaderboard_disclaimer.name = "TweakLeaderboardDisclaimer"
	tweak_leaderboard_disclaimer.text = L10n.t(
		"tuning.hud.leaderboard_disabled"
	)
	tweak_leaderboard_disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tweak_leaderboard_disclaimer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tweak_leaderboard_disclaimer.clip_text = true
	tweak_leaderboard_disclaimer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tweak_leaderboard_disclaimer.z_index = TWEAK_BUTTON_Z_INDEX
	tweak_leaderboard_disclaimer.add_theme_color_override(
		&"font_color", Color("ff695c")
	)
	tweak_leaderboard_disclaimer.add_theme_constant_override(&"outline_size", 4)
	tweak_leaderboard_disclaimer.add_theme_color_override(
		&"font_outline_color", Color(0.0, 0.0, 0.0, 0.94)
	)
	tweak_leaderboard_disclaimer.visible = false
	add_child(tweak_leaderboard_disclaimer)


func _layout_tweak_controls_button(viewport_size: Vector2) -> void:
	if tweak_controls_button == null or tweak_leaderboard_disclaimer == null:
		return
	var width: float = minf(TWEAK_BUTTON_WIDTH, viewport_size.x - 32.0)
	var disclaimer_height: float = 22.0
	var button_y: float = (
		viewport_size.y - TWEAK_BUTTON_BOTTOM_MARGIN - TWEAK_BUTTON_HEIGHT
	)
	tweak_controls_button.position = Vector2(
		viewport_size.x - width - TWEAK_BUTTON_RIGHT_MARGIN,
		button_y
	)
	tweak_controls_button.size = Vector2(width, TWEAK_BUTTON_HEIGHT)
	tweak_controls_button.add_theme_font_size_override(
		&"font_size",
		TWEAK_BUTTON_PORTRAIT_FONT_SIZE
		if viewport_size.y > viewport_size.x
		else TWEAK_BUTTON_LANDSCAPE_FONT_SIZE
	)
	tweak_leaderboard_disclaimer.position = Vector2(
		viewport_size.x - width - TWEAK_BUTTON_RIGHT_MARGIN,
		button_y - 4.0 - disclaimer_height
	)
	tweak_leaderboard_disclaimer.size = Vector2(width, disclaimer_height)
	tweak_leaderboard_disclaimer.add_theme_font_size_override(
		&"font_size", 12 if viewport_size.y > viewport_size.x else 13
	)


func _set_tweak_controls_button_hovered(hovered: bool) -> void:
	_tweak_controls_hovered = hovered
	_apply_tweak_controls_button_opacity()


func _apply_tweak_controls_button_opacity() -> void:
	if tweak_controls_button == null:
		return
	tweak_controls_button.self_modulate = Color(
		1.0,
		1.0,
		1.0,
		TWEAK_BUTTON_HOVER_OPACITY
		if _tweak_controls_hovered
		else TWEAK_BUTTON_IDLE_OPACITY
	)


func _set_tuning_provenance(snapshot: Dictionary) -> void:
	if tweak_leaderboard_disclaimer == null:
		return
	tweak_leaderboard_disclaimer.visible = not bool(
		snapshot.get("ranked_eligible", true)
	)


func _apply_landscape_layout(viewport_size: Vector2) -> void:
	var center_x: float = viewport_size.x * 0.5 - 250.0
	var score_x: float = viewport_size.x - 292.0
	status_panel.position = Vector2(24.0, 22.0)
	status_panel.size = Vector2(420.0, 88.0)
	health_icon.position = Vector2(46.0, 36.0)
	health_icon.size = Vector2(26.0, 26.0)
	health_label.position = Vector2(78.0, 34.0)
	health_label.size = Vector2(350.0, 30.0)
	health_label.add_theme_font_size_override(&"font_size", 25)
	objective_label.position = Vector2(48.0, 68.0)
	objective_label.size = Vector2(380.0, 26.0)
	objective_label.add_theme_font_size_override(&"font_size", 20)
	combo_label.position = Vector2(center_x + 298.0, 28.0)
	combo_label.size = Vector2(176.0, 32.0)
	combo_label.add_theme_font_size_override(&"font_size", 22)
	combo_ring.custom_minimum_size = Vector2(38.0, 38.0)
	combo_ring.position = Vector2(center_x + 246.0, 24.0)
	combo_ring.size = Vector2(38.0, 38.0)
	score_panel.position = Vector2(score_x, 22.0)
	score_panel.size = Vector2(268.0, 88.0)
	_set_score_geometry(
		Vector2(score_x + 24.0, 30.0), Vector2(220.0, 28.0), true, false
	)
	score_caption.add_theme_font_size_override(&"font_size", 18)
	score_label.add_theme_font_size_override(&"font_size", 30)
	pending_score_label.add_theme_font_size_override(&"font_size", 14)
	for index: int in range(rare_labels.size()):
		rare_labels[index].position = Vector2(
			score_x + 24.0, 116.0 + float(index) * 23.0
		)
		rare_labels[index].size = Vector2(220.0, 22.0)
		rare_labels[index].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rare_labels[index].add_theme_font_size_override(&"font_size", 16)
	siege_progress.position = Vector2(center_x, 112.0)
	siege_progress.size = Vector2(500.0, 32.0)
	siege_progress.set_compact(false)
	siege_progress.apply_width(500.0)
	directive_card.position = Vector2(viewport_size.x - 472.0, 382.0)
	var boss_x: float = viewport_size.x * 0.5 - 330.0
	boss_panel.position = Vector2(boss_x, 142.0)
	boss_panel.size = Vector2(660.0, 88.0)
	boss_label.position = Vector2(boss_x + 16.0, 146.0)
	boss_label.size = Vector2(628.0, 30.0)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override(&"font_size", 20)
	boss_armor_track.position = Vector2(boss_x + 16.0, 181.0)
	boss_armor_track.size = Vector2(628.0, 12.0)
	boss_health_track.position = Vector2(boss_x + 16.0, 199.0)
	boss_health_track.size = Vector2(628.0, 18.0)
	boss_armor_fill.position = boss_armor_track.position
	boss_health_fill.position = boss_health_track.position
	_set_boss_bar_ratios(_boss_armor_ratio, _boss_health_ratio)
	_apply_landscape_terminal_layout(viewport_size)


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	var panel_width: float = minf(300.0, viewport_size.x * 0.46)
	status_panel.position = Vector2.ZERO
	status_panel.size = Vector2(panel_width, 34.0)
	health_icon.position = Vector2(8.0, 3.0)
	health_icon.size = Vector2(15.0, 15.0)
	health_label.position = Vector2(27.0, 2.0)
	health_label.size = Vector2(panel_width - 35.0, 17.0)
	health_label.add_theme_font_size_override(&"font_size", 15)
	objective_label.position = Vector2(8.0, 18.0)
	objective_label.size = Vector2(panel_width - 16.0, 14.0)
	objective_label.add_theme_font_size_override(&"font_size", 10)
	objective_label.clip_text = true
	combo_label.position = Vector2(panel_width + 28.0, 3.0)
	combo_label.size = Vector2(94.0, 18.0)
	combo_label.add_theme_font_size_override(&"font_size", 12)
	combo_ring.custom_minimum_size = Vector2(16.0, 16.0)
	combo_ring.position = Vector2(panel_width + 8.0, 4.0)
	combo_ring.size = Vector2(16.0, 16.0)
	score_panel.position = Vector2(0.0, 40.0)
	score_panel.size = Vector2(panel_width, 68.0)
	_set_score_geometry(Vector2(8.0, 44.0), Vector2(136.0, 14.0), false, true)
	score_caption.add_theme_font_size_override(&"font_size", 10)
	score_label.add_theme_font_size_override(&"font_size", 20)
	pending_score_label.add_theme_font_size_override(&"font_size", 9)
	for index: int in range(rare_labels.size()):
		rare_labels[index].position = Vector2(152.0, 45.0 + float(index) * 18.0)
		rare_labels[index].size = Vector2(panel_width - 160.0, 16.0)
		rare_labels[index].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		rare_labels[index].add_theme_font_size_override(&"font_size", 9)
	siege_progress.position = Vector2(0.0, 114.0)
	siege_progress.size = Vector2(panel_width, 24.0)
	siege_progress.set_compact(true)
	siege_progress.apply_width(panel_width)
	directive_card.position = Vector2(18.0, viewport_size.y - 338.0)
	var boss_width: float = minf(viewport_size.x - 24.0, 440.0)
	var boss_x: float = (viewport_size.x - boss_width) * 0.5
	boss_panel.position = Vector2(boss_x, 210.0)
	boss_panel.size = Vector2(boss_width, 66.0)
	boss_label.position = Vector2(boss_x + 10.0, 212.0)
	boss_label.size = Vector2(boss_width - 20.0, 22.0)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override(&"font_size", 13)
	boss_armor_track.position = Vector2(boss_x + 10.0, 239.0)
	boss_armor_track.size = Vector2(boss_width - 20.0, 8.0)
	boss_health_track.position = Vector2(boss_x + 10.0, 253.0)
	boss_health_track.size = Vector2(boss_width - 20.0, 13.0)
	boss_armor_fill.position = boss_armor_track.position
	boss_health_fill.position = boss_health_track.position
	_set_boss_bar_ratios(_boss_armor_ratio, _boss_health_ratio)
	_apply_portrait_terminal_layout(viewport_size)


func _set_score_geometry(
	origin: Vector2,
	label_size: Vector2,
	align_right: bool,
	compact: bool
) -> void:
	score_caption.position = origin
	score_caption.size = label_size
	score_label.position = origin + Vector2(0.0, 16.0 if compact else 26.0)
	score_label.size = Vector2(label_size.x, 26.0 if compact else 42.0)
	pending_score_label.position = origin + Vector2(0.0, 42.0 if compact else 61.0)
	pending_score_label.size = Vector2(label_size.x, 14.0 if compact else 20.0)
	var alignment: HorizontalAlignment = (
		HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	)
	score_caption.horizontal_alignment = alignment
	score_label.horizontal_alignment = alignment
	pending_score_label.horizontal_alignment = alignment


func _apply_landscape_terminal_layout(viewport_size: Vector2) -> void:
	var offset_x: float = (viewport_size.x - 1280.0) * 0.5
	terminal_panel.position = Vector2(315.0 + offset_x, 188.0)
	terminal_panel.size = Vector2(650.0, 340.0)
	new_game_plus_badge.position = Vector2(335.0 + offset_x, 218.0)
	new_game_plus_badge.size = Vector2(72.0, 72.0)
	overlay_title.position = (
		Vector2(425.0 + offset_x, 218.0)
		if new_game_plus_badge.visible
		else Vector2(345.0 + offset_x, 218.0)
	)
	overlay_title.size = (
		Vector2(480.0, 72.0) if new_game_plus_badge.visible else Vector2(590.0, 72.0)
	)
	overlay_summary.position = Vector2(345.0 + offset_x, 296.0)
	overlay_summary.size = Vector2(590.0, 128.0)
	retry_button.position = Vector2(365.0 + offset_x, 430.0)
	retry_button.size = Vector2(260.0, 78.0)
	title_button.position = Vector2(655.0 + offset_x, 430.0)
	title_button.size = Vector2(260.0, 78.0)
	extract_button.position = Vector2(365.0 + offset_x, 430.0)
	extract_button.size = Vector2(260.0, 78.0)
	continue_button.position = Vector2(655.0 + offset_x, 430.0)
	continue_button.size = Vector2(260.0, 78.0)
	purge_button.position = Vector2(365.0 + offset_x, 430.0)
	purge_button.size = Vector2(260.0, 78.0)
	disentangle_button.position = Vector2(655.0 + offset_x, 430.0)
	disentangle_button.size = Vector2(260.0, 78.0)


func _apply_portrait_terminal_layout(viewport_size: Vector2) -> void:
	var panel_width: float = viewport_size.x - 64.0
	terminal_panel.position = Vector2(32.0, 304.0)
	terminal_panel.size = Vector2(panel_width, 560.0)
	new_game_plus_badge.position = Vector2(viewport_size.x * 0.5 - 48.0, 324.0)
	new_game_plus_badge.size = Vector2(96.0, 96.0)
	overlay_title.position = (
		Vector2(52.0, 426.0) if new_game_plus_badge.visible else Vector2(52.0, 334.0)
	)
	overlay_title.size = Vector2(viewport_size.x - 104.0, 82.0)
	overlay_summary.position = (
		Vector2(52.0, 510.0) if new_game_plus_badge.visible else Vector2(52.0, 430.0)
	)
	overlay_summary.size = Vector2(
		viewport_size.x - 104.0,
		156.0 if new_game_plus_badge.visible else 236.0
	)
	retry_button.position = Vector2(82.0, 720.0)
	retry_button.size = Vector2(258.0, 88.0)
	title_button.position = Vector2(viewport_size.x - 340.0, 720.0)
	title_button.size = Vector2(258.0, 88.0)
	extract_button.position = Vector2(82.0, 720.0)
	extract_button.size = Vector2(258.0, 88.0)
	continue_button.position = Vector2(viewport_size.x - 340.0, 720.0)
	continue_button.size = Vector2(258.0, 88.0)
	purge_button.position = Vector2(82.0, 720.0)
	purge_button.size = Vector2(258.0, 88.0)
	disentangle_button.position = Vector2(viewport_size.x - 340.0, 720.0)
	disentangle_button.size = Vector2(258.0, 88.0)


func _hide_terminal_choices() -> void:
	if match_debrief != null:
		match_debrief.hide_panel()
	retry_button.visible = true
	title_button.visible = true
	extract_button.visible = false
	continue_button.visible = false
	purge_button.visible = false
	disentangle_button.visible = false
	new_game_plus_badge.visible = false
	_apply_responsive_layout()
