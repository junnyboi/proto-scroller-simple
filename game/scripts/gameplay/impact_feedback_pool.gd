class_name ImpactFeedbackPool
extends Node

const GLASS_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/glass_shatter.wav"
)
const CONCRETE_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/concrete_crunch.wav"
)
const STEEL_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/steel_groan.wav"
)
const DEBRIS_ENEMY_THUD_SFX: AudioStream = preload(
	"res://audio/sfx/debris/debris_enemy_thud.wav"
)
const IMPACT_SPARK: Texture2D = preload("res://art/presentation/impact_spark.png")
const SPARK_SCALE_NORMALIZER: float = 1.0 / 16.0
const DEBRIS_AUDIO_COOLDOWN_MSEC: int = 55
const MAX_CUE_PITCH_VARIATION: float = 0.08
const MAX_CUE_VOLUME_VARIATION_DB: float = 2.0

@export_range(1, 16, 1) var particle_capacity: int = RuntimeBudget.PARTICLE_SLOTS
@export_range(1, 16, 1) var audio_capacity: int = RuntimeBudget.AUDIO_VOICES

var last_material_audio: StringName = &""
var material_audio_play_count: int = 0
var cue_play_count: int = 0
var invalid_cue_count: int = 0
var last_cue: AudioCueRegistry.Cue = AudioCueRegistry.Cue.INVALID
var last_cue_pitch: float = 1.0
var last_cue_volume_db: float = 0.0
var debris_audio_play_count: int = 0
var debris_spark_play_count: int = 0
var last_debris_mass: float = 0.0
var last_debris_pitch: float = 1.0
var last_debris_volume_db: float = 0.0
var particle_recycle_count: int = 0
var particle_drop_count: int = 0
var audio_recycle_count: int = 0
var audio_drop_count: int = 0
var audio_preemption_count: int = 0
var last_preempted_priority: int = AudioVoicePriority.UNUSED
var _particle_root: Node2D
var _audio_root: Node2D
var _particles: Array[CPUParticles2D] = []
var _audio_players: Array[AudioStreamPlayer2D] = []
var _material_audio_cooldowns: Dictionary[StringName, int] = {}
var _debris_spark_profile: StructuralMaterialProfile
var _debris_audio_next_msec: int = 0
var _debris_audio_player: AudioStreamPlayer2D
var _voice_started_order: int = 0


func setup(particle_root: Node2D, audio_root: Node2D) -> void:
	_particle_root = particle_root
	_audio_root = audio_root


func _ready() -> void:
	_debris_spark_profile = StructuralMaterialProfile.steel()
	_debris_spark_profile.material_id = &"debris_enemy_spark"
	_debris_spark_profile.particle_color = Color("ffd878")
	_debris_spark_profile.particle_amount_scale = 0.030
	_debris_spark_profile.particle_speed_min = 0.18
	_debris_spark_profile.particle_speed_max = 0.36
	_debris_spark_profile.particle_spread = 42.0
	_debris_spark_profile.particle_gravity = 480.0
	_debris_spark_profile.particle_scale_min = 2.5
	_debris_spark_profile.particle_scale_max = 5.5
	_prewarm_particles()
	_prewarm_audio()


func spawn_particles(
	origin: Vector2,
	direction: Vector2,
	impact_speed: float,
	profile: StructuralMaterialProfile,
	priority: int = 1
) -> CPUParticles2D:
	if profile == null or _particles.is_empty():
		return null
	var particles: CPUParticles2D = _acquire_particle_slot(priority)
	if particles == null:
		particle_drop_count += 1
		return null
	particles.global_position = origin
	particles.amount = clampi(roundi(impact_speed * profile.particle_amount_scale), 8, 32)
	particles.direction = direction.normalized()
	particles.spread = profile.particle_spread
	particles.gravity = Vector2(0.0, profile.particle_gravity)
	particles.initial_velocity_min = impact_speed * profile.particle_speed_min
	particles.initial_velocity_max = impact_speed * profile.particle_speed_max
	particles.scale_amount_min = profile.particle_scale_min * SPARK_SCALE_NORMALIZER
	particles.scale_amount_max = profile.particle_scale_max * SPARK_SCALE_NORMALIZER
	particles.color = profile.particle_color
	particles.set_meta(&"structural_material", profile.material_id)
	particles.set_meta(&"priority", priority)
	particles.set_meta(&"started_msec", Time.get_ticks_msec())
	particles.restart()
	return particles


func play_audio(
	profile: StructuralMaterialProfile,
	origin: Vector2,
	impact_speed: float,
	force_play: bool = false,
	priority: int = AudioVoicePriority.ORDINARY
) -> AudioStreamPlayer2D:
	if profile == null or _audio_players.is_empty():
		return null
	var now_msec: int = Time.get_ticks_msec()
	var next_allowed: int = _material_audio_cooldowns.get(profile.material_id, 0)
	if not force_play and now_msec < next_allowed:
		return null
	var player: AudioStreamPlayer2D = _acquire_audio_slot(priority)
	if player == null:
		audio_drop_count += 1
		return null
	_material_audio_cooldowns[profile.material_id] = now_msec + 140
	player.stop()
	player.name = "%sImpact" % profile.display_name
	player.stream = audio_stream_for_material(profile.material_id)
	player.bus = GameAudioBus.SFX
	player.global_position = origin
	player.volume_db = clampf(-8.0 + impact_speed / 90.0, -8.0, -2.0)
	player.pitch_scale = pitch_for_material(profile.material_id, impact_speed)
	player.set_meta(&"structural_material", profile.material_id)
	_stamp_audio_voice(player, priority)
	last_material_audio = profile.material_id
	material_audio_play_count += 1
	player.play()
	return player


func audio_stream_for_material(material_id: StringName) -> AudioStream:
	match material_id:
		&"glass":
			return GLASS_IMPACT_SFX
		&"steel":
			return STEEL_IMPACT_SFX
		_:
			return CONCRETE_IMPACT_SFX


func play_cue(
	cue: AudioCueRegistry.Cue,
	origin: Vector2,
	pitch_variation: float = 0.0,
	volume_variation_db: float = 0.0,
	gain_db: float = 0.0
) -> AudioStreamPlayer2D:
	var profile: Dictionary = AudioCueRegistry.profile(cue)
	if profile.is_empty():
		invalid_cue_count += 1
		return null
	var priority: int = int(profile.priority)
	var player: AudioStreamPlayer2D = _acquire_audio_slot(priority)
	if player == null:
		audio_drop_count += 1
		return null
	player.stop()
	player.name = "%sCue" % String(profile.id).capitalize()
	player.stream = profile.stream as AudioStream
	player.bus = profile.bus as StringName
	player.global_position = origin
	player.volume_db = float(profile.volume_db) + gain_db + (
		0.0
		if is_zero_approx(volume_variation_db)
		else cue_volume_delta_for_sample(randf(), volume_variation_db)
	)
	player.pitch_scale = 1.0 if is_zero_approx(pitch_variation) else cue_pitch_for_sample(
		randf(), pitch_variation
	)
	_stamp_audio_voice(player, priority)
	last_cue = cue
	last_cue_pitch = player.pitch_scale
	last_cue_volume_db = player.volume_db
	cue_play_count += 1
	player.play()
	return player


func play_debris_enemy_impact(
	origin: Vector2,
	direction: Vector2,
	impact_speed: float,
	body_mass: float
) -> AudioStreamPlayer2D:
	var normalized_mass: float = _normalized_debris_mass(body_mass)
	var spark_speed: float = impact_speed * lerpf(0.70, 1.12, normalized_mass)
	var particles: CPUParticles2D = spawn_particles(
		origin,
		-direction,
		spark_speed,
		_debris_spark_profile,
		4
	)
	if particles != null:
		particles.set_meta(&"debris_mass", body_mass)
		debris_spark_play_count += 1
	var now_msec: int = Time.get_ticks_msec()
	var replacing_lighter_thud: bool = now_msec < _debris_audio_next_msec
	if replacing_lighter_thud and body_mass <= last_debris_mass:
		return null
	var player: AudioStreamPlayer2D
	if (
		replacing_lighter_thud
		and is_instance_valid(_debris_audio_player)
		and AudioVoicePriority.priority_of(_debris_audio_player) == AudioVoicePriority.DEFEAT
		and _debris_audio_player.stream == DEBRIS_ENEMY_THUD_SFX
	):
		player = _debris_audio_player
	else:
		player = _acquire_audio_slot(AudioVoicePriority.DEFEAT)
	if player == null:
		audio_drop_count += 1
		return null
	player.stop()
	player.name = "DebrisEnemyThud"
	player.stream = DEBRIS_ENEMY_THUD_SFX
	player.bus = GameAudioBus.SFX
	player.global_position = origin
	player.pitch_scale = debris_pitch_for_mass(body_mass, impact_speed)
	player.volume_db = debris_volume_for_mass(body_mass, impact_speed)
	player.set_meta(&"debris_mass", body_mass)
	_stamp_audio_voice(player, AudioVoicePriority.DEFEAT)
	_debris_audio_next_msec = now_msec + DEBRIS_AUDIO_COOLDOWN_MSEC
	_debris_audio_player = player
	last_debris_mass = body_mass
	last_debris_pitch = player.pitch_scale
	last_debris_volume_db = player.volume_db
	debris_audio_play_count += 1
	player.play()
	return player


func debris_pitch_for_mass(body_mass: float, impact_speed: float) -> float:
	var mass_weight: float = sqrt(_normalized_debris_mass(body_mass))
	var speed_lift: float = clampf(
		(impact_speed - DebrisBody2D.MIN_GROUND_IMPACT_SPEED) / 1260.0,
		0.0,
		1.0
	) * 0.12
	return lerpf(1.14, 0.68, mass_weight) + speed_lift


func debris_volume_for_mass(body_mass: float, impact_speed: float) -> float:
	var mass_weight: float = sqrt(_normalized_debris_mass(body_mass))
	var speed_weight: float = clampf(
		(impact_speed - DebrisBody2D.MIN_GROUND_IMPACT_SPEED) / 1260.0,
		0.0,
		1.0
	)
	return clampf(lerpf(-8.0, -2.0, mass_weight) + speed_weight * 1.5, -8.0, -0.5)


func pitch_for_material(material_id: StringName, impact_speed: float) -> float:
	var speed_pitch: float = clampf(impact_speed / 900.0, 0.0, 0.16)
	match material_id:
		&"glass":
			return 1.04 + speed_pitch
		&"steel":
			return 0.78 + speed_pitch * 0.45
		_:
			return 0.90 + speed_pitch * 0.65


static func cue_pitch_for_sample(random_sample: float, variation: float) -> float:
	var bounded_variation: float = clampf(
		absf(variation), 0.0, MAX_CUE_PITCH_VARIATION
	)
	return lerpf(
		1.0 - bounded_variation,
		1.0 + bounded_variation,
		clampf(random_sample, 0.0, 1.0)
	)


static func cue_volume_delta_for_sample(
	random_sample: float,
	variation_db: float
) -> float:
	var bounded_variation_db: float = clampf(
		absf(variation_db), 0.0, MAX_CUE_VOLUME_VARIATION_DB
	)
	return lerpf(
		-bounded_variation_db,
		bounded_variation_db,
		clampf(random_sample, 0.0, 1.0)
	)


func reset_runtime_state() -> void:
	for particles: CPUParticles2D in _particles:
		particles.emitting = false
		particles.set_meta(&"priority", 0)
	for player: AudioStreamPlayer2D in _audio_players:
		player.stop()
		AudioVoicePriority.stamp(player, AudioVoicePriority.UNUSED, 0)
	_material_audio_cooldowns.clear()
	particle_recycle_count = 0
	particle_drop_count = 0
	audio_recycle_count = 0
	audio_drop_count = 0
	audio_preemption_count = 0
	last_preempted_priority = AudioVoicePriority.UNUSED
	cue_play_count = 0
	invalid_cue_count = 0
	last_cue = AudioCueRegistry.Cue.INVALID
	last_cue_pitch = 1.0
	last_cue_volume_db = 0.0
	debris_audio_play_count = 0
	debris_spark_play_count = 0
	last_debris_mass = 0.0
	last_debris_pitch = 1.0
	last_debris_volume_db = 0.0
	_debris_audio_next_msec = 0
	_debris_audio_player = null
	_voice_started_order = 0


func particle_child_count() -> int:
	return _particles.size()


func audio_child_count() -> int:
	return _audio_players.size()


func _normalized_debris_mass(body_mass: float) -> float:
	return clampf(inverse_lerp(0.5, 24.0, body_mass), 0.0, 1.0)


func _acquire_particle_slot(priority: int) -> CPUParticles2D:
	for particles: CPUParticles2D in _particles:
		if not particles.emitting:
			return particles
	var candidate: CPUParticles2D = _particles[0]
	for particles: CPUParticles2D in _particles:
		if _slot_precedes(particles, candidate):
			candidate = particles
	if int(candidate.get_meta(&"priority", 0)) > priority:
		return null
	particle_recycle_count += 1
	candidate.emitting = false
	return candidate


func _acquire_audio_slot(priority: int) -> AudioStreamPlayer2D:
	var candidate: AudioStreamPlayer2D = AudioVoicePriority.select_2d(
		_audio_players,
		priority
	)
	if candidate == null:
		return null
	if candidate.playing:
		var existing_priority: int = AudioVoicePriority.priority_of(candidate)
		audio_recycle_count += 1
		if existing_priority < priority:
			audio_preemption_count += 1
			last_preempted_priority = existing_priority
	return candidate


func _stamp_audio_voice(player: AudioStreamPlayer2D, priority: int) -> void:
	_voice_started_order += 1
	AudioVoicePriority.stamp(player, priority, _voice_started_order)


func _slot_precedes(a: Node, b: Node) -> bool:
	var a_priority: int = int(a.get_meta(&"priority", 0))
	var b_priority: int = int(b.get_meta(&"priority", 0))
	if a_priority != b_priority:
		return a_priority < b_priority
	return int(a.get_meta(&"started_msec", 0)) < int(b.get_meta(&"started_msec", 0))


func _prewarm_particles() -> void:
	if _particle_root == null:
		return
	for index: int in range(particle_capacity):
		var particles: CPUParticles2D = CPUParticles2D.new()
		particles.name = "ImpactFragments" if index == 0 else "ImpactFragments%d" % index
		particles.z_index = 42
		particles.amount = 8
		particles.lifetime = 0.9
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.local_coords = false
		particles.emitting = false
		particles.angular_velocity_min = -420.0
		particles.angular_velocity_max = 420.0
		particles.damping_min = 25.0
		particles.damping_max = 70.0
		particles.texture = IMPACT_SPARK
		particles.set_meta(&"priority", 0)
		_particle_root.add_child(particles)
		_particles.append(particles)


func _prewarm_audio() -> void:
	if _audio_root == null:
		return
	for index: int in range(audio_capacity):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "ImpactAudio%02d" % index
		player.max_distance = 1500.0
		player.attenuation = 0.55
		player.bus = GameAudioBus.SFX
		AudioVoicePriority.stamp(player, AudioVoicePriority.UNUSED, 0)
		_audio_root.add_child(player)
		_audio_players.append(player)
