class_name MusicDuckController
extends Node

const DEFAULT_BUS_NAME: StringName = GameAudioBus.MUSIC
const DEFAULT_DUCK_DB: float = -12.0
const SILENCE_FLOOR_DB: float = -80.0

@export var bus_name: StringName = DEFAULT_BUS_NAME
@export_range(-36.0, -3.0, 0.5) var duck_db: float = DEFAULT_DUCK_DB
@export_range(0.0, 1.0, 0.01) var attack_seconds: float = 0.16
@export_range(0.0, 2.0, 0.01) var release_seconds: float = 0.32

var _bus_index: int = -1
var _base_volume_db: float = 0.0
var _ducked: bool = false
var _volume_tween: Tween


func _ready() -> void:
	name = "MusicDuckController"
	_bus_index = _ensure_bus(bus_name)
	_base_volume_db = AudioServer.get_bus_volume_db(_bus_index)


func set_ducked(value: bool, immediate: bool = false) -> void:
	if _bus_index < 0:
		_bus_index = _ensure_bus(bus_name)
	if _ducked == value and not immediate:
		return
	_ducked = value
	if _volume_tween != null and _volume_tween.is_valid():
		_volume_tween.kill()
	var target_db: float = (
		maxf(_base_volume_db + duck_db, SILENCE_FLOOR_DB)
		if value
		else _base_volume_db
	)
	var duration: float = 0.0 if immediate else (attack_seconds if value else release_seconds)
	if duration <= 0.0:
		_set_bus_volume(target_db)
		return
	_volume_tween = create_tween()
	_volume_tween.set_trans(Tween.TRANS_SINE)
	_volume_tween.set_ease(Tween.EASE_OUT)
	_volume_tween.tween_method(
		_set_bus_volume,
		AudioServer.get_bus_volume_db(_bus_index),
		target_db,
		duration
	)


func is_ducked() -> bool:
	return _ducked


func current_volume_db() -> float:
	if _bus_index < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(_bus_index)


func base_volume_db() -> float:
	return _base_volume_db


func _exit_tree() -> void:
	if _volume_tween != null and _volume_tween.is_valid():
		_volume_tween.kill()
	if _bus_index >= 0 and _bus_index < AudioServer.bus_count:
		AudioServer.set_bus_volume_db(_bus_index, _base_volume_db)
	_ducked = false


func _set_bus_volume(volume_db: float) -> void:
	if _bus_index >= 0 and _bus_index < AudioServer.bus_count:
		AudioServer.set_bus_volume_db(_bus_index, volume_db)


func _ensure_bus(target_name: StringName) -> int:
	var index: int = AudioServer.get_bus_index(target_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, target_name)
	AudioServer.set_bus_send(index, GameAudioBus.MASTER)
	return index
