class_name RuntimeTweakPersistence
extends RefCounted

const SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "user://runtime_tweaks/v1/current.json"

var save_path: String = DEFAULT_PATH
var write_count: int = 0
var recovery_count: int = 0
var last_error: String = ""


func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path


func load_overlay(catalog: RuntimeTweakCatalog) -> Dictionary[StringName, Variant]:
	last_error = ""
	var primary: Dictionary = _read_valid_file(save_path, catalog)
	if bool(primary.get("ok", false)):
		return primary.values as Dictionary[StringName, Variant]
	if FileAccess.file_exists(save_path):
		_quarantine_primary()
	var backup_path: String = save_path + ".bak"
	var backup: Dictionary = _read_valid_file(backup_path, catalog)
	if bool(backup.get("ok", false)):
		recovery_count += 1
		return backup.values as Dictionary[StringName, Variant]
	return {}


func save_delta(values: Dictionary, catalog_revision: String) -> bool:
	last_error = ""
	var directory: String = save_path.get_base_dir()
	var global_directory: String = ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(global_directory) != OK:
		last_error = "cannot create tuning save directory"
		return false
	var temporary_path: String = save_path + ".tmp"
	var backup_path: String = save_path + ".bak"
	var serial_values: Dictionary = {}
	var keys: Array = values.keys()
	keys.sort_custom(func(first: Variant, second: Variant) -> bool:
		return String(first) < String(second)
	)
	for key: Variant in keys:
		serial_values[String(key)] = values[key]
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "cannot open temporary tuning file"
		return false
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"catalog_revision": catalog_revision,
		"values": serial_values,
	}, "  ", true, true) + "\n")
	file.close()
	var temporary_global: String = ProjectSettings.globalize_path(temporary_path)
	var save_global: String = ProjectSettings.globalize_path(save_path)
	var backup_global: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_global)
	if FileAccess.file_exists(save_path):
		if DirAccess.rename_absolute(save_global, backup_global) != OK:
			last_error = "cannot rotate tuning backup"
			DirAccess.remove_absolute(temporary_global)
			return false
	if DirAccess.rename_absolute(temporary_global, save_global) != OK:
		last_error = "cannot activate tuning file"
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_global, save_global)
		return false
	write_count += 1
	return true


func clear() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read_valid_file(path: String, catalog: RuntimeTweakCatalog) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "values": {}}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "cannot open tuning overlay"
		return {"ok": false, "values": {}}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		last_error = "invalid tuning overlay JSON"
		return {"ok": false, "values": {}}
	if not parser.data is Dictionary:
		last_error = "invalid tuning overlay root"
		return {"ok": false, "values": {}}
	var root: Dictionary = parser.data as Dictionary
	if int(root.get("schema_version", 0)) != SCHEMA_VERSION:
		last_error = "unsupported tuning overlay schema"
		return {"ok": false, "values": {}}
	var raw_values: Variant = root.get("values", {})
	if not raw_values is Dictionary:
		last_error = "invalid tuning overlay values"
		return {"ok": false, "values": {}}
	var known_candidates: Dictionary = {}
	for raw_identifier: Variant in raw_values as Dictionary:
		var identifier: StringName = StringName(raw_identifier)
		if catalog.descriptor(identifier) != null:
			known_candidates[identifier] = (raw_values as Dictionary)[raw_identifier]
	var checked: Dictionary = catalog.validate_transaction(known_candidates)
	if not bool(checked.ok):
		last_error = String(checked.error)
		return {"ok": false, "values": {}}
	var merged: Dictionary = catalog.baseline_values()
	for identifier: StringName in checked.values:
		merged[identifier] = checked.values[identifier]
	var cross_checked: Dictionary = catalog.validate_cross_fields(merged)
	if not bool(cross_checked.ok):
		last_error = String(cross_checked.error)
		return {"ok": false, "values": {}}
	return {"ok": true, "values": checked.values}


func _quarantine_primary() -> void:
	var source: String = ProjectSettings.globalize_path(save_path)
	var quarantine: String = ProjectSettings.globalize_path(
		"%s.corrupt-%d" % [save_path, Time.get_unix_time_from_system()]
	)
	if DirAccess.rename_absolute(source, quarantine) != OK:
		DirAccess.remove_absolute(source)
