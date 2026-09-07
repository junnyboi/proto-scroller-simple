class_name CampaignProgressPanel
extends Control

signal codex_requested

const PANEL_COLOR: Color = Color(0.01, 0.035, 0.055, 0.94)
const ACCENT_COLOR: Color = Color("72e5ec")
const MUTED_COLOR: Color = Color("a8bbc2")
const BUTTON_ONLY_LANDSCAPE_CONTROLS_WIDTH: float = 674.0
const BUTTON_ONLY_LANDSCAPE_BUTTON_WIDTH: float = 430.0
const BUTTON_ONLY_LANDSCAPE_GAP: float = 72.0
const BUTTON_ONLY_PORTRAIT_CONTROLS_HEIGHT: float = 214.0
const BUTTON_ONLY_PORTRAIT_GAP: float = 32.0
const BUTTON_ONLY_HEIGHT: float = 72.0

var panel: ColorRect
var heading_label: Label
var progress_label: Label
var evidence_label: Label
var continuity_label: Label
var endings_label: Label
var codex_button: Button
var _snapshot: Dictionary = {}
var _button_only: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	_apply_mode_visibility()
	refresh_locale()


func setup(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	refresh_locale()


func set_button_only(enabled: bool) -> void:
	_button_only = enabled
	_apply_mode_visibility()


func refresh_locale() -> void:
	if heading_label == null:
		return
	heading_label.text = L10n.t("narrative.campaign.heading")
	progress_label.text = L10n.t("narrative.campaign.progress", {
		"dossiers": int(_snapshot.get("dossier_count", 0)),
		"total": CityDistrictCatalog.BUILDING_VARIANT_COUNT,
	})
	evidence_label.text = L10n.t("narrative.campaign.evidence", {
		"evidence": int(_snapshot.get("evidence_count", 0)),
		"total": DossierCatalog.EVIDENCE_FLAGS.size(),
		"echo_status": L10n.t(
			"narrative.echo7.resolved"
			if bool(_snapshot.get("echo7_resolved", false))
			else "narrative.echo7.ambiguous"
		),
	})
	continuity_label.text = L10n.t("narrative.campaign.continuity", {
		"generation": int(_snapshot.get("continuity_generation", 0)),
	})
	endings_label.text = _ending_archive_text()
	codex_button.text = L10n.t("narrative.campaign.open_codex")


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if _button_only:
		_apply_button_only_layout(viewport_size)
		return
	if viewport_size.y > viewport_size.x:
		position = Vector2(28.0, 790.0)
		size = Vector2(viewport_size.x - 56.0, 370.0)
	else:
		position = Vector2(viewport_size.x - 482.0, 310.0)
		size = Vector2(430.0, 350.0)
	panel.size = size
	heading_label.position = Vector2(22.0, 18.0)
	heading_label.size = Vector2(size.x - 44.0, 60.0)
	progress_label.position = Vector2(22.0, 82.0)
	progress_label.size = Vector2(size.x - 44.0, 34.0)
	evidence_label.position = Vector2(22.0, 116.0)
	evidence_label.size = Vector2(size.x - 44.0, 70.0)
	continuity_label.position = Vector2(22.0, 188.0)
	continuity_label.size = Vector2(size.x - 44.0, 34.0)
	endings_label.position = Vector2(22.0, 224.0)
	endings_label.size = Vector2(size.x - 44.0, 58.0)
	codex_button.position = Vector2(22.0, size.y - 66.0)
	codex_button.size = Vector2(size.x - 44.0, 44.0)


func _apply_button_only_layout(viewport_size: Vector2) -> void:
	var portrait: bool = viewport_size.y > viewport_size.x
	var button_width: float = minf(
		536.0 if portrait else BUTTON_ONLY_LANDSCAPE_BUTTON_WIDTH,
		viewport_size.x - 56.0
	)
	size = Vector2(button_width, BUTTON_ONLY_HEIGHT)
	if portrait:
		var group_height: float = (
			BUTTON_ONLY_PORTRAIT_CONTROLS_HEIGHT
			+ BUTTON_ONLY_PORTRAIT_GAP
			+ BUTTON_ONLY_HEIGHT
		)
		position = Vector2(
			(viewport_size.x - button_width) * 0.5,
			(viewport_size.y - group_height) * 0.5
				+ BUTTON_ONLY_PORTRAIT_CONTROLS_HEIGHT
				+ BUTTON_ONLY_PORTRAIT_GAP
		)
	else:
		var group_width: float = (
			BUTTON_ONLY_LANDSCAPE_CONTROLS_WIDTH
			+ BUTTON_ONLY_LANDSCAPE_GAP
			+ BUTTON_ONLY_LANDSCAPE_BUTTON_WIDTH
		)
		position = Vector2(
			(viewport_size.x - group_width) * 0.5
				+ BUTTON_ONLY_LANDSCAPE_CONTROLS_WIDTH
				+ BUTTON_ONLY_LANDSCAPE_GAP,
			(viewport_size.y - BUTTON_ONLY_HEIGHT) * 0.5
		)
	codex_button.position = Vector2.ZERO
	codex_button.size = size


func _apply_mode_visibility() -> void:
	if panel == null:
		return
	panel.visible = not _button_only
	for summary_label: Label in [
		heading_label,
		progress_label,
		evidence_label,
		continuity_label,
		endings_label,
	]:
		summary_label.visible = not _button_only
	codex_button.visible = true


func _build() -> void:
	panel = ColorRect.new()
	panel.color = PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	heading_label = Label.new()
	heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_label.add_theme_font_size_override(&"font_size", 24)
	heading_label.modulate = ACCENT_COLOR
	add_child(heading_label)
	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_font_size_override(&"font_size", 20)
	add_child(progress_label)
	evidence_label = Label.new()
	evidence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_label.add_theme_font_size_override(&"font_size", 16)
	evidence_label.modulate = ACCENT_COLOR
	add_child(evidence_label)
	continuity_label = Label.new()
	continuity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continuity_label.add_theme_font_size_override(&"font_size", 18)
	continuity_label.modulate = MUTED_COLOR
	add_child(continuity_label)
	endings_label = Label.new()
	endings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	endings_label.add_theme_font_size_override(&"font_size", 16)
	endings_label.modulate = ACCENT_COLOR
	add_child(endings_label)
	codex_button = Button.new()
	codex_button.focus_mode = Control.FOCUS_ALL
	codex_button.add_theme_font_size_override(&"font_size", 24)
	codex_button.pressed.connect(codex_requested.emit)
	add_child(codex_button)


func _ending_archive_text() -> String:
	var seen_endings: PackedStringArray = _snapshot.get(
		"seen_endings",
		PackedStringArray()
	) as PackedStringArray
	if seen_endings.is_empty():
		return L10n.t("narrative.campaign.endings_locked")
	var ending_names: PackedStringArray = PackedStringArray()
	for ending_id: String in seen_endings:
		ending_names.append(L10n.t("finale.ending.%s.archive" % ending_id.to_lower()))
	return L10n.t("narrative.campaign.endings", {
		"endings": " · ".join(ending_names),
	})
