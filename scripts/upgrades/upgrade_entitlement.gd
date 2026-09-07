class_name UpgradeEntitlement
extends RefCounted

var level: int
var accepted_event_id: int
var ordinal_in_event: int
var claim_key: StringName


func _init(p_level: int, p_event_id: int, p_ordinal: int = 0) -> void:
	level = p_level
	accepted_event_id = p_event_id
	ordinal_in_event = p_ordinal
	claim_key = StringName("level:%d:event:%d" % [level, accepted_event_id])
