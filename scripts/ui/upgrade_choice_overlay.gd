class_name UpgradeChoiceOverlay
extends Control

signal choice_selected(upgrade_id: StringName, offer_sequence: int)

var title_label: Label
var batch_label: Label
var queue_label: Label
var shade: ColorRect
var cards: Array[UpgradeChoiceCard] = []
var offer_sequence: int = 0
var active: bool = false
var _input_arm_pending: bool = false
var _input_arm_sequence: int = 0
var _input_arm_frame: int = 0


func _ready() -> void:
	name = "UpgradeChoiceOverlay"
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_fixed_controls()
	visible = false
	get_viewport().size_changed.connect(apply_responsive_layout)
	apply_responsive_layout()


func _process(_delta: float) -> void:
	if not _input_arm_pending:
		return
	if not active or offer_sequence != _input_arm_sequence:
		_input_arm_pending = false
		return
	if Engine.get_process_frames() < _input_arm_frame:
		return
	if Input.is_action_pressed(&"stomp"):
		return
	_input_arm_pending = false
	for card: UpgradeChoiceCard in cards:
		card.disabled = false
	cards[0].grab_focus()


func show_offer(
	offer: UpgradeOffer,
	catalog: UpgradeCatalog,
	ranks: Dictionary[StringName, int],
	queue_total: int = 1
) -> void:
	if offer == null or offer.choice_ids.size() != 2:
		return
	offer_sequence = offer.sequence
	for index: int in range(2):
		var profile: UpgradeProfile = catalog.get_profile(offer.choice_ids[index])
		cards[index].configure(profile, int(ranks.get(profile.upgrade_id, 0)))
	batch_label.text = L10n.t("upgrade.level", {"level": "%02d" % offer.entitlement.level})
	queue_label.text = L10n.t("upgrade.choice", {
		"current": offer.sequence,
		"total": maxi(queue_total, offer.sequence),
	})
	active = true
	visible = true
	shade.color.a = float(RuntimeTweakAccess.live_value(
		&"interface.upgrade_modal_shade_opacity", 0.88
	))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for card: UpgradeChoiceCard in cards:
		card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_responsive_layout()
	_input_arm_pending = true
	_input_arm_sequence = offer_sequence
	_input_arm_frame = Engine.get_process_frames() + 1


func hide_offer() -> void:
	active = false
	_input_arm_pending = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for card: UpgradeChoiceCard in cards:
		card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	release_focus()

func apply_responsive_layout() -> void:
	if title_label == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	shade.size = viewport_size
	if viewport_size.y > viewport_size.x:
		_apply_portrait(viewport_size)
	else:
		_apply_landscape(viewport_size)


func _build_fixed_controls() -> void:
	shade = ColorRect.new()
	shade.name = "ModalShade"
	shade.position = Vector2.ZERO
	shade.color = Color(0.005, 0.015, 0.025, 0.88)
	add_child(shade)
	title_label = Label.new()
	title_label.text = L10n.t("upgrade.select")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override(&"font_size", 38)
	title_label.modulate = Color("f1b36f")
	add_child(title_label)
	batch_label = Label.new()
	batch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	batch_label.add_theme_font_size_override(&"font_size", 20)
	batch_label.modulate = Color("7ae4ff")
	add_child(batch_label)
	for index: int in range(2):
		var card: UpgradeChoiceCard = UpgradeChoiceCard.new()
		card.name = "UpgradeChoiceCard%d" % index
		card.chosen.connect(_on_card_chosen)
		add_child(card)
		cards.append(card)
	cards[0].focus_neighbor_right = cards[1].get_path()
	cards[1].focus_neighbor_left = cards[0].get_path()
	queue_label = Label.new()
	queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_label.add_theme_font_size_override(&"font_size", 17)
	queue_label.modulate = Color("b7c4cb")
	add_child(queue_label)


func _apply_landscape(viewport_size: Vector2) -> void:
	var card_size: Vector2 = Vector2(390.0, 230.0)
	var gap: float = 30.0
	var left: float = (viewport_size.x - card_size.x * 2.0 - gap) * 0.5
	title_label.position = Vector2(240.0, 100.0)
	title_label.size = Vector2(viewport_size.x - 480.0, 54.0)
	batch_label.position = Vector2(240.0, 152.0)
	batch_label.size = Vector2(viewport_size.x - 480.0, 32.0)
	cards[0].position = Vector2(left, 206.0)
	cards[1].position = Vector2(left + card_size.x + gap, 206.0)
	for card: UpgradeChoiceCard in cards:
		card.size = card_size
	queue_label.position = Vector2(240.0, 460.0)
	queue_label.size = Vector2(viewport_size.x - 480.0, 32.0)
	cards[0].focus_neighbor_bottom = NodePath()
	cards[1].focus_neighbor_top = NodePath()


func _apply_portrait(viewport_size: Vector2) -> void:
	var card_width: float = minf(viewport_size.x - 64.0, 600.0)
	var card_height: float = 230.0
	var left: float = (viewport_size.x - card_width) * 0.5
	title_label.position = Vector2(32.0, 286.0)
	title_label.size = Vector2(viewport_size.x - 64.0, 54.0)
	batch_label.position = Vector2(32.0, 338.0)
	batch_label.size = Vector2(viewport_size.x - 64.0, 32.0)
	cards[0].position = Vector2(left, 390.0)
	cards[1].position = Vector2(left, 642.0)
	for card: UpgradeChoiceCard in cards:
		card.size = Vector2(card_width, card_height)
	queue_label.position = Vector2(32.0, 892.0)
	queue_label.size = Vector2(viewport_size.x - 64.0, 32.0)
	cards[0].focus_neighbor_bottom = cards[1].get_path()
	cards[1].focus_neighbor_top = cards[0].get_path()


func _on_card_chosen(upgrade_id: StringName) -> void:
	if active:
		choice_selected.emit(upgrade_id, offer_sequence)
