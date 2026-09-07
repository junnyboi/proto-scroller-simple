class_name RuntimeTweakService
extends Node

signal value_changed(identifier: StringName, requested_value: Variant, active_value: Variant)
signal persistence_state_changed(state: StringName, message: String)
signal run_provenance_changed(snapshot: Dictionary)
signal city_bound(city: CitySlice)

const SAVE_DEBOUNCE_SECONDS: float = 0.40

var catalog: RuntimeTweakCatalog
var persistence: RuntimeTweakPersistence
var provenance: RunTuningProvenance = RunTuningProvenance.new()
var requested_values: Dictionary[StringName, Variant] = {}
var run_values: Dictionary[StringName, Variant] = {}
var district_values: Dictionary[StringName, Variant] = {}
var active_values: Dictionary[StringName, Variant] = {}
var current_city: CitySlice
var persistence_state: StringName = &"SAVED"
var persistence_message: String = ""
var run_active: bool = false
var last_error: String = ""
var next_run_sandbox_reason: StringName = &""
var _save_remaining_seconds: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func setup(
	catalog_path: String = RuntimeTweakCatalog.DEFAULT_PATH,
	save_path: String = RuntimeTweakPersistence.DEFAULT_PATH
) -> PackedStringArray:
	catalog = RuntimeTweakCatalog.load_catalog(catalog_path)
	if not catalog.is_valid():
		last_error = "; ".join(catalog.errors)
		return catalog.errors.duplicate()
	persistence = RuntimeTweakPersistence.new(save_path)
	requested_values = catalog.baseline_values()
	var overlay: Dictionary[StringName, Variant] = (
		persistence.load_overlay(catalog) if OS.is_debug_build() else {}
	)
	for identifier: StringName in overlay:
		requested_values[identifier] = overlay[identifier]
	run_values = requested_values.duplicate(true)
	district_values = run_values.duplicate(true)
	active_values = run_values.duplicate(true)
	provenance.start_run(0, configuration_hash(run_values), catalog.catalog_revision)
	RuntimeTweakAccess.bind_service(self)
	for identifier: StringName in overlay:
		_apply_audio_value(identifier, overlay[identifier])
	_set_persistence_state(
		&"NOT_SAVED" if not persistence.last_error.is_empty() else &"SAVED",
		persistence.last_error
	)
	return []


func _exit_tree() -> void:
	flush_now()
	RuntimeTweakAccess.unbind_service(self)


func _process(delta: float) -> void:
	if _save_remaining_seconds < 0.0:
		return
	_save_remaining_seconds = maxf(_save_remaining_seconds - maxf(delta, 0.0), 0.0)
	if not is_zero_approx(_save_remaining_seconds):
		return
	flush_now()


func descriptor(identifier: StringName) -> RuntimeTweakDescriptor:
	return catalog.descriptor(identifier) if catalog != null else null


func requested_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return requested_values.get(identifier, fallback)


func live_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return requested_values.get(identifier, fallback)


func run_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return run_values.get(identifier, fallback)


func district_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return district_values.get(identifier, run_values.get(identifier, fallback))


func active_value(identifier: StringName, fallback: Variant = null) -> Variant:
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	if entry == null:
		return fallback
	if entry.apply_mode == &"LIVE":
		return requested_values.get(identifier, fallback)
	return active_values.get(identifier, run_values.get(identifier, fallback))


func set_value(identifier: StringName, candidate: Variant) -> Dictionary:
	if catalog == null:
		return {"ok": false, "error": "service is not initialized", "value": null}
	var checked: Dictionary = catalog.validate_value(identifier, candidate)
	if not bool(checked.ok):
		last_error = String(checked.error)
		return checked
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	var next_value: Variant = checked.value
	var previous: Variant = requested_values[identifier]
	if entry.values_equal(previous, next_value):
		return {"ok": true, "error": "", "value": previous, "changed": false}
	var merged: Dictionary = requested_values.duplicate(true)
	merged[identifier] = next_value
	var cross_checked: Dictionary = catalog.validate_cross_fields(merged)
	if not bool(cross_checked.ok):
		last_error = String(cross_checked.error)
		return {"ok": false, "error": last_error, "value": previous}
	return _apply_checked_value(identifier, next_value)


func _apply_checked_value(identifier: StringName, next_value: Variant) -> Dictionary:
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	requested_values[identifier] = next_value
	if entry.apply_mode == &"LIVE":
		active_values[identifier] = next_value
		_mark_applied_if_tuned(entry, next_value)
	_apply_audio_value(identifier, next_value)
	value_changed.emit(identifier, next_value, active_value(identifier, next_value))
	_schedule_save()
	return {"ok": true, "error": "", "value": next_value, "changed": true}


func set_values(candidates: Dictionary) -> Dictionary:
	var checked: Dictionary = catalog.validate_transaction(candidates)
	if not bool(checked.ok):
		last_error = String(checked.error)
		return checked
	var merged: Dictionary = requested_values.duplicate(true)
	for identifier: StringName in checked.values:
		merged[identifier] = checked.values[identifier]
	var cross_checked: Dictionary = catalog.validate_cross_fields(merged)
	if not bool(cross_checked.ok):
		last_error = String(cross_checked.error)
		return {"ok": false, "error": last_error, "values": {}}
	var changed: int = 0
	for identifier: StringName in checked.values:
		var entry: RuntimeTweakDescriptor = descriptor(identifier)
		if entry.values_equal(requested_values[identifier], checked.values[identifier]):
			continue
		var result: Dictionary = _apply_checked_value(
			identifier, checked.values[identifier]
		)
		if bool(result.get("changed", false)):
			changed += 1
	return {"ok": true, "error": "", "values": checked.values, "changed": changed}


func reset_value(identifier: StringName) -> bool:
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	if entry == null:
		return false
	return bool(set_value(identifier, entry.default_value).get("changed", false))


func reset_all() -> int:
	var result: Dictionary = set_values(catalog.baseline_values())
	return int(result.get("changed", 0)) if bool(result.get("ok", false)) else 0

func freeze_run(seed: int) -> Dictionary[StringName, Variant]:
	run_values = requested_values.duplicate(true)
	district_values = run_values.duplicate(true)
	active_values = run_values.duplicate(true)
	run_active = true
	provenance.start_run(seed, configuration_hash(run_values), catalog.catalog_revision)
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		if entry.apply_mode in [&"LIVE", &"NEXT_RUN"]:
			_mark_applied_if_tuned(entry, run_values[entry.id])
	if not next_run_sandbox_reason.is_empty():
		provenance.mark_sandbox(next_run_sandbox_reason)
		next_run_sandbox_reason = &""
	run_provenance_changed.emit(provenance.snapshot())
	return run_values.duplicate(true)


func end_run() -> void:
	run_active = false
	current_city = null


func begin_district() -> Dictionary[StringName, Variant]:
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		if entry.apply_mode != &"NEXT_DISTRICT":
			continue
		district_values[entry.id] = requested_values[entry.id]
		active_values[entry.id] = requested_values[entry.id]
		_mark_applied_if_tuned(entry, requested_values[entry.id])
	return district_values.duplicate(true)


func next_attack_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return _consume_boundary(identifier, &"NEXT_ATTACK", fallback)


func next_spawn_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return _consume_boundary(identifier, &"NEXT_SPAWN", fallback)


func bind_city(city: CitySlice) -> void:
	current_city = city
	city_bound.emit(city)


func mark_sandbox(reason: StringName) -> void:
	if not run_active:
		return
	provenance.mark_sandbox(reason)
	run_provenance_changed.emit(provenance.snapshot())


func mark_next_run_sandbox(reason: StringName) -> void:
	next_run_sandbox_reason = reason


func provenance_snapshot() -> Dictionary:
	return provenance.snapshot()


func requested_configuration_hash() -> String:
	return configuration_hash(requested_values)


func run_configuration_hash() -> String:
	return configuration_hash(run_values)


func pending_count() -> int:
	var count: int = 0
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		if entry.values_equal(requested_values[entry.id], active_value(entry.id)):
			continue
		count += 1
	return count


func delta_values() -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		var value: Variant = requested_values[entry.id]
		if not entry.values_equal(value, entry.default_value):
			result[entry.id] = value
	return result


func flush_now() -> bool:
	if persistence == null or catalog == null:
		return false
	_save_remaining_seconds = -1.0
	var saved: bool = persistence.save_delta(delta_values(), catalog.catalog_revision)
	_set_persistence_state(
		&"SAVED" if saved else &"NOT_SAVED",
		"" if saved else persistence.last_error
	)
	return saved


func configuration_hash(values: Dictionary) -> String:
	if catalog == null:
		return ""
	var canonical: Array[Dictionary] = []
	for identifier: StringName in catalog.ids():
		canonical.append({
			"id": String(identifier),
			"value": values.get(identifier, catalog.descriptor(identifier).default_value),
		})
	return (JSON.stringify(canonical) + "\n").sha256_text()


func _consume_boundary(identifier: StringName, expected_mode: StringName, fallback: Variant) -> Variant:
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	if entry == null or entry.apply_mode != expected_mode:
		return requested_values.get(identifier, fallback)
	var value: Variant = requested_values.get(identifier, fallback)
	active_values[identifier] = value
	_mark_applied_if_tuned(entry, value)
	value_changed.emit(identifier, value, value)
	return value


func _mark_applied_if_tuned(entry: RuntimeTweakDescriptor, value: Variant) -> void:
	if not run_active or not entry.is_gameplay_affecting():
		return
	if entry.values_equal(value, entry.default_value):
		return
	var previous_status: StringName = provenance.status
	provenance.mark_tuned(entry.id)
	if provenance.status != previous_status or String(entry.id) in provenance.reasons:
		run_provenance_changed.emit(provenance.snapshot())


func _schedule_save() -> void:
	_save_remaining_seconds = SAVE_DEBOUNCE_SECONDS
	_set_persistence_state(&"SAVING", "")


func _set_persistence_state(state: StringName, message: String) -> void:
	persistence_state = state
	persistence_message = message
	persistence_state_changed.emit(state, message)


func _apply_audio_value(identifier: StringName, value: Variant) -> void:
	var parts: PackedStringArray = String(identifier).split(".")
	if parts.size() != 3 or parts[0] != "audio":
		return
	var channels: Dictionary = {"master": AudioVolumeSettings.Channel.MASTER, "music": AudioVolumeSettings.Channel.MUSIC, "sfx": AudioVolumeSettings.Channel.SFX, "voice": AudioVolumeSettings.Channel.VOICE, "ui": AudioVolumeSettings.Channel.UI}
	if not channels.has(parts[1]):
		return
	if parts[2] == "volume":
		AudioVolumeSettings.apply_percent(int(channels[parts[1]]), float(value))
	elif parts[2] == "muted":
		AudioVolumeSettings.apply_muted(int(channels[parts[1]]), bool(value))


func apply_audio_overrides() -> void:
	if catalog == null or not catalog.is_valid() or not OS.is_debug_build():
		return
	for entry: RuntimeTweakDescriptor in catalog.descriptors_for_category(&"AUDIO"):
		var value: Variant = requested_value(entry.id)
		if not entry.values_equal(value, entry.default_value):
			_apply_audio_value(entry.id, value)


func sync_audio_from_buses() -> void:
	for channel: int in AudioVolumeSettings.CHANNELS:
		var name: String = String(AudioVolumeSettings.bus_name(channel)).to_lower()
		var index: int = AudioServer.get_bus_index(AudioVolumeSettings.bus_name(channel))
		set_value(StringName("audio.%s.volume" % name), roundf(db_to_linear(AudioServer.get_bus_volume_db(index)) * 100))
		set_value(StringName("audio.%s.muted" % name), AudioServer.is_bus_mute(index))
