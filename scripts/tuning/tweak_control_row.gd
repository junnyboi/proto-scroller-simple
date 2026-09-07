class_name TweakControlRow
extends PanelContainer

signal value_requested(identifier: StringName, value: Variant)
signal reset_requested(identifier: StringName)

const ROW_HEIGHT: float = 42.0
const TITLE_WIDTH: float = 280.0
const COMPACT_TITLE_WIDTH: float = 132.0
const MODE_WIDTH: float = 104.0
const VALUE_WIDTH: float = 118.0
const COMPACT_VALUE_WIDTH: float = 82.0

var descriptor: RuntimeTweakDescriptor
var title_label: Label
var mode_label: Label
var value_label: Label
var slider: HSlider
var toggle: CheckButton
var color_picker: ColorPickerButton
var reset_button: Button
var _binding: bool = false
var _compact: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	add_theme_stylebox_override(&"panel", RuntimeTweakTheme.panel_style(true, true))
	_build()


func bind(entry: RuntimeTweakDescriptor, requested: Variant, active: Variant) -> void:
	descriptor = entry
	visible = entry != null
	if entry == null:
		return
	_binding = true
	title_label.text = L10n.t(entry.label_key)
	if title_label.text == entry.label_key:
		title_label.text = entry.label_fallback()
	title_label.tooltip_text = L10n.t(entry.description_key)
	mode_label.text = L10n.t("tuning.mode.%s" % String(entry.apply_mode).to_lower())
	mode_label.modulate = (
		RuntimeTweakTheme.MUTED
		if entry.integrity == &"COSMETIC"
		else RuntimeTweakTheme.AMBER
	)
	mode_label.visible = not _compact
	slider.visible = entry.value_type in [&"int", &"float"]
	toggle.visible = entry.value_type == &"bool"
	color_picker.visible = entry.value_type == &"color"
	if entry.value_type == &"bool":
		toggle.set_pressed_no_signal(bool(requested))
		toggle.text = L10n.t("tuning.value.on" if bool(requested) else "tuning.value.off")
	elif entry.value_type == &"color":
		color_picker.color = Color.from_string(String(requested), Color.WHITE)
	else:
		slider.min_value = entry.minimum
		slider.max_value = entry.maximum
		slider.step = entry.step
		slider.set_value_no_signal(float(requested))
	_update_value_label(requested, active)
	reset_button.disabled = entry.values_equal(requested, entry.default_value)
	_binding = false


func refresh(requested: Variant, active: Variant) -> void:
	if descriptor != null:
		bind(descriptor, requested, active)


func set_compact(compact: bool) -> void:
	_compact = compact
	if title_label == null:
		return
	title_label.custom_minimum_size.x = COMPACT_TITLE_WIDTH if compact else TITLE_WIDTH
	title_label.add_theme_font_size_override(&"font_size", 12 if compact else 14)
	mode_label.visible = not compact and descriptor != null
	value_label.custom_minimum_size.x = COMPACT_VALUE_WIDTH if compact else VALUE_WIDTH
	value_label.add_theme_font_size_override(&"font_size", 11 if compact else 12)
	color_picker.custom_minimum_size.x = 58.0 if compact else 84.0


func _build() -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(line)

	title_label = Label.new()
	title_label.custom_minimum_size.x = TITLE_WIDTH
	title_label.add_theme_font_size_override(&"font_size", 14)
	title_label.add_theme_color_override(&"font_color", RuntimeTweakTheme.TEXT)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	line.add_child(title_label)

	mode_label = Label.new()
	mode_label.custom_minimum_size.x = MODE_WIDTH
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_label.add_theme_font_size_override(&"font_size", 10)
	line.add_child(mode_label)

	slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120.0, 24.0)
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(_on_slider_changed)
	line.add_child(slider)

	toggle = CheckButton.new()
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.custom_minimum_size = Vector2(120.0, 28.0)
	toggle.toggled.connect(_on_toggle_changed)
	line.add_child(toggle)

	color_picker = ColorPickerButton.new()
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.custom_minimum_size = Vector2(84.0, 28.0)
	color_picker.edit_alpha = false
	color_picker.color_changed.connect(_on_color_changed)
	line.add_child(color_picker)

	value_label = Label.new()
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override(&"font_size", 12)
	value_label.add_theme_color_override(&"font_color", RuntimeTweakTheme.ACCENT)
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.clip_text = true
	line.add_child(value_label)

	reset_button = Button.new()
	reset_button.text = "R"
	reset_button.add_theme_font_size_override(&"font_size", 16)
	reset_button.accessibility_name = L10n.t("tuning.action.reset_parameter")
	reset_button.custom_minimum_size = Vector2(30.0, 28.0)
	reset_button.focus_mode = Control.FOCUS_ALL
	reset_button.tooltip_text = L10n.t("tuning.action.reset_parameter")
	var reset_style: StyleBoxFlat = RuntimeTweakTheme.button_style(
		RuntimeTweakTheme.SURFACE_RAISED, RuntimeTweakTheme.BORDER, true
	)
	reset_button.add_theme_stylebox_override(&"disabled", reset_style)
	reset_button.add_theme_stylebox_override(&"normal", reset_style)
	reset_button.add_theme_stylebox_override(&"hover", reset_style)
	reset_button.add_theme_stylebox_override(&"pressed", reset_style)
	reset_button.add_theme_stylebox_override(&"focus", reset_style)
	reset_button.pressed.connect(_on_reset_pressed)
	line.add_child(reset_button)


func _on_slider_changed(value: float) -> void:
	if _binding or descriptor == null:
		return
	var submitted: Variant = roundi(value) if descriptor.value_type == &"int" else value
	value_requested.emit(descriptor.id, submitted)


func _on_toggle_changed(enabled: bool) -> void:
	if _binding or descriptor == null:
		return
	toggle.text = L10n.t("tuning.value.on" if enabled else "tuning.value.off")
	value_requested.emit(descriptor.id, enabled)


func _on_color_changed(color: Color) -> void:
	if _binding or descriptor == null:
		return
	color.a = 1.0
	value_requested.emit(descriptor.id, "#%s" % color.to_html(false))


func _on_reset_pressed() -> void:
	if descriptor != null:
		reset_requested.emit(descriptor.id)


func _update_value_label(requested: Variant, active: Variant) -> void:
	var requested_text: String = _format_value(requested)
	var active_text: String = _format_value(active)
	value_label.text = (
		requested_text
		if descriptor.values_equal(requested, active)
		else "%s > %s" % [active_text, requested_text]
	)
	value_label.modulate = (
		RuntimeTweakTheme.ACCENT
		if descriptor.values_equal(requested, active)
		else RuntimeTweakTheme.AMBER
	)


func _format_value(value: Variant) -> String:
	if descriptor.value_type == &"bool":
		return L10n.t("tuning.value.on" if bool(value) else "tuning.value.off")
	if descriptor.value_type == &"color":
		return "#%s" % Color.from_string(String(value), Color.WHITE).to_html(false).to_upper()
	var number: String = (
		str(int(value))
		if descriptor.value_type == &"int" or is_equal_approx(float(value), roundf(float(value)))
		else "%.3f" % float(value)
	)
	number = number.trim_suffix("0").trim_suffix("0").trim_suffix(".") if "." in number else number
	return "%s %s" % [number, descriptor.unit] if not descriptor.unit.is_empty() else number
