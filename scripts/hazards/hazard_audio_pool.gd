class_name HazardAudioPool
extends Node2D

const WARNING_SFX: AudioStream = preload(
	"res://assets/audio/sfx/hazards/hazard_warning.wav"
)
const CHAIN_SFX: AudioStream = preload(
	"res://assets/audio/sfx/hazards/hazard_chain_reaction.wav"
)
const MAX_DISTANCE: float = 1900.0
const ATTENUATION: float = 0.45

var voice_capacity: int = RuntimeBudget.HAZARD_AUDIO_VOICES
var warning_play_count: int = 0
var impact_play_count: int = 0
var pulse_play_count: int = 0
var chain_play_count: int = 0
var recycle_count: int = 0
var drop_count: int = 0
var preemption_count: int = 0
var last_preempted_priority: int = AudioVoicePriority.UNUSED
var last_hazard_id: StringName = &""
var last_phase: StringName = &""
var _voices: Array[AudioStreamPlayer2D] = []
var _streams: Dictionary[StringName, AudioStream] = {}
var _cooldowns: Dictionary[StringName, int] = {}
var _paused: bool = false
var _voice_started_order: int = 0


func _ready() -> void:
	for hazard_id: StringName in EnvironmentalHazardCatalog.ACTIVE_IDS:
		var audio_profile: Dictionary = EnvironmentalHazardCatalog.audio_profile(hazard_id)
		_streams[hazard_id] = load(String(audio_profile.stream)) as AudioStream
	for index: int in range(voice_capacity):
		var voice: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		voice.name = "HazardVoice%02d" % index
		voice.max_distance = MAX_DISTANCE
		voice.attenuation = ATTENUATION
		voice.bus = GameAudioBus.THREAT
		AudioVoicePriority.stamp(voice, AudioVoicePriority.UNUSED, 0)
		add_child(voice)
		_voices.append(voice)


func play_warning(hazard_id: StringName, origin: Vector2) -> AudioStreamPlayer2D:
	var profile: Dictionary = EnvironmentalHazardCatalog.audio_profile(hazard_id)
	var voice: AudioStreamPlayer2D = _play(
		&"warning",
		hazard_id,
		WARNING_SFX,
		origin,
		float(profile.warning_gain_db),
		float(profile.warning_pitch),
		AudioVoicePriority.CRITICAL,
		0,
		true
	)
	if voice != null:
		warning_play_count += 1
	return voice


func play_impact(
	hazard_id: StringName,
	origin: Vector2,
	primary: bool
) -> AudioStreamPlayer2D:
	var profile: Dictionary = EnvironmentalHazardCatalog.audio_profile(hazard_id)
	var phase: StringName = &"impact" if primary else &"pulse"
	var gain_db: float = (
		float(profile.impact_gain_db) if primary else float(profile.pulse_gain_db)
	)
	var pitch: float = float(profile.impact_pitch) if primary else float(profile.pulse_pitch)
	var priority: int = int(profile.priority) if primary else maxi(int(profile.priority) - 3, 1)
	var retrigger_ms: int = 0 if primary else int(profile.retrigger_ms)
	var voice: AudioStreamPlayer2D = _play(
		phase,
		hazard_id,
		_streams.get(hazard_id) as AudioStream,
		origin,
		gain_db,
		pitch,
		priority,
		retrigger_ms,
		primary
	)
	if voice != null:
		if primary:
			impact_play_count += 1
		else:
			pulse_play_count += 1
	return voice


func play_chain(
	source_id: StringName,
	target_id: StringName,
	origin: Vector2,
	causal_depth: int
) -> AudioStreamPlayer2D:
	var cue_id: StringName = StringName("%s_to_%s" % [source_id, target_id])
	var voice: AudioStreamPlayer2D = _play(
		&"chain",
		cue_id,
		CHAIN_SFX,
		origin,
		-1.5,
		clampf(1.04 - float(causal_depth) * 0.06, 0.82, 1.04),
		10,
		120,
		true
	)
	if voice != null:
		chain_play_count += 1
	return voice


func set_paused(paused: bool) -> void:
	_paused = paused
	for voice: AudioStreamPlayer2D in _voices:
		voice.stream_paused = paused


func is_paused() -> bool:
	return _paused


func reset_all() -> void:
	_paused = false
	for voice: AudioStreamPlayer2D in _voices:
		voice.stop()
		voice.stream_paused = false
		AudioVoicePriority.stamp(voice, AudioVoicePriority.UNUSED, 0)
	_cooldowns.clear()
	warning_play_count = 0
	impact_play_count = 0
	pulse_play_count = 0
	chain_play_count = 0
	recycle_count = 0
	drop_count = 0
	preemption_count = 0
	last_preempted_priority = AudioVoicePriority.UNUSED
	last_hazard_id = &""
	last_phase = &""
	_voice_started_order = 0


func voice_count() -> int:
	return _voices.size()


func active_voice_count() -> int:
	var count: int = 0
	for voice: AudioStreamPlayer2D in _voices:
		count += 1 if voice.playing else 0
	return count


func stream_for(hazard_id: StringName) -> AudioStream:
	return _streams.get(hazard_id) as AudioStream


func _play(
	phase: StringName,
	hazard_id: StringName,
	stream: AudioStream,
	origin: Vector2,
	gain_db: float,
	pitch: float,
	priority: int,
	retrigger_ms: int,
	force_play: bool
) -> AudioStreamPlayer2D:
	if stream == null or _voices.is_empty():
		return null
	var cooldown_key: StringName = StringName("%s:%s" % [hazard_id, phase])
	var now_msec: int = Time.get_ticks_msec()
	if not force_play and now_msec < _cooldowns.get(cooldown_key, 0):
		return null
	var voice: AudioStreamPlayer2D = (
		_warning_voice_for(hazard_id) if phase == &"impact" else null
	)
	if voice == null:
		voice = _acquire_voice(priority)
	if voice == null:
		drop_count += 1
		return null
	voice.stop()
	voice.name = "%s%s" % [String(hazard_id).to_pascal_case(), String(phase).capitalize()]
	voice.stream = stream
	voice.global_position = origin
	voice.volume_db = gain_db
	voice.pitch_scale = pitch
	voice.set_meta(&"hazard_id", hazard_id)
	voice.set_meta(&"phase", phase)
	_voice_started_order += 1
	AudioVoicePriority.stamp(voice, priority, _voice_started_order)
	_cooldowns[cooldown_key] = now_msec + retrigger_ms
	last_hazard_id = hazard_id
	last_phase = phase
	voice.play()
	return voice


func _warning_voice_for(hazard_id: StringName) -> AudioStreamPlayer2D:
	for voice: AudioStreamPlayer2D in _voices:
		if (
			voice.playing
			and voice.get_meta(&"hazard_id", &"") == hazard_id
			and voice.get_meta(&"phase", &"") == &"warning"
		):
			return voice
	return null


func _acquire_voice(priority: int) -> AudioStreamPlayer2D:
	var candidate: AudioStreamPlayer2D = AudioVoicePriority.select_2d(
		_voices,
		priority
	)
	if candidate == null:
		return null
	if candidate.playing:
		var existing_priority: int = AudioVoicePriority.priority_of(candidate)
		recycle_count += 1
		if existing_priority < priority:
			preemption_count += 1
			last_preempted_priority = existing_priority
	return candidate
