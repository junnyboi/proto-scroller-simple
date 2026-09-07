class_name UpgradeOffer
extends RefCounted

var sequence: int
var entitlement: UpgradeEntitlement
var choice_ids: PackedStringArray
var offer_seed: int
var rng_draw_before: int
var selected_id: StringName
var resolved: bool = false


func _init(
	p_sequence: int,
	p_entitlement: UpgradeEntitlement,
	p_choice_ids: PackedStringArray,
	p_offer_seed: int,
	p_rng_draw_before: int
) -> void:
	sequence = p_sequence
	entitlement = p_entitlement
	choice_ids = p_choice_ids
	offer_seed = p_offer_seed
	rng_draw_before = p_rng_draw_before
