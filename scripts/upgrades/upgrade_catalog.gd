class_name UpgradeCatalog
extends Resource

@export var profiles: Array[UpgradeProfile] = []

var _by_id: Dictionary[StringName, UpgradeProfile] = {}
var _sorted: Array[UpgradeProfile] = []


func rebuild() -> PackedStringArray:
	_by_id.clear()
	_sorted.clear()
	var errors: PackedStringArray = []
	for item: UpgradeProfile in profiles:
		if item == null:
			errors.append("catalog contains null profile")
			continue
		errors.append_array(item.validation_errors())
		if _by_id.has(item.upgrade_id):
			errors.append("duplicate upgrade_id %s" % item.upgrade_id)
			continue
		_by_id[item.upgrade_id] = item
		_sorted.append(item)
	_sorted.sort_custom(_sort_profiles)
	return errors


func sorted_profiles() -> Array[UpgradeProfile]:
	if _sorted.size() != profiles.size():
		rebuild()
	return _sorted


func get_profile(upgrade_id: StringName) -> UpgradeProfile:
	if _by_id.size() != profiles.size():
		rebuild()
	return _by_id.get(upgrade_id) as UpgradeProfile


func size() -> int:
	return profiles.size()


func _sort_profiles(a: UpgradeProfile, b: UpgradeProfile) -> bool:
	if a.sort_order != b.sort_order:
		return a.sort_order < b.sort_order
	return String(a.upgrade_id) < String(b.upgrade_id)
