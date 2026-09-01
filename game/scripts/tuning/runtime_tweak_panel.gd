class_name RuntimeTweakPanel
extends Control

signal opened
signal closed

const ROW_POOL_SIZE: int = 16
const SESSION_CATEGORY: StringName = &"SESSION"

var main: Main
var service: RuntimeTweakService
var pause_adapter: RuntimeTweakPauseAdapter = RuntimeTweakPauseAdapter.new()
var sandbox: TuningSandboxRunner = TuningSandboxRunner.new()
var frame: PanelContainer
var title_label: Label
var run_status_label: Label
var save_status_label: Label
var category_selector: OptionButton
var search_field: LineEdit
var reset_all_button: Button
var close_button: Button
var rows_scroll: ScrollContainer
var rows_container: VBoxContainer
var rows: Array[TweakControlRow] = []
var sandbox_panel: PanelContainer
var sandbox_grid: GridContainer
var enemy_selector: OptionButton
var hazard_selector: OptionButton
var seed_input: SpinBox
var sandbox_warning_label: Label
var sandbox_status_label: Label
var copy_hash_button: Button
var _filtered: Array[RuntimeTweakDescriptor] = []
var _portrait: bool = false


func _ready() -> void:
	name = "RuntimeTweakPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 90
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_changed)
	apply_responsive_layout(get_viewport_rect().size)


func configure(owner: Main, authority: RuntimeTweakService) -> void:
	main = owner
	service = authority
	sandbox.setup(owner, authority)
	service.persistence_state_changed.connect(_on_persistence_state_changed)
	service.run_provenance_changed.connect(_on_provenance_changed)
	service.value_changed.connect(_on_service_value_changed)
	_populate_categories()
	_populate_sandbox_selectors()
	refresh_locale()
	_refresh_rows()


func open() -> bool:
	if visible or main == null or service == null:
		return false
	var status: Dictionary = RuntimeTweakModalPolicy.entry_status(main.city_slice)
	if not bool(status.allowed):
		return false
	if not pause_adapter.acquire(main.city_slice):
		return false
	visible = true
	refresh_locale()
	_refresh_rows()
	close_button.call_deferred(&"grab_focus")
	opened.emit()
	return true


func close() -> bool:
	if not visible:
		return false
	visible = false
	service.flush_now()
	pause_adapter.release()
	closed.emit()
	return true


func toggle() -> bool:
	return close() if visible else open()


func is_open() -> bool:
	return visible


func refresh_locale() -> void:
	if title_label == null:
		return
	title_label.text = L10n.t("tuning.title")
	search_field.placeholder_text = L10n.t("tuning.search_placeholder")
	reset_all_button.text = L10n.t("tuning.action.reset_all")
	close_button.text = "X" if _portrait else L10n.t("tuning.action.resume")
	copy_hash_button.text = L10n.t("tuning.action.copy_hash")
	sandbox_warning_label.text = L10n.t("tuning.session.warning")
	for child: Node in sandbox_grid.get_children():
		if child is Button and child.has_meta(&"l10n_key"):
			(child as Button).text = L10n.t(String(child.get_meta(&"l10n_key")))
	_update_category_labels()
	_update_run_status()
	_on_persistence_state_changed(service.persistence_state, service.persistence_message)
	L10n.apply_locale_font(self)
	L10n.apply_locale_popup_font(category_selector.get_popup())
	L10n.apply_locale_popup_font(enemy_selector.get_popup())
	L10n.apply_locale_popup_font(hazard_selector.get_popup())


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if frame == null:
		return
	# Main is a plain Node, so Control anchors have no parent rectangle to resolve.
	# Own the viewport rectangle explicitly before sizing anchored children.
	size = viewport_size
	position = Vector2.ZERO
	var portrait: bool = viewport_size.y > viewport_size.x
	_portrait = portrait
	var margin: float = 8.0 if portrait else 10.0
	sandbox_grid.columns = 2 if portrait else 3
	title_label.add_theme_font_size_override(&"font_size", 17 if portrait else 20)
	run_status_label.visible = not portrait
	reset_all_button.visible = not portrait
	save_status_label.visible = not portrait
	copy_hash_button.visible = not portrait
	category_selector.custom_minimum_size.x = 136.0 if portrait else 170.0
	close_button.text = "X" if portrait else L10n.t("tuning.action.resume")
	for row: TweakControlRow in rows:
		row.set_compact(portrait)
	_refresh_rows()
	frame.position = Vector2(margin, margin)
	frame.size = viewport_size - Vector2.ONE * margin * 2.0


func _unhandled_input(event: InputEvent) -> void:
	if _is_gamepad_chord(event) or event.is_action_pressed(&"tuning_lab"):
		if toggle():
			get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _is_gamepad_chord(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton or not (event as InputEventJoypadButton).pressed:
		return false
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button.button_index == JOY_BUTTON_START:
		return Input.is_joy_button_pressed(button.device, JOY_BUTTON_BACK)
	if button.button_index == JOY_BUTTON_BACK:
		return Input.is_joy_button_pressed(button.device, JOY_BUTTON_START)
	return false


func _build_ui() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = RuntimeTweakTheme.BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override(&"panel", RuntimeTweakTheme.panel_style())
	add_child(frame)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 4)
	frame.add_child(content)
	content.add_child(_build_header())
	content.add_child(_build_toolbar())
	rows_scroll = ScrollContainer.new()
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rows_scroll.follow_focus = true
	content.add_child(rows_scroll)
	rows_container = VBoxContainer.new()
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_container.add_theme_constant_override(&"separation", 2)
	rows_scroll.add_child(rows_container)
	for index: int in range(ROW_POOL_SIZE):
		_create_row(index)
	sandbox_panel = _build_sandbox_panel()
	content.add_child(sandbox_panel)
	content.add_child(_build_footer())


func _build_header() -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size.y = 38.0
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override(&"font_size", 20)
	title_label.add_theme_color_override(&"font_color", RuntimeTweakTheme.TEXT)
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title_label)
	run_status_label = Label.new()
	run_status_label.add_theme_font_size_override(&"font_size", 14)
	header.add_child(run_status_label)
	close_button = Button.new()
	RuntimeTweakTheme.style_button(close_button, true, true)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	return header


func _build_toolbar() -> Control:
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.add_theme_constant_override(&"separation", 4)
	category_selector = OptionButton.new()
	category_selector.custom_minimum_size = Vector2(170.0, 34.0)
	category_selector.item_selected.connect(_on_filter_changed)
	toolbar.add_child(category_selector)
	search_field = LineEdit.new()
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.custom_minimum_size.y = 34.0
	search_field.clear_button_enabled = true
	search_field.text_changed.connect(_on_search_changed)
	toolbar.add_child(search_field)
	reset_all_button = Button.new()
	RuntimeTweakTheme.style_button(reset_all_button, false, true)
	reset_all_button.pressed.connect(_on_reset_all_pressed)
	toolbar.add_child(reset_all_button)
	return toolbar


func _build_footer() -> Control:
	var footer: HBoxContainer = HBoxContainer.new()
	footer.custom_minimum_size.y = 34.0
	save_status_label = Label.new()
	save_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	save_status_label.add_theme_color_override(&"font_color", RuntimeTweakTheme.MUTED)
	footer.add_child(save_status_label)
	copy_hash_button = Button.new()
	RuntimeTweakTheme.style_button(copy_hash_button, false, true)
	copy_hash_button.pressed.connect(_copy_hash)
	footer.add_child(copy_hash_button)
	return footer


func _build_sandbox_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", RuntimeTweakTheme.panel_style(true))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	panel.add_child(column)
	sandbox_warning_label = Label.new()
	sandbox_warning_label.text = L10n.t("tuning.session.warning")
	sandbox_warning_label.modulate = RuntimeTweakTheme.AMBER
	sandbox_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sandbox_warning_label)
	sandbox_grid = GridContainer.new()
	sandbox_grid.columns = 3
	sandbox_grid.add_theme_constant_override(&"h_separation", 4)
	sandbox_grid.add_theme_constant_override(&"v_separation", 4)
	column.add_child(sandbox_grid)
	enemy_selector = OptionButton.new()
	enemy_selector.custom_minimum_size.y = 34.0
	sandbox_grid.add_child(enemy_selector)
	sandbox_grid.add_child(_sandbox_button("tuning.session.spawn_enemy", _spawn_selected_enemy))
	hazard_selector = OptionButton.new()
	hazard_selector.custom_minimum_size.y = 34.0
	sandbox_grid.add_child(hazard_selector)
	sandbox_grid.add_child(_sandbox_button("tuning.session.spawn_hazard", _spawn_selected_hazard))
	sandbox_grid.add_child(_sandbox_button("tuning.session.clear", _clear_transient))
	sandbox_grid.add_child(_sandbox_button("tuning.session.repair", _repair_chassis))
	seed_input = SpinBox.new()
	seed_input.min_value = 0.0
	seed_input.max_value = 2_147_483_647.0
	seed_input.step = 1.0
	seed_input.value = 0.0
	seed_input.custom_minimum_size.y = 34.0
	sandbox_grid.add_child(seed_input)
	sandbox_grid.add_child(_sandbox_button("tuning.session.restart", _restart_with_seed))
	sandbox_status_label = Label.new()
	sandbox_status_label.modulate = RuntimeTweakTheme.MUTED
	column.add_child(sandbox_status_label)
	return panel


func _sandbox_button(key: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = L10n.t(key)
	button.set_meta(&"l10n_key", key)
	RuntimeTweakTheme.style_button(button, false, true)
	button.pressed.connect(callback)
	return button


func _populate_categories() -> void:
	category_selector.clear()
	for category: StringName in service.catalog.categories():
		category_selector.add_item("")
		category_selector.set_item_metadata(category_selector.item_count - 1, category)
	category_selector.add_item("")
	category_selector.set_item_metadata(category_selector.item_count - 1, SESSION_CATEGORY)
	_update_category_labels()


func _update_category_labels() -> void:
	if service == null:
		return
	for index: int in range(category_selector.item_count):
		var category: StringName = StringName(category_selector.get_item_metadata(index))
		category_selector.set_item_text(index, L10n.t("tuning.category.%s" % String(category).to_lower()))


func _populate_sandbox_selectors() -> void:
	enemy_selector.clear()
	for identifier: StringName in sandbox.enemy_ids():
		enemy_selector.add_item(String(identifier).replace("_", " ").capitalize())
		enemy_selector.set_item_metadata(enemy_selector.item_count - 1, identifier)
	hazard_selector.clear()
	for identifier: StringName in sandbox.hazard_ids():
		hazard_selector.add_item(String(identifier).replace("_", " ").capitalize())
		hazard_selector.set_item_metadata(hazard_selector.item_count - 1, identifier)


func _refresh_rows() -> void:
	if service == null or category_selector == null or category_selector.item_count == 0:
		return
	var category: StringName = StringName(category_selector.get_selected_metadata())
	var session_active: bool = category == SESSION_CATEGORY
	rows_container.visible = not session_active
	rows_scroll.visible = not session_active
	sandbox_panel.visible = session_active
	if session_active:
		return
	_filtered.clear()
	var search: String = search_field.text.strip_edges().to_lower()
	for entry: RuntimeTweakDescriptor in service.catalog.descriptors_for_category(category):
		var label: String = L10n.t(entry.label_key)
		if label == entry.label_key:
			label = entry.label_fallback()
		var description: String = L10n.t(entry.description_key)
		var searchable: String = "%s %s %s %s" % [
			label, description, String(entry.id), " ".join(entry.tags),
		]
		if not search.is_empty() and search not in searchable.to_lower():
			continue
		_filtered.append(entry)
	_ensure_row_capacity(_filtered.size())
	for index: int in range(rows.size()):
		if index >= _filtered.size():
			rows[index].bind(null, null, null)
			continue
		var entry: RuntimeTweakDescriptor = _filtered[index]
		rows[index].bind(
			entry,
			service.requested_value(entry.id),
			service.active_value(entry.id)
		)


func _ensure_row_capacity(required: int) -> void:
	while rows.size() < required:
		_create_row(rows.size())


func _create_row(index: int) -> void:
	var row: TweakControlRow = TweakControlRow.new()
	row.name = "TweakRow%02d" % index
	row.value_requested.connect(_on_row_value_requested)
	row.reset_requested.connect(_on_row_reset_requested)
	row.set_compact(_portrait)
	rows_container.add_child(row)
	rows.append(row)


func _on_filter_changed(_index: int) -> void:
	rows_scroll.scroll_vertical = 0
	_refresh_rows()


func _on_search_changed(_text: String) -> void:
	rows_scroll.scroll_vertical = 0
	_refresh_rows()


func _on_row_value_requested(identifier: StringName, value: Variant) -> void:
	var result: Dictionary = service.set_value(identifier, value)
	if not bool(result.get("ok", false)):
		save_status_label.text = L10n.t("tuning.validation.invalid_combination")
		save_status_label.tooltip_text = String(result.get("error", ""))
		save_status_label.modulate = RuntimeTweakTheme.DANGER
	_refresh_rows()
	_update_run_status()


func _on_row_reset_requested(identifier: StringName) -> void:
	service.reset_value(identifier)
	_refresh_rows()
	_update_run_status()


func _on_reset_all_pressed() -> void:
	service.reset_all()
	_refresh_rows()
	_update_run_status()


func _on_service_value_changed(identifier: StringName, requested: Variant, active: Variant) -> void:
	if not visible:
		return
	for row: TweakControlRow in rows:
		if row.descriptor != null and row.descriptor.id == identifier:
			row.refresh(requested, active)
			break
	_update_run_status()


func _on_provenance_changed(_snapshot: Dictionary) -> void:
	_update_run_status()


func _update_run_status() -> void:
	if service == null or run_status_label == null:
		return
	var status: StringName = service.provenance.status
	run_status_label.text = "%s  /  %s" % [
		L10n.t("tuning.status.%s" % String(status).to_lower()),
		L10n.t("tuning.pending", {"count": service.pending_count()}),
	]
	run_status_label.modulate = (
		RuntimeTweakTheme.ACCENT
		if status == RunTuningProvenance.BASELINE
		else RuntimeTweakTheme.AMBER
	)


func _on_persistence_state_changed(state: StringName, message: String) -> void:
	if save_status_label == null:
		return
	save_status_label.text = L10n.t("tuning.save.%s" % String(state).to_lower())
	if not message.is_empty():
		save_status_label.tooltip_text = message
	save_status_label.modulate = RuntimeTweakTheme.DANGER if state == &"NOT_SAVED" else RuntimeTweakTheme.MUTED


func _copy_hash() -> void:
	DisplayServer.clipboard_set(service.run_configuration_hash())
	save_status_label.text = L10n.t("tuning.hash_copied")


func _spawn_selected_enemy() -> void:
	_present_sandbox_result(sandbox.spawn_enemy(StringName(enemy_selector.get_selected_metadata())))


func _spawn_selected_hazard() -> void:
	_present_sandbox_result(sandbox.spawn_hazard(StringName(hazard_selector.get_selected_metadata())))


func _clear_transient() -> void:
	_present_sandbox_result(sandbox.clear_transient())


func _repair_chassis() -> void:
	_present_sandbox_result(sandbox.repair_chassis())


func _restart_with_seed() -> void:
	var seed: int = roundi(seed_input.value)
	close()
	_present_sandbox_result(sandbox.restart_with_seed(seed))


func _present_sandbox_result(result: Dictionary) -> void:
	var reason: StringName = StringName(result.get("reason", &""))
	sandbox_status_label.text = L10n.t("tuning.session.result.%s" % String(reason))
	sandbox_status_label.modulate = RuntimeTweakTheme.ACCENT if bool(result.get("ok", false)) else RuntimeTweakTheme.DANGER
	_update_run_status()


func _on_viewport_changed() -> void:
	apply_responsive_layout(get_viewport_rect().size)
