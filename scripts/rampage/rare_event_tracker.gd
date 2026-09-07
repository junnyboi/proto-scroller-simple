class_name RareEventTracker
extends Node

signal tags_changed(tags: PackedStringArray)

const MAX_VISIBLE_TAGS: int = RuntimeBudget.RARE_TAG_ROWS

var counts: Dictionary[StringName, int] = {}
var _visible_tags: Array[StringName] = []


func register_event(event: GameplayEvent) -> bool:
	if event == null:
		return false
	var tag: StringName = _tag_for_event(event)
	if tag.is_empty():
		return false
	counts[tag] = counts.get(tag, 0) + 1
	_visible_tags.erase(tag)
	_visible_tags.push_front(tag)
	if _visible_tags.size() > MAX_VISIBLE_TAGS:
		_visible_tags.resize(MAX_VISIBLE_TAGS)
	tags_changed.emit(visible_text())
	return true


func visible_text() -> PackedStringArray:
	var text: PackedStringArray = []
	for tag: StringName in _visible_tags:
		var key: String = "rare.%s" % String(tag).to_lower().replace(" ", "_")
		text.append(L10n.t(key, {"count": counts.get(tag, 0)}))
	return text


func snapshot_counts() -> Dictionary[StringName, int]:
	return counts.duplicate()


func reset_run() -> void:
	counts.clear()
	_visible_tags.clear()
	tags_changed.emit(PackedStringArray())


func _tag_for_event(event: GameplayEvent) -> StringName:
	if event.action_tag == GameplayEvent.AIR_DEBRIS_HIT:
		return &"SKYBREAKER"
	if event.action_tag == GameplayEvent.CHAIN_COLLAPSE:
		return &"DOMINO"
	if event.action_tag == GameplayEvent.TANK_SCRAP:
		return &"IRON HARVEST"
	return &""
