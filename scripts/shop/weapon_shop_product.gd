class_name WeaponShopProduct
extends RefCounted

var product_id: StringName
var district_id: StringName
var name_key: String
var description_key: String
var price: int
var effect_key: StringName
var effect_value: float
var repair_ratio: float


func _init(
	p_product_id: StringName,
	p_district_id: StringName,
	p_name_key: String,
	p_description_key: String,
	p_price: int,
	p_effect_key: StringName,
	p_effect_value: float = 0.0,
	p_repair_ratio: float = 0.0
) -> void:
	product_id = p_product_id
	district_id = p_district_id
	name_key = p_name_key
	description_key = p_description_key
	price = maxi(p_price, 0)
	effect_key = p_effect_key
	effect_value = p_effect_value
	repair_ratio = clampf(p_repair_ratio, 0.0, 1.0)


func is_repair() -> bool:
	return repair_ratio > 0.0


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if product_id.is_empty():
		errors.append("weapon shop product_id is empty")
	if district_id.is_empty():
		errors.append("%s district_id is empty" % product_id)
	if name_key.is_empty() or description_key.is_empty():
		errors.append("%s localization key is empty" % product_id)
	if price <= 0:
		errors.append("%s price=%d" % [product_id, price])
	if effect_key.is_empty():
		errors.append("%s effect_key is empty" % product_id)
	return errors


func snapshot() -> Dictionary:
	return {
		"product_id": product_id,
		"district_id": district_id,
		"name_key": name_key,
		"description_key": description_key,
		"price": price,
		"effect_key": effect_key,
		"effect_value": effect_value,
		"repair_ratio": repair_ratio,
	}
