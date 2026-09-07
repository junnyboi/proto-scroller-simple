class_name RuntimeTweakDescriptor
extends RefCounted

const SUPPORTED_TYPES: Array[StringName] = [&"bool", &"int", &"float", &"color"]
const APPLY_MODES: Array[StringName] = [
	&"LIVE", &"NEXT_ATTACK", &"NEXT_SPAWN", &"NEXT_DISTRICT", &"NEXT_RUN",
]
const INTEGRITY_CLASSES: Array[StringName] = [
	&"COSMETIC", &"GAMEPLAY", &"SCORE_AFFECTING",
]

var id: StringName
var category: StringName
var value_type: StringName
var default_value: Variant
var minimum: float = 0.0
var maximum: float = 0.0
var step: float = 0.0
var unit: String
var apply_mode: StringName
var integrity: StringName
var label_key: String
var description_key: String
var tags: PackedStringArray
var enabled: bool = true


static func from_dictionary(raw: Dictionary, errors: PackedStringArray) -> RuntimeTweakDescriptor:
	var descriptor: RuntimeTweakDescriptor = RuntimeTweakDescriptor.new()
	descriptor.id = StringName(raw.get("id", ""))
	descriptor.category = StringName(raw.get("category", ""))
	descriptor.value_type = StringName(raw.get("type", ""))
	descriptor.default_value = raw.get("default")
	descriptor.minimum = float(raw.get("minimum", 0.0))
	descriptor.maximum = float(raw.get("maximum", 0.0))
	descriptor.step = float(raw.get("step", 0.0))
	descriptor.unit = String(raw.get("unit", ""))
	descriptor.apply_mode = StringName(raw.get("apply_mode", ""))
	descriptor.integrity = StringName(raw.get("integrity", ""))
	descriptor.label_key = String(raw.get("label_key", ""))
	descriptor.description_key = String(raw.get("description_key", ""))
	descriptor.enabled = bool(raw.get("enabled", true))
	var raw_tags: Array = raw.get("tags", []) as Array
	for tag: Variant in raw_tags:
		descriptor.tags.append(String(tag))
	var prefix: String = String(descriptor.id) if not descriptor.id.is_empty() else "<missing-id>"
	if descriptor.id.is_empty():
		errors.append("descriptor is missing id")
	if descriptor.category.is_empty():
		errors.append("%s is missing category" % prefix)
	if descriptor.value_type not in SUPPORTED_TYPES:
		errors.append("%s has unsupported type %s" % [prefix, descriptor.value_type])
	if descriptor.apply_mode not in APPLY_MODES:
		errors.append("%s has invalid apply mode %s" % [prefix, descriptor.apply_mode])
	if descriptor.integrity not in INTEGRITY_CLASSES:
		errors.append("%s has invalid integrity %s" % [prefix, descriptor.integrity])
	if descriptor.label_key.is_empty() or descriptor.description_key.is_empty():
		errors.append("%s is missing localization metadata" % prefix)
	if descriptor.value_type == &"bool":
		if not descriptor.default_value is bool:
			errors.append("%s default must be boolean" % prefix)
	elif descriptor.value_type == &"color":
		var checked: Dictionary = descriptor.sanitize(descriptor.default_value)
		if not bool(checked.get("ok", false)):
			errors.append("%s default must be an HTML color" % prefix)
		else:
			descriptor.default_value = checked.value
	else:
		if not descriptor.default_value is int and not descriptor.default_value is float:
			errors.append("%s default must be numeric" % prefix)
		elif not is_finite(float(descriptor.default_value)):
			errors.append("%s default must be finite" % prefix)
		if descriptor.maximum < descriptor.minimum or descriptor.step <= 0.0:
			errors.append("%s has invalid numeric bounds" % prefix)
		var checked: Dictionary = descriptor.sanitize(descriptor.default_value)
		if not bool(checked.get("ok", false)):
			errors.append("%s default is outside its numeric contract" % prefix)
		else:
			descriptor.default_value = checked.value
	return descriptor


func sanitize(candidate: Variant) -> Dictionary:
	if value_type == &"bool":
		return {"ok": candidate is bool, "value": bool(candidate) if candidate is bool else false}
	if value_type == &"color":
		var parsed: Color
		if candidate is Color:
			parsed = candidate as Color
		elif candidate is String and Color.html_is_valid(String(candidate)):
			parsed = Color.from_string(String(candidate), Color.WHITE)
		else:
			return {"ok": false, "value": default_value}
		parsed.a = 1.0
		return {"ok": true, "value": "#%s" % parsed.to_html(false)}
	if not candidate is int and not candidate is float:
		return {"ok": false, "value": default_value}
	var numeric: float = float(candidate)
	if not is_finite(numeric):
		return {"ok": false, "value": default_value}
	var quantized: float = snappedf(numeric - minimum, step) + minimum
	quantized = clampf(quantized, minimum, maximum)
	if value_type == &"int":
		return {"ok": true, "value": clampi(roundi(quantized), roundi(minimum), roundi(maximum))}
	return {"ok": true, "value": quantized}


func values_equal(first: Variant, second: Variant) -> bool:
	if value_type == &"float":
		return is_equal_approx(float(first), float(second))
	if value_type == &"color":
		var first_checked: Dictionary = sanitize(first)
		var second_checked: Dictionary = sanitize(second)
		return (
			bool(first_checked.get("ok", false))
			and bool(second_checked.get("ok", false))
			and first_checked.value == second_checked.value
		)
	return first == second


func label_fallback() -> String:
	return String(id).replace(".", " ").replace("_", " ").capitalize()


func is_gameplay_affecting() -> bool:
	return integrity != &"COSMETIC"
