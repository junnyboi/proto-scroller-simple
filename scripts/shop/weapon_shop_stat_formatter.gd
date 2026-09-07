class_name WeaponShopStatFormatter
extends RefCounted


static func format_row(row: Dictionary) -> String:
	return "%s  %s  >>  %s" % [
		L10n.t(String(row.get("label_key", ""))),
		_format_value(row, float(row.get("before", 0.0))),
		_format_value(row, float(row.get("after", 0.0))),
	]


static func format_rows(rows: Array[Dictionary]) -> String:
	var lines: PackedStringArray = []
	for row: Dictionary in rows:
		lines.append(format_row(row))
	return "\n".join(lines)


static func format_stacked_row(row: Dictionary) -> String:
	return "%s\n%s  >>  %s" % [
		L10n.t(String(row.get("label_key", ""))),
		_format_value(row, float(row.get("before", 0.0))),
		_format_value(row, float(row.get("after", 0.0))),
	]


static func format_stacked_rows(rows: Array[Dictionary]) -> String:
	var blocks: PackedStringArray = []
	for row: Dictionary in rows:
		blocks.append(format_stacked_row(row))
	return "\n\n".join(blocks)


static func _format_value(row: Dictionary, value: float) -> String:
	var unit: StringName = StringName(row.get("unit", &"percent"))
	match unit:
		&"integrity":
			return "%d / %d" % [roundi(value), roundi(float(row.get("maximum", 0.0)))]
		&"damage":
			return L10n.t("shop.value.damage", {"value": roundi(value)})
		&"chance":
			return "%d%%" % roundi(value * 100.0)
		_:
			return "%d%%" % roundi(value * 100.0)
