class_name BossMusicDirector
extends Node

const TRACKS: Dictionary[StringName, AudioStream] = {
	&"SETTLEMENT_ENGINE_S04": preload(
		"res://audio/music/bosses/settlement-engine-s04.ogg"
	),
	&"SAMARITAN_15": preload("res://audio/music/bosses/samaritan-15.ogg"),
}

var player: AudioStreamPlayer
var active_boss_id: StringName = &""
var play_count: int = 0
var stop_count: int = 0

var _background_player: AudioStreamPlayer
var _background_was_playing: bool = false
var _background_resume_position: float = 0.0


func _init() -> void:
	name = "BossMusicDirector"
	player = AudioStreamPlayer.new()
	player.name = "BossMusicPlayer"
	player.bus = GameAudioBus.MUSIC
	add_child(player)
	for stream: AudioStream in TRACKS.values():
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true


func setup(background_player: AudioStreamPlayer = null) -> void:
	_background_player = background_player


func play_definition(definition: BossEncounterDefinition) -> bool:
	if definition == null or not TRACKS.has(definition.boss_id):
		return false
	if active_boss_id == definition.boss_id and player.playing:
		return true
	if active_boss_id.is_empty():
		_capture_background_state()
	active_boss_id = definition.boss_id
	player.stream = TRACKS[definition.boss_id]
	player.play(0.0)
	play_count += 1
	return true


func stop_music(_definition: BossEncounterDefinition = null) -> void:
	if active_boss_id.is_empty() and not player.playing:
		return
	player.stop()
	player.stream = null
	active_boss_id = &""
	stop_count += 1
	_restore_background_state()


func stream_for_boss(boss_id: StringName) -> AudioStream:
	return TRACKS.get(boss_id) as AudioStream


func track_count() -> int:
	return TRACKS.size()


func _exit_tree() -> void:
	stop_music()


func _capture_background_state() -> void:
	_background_was_playing = (
		is_instance_valid(_background_player) and _background_player.playing
	)
	_background_resume_position = (
		_background_player.get_playback_position() if _background_was_playing else 0.0
	)
	if _background_was_playing:
		_background_player.stop()


func _restore_background_state() -> void:
	if _background_was_playing and is_instance_valid(_background_player):
		_background_player.play(_background_resume_position)
	_background_was_playing = false
	_background_resume_position = 0.0
