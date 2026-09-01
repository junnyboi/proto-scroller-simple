class_name RobotAnimationPresenter
extends Node

const ATTACK_EVENT_FRAME: int = AttackResolver.ATTACK_EVENT_FRAME
const PUNCH_CONTACT_FRAMES: Array[int] = [11, 14]
const PUNCH_CONTACT_INTERVAL_SECONDS: float = (
	float(PUNCH_CONTACT_FRAMES[1] - PUNCH_CONTACT_FRAMES[0])
	/ RobotSpriteFramesBuilder.DEFAULT_FPS
)
const WALK_REFERENCE_SPEED: float = 260.0
const AUDIO_VOICE_CAPACITY: int = 4
const AFTERIMAGE_CAPACITY: int = 8
const AFTERIMAGE_INTERVAL: float = 0.035
const AFTERIMAGE_LIFETIME: float = 0.22
const AFTERIMAGE_ALPHA: float = 0.34
const DUST_INTERVAL: float = 0.055
const CRITICAL_HEALTH_RATIO: float = 0.25
const ATTACK_IMPACT_BASE_VOLUME_DB: float = 1.5
const ATTACK_IMPACT_GAIN_DB: float = 9.5424250941
const ATTACK_IMPACT_REDUCTION_DB: float = -2.4987747322
const ATTACK_IMPACT_VOLUME_DB: float = (
	ATTACK_IMPACT_BASE_VOLUME_DB + ATTACK_IMPACT_GAIN_DB
	+ ATTACK_IMPACT_REDUCTION_DB
)
const MELEE_IMPACT_VOLUME_VARIATION_DB: float = 0.55
const MAX_MECHANICS_VOLUME_VARIATION_DB: float = 2.0
const CRITICAL_SMOKE_OFFSET: Vector2 = Vector2(28.0, -42.0)
const CHARGE_PARTICLE_OFFSET: Vector2 = Vector2(0.0, 34.0)
const CHARGE_PARTICLE_CAPACITY: int = 56
const CHARGE_PARTICLE_DELAY_SECONDS: float = 0.60
const CHARGE_METER_OFFSET: Vector2 = Vector2(0.0, -82.0)
const CHARGE_METER_FILL_SIZE: Vector2 = Vector2(150.0, 7.0)
const CHARGE_CORE_MIN_SCALE: float = 0.055
const CHARGE_CORE_MAX_SCALE: float = 0.26
const RELEASE_SHOCKWAVE_SECONDS: float = 0.38
const RELEASE_SHOCKWAVE_START_SCALE: float = 0.12
const RELEASE_SHOCKWAVE_END_SCALE: float = 0.92
const FULL_CHARGE_HIT_FLASH_SECONDS: float = 0.26
const CHARGE_PARTICLE_COLOR: Color = Color(1.0, 0.72, 0.16, 0.92)
const FULL_CHARGE_CORE_COLOR: Color = Color(0.12, 0.42, 1.0, 1.0)
const RELEASE_SHOCKWAVE_COLOR: Color = Color(0.72, 0.86, 1.0, 1.0)
const FULL_CHARGE_CORE_SHADER_CODE: String = """
shader_type canvas_item;
uniform float shift_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shift_color = vec3(0.12, 0.42, 1.0);
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shifted = shift_color * (0.32 + luminance * 0.92);
	COLOR = vec4(mix(source.rgb, shifted, shift_amount), source.a) * COLOR;
}
"""
const CRITICAL_SMOKE_TEXTURE: Texture2D = preload(
	"res://art/player/weapons/missile_explosion_smoke.png"
)
const CHARGE_METER_FRAME_TEXTURE: Texture2D = preload(
	"res://art/ui/gameplay/photon_charge_meter_frame.png"
)
const PHOTON_CORE_TEXTURE: Texture2D = preload(
	"res://art/player/vfx/photon_core_orb.png"
)
const PHOTON_RELEASE_SHOCKWAVE_TEXTURE: Texture2D = preload(
	"res://art/player/vfx/photon_release_shockwave.png"
)
const WALK_SERVO_FRAMES: Array[int] = [2, 15]
const WALK_CONTACT_FRAMES: Array[int] = [5, 18]
const FOOTSTEP_SFX: AudioStream = preload(
	"res://audio/sfx/robot/robot_footstep.wav"
)
const SERVO_SFX: AudioStream = preload(
	"res://audio/sfx/robot/robot_servo.wav"
)
const DASH_WARP_SFX: AudioStream = preload(
	"res://audio/sfx/robot/robot_dash_warp_drive.wav"
)
const DODGE_RECHARGED_SFX: AudioStream = preload(
	"res://audio/sfx/robot/dodge_energy_recharged.wav"
)
const GROUND_SLAM_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/robot/ground_slam_impact.wav"
)
const DOUBLE_PUNCH_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/robot/double_punch_impact.wav"
)
const PHOTON_CHARGE_SFX: AudioStream = preload(
	"res://audio/sfx/robot/photon_charge.wav"
)
const PHOTON_FULL_HIT_SFX: AudioStream = preload(
	"res://audio/sfx/robot/photon_full_hit.wav"
)
const FULLY_CHARGED_VOICE: AudioStream = preload(
	"res://audio/voice/fully_charged.wav"
)

var robot: GiantRobotController
var sprite: AnimatedSprite2D
var attacking: bool = false
var dodging: bool = false
var selected_attack_id: int = 0
var audio_play_count: int = 0
var footstep_play_count: int = 0
var servo_play_count: int = 0
var dash_warp_sfx_play_count: int = 0
var dodge_recharged_sfx_play_count: int = 0
var attack_impact_play_count: int = 0
var charge_sfx_play_count: int = 0
var full_charge_voice_play_count: int = 0
var full_charge_hit_sfx_play_count: int = 0
var audio_recycle_count: int = 0
var audio_drop_count: int = 0
var audio_preemption_count: int = 0
var last_preempted_priority: int = AudioVoicePriority.UNUSED
var last_audio_cue: StringName = &""
var last_audio_volume_db: float = 0.0
var last_completed_attack_frame: int = -1
var completed_full_attack_count: int = 0
var charging: bool = false
var last_charge_progress: float = 0.0
var last_full_charge_hit_position: Vector2 = Vector2.ZERO
var dust_intensity_scale: float = 1.0
var _audio_players: Array[AudioStreamPlayer2D] = []
var _status_sfx_player: AudioStreamPlayer
var _charge_sfx_player: AudioStreamPlayer2D
var _charge_voice_player: AudioStreamPlayer
var _voice_started_order: int = 0
var _afterimage_root: Node2D
var _afterimages: Array[Sprite2D] = []
var _afterimage_remaining: Array[float] = []
var _afterimage_cursor: int = 0
var _afterimage_elapsed: float = 0.0
var _dust_pool: DodgeDustPool2D
var _dust_elapsed: float = 0.0
var _dodge_facing: int = 1
var _critical_smoke: CPUParticles2D
var _charge_particles: CPUParticles2D
var _charge_meter_root: Node2D
var _charge_meter_fill: ColorRect
var _charge_meter_frame: Sprite2D
var _charge_core: Sprite2D
var _charge_core_material: ShaderMaterial
var _release_shockwave: Sprite2D
var _full_charge_hit_flash: Sprite2D
var _full_charge_announced: bool = false
var _charge_pulse_elapsed: float = 0.0
var _release_shockwave_remaining: float = 0.0
var _full_charge_hit_flash_remaining: float = 0.0
var _authored_sprite_scale: Vector2 = Vector2.ONE
var _visual_tuning_scale: float = -1.0
var _visual_tuning_tint: Color = Color.TRANSPARENT
var _animation_speed_scale: float = 1.0


func setup(p_robot: GiantRobotController, p_sprite: AnimatedSprite2D) -> void:
	robot = p_robot
	sprite = p_sprite
	_authored_sprite_scale = sprite.scale
	robot.facing_changed.connect(_on_facing_changed)
	robot.locomotion_changed.connect(_on_locomotion_changed)
	robot.attack_mode_selected.connect(_on_attack_selected)
	robot.attack_committed.connect(_on_attack_committed)
	robot.dodge_started.connect(_on_dodge_started)
	robot.dodge_finished.connect(_on_dodge_finished)
	robot.dodge_cooldown_ready.connect(_on_dodge_cooldown_ready)
	robot.health_changed.connect(_on_health_changed)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	_prewarm_audio()
	_prewarm_afterimages()
	_prewarm_dust()
	_prewarm_critical_smoke()
	_prewarm_charge_particles()
	_prewarm_charge_visuals()
	_on_health_changed(robot.current_health, robot.max_health)
	_apply_live_visual_tuning()
	_show_idle()


func bind_attacks(controller: ContextualAttackController) -> void:
	controller.attack_finished.connect(_on_attack_finished)
	controller.charge_started.connect(_on_charge_started)
	controller.charge_updated.connect(_on_charge_updated)
	controller.charge_released.connect(_on_charge_released)
	controller.attack_cancelled.connect(_on_attack_cancelled)
	controller.full_charge_enemy_hit.connect(_on_full_charge_enemy_hit)


func audio_voice_count() -> int:
	return (
		_audio_players.size()
		+ (1 if _status_sfx_player != null else 0)
		+ (1 if _charge_sfx_player != null else 0)
		+ (1 if _charge_voice_player != null else 0)
	)


func afterimage_slot_count() -> int:
	return _afterimages.size()


func active_afterimage_count() -> int:
	var active_count: int = 0
	for ghost: Sprite2D in _afterimages:
		if ghost.visible:
			active_count += 1
	return active_count


func dust_slot_count() -> int:
	return _dust_pool.slot_count() if _dust_pool != null else 0


func active_dust_slot_count() -> int:
	return _dust_pool.active_slot_count() if _dust_pool != null else 0


func critical_smoke_emitter_count() -> int:
	return 1 if _critical_smoke != null else 0


func critical_smoke_emitting() -> bool:
	return _critical_smoke != null and _critical_smoke.emitting


func charge_particle_emitter_count() -> int:
	return 1 if _charge_particles != null else 0


func charge_particle_capacity() -> int:
	return _charge_particles.amount if _charge_particles != null else 0


func charge_particles_emitting() -> bool:
	return _charge_particles != null and _charge_particles.emitting


func charge_meter_visible() -> bool:
	return _charge_meter_root != null and _charge_meter_root.visible


func charge_meter_fill_ratio() -> float:
	if _charge_meter_fill == null:
		return 0.0
	return _charge_meter_fill.size.x / CHARGE_METER_FILL_SIZE.x


func charge_core_visible() -> bool:
	return _charge_core != null and _charge_core.visible


func charge_core_max_shifted() -> bool:
	if _charge_core_material == null:
		return false
	return float(_charge_core_material.get_shader_parameter(&"shift_amount")) >= 1.0


func release_shockwave_visible() -> bool:
	return _release_shockwave != null and _release_shockwave.visible


func release_shockwave_scale() -> float:
	return _release_shockwave.scale.x if _release_shockwave != null else 0.0


func charge_visual_count() -> int:
	return (
		(1 if _charge_meter_root != null else 0)
		+ (1 if _charge_core != null else 0)
		+ (1 if _release_shockwave != null else 0)
		+ (1 if _full_charge_hit_flash != null else 0)
	)


func full_charge_hit_flash_visible() -> bool:
	return _full_charge_hit_flash != null and _full_charge_hit_flash.visible


func _process(delta: float) -> void:
	_apply_live_visual_tuning()
	_advance_afterimages(delta)
	_advance_charge_visuals(delta)
	if dodging:
		_afterimage_elapsed += delta
		while _afterimage_elapsed >= AFTERIMAGE_INTERVAL:
			_afterimage_elapsed -= AFTERIMAGE_INTERVAL
			_spawn_afterimage()
		_dust_elapsed += delta
		while _dust_elapsed >= DUST_INTERVAL:
			_dust_elapsed -= DUST_INTERVAL
			_spawn_dodge_dust(0.82)
	if robot == null or sprite == null or attacking:
		return
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		sprite.speed_scale = clampf(
			absf(robot.velocity.x) / WALK_REFERENCE_SPEED,
			0.45,
			1.35
		) * _animation_speed_scale


func _apply_live_visual_tuning() -> void:
	if sprite == null:
		return
	var tuned_scale: float = float(RuntimeTweakAccess.live_value(
		&"player.visual.scale", 1.0
	))
	var tuned_tint: Color = RuntimeTweakAccess.live_color(
		&"player.visual.tint", Color.WHITE
	)
	_animation_speed_scale = float(RuntimeTweakAccess.live_value(
		&"player.visual.animation_speed", 1.0
	))
	if not is_equal_approx(tuned_scale, _visual_tuning_scale):
		_visual_tuning_scale = tuned_scale
		sprite.scale = _authored_sprite_scale * tuned_scale
	if tuned_tint != _visual_tuning_tint:
		_visual_tuning_tint = tuned_tint
		sprite.self_modulate = tuned_tint


func _on_facing_changed(_facing: int) -> void:
	_update_emitter_facing()
	if attacking:
		return
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_locomotion_changed(state: int) -> void:
	if attacking or dodging:
		return
	if state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_attack_selected(mode: int, attack_id: int) -> void:
	attacking = true
	selected_attack_id = attack_id
	sprite.speed_scale = _animation_speed_scale
	sprite.play(_attack_animation(mode), 1.0, false)
	var pitch: float = 0.86 if mode == AttackSpec.Mode.GROUND_SMASH else 1.03
	_play_mechanics(SERVO_SFX, &"attack_windup", 2.5, pitch)


func _on_charge_started(spec: AttackSpec) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	charging = true
	last_charge_progress = 0.0
	_full_charge_announced = false
	_charge_pulse_elapsed = 0.0
	sprite.pause()
	sprite.set_frame_and_progress(0, 0.0)
	if _charge_particles != null:
		_charge_particles.emitting = false
	if _charge_meter_root != null:
		_charge_meter_root.visible = true
	if _charge_meter_fill != null:
		_charge_meter_fill.size.x = 0.0
	if _charge_core != null:
		_charge_core.visible = true
		_charge_core.scale = Vector2.ONE * CHARGE_CORE_MIN_SCALE
	if _charge_core_material != null:
		_charge_core_material.set_shader_parameter(&"shift_amount", 0.0)
	_hide_release_shockwave()
	if _charge_voice_player != null:
		_charge_voice_player.stop()
	if _charge_sfx_player != null:
		_charge_sfx_player.stop()
		_charge_sfx_player.play()
		charge_sfx_play_count += 1
		last_audio_cue = &"photon_charge"


func _on_charge_updated(
	spec: AttackSpec,
	duration: float,
	progress: float,
	_multiplier: float
) -> void:
	if spec == null or spec.attack_id != selected_attack_id or not charging:
		return
	last_charge_progress = clampf(progress, 0.0, 1.0)
	if _charge_particles != null:
		_charge_particles.emitting = (
			duration >= CHARGE_PARTICLE_DELAY_SECONDS
			and last_charge_progress < 1.0
		)
		_charge_particles.initial_velocity_min = 44.0 + last_charge_progress * 24.0
		_charge_particles.initial_velocity_max = 104.0 + last_charge_progress * 46.0
		_charge_particles.radial_accel_min = -420.0 - last_charge_progress * 520.0
		_charge_particles.radial_accel_max = -260.0 - last_charge_progress * 390.0
	if _charge_meter_fill != null:
		_charge_meter_fill.size.x = CHARGE_METER_FILL_SIZE.x * last_charge_progress
		_charge_meter_fill.color = Color(1.0, 0.43, 0.06, 0.96).lerp(
			Color(1.0, 0.93, 0.50, 1.0),
			last_charge_progress
		)
	if _charge_core != null:
		var core_scale: float = lerpf(
			CHARGE_CORE_MIN_SCALE,
			CHARGE_CORE_MAX_SCALE,
			last_charge_progress
		)
		_charge_core.scale = Vector2.ONE * core_scale
	if _charge_core_material != null:
		_charge_core_material.set_shader_parameter(
			&"shift_amount",
			1.0 if last_charge_progress >= 1.0 else 0.0
		)
	if last_charge_progress >= 1.0:
		_announce_full_charge()


func _on_charge_released(
	spec: AttackSpec,
	_duration: float,
	_multiplier: float
) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	charging = false
	if spec.is_fully_charged():
		_announce_full_charge()
		_start_release_shockwave()
	if _charge_particles != null:
		_charge_particles.emitting = false
	_hide_charge_visuals()
	sprite.speed_scale = _animation_speed_scale
	sprite.play()


func _announce_full_charge() -> void:
	if _full_charge_announced:
		return
	_full_charge_announced = true
	if _charge_voice_player == null:
		return
	_charge_voice_player.play()
	full_charge_voice_play_count += 1
	last_audio_cue = &"fully_charged"


func _on_attack_cancelled(spec: AttackSpec) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	if _charge_voice_player != null:
		_charge_voice_player.stop()
	_hide_release_shockwave()


func _on_attack_committed(mode: int, attack_id: int) -> void:
	if not attacking or attack_id != selected_attack_id:
		return
	if sprite.frame < ATTACK_EVENT_FRAME:
		sprite.set_frame_and_progress(ATTACK_EVENT_FRAME, 0.0)
	if mode == AttackSpec.Mode.GROUND_SMASH:
		_play_mechanics(
			GROUND_SLAM_IMPACT_SFX,
			&"ground_slam_impact",
			ATTACK_IMPACT_VOLUME_DB,
			1.0,
			MELEE_IMPACT_VOLUME_VARIATION_DB
		)
	else:
		_play_mechanics(
			DOUBLE_PUNCH_IMPACT_SFX,
			&"double_punch_impact",
			ATTACK_IMPACT_VOLUME_DB,
			1.0,
			MELEE_IMPACT_VOLUME_VARIATION_DB
		)


func _on_attack_finished(spec: AttackSpec) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	last_completed_attack_frame = sprite.frame
	if sprite.frame == RobotSpriteFramesBuilder.FRAME_COUNT - 1:
		completed_full_attack_count += 1
	attacking = false
	charging = false
	last_charge_progress = 0.0
	if _charge_particles != null:
		_charge_particles.emitting = false
	_hide_charge_visuals()
	selected_attack_id = 0
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_full_charge_enemy_hit(
	spec: AttackSpec,
	world_position: Vector2,
	enemy_count: int
) -> void:
	if spec == null or not spec.is_fully_charged() or enemy_count <= 0:
		return
	_play_mechanics(PHOTON_FULL_HIT_SFX, &"photon_full_hit", 5.0, 1.0)
	last_full_charge_hit_position = world_position
	full_charge_hit_sfx_play_count += 1
	if _full_charge_hit_flash != null:
		_full_charge_hit_flash.global_position = world_position
		_full_charge_hit_flash.scale = Vector2.ONE * 0.22
		_full_charge_hit_flash.modulate = Color(1.0, 0.92, 0.55, 1.0)
		_full_charge_hit_flash.visible = true
		_full_charge_hit_flash_remaining = FULL_CHARGE_HIT_FLASH_SECONDS


func _on_dodge_started(p_facing: int, _duration: float) -> void:
	dodging = true
	_dodge_facing = 1 if p_facing >= 0 else -1
	_play_mechanics(DASH_WARP_SFX, &"dash_warp", 0.5, 1.0)
	_show_idle()
	sprite.skew = -float(p_facing) * 0.10
	sprite.modulate = Color(0.72, 0.94, 1.0, 0.82)
	_afterimage_elapsed = 0.0
	_dust_elapsed = 0.0
	_spawn_afterimage()
	_spawn_dodge_dust(1.20)


func _on_dodge_finished() -> void:
	dodging = false
	_spawn_dodge_dust(0.70)
	sprite.skew = 0.0
	sprite.modulate = Color.WHITE
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_health_changed(current: float, maximum: float) -> void:
	if _critical_smoke == null:
		return
	var ratio: float = current / maxf(maximum, 1.0)
	var critical_ratio: float = float(RuntimeTweakAccess.live_value(
		&"player.visual.critical_health_ratio", CRITICAL_HEALTH_RATIO
	))
	_critical_smoke.emitting = current > 0.0 and ratio <= critical_ratio


func _on_dodge_cooldown_ready() -> void:
	if _status_sfx_player == null or DODGE_RECHARGED_SFX == null:
		return
	_status_sfx_player.stop()
	_status_sfx_player.stream = DODGE_RECHARGED_SFX
	_status_sfx_player.volume_db = -4.0
	_status_sfx_player.play()
	dodge_recharged_sfx_play_count += 1
	audio_play_count += 1
	last_audio_cue = &"dodge_recharged"


func _on_sprite_frame_changed() -> void:
	if attacking or robot.locomotion_state != GiantRobotController.LocomotionState.WALK:
		return
	if sprite.animation != &"walk_e" and sprite.animation != &"walk_w":
		return
	if sprite.frame in WALK_SERVO_FRAMES:
		var servo_index: int = WALK_SERVO_FRAMES.find(sprite.frame)
		var servo_pitch: float = 0.96 if servo_index == 0 else 1.04
		_play_mechanics(SERVO_SFX, &"walk_servo", -7.0, servo_pitch)
	elif sprite.frame in WALK_CONTACT_FRAMES:
		var contact_index: int = WALK_CONTACT_FRAMES.find(sprite.frame)
		var foot_pitch: float = 0.94 if contact_index == 0 else 1.02
		var speed_ratio: float = clampf(
			absf(robot.velocity.x) / maxf(robot.max_speed, 1.0),
			0.65,
			1.35
		)
		robot.notify_footstep(speed_ratio)
		_play_mechanics(
			FOOTSTEP_SFX,
			&"walk_footstep",
			clampf(-2.0 + speed_ratio * 1.5, -1.0, 0.5),
			foot_pitch
		)


func _play_walk() -> void:
	var animation: StringName = &"walk_e" if robot.facing >= 0 else &"walk_w"
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _show_idle() -> void:
	if sprite == null or robot == null:
		return
	sprite.speed_scale = _animation_speed_scale
	sprite.play(&"idle_s")
	sprite.pause()
	sprite.set_frame_and_progress(0, 0.0)


func _attack_animation(mode: int) -> StringName:
	if mode == AttackSpec.Mode.JAB_CROSS:
		return &"attack_e" if robot.facing >= 0 else &"attack_w"
	return &"attack_se" if robot.facing >= 0 else &"attack_sw"


func _update_emitter_facing() -> void:
	var emitter: Node2D = robot.get_node_or_null(^"VisualRoot/LaserEmitter") as Node2D
	if emitter != null:
		emitter.position.x = absf(emitter.position.x) * float(robot.facing)
	if _critical_smoke != null:
		_critical_smoke.position = Vector2(
			absf(CRITICAL_SMOKE_OFFSET.x) * float(robot.facing),
			CRITICAL_SMOKE_OFFSET.y
		)


func _prewarm_critical_smoke() -> void:
	var visual_root: Node2D = robot.get_node_or_null(^"VisualRoot") as Node2D
	if visual_root == null:
		return
	_critical_smoke = CPUParticles2D.new()
	_critical_smoke.name = "CriticalHealthSmoke"
	_critical_smoke.texture = CRITICAL_SMOKE_TEXTURE
	_critical_smoke.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_critical_smoke.amount = 14
	_critical_smoke.lifetime = 1.25
	_critical_smoke.randomness = 0.55
	_critical_smoke.direction = Vector2.UP
	_critical_smoke.spread = 30.0
	_critical_smoke.gravity = Vector2(0.0, -12.0)
	_critical_smoke.initial_velocity_min = 28.0
	_critical_smoke.initial_velocity_max = 72.0
	_critical_smoke.scale_amount_min = 0.08
	_critical_smoke.scale_amount_max = 0.18
	_critical_smoke.color = Color(0.62, 0.65, 0.67, 0.74)
	_critical_smoke.z_index = -1
	_critical_smoke.emitting = false
	visual_root.add_child(_critical_smoke)
	_update_emitter_facing()


func _prewarm_charge_particles() -> void:
	var visual_root: Node2D = robot.get_node_or_null(^"VisualRoot") as Node2D
	if visual_root == null:
		return
	_charge_particles = CPUParticles2D.new()
	_charge_particles.name = "MeleeChargeParticles"
	_charge_particles.position = CHARGE_PARTICLE_OFFSET
	_charge_particles.texture = PHOTON_CORE_TEXTURE
	_charge_particles.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_charge_particles.amount = CHARGE_PARTICLE_CAPACITY
	_charge_particles.lifetime = 0.72
	_charge_particles.preprocess = 0.35
	_charge_particles.randomness = 0.82
	_charge_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_charge_particles.emission_sphere_radius = 210.0
	_charge_particles.direction = Vector2.ZERO
	_charge_particles.spread = 180.0
	_charge_particles.gravity = Vector2.ZERO
	_charge_particles.initial_velocity_min = 44.0
	_charge_particles.initial_velocity_max = 104.0
	_charge_particles.radial_accel_min = -300.0
	_charge_particles.radial_accel_max = -190.0
	_charge_particles.damping_min = 18.0
	_charge_particles.damping_max = 30.0
	_charge_particles.scale_amount_min = 0.018
	_charge_particles.scale_amount_max = 0.045
	_charge_particles.color = CHARGE_PARTICLE_COLOR
	_charge_particles.z_index = 2
	_charge_particles.emitting = false
	visual_root.add_child(_charge_particles)


func _prewarm_charge_visuals() -> void:
	var visual_root: Node2D = robot.get_node_or_null(^"VisualRoot") as Node2D
	if visual_root == null:
		return
	_charge_meter_root = Node2D.new()
	_charge_meter_root.name = "PhotonChargeMeter"
	_charge_meter_root.position = CHARGE_METER_OFFSET
	_charge_meter_root.z_index = 7
	_charge_meter_root.visible = false
	visual_root.add_child(_charge_meter_root)
	_charge_meter_fill = ColorRect.new()
	_charge_meter_fill.name = "Fill"
	_charge_meter_fill.position = -CHARGE_METER_FILL_SIZE * 0.5
	_charge_meter_fill.size = Vector2(0.0, CHARGE_METER_FILL_SIZE.y)
	_charge_meter_fill.color = Color(1.0, 0.43, 0.06, 0.96)
	_charge_meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_meter_root.add_child(_charge_meter_fill)
	_charge_meter_frame = Sprite2D.new()
	_charge_meter_frame.name = "Frame"
	_charge_meter_frame.texture = CHARGE_METER_FRAME_TEXTURE
	_charge_meter_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_charge_meter_frame.scale = Vector2.ONE * 0.25
	_charge_meter_root.add_child(_charge_meter_frame)
	_charge_core = Sprite2D.new()
	_charge_core.name = "PhotonChestCore"
	_charge_core.texture = PHOTON_CORE_TEXTURE
	_charge_core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_charge_core.position = CHARGE_PARTICLE_OFFSET
	_charge_core.scale = Vector2.ONE * CHARGE_CORE_MIN_SCALE
	var core_shader: Shader = Shader.new()
	core_shader.code = FULL_CHARGE_CORE_SHADER_CODE
	_charge_core_material = ShaderMaterial.new()
	_charge_core_material.shader = core_shader
	_charge_core_material.set_shader_parameter(&"shift_amount", 0.0)
	_charge_core_material.set_shader_parameter(&"shift_color", Vector3(
		FULL_CHARGE_CORE_COLOR.r,
		FULL_CHARGE_CORE_COLOR.g,
		FULL_CHARGE_CORE_COLOR.b
	))
	_charge_core.material = _charge_core_material
	_charge_core.z_index = 6
	_charge_core.visible = false
	visual_root.add_child(_charge_core)
	_release_shockwave = Sprite2D.new()
	_release_shockwave.name = "FullChargeReleaseShockwave"
	_release_shockwave.texture = PHOTON_RELEASE_SHOCKWAVE_TEXTURE
	_release_shockwave.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_release_shockwave.position = CHARGE_PARTICLE_OFFSET
	_release_shockwave.scale = Vector2.ONE * RELEASE_SHOCKWAVE_START_SCALE
	_release_shockwave.modulate = RELEASE_SHOCKWAVE_COLOR
	_release_shockwave.z_index = 5
	_release_shockwave.visible = false
	visual_root.add_child(_release_shockwave)
	_full_charge_hit_flash = Sprite2D.new()
	_full_charge_hit_flash.name = "FullChargeHitFlash"
	_full_charge_hit_flash.texture = PHOTON_CORE_TEXTURE
	_full_charge_hit_flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_full_charge_hit_flash.top_level = true
	_full_charge_hit_flash.z_as_relative = false
	_full_charge_hit_flash.z_index = 120
	_full_charge_hit_flash.visible = false
	add_child(_full_charge_hit_flash)


func _prewarm_audio() -> void:
	for index: int in range(AUDIO_VOICE_CAPACITY):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "RobotMechanicsAudio%02d" % index
		player.max_distance = 1500.0
		player.attenuation = 0.45
		player.bus = GameAudioBus.MECHANICS
		AudioVoicePriority.stamp(player, AudioVoicePriority.UNUSED, 0)
		add_child(player)
		_audio_players.append(player)
	_status_sfx_player = AudioStreamPlayer.new()
	_status_sfx_player.name = "RobotStatusRechargeSfx"
	_status_sfx_player.bus = GameAudioBus.MECHANICS
	add_child(_status_sfx_player)
	_charge_sfx_player = AudioStreamPlayer2D.new()
	_charge_sfx_player.name = "PhotonChargeSfx"
	_charge_sfx_player.stream = PHOTON_CHARGE_SFX
	_charge_sfx_player.max_distance = 1500.0
	_charge_sfx_player.attenuation = 0.45
	_charge_sfx_player.volume_db = 3.0
	_charge_sfx_player.bus = GameAudioBus.MECHANICS
	add_child(_charge_sfx_player)
	_charge_voice_player = AudioStreamPlayer.new()
	_charge_voice_player.name = "FullyChargedVoice"
	_charge_voice_player.stream = FULLY_CHARGED_VOICE
	_charge_voice_player.volume_db = -1.5
	_charge_voice_player.bus = GameAudioBus.VOICE
	add_child(_charge_voice_player)


func _prewarm_afterimages() -> void:
	_afterimage_root = Node2D.new()
	_afterimage_root.name = "DodgeAfterimagePool"
	_afterimage_root.top_level = true
	_afterimage_root.z_as_relative = false
	_afterimage_root.z_index = 99
	add_child(_afterimage_root)
	for index: int in range(AFTERIMAGE_CAPACITY):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.name = "DodgeAfterimage%02d" % index
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.visible = false
		_afterimage_root.add_child(ghost)
		_afterimages.append(ghost)
		_afterimage_remaining.append(0.0)


func _prewarm_dust() -> void:
	_dust_pool = DodgeDustPool2D.new()
	_dust_pool.name = "DodgeDustPool"
	add_child(_dust_pool)
	_dust_pool.setup()


func _spawn_dodge_dust(intensity: float) -> void:
	if _dust_pool == null or robot == null:
		return
	var ground_origin: Node2D = robot.get_node_or_null(
		^"VisualRoot/VisualGroundOrigin"
	) as Node2D
	var origin: Vector2 = (
		ground_origin.global_position if ground_origin != null else robot.global_position
	)
	_dust_pool.spawn(
		origin,
		_dodge_facing,
		intensity * dust_intensity_scale * float(RuntimeTweakAccess.live_value(
			&"player.visual.dust_intensity", 1.0
		))
	)


func _spawn_afterimage() -> void:
	if sprite == null or _afterimages.is_empty():
		return
	var ghost: Sprite2D = _afterimages[_afterimage_cursor]
	var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(
		sprite.animation,
		sprite.frame
	)
	ghost.texture = frame_texture
	ghost.global_transform = sprite.global_transform
	ghost.skew = sprite.skew
	var tuned_alpha: float = AFTERIMAGE_ALPHA * float(RuntimeTweakAccess.live_value(
		&"player.visual.afterimage_alpha", 1.0
	))
	ghost.modulate = Color(0.35, 0.92, 1.0, tuned_alpha)
	ghost.visible = true
	_afterimage_remaining[_afterimage_cursor] = AFTERIMAGE_LIFETIME
	_afterimage_cursor = (_afterimage_cursor + 1) % _afterimages.size()


func _advance_afterimages(delta: float) -> void:
	for index: int in range(_afterimages.size()):
		var ghost: Sprite2D = _afterimages[index]
		if not ghost.visible:
			continue
		_afterimage_remaining[index] = maxf(_afterimage_remaining[index] - delta, 0.0)
		var ratio: float = _afterimage_remaining[index] / AFTERIMAGE_LIFETIME
		ghost.modulate.a = (
			AFTERIMAGE_ALPHA
			* float(RuntimeTweakAccess.live_value(
				&"player.visual.afterimage_alpha", 1.0
			))
			* ratio * ratio
		)
		if is_zero_approx(_afterimage_remaining[index]):
			ghost.visible = false


func _advance_charge_visuals(delta: float) -> void:
	if charging and last_charge_progress >= 1.0:
		_charge_pulse_elapsed += maxf(delta, 0.0)
		var pulse: float = 1.0 + sin(_charge_pulse_elapsed * 11.0) * 0.055
		if _charge_core != null:
			_charge_core.scale = Vector2.ONE * CHARGE_CORE_MAX_SCALE * pulse
			_charge_core.rotation += delta * 0.32
		if _charge_meter_root != null:
			_charge_meter_root.scale = Vector2.ONE * (1.0 + (pulse - 1.0) * 0.45)
		if _charge_meter_frame != null:
			_charge_meter_frame.modulate = Color(1.0, 0.91, 0.55, 1.0)
	elif _charge_meter_root != null:
		_charge_meter_root.scale = Vector2.ONE
		if _charge_meter_frame != null:
			_charge_meter_frame.modulate = Color.WHITE
	if _release_shockwave != null and _release_shockwave.visible:
		_release_shockwave_remaining = maxf(
			_release_shockwave_remaining - maxf(delta, 0.0),
			0.0
		)
		var shockwave_ratio: float = 1.0 - (
			_release_shockwave_remaining / RELEASE_SHOCKWAVE_SECONDS
		)
		var shockwave_ease: float = 1.0 - pow(1.0 - shockwave_ratio, 3.0)
		_release_shockwave.scale = Vector2.ONE * lerpf(
			RELEASE_SHOCKWAVE_START_SCALE,
			RELEASE_SHOCKWAVE_END_SCALE,
			shockwave_ease
		)
		_release_shockwave.modulate = RELEASE_SHOCKWAVE_COLOR
		_release_shockwave.modulate.a *= 1.0 - shockwave_ratio
		_release_shockwave.rotation += maxf(delta, 0.0) * 0.46
		if is_zero_approx(_release_shockwave_remaining):
			_hide_release_shockwave()
	if _full_charge_hit_flash == null or not _full_charge_hit_flash.visible:
		return
	_full_charge_hit_flash_remaining = maxf(
		_full_charge_hit_flash_remaining - maxf(delta, 0.0), 0.0
	)
	var flash_ratio: float = _full_charge_hit_flash_remaining / FULL_CHARGE_HIT_FLASH_SECONDS
	_full_charge_hit_flash.scale = Vector2.ONE * lerpf(0.56, 0.22, flash_ratio)
	_full_charge_hit_flash.modulate.a = flash_ratio * flash_ratio
	if is_zero_approx(_full_charge_hit_flash_remaining):
		_full_charge_hit_flash.visible = false


func _hide_charge_visuals() -> void:
	if _charge_sfx_player != null:
		_charge_sfx_player.stop()
	if _charge_meter_root != null:
		_charge_meter_root.visible = false
		_charge_meter_root.scale = Vector2.ONE
	if _charge_core != null:
		_charge_core.visible = false
		_charge_core.rotation = 0.0
	if _charge_core_material != null:
		_charge_core_material.set_shader_parameter(&"shift_amount", 0.0)
	_charge_pulse_elapsed = 0.0


func _start_release_shockwave() -> void:
	if _release_shockwave == null:
		return
	_release_shockwave_remaining = RELEASE_SHOCKWAVE_SECONDS
	_release_shockwave.scale = Vector2.ONE * RELEASE_SHOCKWAVE_START_SCALE
	_release_shockwave.modulate = RELEASE_SHOCKWAVE_COLOR
	_release_shockwave.rotation = 0.0
	_release_shockwave.visible = true


func _hide_release_shockwave() -> void:
	_release_shockwave_remaining = 0.0
	if _release_shockwave == null:
		return
	_release_shockwave.visible = false
	_release_shockwave.scale = Vector2.ONE * RELEASE_SHOCKWAVE_START_SCALE
	_release_shockwave.modulate = RELEASE_SHOCKWAVE_COLOR
	_release_shockwave.rotation = 0.0


func _play_mechanics(
	stream: AudioStream,
	cue: StringName,
	volume_db: float,
	pitch_scale: float,
	volume_variation_db: float = 0.0
) -> void:
	if stream == null or _audio_players.is_empty():
		return
	var priority: int = _priority_for_mechanics(cue)
	var player: AudioStreamPlayer2D = _acquire_audio_voice(priority)
	if player == null:
		audio_drop_count += 1
		return
	player.stop()
	player.stream = stream
	player.global_position = robot.global_position if robot != null else Vector2.ZERO
	var tuned_gain_db: float = float(RuntimeTweakAccess.live_value(
		&"audio.player.footstep_gain_db"
		if cue == &"walk_footstep"
		else &"audio.player.combat_gain_db",
		0.0
	))
	player.volume_db = volume_db + tuned_gain_db + (
		0.0
		if is_zero_approx(volume_variation_db)
		else volume_delta_for_sample(randf(), volume_variation_db)
	)
	player.pitch_scale = pitch_scale
	_voice_started_order += 1
	AudioVoicePriority.stamp(player, priority, _voice_started_order)
	player.play()
	audio_play_count += 1
	last_audio_cue = cue
	last_audio_volume_db = player.volume_db
	if cue == &"walk_footstep":
		footstep_play_count += 1
	elif cue in [&"ground_slam_impact", &"double_punch_impact"]:
		attack_impact_play_count += 1
	elif cue == &"photon_full_hit":
		pass
	else:
			servo_play_count += 1
			if cue == &"dash_warp":
				dash_warp_sfx_play_count += 1


static func volume_delta_for_sample(random_sample: float, variation_db: float) -> float:
	var bounded_variation_db: float = clampf(
		absf(variation_db), 0.0, MAX_MECHANICS_VOLUME_VARIATION_DB
	)
	return lerpf(
		-bounded_variation_db,
		bounded_variation_db,
		clampf(random_sample, 0.0, 1.0)
	)


func _acquire_audio_voice(priority: int) -> AudioStreamPlayer2D:
	var player: AudioStreamPlayer2D = AudioVoicePriority.select_2d(
		_audio_players,
		priority
	)
	if player == null:
		return null
	if player.playing:
		var existing_priority: int = AudioVoicePriority.priority_of(player)
		audio_recycle_count += 1
		if existing_priority < priority:
			audio_preemption_count += 1
			last_preempted_priority = existing_priority
	return player


func _priority_for_mechanics(cue: StringName) -> int:
	match cue:
		&"ground_slam_impact", &"double_punch_impact", &"dash_warp", &"photon_full_hit":
			return AudioVoicePriority.SIGNATURE
		&"attack_windup":
			return AudioVoicePriority.MAJOR
		&"walk_footstep":
			return AudioVoicePriority.UI_NAVIGATION
		_:
			return AudioVoicePriority.LOCOMOTION
