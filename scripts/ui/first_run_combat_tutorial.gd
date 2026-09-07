class_name FirstRunCombatTutorial
extends Control

signal step_changed(step: int)
signal tutorial_completed(skipped: bool)

enum Step {
	MOVE,
	GROUND_SMASH,
	JAB_CROSS,
	CHARGE_ATTACK,
	DASH,
	DASH_PUNCH,
	COMPLETE,
}

const VERSION: int = 1
const PREFERENCE_PATH: String = "user://combat_tutorial.cfg"
const STEP_COUNT: int = 6
const PANEL_COLOR: Color = Color(0.018, 0.042, 0.055, 0.94)
const BORDER_COLOR: Color = Color("5dc9c2")
const ACCENT_COLOR: Color = Color("7ef4df")
const MUTED_COLOR: Color = Color("b7c4cb")
const COMPLETE_COLOR: Color = Color("f1b36f")
const COMPLETE_HOLD_SECONDS: float = 1.6

var preference_path: String = PREFERENCE_PATH
var input_method: StringName = &"all"
var _shown_locale: String = ""
var _step_seconds: float = 0.0
var _help_shown: bool = false
var current_step: Step = Step.MOVE
var tutorial_active: bool = false
var completed: bool = false
var skipped: bool = false
var panel: Panel
var accent_line: ColorRect
var progress_label: Label
var title_label: Label
var body_label: Label
var skip_button: Button
var _robot: GiantRobotController
var _attacks: ContextualAttackController
var _mobile_controls: MobileControls
var _completion_generation: int = 0
var _pending_dash_punch_attack_id: int = 0


func setup(
	robot: GiantRobotController,
	attacks: ContextualAttackController,
	mobile_controls: MobileControls = null
) -> void:
	_robot = robot
	_attacks = attacks
	_mobile_controls = mobile_controls
	_bind_mechanic_signals()
	if is_node_ready():
		_start_if_needed()


func _ready() -> void:
	name = "FirstRunCombatTutorial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12
	_build_card()
	get_viewport().size_changed.connect(_apply_viewport_layout)
	_apply_viewport_layout()
	L10n.apply_locale_font(self)
	_start_if_needed()


func start_for_test() -> void:
	_start_tutorial()


func observe_locomotion(state: int) -> void:
	if not tutorial_active or current_step != Step.MOVE:
		return
	if state == GiantRobotController.LocomotionState.WALK:
		_advance_to(Step.GROUND_SMASH)


func observe_attack_committed(mode: int, attack_id: int) -> void:
	if not tutorial_active:
		return
	if current_step == Step.GROUND_SMASH and mode == AttackSpec.Mode.GROUND_SMASH:
		_advance_to(Step.JAB_CROSS)
	elif current_step == Step.JAB_CROSS and mode == AttackSpec.Mode.JAB_CROSS:
		_advance_to(Step.CHARGE_ATTACK)
	elif (
		current_step == Step.DASH_PUNCH
		and mode == AttackSpec.Mode.JAB_CROSS
		and attack_id == _pending_dash_punch_attack_id
	):
		_finish_tutorial(false)


func observe_charge_released(
	spec: AttackSpec,
	_duration: float,
	_multiplier: float
) -> void:
	if (
		tutorial_active
		and current_step == Step.CHARGE_ATTACK
		and spec != null
		and spec.is_fully_charged()
	):
		_advance_to(Step.DASH)


func observe_attack_started(spec: AttackSpec) -> void:
	if (
		tutorial_active
		and current_step == Step.DASH_PUNCH
		and spec != null
		and spec.is_jab_cross()
		and is_equal_approx(
			spec.speed_ratio,
			ContextualAttackController.DODGE_CANCEL_MELEE_MOMENTUM_RATIO
		)
	):
		_pending_dash_punch_attack_id = spec.attack_id


func observe_dodge_started(_facing: int, _duration: float) -> void:
	if tutorial_active and current_step == Step.DASH:
		_advance_to(Step.DASH_PUNCH)


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	var portrait: bool = viewport_size.y > viewport_size.x
	if portrait:
		panel.position = Vector2(18.0, 226.0)
		panel.size = Vector2(maxf(viewport_size.x - 36.0, 0.0), 236.0 if _help_shown else 190.0)
	else:
		panel.position = Vector2(36.0, 166.0)
		panel.size = Vector2(520.0, 236.0 if _help_shown else 190.0)
	accent_line.position = Vector2.ZERO
	accent_line.size = Vector2(5.0, panel.size.y)
	progress_label.position = Vector2(24.0, 16.0)
	progress_label.size = Vector2(panel.size.x - 152.0, 24.0)
	title_label.position = Vector2(24.0, 43.0)
	title_label.size = Vector2(panel.size.x - 48.0, 34.0)
	body_label.position = Vector2(24.0, 82.0)
	body_label.size = Vector2(panel.size.x - 48.0, panel.size.y - 96.0)
	skip_button.position = Vector2(panel.size.x - 124.0, 12.0)
	skip_button.size = Vector2(104.0, 38.0)
	progress_label.add_theme_font_size_override(&"font_size", 16 if portrait else 15)
	title_label.add_theme_font_size_override(&"font_size", 25 if portrait else 23)
	body_label.add_theme_font_size_override(&"font_size", 20 if portrait else 18)
	skip_button.add_theme_font_size_override(&"font_size", 16)


func _bind_mechanic_signals() -> void:
	if _robot != null:
		if not _robot.locomotion_changed.is_connected(observe_locomotion):
			_robot.locomotion_changed.connect(observe_locomotion)
		if not _robot.attack_committed.is_connected(observe_attack_committed):
			_robot.attack_committed.connect(observe_attack_committed)
		if not _robot.dodge_started.is_connected(observe_dodge_started):
			_robot.dodge_started.connect(observe_dodge_started)
	if _attacks != null:
		if not _attacks.charge_released.is_connected(observe_charge_released):
			_attacks.charge_released.connect(observe_charge_released)
		if not _attacks.attack_started.is_connected(observe_attack_started):
			_attacks.attack_started.connect(observe_attack_started)


func _start_tutorial() -> void:
	if panel == null:
		return
	_completion_generation += 1
	_pending_dash_punch_attack_id = 0
	current_step = Step.MOVE
	tutorial_active = true
	completed = false
	skipped = false
	visible = true
	_update_copy()
	step_changed.emit(current_step)


func _advance_to(next_step: Step) -> void:
	if not tutorial_active or next_step <= current_step or next_step >= Step.COMPLETE:
		return
	_step_seconds = 0.0
	_help_shown = false
	current_step = next_step
	_update_copy()
	step_changed.emit(current_step)


func _finish_tutorial(was_skipped: bool) -> void:
	if completed:
		return
	_completion_generation += 1
	_pending_dash_punch_attack_id = 0
	var generation: int = _completion_generation
	current_step = Step.COMPLETE
	tutorial_active = false
	completed = true
	skipped = was_skipped
	var preference: ConfigFile = ConfigFile.new()
	preference.set_value("combat_tutorial", "version", VERSION)
	preference.set_value("combat_tutorial", "completed", true)
	preference.save(preference_path)
	_update_copy()
	tutorial_completed.emit(skipped)
	_hold_completion_card(generation)


func _hold_completion_card(generation: int) -> void:
	await get_tree().create_timer(COMPLETE_HOLD_SECONDS, false).timeout
	if generation == _completion_generation and current_step == Step.COMPLETE:
		visible = false


func _update_copy() -> void:
	if progress_label == null:
		return
	var step_number: int = mini(int(current_step) + 1, STEP_COUNT)
	progress_label.text = L10n.t("tutorial.progress", {
		"current": "%02d" % step_number,
		"total": "%02d" % STEP_COUNT,
	})
	var key: String = ""
	match current_step:
		Step.MOVE:
			key = "move"
		Step.GROUND_SMASH:
			key = "ground_smash"
		Step.JAB_CROSS:
			key = "jab_cross"
		Step.CHARGE_ATTACK:
			key = "charge_attack"
		Step.DASH:
			key = "dash"
		Step.DASH_PUNCH:
			key = "dash_punch"
		Step.COMPLETE:
			key = "complete"
	title_label.text = L10n.t("tutorial.%s.title" % key)
	body_label.text = L10n.t(
		"tutorial.%s.body%s" % [key, "" if input_method == &"all" or current_step == Step.COMPLETE else "." + String(input_method)],
		InputBindingSettings.display_placeholders()
	)
	if _help_shown and tutorial_active:
		body_label.text = L10n.t("tutorial.with_help", {"body": body_label.text})
	_apply_viewport_layout()
	_shown_locale = L10n.current_locale()
	L10n.apply_locale_font(self)
	skip_button.text = L10n.t("tutorial.skip")
	skip_button.visible = current_step != Step.COMPLETE
	progress_label.modulate = COMPLETE_COLOR if current_step == Step.COMPLETE else ACCENT_COLOR
	title_label.modulate = COMPLETE_COLOR if current_step == Step.COMPLETE else Color.WHITE
	accent_line.color = COMPLETE_COLOR if current_step == Step.COMPLETE else BORDER_COLOR


func _build_card() -> void:
	panel = Panel.new()
	panel.name = "TutorialCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = PANEL_COLOR
	card_style.border_color = Color(0.36, 0.80, 0.76, 0.72)
	card_style.set_border_width_all(2)
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override(&"panel", card_style)
	add_child(panel)
	accent_line = ColorRect.new()
	accent_line.name = "AccentLine"
	accent_line.color = BORDER_COLOR
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent_line)
	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.modulate = ACCENT_COLOR
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(progress_label)
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_label)
	body_label = Label.new()
	body_label.name = "BodyLabel"
	body_label.modulate = MUTED_COLOR
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body_label)
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.focus_mode = Control.FOCUS_ALL
	skip_button.pressed.connect(_finish_tutorial.bind(true))
	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.bg_color = Color(0.05, 0.11, 0.14, 0.94)
	button_style.border_color = Color(0.36, 0.80, 0.76, 0.60)
	button_style.set_border_width_all(1)
	skip_button.add_theme_stylebox_override(&"normal", button_style)
	skip_button.add_theme_stylebox_override(&"hover", button_style)
	skip_button.add_theme_stylebox_override(&"pressed", button_style)
	panel.add_child(skip_button)


func _apply_viewport_layout() -> void:
	apply_responsive_layout(get_viewport().get_visible_rect().size)


func _start_if_needed() -> void:
	if tutorial_active or completed:
		return
	var preference: ConfigFile = ConfigFile.new()
	if preference.load(preference_path) == OK and int(preference.get_value("combat_tutorial", "version", 0)) == VERSION and bool(preference.get_value("combat_tutorial", "completed", false)):
		completed = true
		current_step = Step.COMPLETE
		hide()
		return
	_start_tutorial()


func replay() -> void:
	if FileAccess.file_exists(preference_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(preference_path))
	_step_seconds = 0.0
	_help_shown = false
	_start_tutorial()


func _input(event: InputEvent) -> void:
	var method: StringName = input_method
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		method = &"gamepad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		method = &"touch"
	elif event is InputEventKey:
		method = &"keyboard"
	if method != input_method:
		input_method = method
		_update_copy()


func _process(delta: float) -> void:
	if tutorial_active and not get_tree().paused:
		_step_seconds += maxf(delta, 0.0)
		if _step_seconds >= 35.0 and not _help_shown:
			_help_shown = true
			_update_copy()
	if _shown_locale != L10n.current_locale():
		_update_copy()
	var hud: GameplayHud = get_parent() as GameplayHud
	if hud != null and hud.transmission_toast != null:
		hud.transmission_toast.set_suppressed(visible)
