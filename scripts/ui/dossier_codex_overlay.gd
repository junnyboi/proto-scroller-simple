class_name DossierCodexOverlay
extends Control

signal closed

const BACKGROUND: Texture2D = preload("res://assets/narrative/continuity-cradle.jpg")
const EVIDENCE_NODE: Texture2D = preload("res://assets/narrative/memory-glass-node.png")
const PANEL_COLOR: Color = Color(0.005, 0.02, 0.035, 0.97)
const ACCENT_COLOR: Color = Color("72e5ec")
const MUTED_COLOR: Color = Color("a8bbc2")

var background: TextureRect
var shade: ColorRect
var panel: ColorRect
var heading_label: Label
var progress_label: Label
var evidence_label: Label
var dossier_list: ItemList
var evidence_image: TextureRect
var detail_title: Label
var detail_body: Label
var close_button: Button
var _snapshot: Dictionary = {}
var _definitions: Array[DossierDefinition] = []
var _collected: Dictionary[StringName, bool] = {}
var _return_focus: Control


func _ready() -> void:
	name = "DossierCodexOverlay"
	z_index = 120
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	_definitions = DossierCatalog.definitions()
	get_viewport().size_changed.connect(_apply_current_layout)


func open(snapshot: Dictionary, return_focus: Control = null) -> void:
	_snapshot = snapshot.duplicate(true)
	_return_focus = return_focus
	_rebuild_collected()
	refresh_locale()
	visible = true
	_apply_current_layout()
	close_button.call_deferred("grab_focus")


func close(restore_focus: bool = true) -> bool:
	if not visible:
		return false
	visible = false
	if restore_focus and is_instance_valid(_return_focus):
		_return_focus.call_deferred("grab_focus")
	closed.emit()
	return true


func refresh_locale() -> void:
	if heading_label == null:
		return
	heading_label.text = L10n.t("narrative.codex.heading")
	progress_label.text = L10n.t("narrative.codex.progress", {
		"dossiers": int(_snapshot.get("dossier_count", 0)),
		"total": CityDistrictCatalog.BUILDING_VARIANT_COUNT,
	})
	evidence_label.text = L10n.t("narrative.codex.evidence", {
		"evidence": int(_snapshot.get("evidence_count", 0)),
		"total": DossierCatalog.EVIDENCE_FLAGS.size(),
		"echo_status": L10n.t(
			"narrative.echo7.resolved"
			if bool(_snapshot.get("echo7_resolved", false))
			else "narrative.echo7.ambiguous"
		),
	})
	close_button.text = L10n.t("narrative.codex.close")
	dossier_list.clear()
	for definition: DossierDefinition in _definitions:
		var unlocked: bool = _collected.has(definition.dossier_id)
		var title: String = (
			L10n.t(definition.title_key)
			if unlocked
			else L10n.t("narrative.codex.locked_entry")
		)
		dossier_list.add_item(("◆ " if unlocked else "◇ ") + title)
	if not _definitions.is_empty():
		dossier_list.select(0)
		_show_definition(0)


func apply_responsive_layout(viewport_size: Vector2) -> void:
	background.size = viewport_size
	shade.size = viewport_size
	if viewport_size.y > viewport_size.x:
		panel.position = Vector2(20.0, 28.0)
		panel.size = Vector2(viewport_size.x - 40.0, viewport_size.y - 56.0)
		heading_label.position = Vector2(42.0, 48.0)
		heading_label.size = Vector2(viewport_size.x - 84.0, 42.0)
		progress_label.position = Vector2(42.0, 92.0)
		progress_label.size = Vector2(viewport_size.x - 84.0, 30.0)
		evidence_label.position = Vector2(42.0, 120.0)
		evidence_label.size = Vector2(viewport_size.x - 84.0, 72.0)
		dossier_list.position = Vector2(42.0, 204.0)
		dossier_list.size = Vector2(viewport_size.x - 84.0, 354.0)
		evidence_image.position = Vector2(48.0, 582.0)
		evidence_image.size = Vector2(96.0, 166.0)
		detail_title.position = Vector2(164.0, 582.0)
		detail_title.size = Vector2(viewport_size.x - 206.0, 66.0)
		detail_body.position = Vector2(164.0, 654.0)
		detail_body.size = Vector2(viewport_size.x - 206.0, 350.0)
		close_button.position = Vector2(42.0, viewport_size.y - 112.0)
		close_button.size = Vector2(viewport_size.x - 84.0, 64.0)
	else:
		panel.position = Vector2(52.0, 38.0)
		panel.size = Vector2(viewport_size.x - 104.0, viewport_size.y - 76.0)
		heading_label.position = Vector2(82.0, 66.0)
		heading_label.size = Vector2(viewport_size.x - 164.0, 42.0)
		progress_label.position = Vector2(82.0, 108.0)
		progress_label.size = Vector2(430.0, 30.0)
		evidence_label.position = Vector2(82.0, 134.0)
		evidence_label.size = Vector2(440.0, 72.0)
		dossier_list.position = Vector2(82.0, 214.0)
		dossier_list.size = Vector2(440.0, 404.0)
		evidence_image.position = Vector2(570.0, 170.0)
		evidence_image.size = Vector2(128.0, 220.0)
		detail_title.position = Vector2(724.0, 170.0)
		detail_title.size = Vector2(viewport_size.x - 806.0, 78.0)
		detail_body.position = Vector2(570.0, 274.0)
		detail_body.size = Vector2(viewport_size.x - 652.0, 260.0)
		close_button.position = Vector2(570.0, 552.0)
		close_button.size = Vector2(viewport_size.x - 652.0, 66.0)


func _apply_current_layout() -> void:
	apply_responsive_layout(get_viewport().get_visible_rect().size)


func _rebuild_collected() -> void:
	_collected.clear()
	var ids: PackedStringArray = _snapshot.get("dossiers", PackedStringArray())
	for dossier_id: String in ids:
		_collected[StringName(dossier_id)] = true


func _show_definition(index: int) -> void:
	if index < 0 or index >= _definitions.size():
		return
	var definition: DossierDefinition = _definitions[index]
	var unlocked: bool = _collected.has(definition.dossier_id)
	evidence_image.visible = unlocked
	detail_title.text = (
		L10n.t(definition.title_key)
		if unlocked
		else L10n.t("narrative.codex.locked_title")
	)
	detail_body.text = (
		L10n.t(definition.body_primary_key)
		+ "\n\n"
		+ L10n.t(definition.body_secondary_key)
		+ _boss_result_wording(definition)
		if unlocked
		else L10n.t("narrative.codex.locked_body")
	)


func _boss_result_wording(definition: DossierDefinition) -> String:
	var results: Dictionary = _snapshot.get("boss_results", {})
	var result: Dictionary = results.get(String(definition.boss_id), {})
	if result.is_empty():
		return ""
	if definition.boss_id == &"SETTLEMENT_ENGINE_S04":
		return "\n\n" + L10n.t(
			"narrative.dossier.business_crown_reserve_treasury.result_preserved"
			if bool(result.get("archive_preserved", false))
			else "narrative.dossier.business_crown_reserve_treasury.result_lost"
		)
	if definition.boss_id == &"SAMARITAN_15":
		var lost: int = int(result.get("pod_loss_count", 0))
		return "\n\n" + L10n.t(
			"narrative.dossier.residential_nightglass_mutual_clinic.result_preserved"
			if lost == 0
			else "narrative.dossier.residential_nightglass_mutual_clinic.result_losses",
			{"lost": lost, "rescued": int(result.get("rescue_tally", 4))}
		)
	return ""


func _build() -> void:
	background = TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	shade = ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	panel = ColorRect.new()
	panel.color = PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	heading_label = Label.new()
	heading_label.add_theme_font_size_override(&"font_size", 30)
	heading_label.modulate = ACCENT_COLOR
	add_child(heading_label)
	progress_label = Label.new()
	progress_label.add_theme_font_size_override(&"font_size", 18)
	progress_label.modulate = MUTED_COLOR
	add_child(progress_label)
	evidence_label = Label.new()
	evidence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_label.add_theme_font_size_override(&"font_size", 15)
	evidence_label.modulate = ACCENT_COLOR
	add_child(evidence_label)
	dossier_list = ItemList.new()
	dossier_list.focus_mode = Control.FOCUS_ALL
	dossier_list.add_theme_font_size_override(&"font_size", 16)
	dossier_list.item_selected.connect(_show_definition)
	add_child(dossier_list)
	evidence_image = TextureRect.new()
	evidence_image.texture = EVIDENCE_NODE
	evidence_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	evidence_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	evidence_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(evidence_image)
	detail_title = Label.new()
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_title.add_theme_font_size_override(&"font_size", 22)
	detail_title.modulate = ACCENT_COLOR
	add_child(detail_title)
	detail_body = Label.new()
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_body.add_theme_font_size_override(&"font_size", 17)
	add_child(detail_body)
	close_button = Button.new()
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(close)
	add_child(close_button)
