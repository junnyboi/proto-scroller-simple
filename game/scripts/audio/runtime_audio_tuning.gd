class_name RuntimeAudioTuning
extends Node

const BUS_TWEAKS: Dictionary[StringName, StringName] = {
	GameAudioBus.MECHANICS: &"audio.mechanics.gain_db",
	GameAudioBus.THREAT: &"audio.threat.gain_db",
	GameAudioBus.UI: &"audio.ui.gain_db",
	GameAudioBus.AMBIENCE: &"audio.ambience.gain_db",
}

var _applied_offsets: Dictionary[StringName, float] = {}


func _ready() -> void:
	name = "RuntimeAudioTuning"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_offsets()


func _process(_delta: float) -> void:
	_apply_offsets()


func _exit_tree() -> void:
	for bus_name: StringName in _applied_offsets:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		AudioServer.set_bus_volume_db(
			bus_index,
			AudioServer.get_bus_volume_db(bus_index) - _applied_offsets[bus_name]
		)
	_applied_offsets.clear()


func _apply_offsets() -> void:
	for bus_name: StringName in BUS_TWEAKS:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		var previous_offset: float = _applied_offsets.get(bus_name, 0.0)
		var base_volume: float = AudioServer.get_bus_volume_db(bus_index) - previous_offset
		var next_offset: float = float(RuntimeTweakAccess.live_value(
			BUS_TWEAKS[bus_name], 0.0
		))
		if not is_equal_approx(previous_offset, next_offset):
			AudioServer.set_bus_volume_db(bus_index, base_volume + next_offset)
		_applied_offsets[bus_name] = next_offset
