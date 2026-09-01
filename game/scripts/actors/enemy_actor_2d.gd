# gdlint: disable=max-public-methods
class_name EnemyActor2D
extends CharacterBody2D

signal projectile_requested(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName,
	source: Node
)
signal died(actor: EnemyActor2D, event: DamageEvent)
signal profile_changed(actor: EnemyActor2D)
signal boss_armor_changed(current: float, maximum: float)
signal health_changed(current: float, maximum: float)
signal boss_armor_broken()

const MINIMUM_TELEGRAPH_SECONDS: float = 0.32
const SURVIVING_MELEE_KNOCKBACK_MULTIPLIER: float = 5.0
const SURVIVING_PLAYER_LIGHT_VEHICLE_KNOCKBACK_MULTIPLIER: float = 0.45
const SURVIVING_PLAYER_HEAVY_VEHICLE_KNOCKBACK_MULTIPLIER: float = 0.12
const TELEGRAPH_REFERENCE_SPAN: float = 96.0
const TELEGRAPH_MINIMUM_THICKNESS_SCALE: float = 0.85
const TELEGRAPH_MAXIMUM_THICKNESS_SCALE: float = 2.40
const TELEGRAPH_REFERENCE_DAMAGE: float = 16.0
const TELEGRAPH_MINIMUM_COLOR_INTENSITY: float = 0.72
const TELEGRAPH_MAXIMUM_COLOR_INTENSITY: float = 1.55
const VISUAL_CONTENT_RECT_META: StringName = &"enemy_visual_content_rect"
const ATTACK_ORIGIN_FORWARD_CLEARANCE: float = 8.0
const ENEMY_DAMAGE_MULTIPLIER: float = 0.75
const HIDDEN_BOSS_TELEGRAPH_ID: int = -1

@export var max_health: float = 60.0

@export_group("Movement Bounce")
@export var movement_bounce_enabled: bool = false
@export var bounce_height: float = 4.0
@export var bounce_frequency: float = 3.5
@export var bounce_squash: float = 0.04
@export var bounce_speed_reference: float = 90.0

var current_health: float
var target: GiantRobotController
var dead: bool = false
var active: bool = true
var visual_faces_right_by_default: bool = false
var activation_generation: int = 0
var telegraph_presenter: TelegraphPresenter2D
var projectile_pool: ProjectilePool
var projectile_target_mask: int = 0
var facing: int = -1
var visual_ground_offset: float = 0.0
var attack_gate_enabled: bool = true
var role_id: StringName = &"BASE"
var trait_id: StringName = &""
var movement_multiplier: float = 1.0
var acceleration_multiplier: float = 1.0
var attack_interval_multiplier: float = 1.0
var score_multiplier: float = 1.0
var projectile_damage_multiplier: float = 1.0
var telegraph_multiplier: float = 1.0
var external_attack_interval_multiplier: float = 1.0
var aura_attack_interval_multiplier: float = 1.0
var aura_damage_multiplier: float = 1.0
var incoming_damage_multiplier: float = 1.0
var cycle_health_multiplier: float = 1.0
var cycle_attack_multiplier: float = 1.0
var role_badge: EnemyRoleBadge
var structural_target: StructuralBuilding2D
var catalyst_target: Catalyst2D
var boss_mode: bool = false
var hidden_authority: bool = false
var boss_armor: float = 0.0
var boss_max_armor: float = 0.0
var player_anticipation_count: int = 0
var player_strike_reaction_count: int = 0
var last_player_reaction_attack_id: int = 0
var last_player_knockback_attack_id: int = 0
var dodge_wheel_slip_count: int = 0
var last_dodge_wheel_slip_direction: int = 0
var _base_max_health: float = 0.0
var _profile_health_multiplier: float = 1.0
var _boss_base_health: float = 0.0
var _boss_health_multiplier: float = 1.0
var _shield_available: bool = false
var _shield_damage_ratio: float = 1.0
var _seen_attacks: Dictionary[int, bool] = {}
var _bounce_phase: float = 0.0
var _visual_rest_position: Vector2
var _visual_rest_scale: Vector2 = Vector2.ONE
var _visual_authored_scale: Vector2 = Vector2.ONE
var _visual_tuning_scale: float = 1.0
var _visual_tuning_tint: Color = Color.WHITE
var _base_collision_layer: int = 0
var _base_collision_mask: int = 0
var _telegraph_id: int = 0
var _telegraph_remaining: float = 0.0
var _telegraph_kind: StringName = &""
var _telegraph_origin: Vector2 = Vector2.ZERO
var _telegraph_target: Vector2 = Vector2.ZERO
var _projectile_reservation_id: int = 0
var _attack_outgoing_multiplier: float = ENEMY_DAMAGE_MULTIPLIER
var _attack_projectile_lifetime: float = 2.5
var _attack_projectile_speed_multiplier: float = 1.0
var _attack_anticipation_multiplier: float = 1.0
var _attack_telegraph_duration_multiplier: float = 1.0
var _spawn_health_multiplier: float = 1.0
var _spawn_movement_multiplier: float = 1.0
var _spawn_acceleration_multiplier: float = 1.0
var _spawn_attack_interval_multiplier: float = 1.0
var _player_reaction_tween: Tween

@onready var visual: Sprite2D = get_node_or_null(^"Visual") as Sprite2D


func _ready() -> void:
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask
	_base_max_health = max_health
	current_health = max_health
	role_badge = EnemyRoleBadge.new()
	role_badge.name = "RoleBadge"
	role_badge.position = Vector2(0.0, -72.0)
	role_badge.z_index = 4
	add_child(role_badge)
	role_badge.visible = false
	if visual != null:
		_visual_rest_position = visual.position
		set_authored_visual_scale(visual.scale)
		apply_live_visual_tuning(
			RuntimeTweakAccess.live_color(&"enemy.visual.tint", Color.WHITE),
			float(RuntimeTweakAccess.live_value(&"enemy.visual.scale", 1.0))
		)


func update_movement_bounce(delta: float) -> void:
	if visual == null:
		return
	var speed_ratio: float = clampf(
		absf(velocity.x) / maxf(bounce_speed_reference, 1.0),
		0.0,
		1.0
	)
	if movement_bounce_enabled and speed_ratio > 0.08 and is_on_floor():
		var frequency_multiplier: float = float(RuntimeTweakAccess.live_value(
			&"enemy.visual.bounce_frequency_multiplier", 1.0
		))
		var height_multiplier: float = float(RuntimeTweakAccess.live_value(
			&"enemy.visual.bounce_height_multiplier", 1.0
		))
		_bounce_phase = fmod(
			_bounce_phase + delta * TAU * bounce_frequency * frequency_multiplier
				* lerpf(0.75, 1.0, speed_ratio),
			TAU
		)
		var hop: float = absf(sin(_bounce_phase))
		var contact: float = absf(cos(_bounce_phase))
		visual.position.y = (
			_visual_rest_position.y - hop * bounce_height * height_multiplier * speed_ratio
		)
		visual.scale = Vector2(
			_visual_rest_scale.x * (1.0 + contact * bounce_squash * speed_ratio),
			_visual_rest_scale.y * (1.0 - contact * bounce_squash * speed_ratio)
		)
		visual.rotation = sin(_bounce_phase * 0.5) * 0.018 * float(facing)
		return
	_bounce_phase = 0.0
	visual.position = visual.position.move_toward(_visual_rest_position, 30.0 * delta)
	visual.scale = visual.scale.move_toward(_visual_rest_scale, 0.8 * delta)
	visual.rotation = move_toward(visual.rotation, 0.0, 0.3 * delta)


func set_authored_visual_scale(authored_scale: Vector2) -> void:
	_visual_authored_scale = authored_scale
	_visual_rest_scale = authored_scale * _visual_tuning_scale
	if visual != null:
		visual.scale = _visual_rest_scale


func apply_live_visual_tuning(tint: Color, size_multiplier: float) -> void:
	if visual == null:
		return
	var safe_scale: float = maxf(size_multiplier, 0.01)
	if not is_equal_approx(safe_scale, _visual_tuning_scale):
		_visual_tuning_scale = safe_scale
		_visual_rest_scale = _visual_authored_scale * safe_scale
		visual.scale = _visual_rest_scale
	if tint != _visual_tuning_tint:
		_visual_tuning_tint = tint
		visual.self_modulate = tint


func set_target(p_target: GiantRobotController) -> void:
	target = p_target


func receive_damage(event: DamageEvent) -> bool:
	if not active or dead or event == null or event.amount <= 0.0:
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	var transformed_event: DamageEvent = _transform_incoming_damage(event)
	if transformed_event == null or transformed_event.amount <= 0.0:
		return true
	event = transformed_event
	if boss_mode and boss_armor > 0.0:
		_receive_boss_armor_damage(event)
		return true
	var accepted_event: DamageEvent = event
	if _shield_available:
		_shield_available = false
		accepted_event = event.scaled(_shield_damage_ratio)
	if not is_equal_approx(incoming_damage_multiplier, 1.0):
		accepted_event = accepted_event.scaled(incoming_damage_multiplier)
	current_health = maxf(current_health - accepted_event.amount, 0.0)
	health_changed.emit(current_health, max_health)
	var melee_hit: bool = accepted_event.damage_type in [&"jab_cross", &"ground_smash"]
	var knockback_scale: float = 0.28 if melee_hit else 0.18
	if melee_hit and current_health > 0.0:
		knockback_scale *= SURVIVING_MELEE_KNOCKBACK_MULTIPLIER
	if current_health > 0.0 and accepted_event.source is GiantRobotController:
		var vehicle_weight: StringName = _ground_vehicle_weight_class()
		if vehicle_weight == EnemyArchetypeCatalog.VEHICLE_WEIGHT_LIGHT:
			knockback_scale *= SURVIVING_PLAYER_LIGHT_VEHICLE_KNOCKBACK_MULTIPLIER
		elif vehicle_weight == EnemyArchetypeCatalog.VEHICLE_WEIGHT_HEAVY:
			knockback_scale *= SURVIVING_PLAYER_HEAVY_VEHICLE_KNOCKBACK_MULTIPLIER
	velocity += accepted_event.direction * accepted_event.impulse_per_mass * knockback_scale
	if accepted_event.damage_type in [&"jab_cross", &"ground_smash"]:
		last_player_knockback_attack_id = accepted_event.attack_id
	if visual != null:
		var flash_intensity: float = float(RuntimeTweakAccess.live_value(
			&"interface.flash_intensity", 1.0
		))
		visual.modulate = Color.WHITE.lerp(Color("ffd0a6"), flash_intensity)
		var tween: Tween = create_tween()
		tween.tween_property(visual, "modulate", Color.WHITE, 0.12)
	if current_health <= 0.0:
		_die(accepted_event)
	return true


func _transform_incoming_damage(event: DamageEvent) -> DamageEvent:
	return event


func _ground_vehicle_weight_class() -> StringName:
	if self is TankEnemy:
		return EnemyArchetypeCatalog.VEHICLE_WEIGHT_HEAVY
	if self is ProceduralEnemy:
		return EnemyArchetypeCatalog.vehicle_weight_class(
			(self as ProceduralEnemy).archetype_id
		)
	var archetype_id: StringName = StringName(get_meta(&"enemy_archetype", &""))
	return EnemyArchetypeCatalog.vehicle_weight_class(archetype_id)


func _receive_boss_armor_damage(event: DamageEvent) -> void:
	boss_armor = maxf(boss_armor - event.amount, 0.0)
	boss_armor_changed.emit(boss_armor, boss_max_armor)
	if is_zero_approx(boss_armor):
		boss_armor_broken.emit()


func request_projectile(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName
) -> void:
	if not attack_gate_enabled:
		return
	if _telegraph_id == 0:
		_capture_attack_tuning()
	projectile_requested.emit(
		origin,
		direction,
		speed * _attack_projectile_speed_multiplier,
		_scale_outgoing_damage(damage),
		kind,
		self
	)


func _configure_cycle_difficulty(health_multiplier: float, attack_multiplier: float) -> void:
	var health_ratio: float = current_health / maxf(max_health, 1.0)
	cycle_health_multiplier = maxf(health_multiplier, 1.0)
	cycle_attack_multiplier = maxf(attack_multiplier, 1.0)
	max_health = (
		_boss_base_health * _boss_health_multiplier * cycle_health_multiplier
			* _spawn_health_multiplier
		if boss_mode
		else _base_max_health * _profile_health_multiplier * cycle_health_multiplier
			* _spawn_health_multiplier
	)
	current_health = max_health * clampf(health_ratio, 0.0, 1.0)


func _scale_outgoing_damage(amount: float) -> float:
	return maxf(amount, 0.0) * cycle_attack_multiplier * _attack_outgoing_multiplier


func _capture_attack_tuning() -> void:
	_attack_outgoing_multiplier = float(RuntimeTweakAccess.next_attack_value(
		&"enemy.outgoing_damage_multiplier", ENEMY_DAMAGE_MULTIPLIER
	))
	_attack_projectile_lifetime = float(RuntimeTweakAccess.next_attack_value(
		&"projectile.hostile_lifetime", 2.5
	))
	_attack_projectile_speed_multiplier = float(RuntimeTweakAccess.next_attack_value(
		&"enemy.projectile_speed_multiplier", 1.0
	))
	_attack_anticipation_multiplier = float(RuntimeTweakAccess.next_attack_value(
		&"enemy.anticipation_multiplier", 1.0
	))
	_attack_telegraph_duration_multiplier = float(RuntimeTweakAccess.next_attack_value(
		(
			&"boss.telegraph.duration_multiplier"
			if boss_mode
			else &"enemy.telegraph.duration_multiplier"
		),
		1.0
	))


func _capture_spawn_tuning() -> void:
	_spawn_health_multiplier = float(RuntimeTweakAccess.next_spawn_value(
		&"enemy.health_multiplier", 1.0
	))
	_spawn_movement_multiplier = float(RuntimeTweakAccess.next_spawn_value(
		&"enemy.movement_speed_multiplier", 1.0
	))
	_spawn_acceleration_multiplier = float(RuntimeTweakAccess.next_spawn_value(
		&"enemy.acceleration_multiplier", 1.0
	))
	_spawn_attack_interval_multiplier = float(RuntimeTweakAccess.next_spawn_value(
		&"enemy.attack_interval_multiplier", 1.0
	))
	score_multiplier = float(RuntimeTweakAccess.next_spawn_value(
		&"enemy.score_multiplier", 1.0
	))


func attack_projectile_lifetime() -> float:
	return _attack_projectile_lifetime


func begin_player_attack_reaction(
	attack_id: int,
	attacker_position: Vector2,
	duration: float
) -> void:
	if not active or dead or visual == null:
		return
	_cancel_player_reaction_tween()
	last_player_reaction_attack_id = attack_id
	player_anticipation_count += 1
	var away: float = signf(global_position.x - attacker_position.x)
	if is_zero_approx(away):
		away = float(-facing)
	visual.skew = 0.0
	visual.modulate = Color("fff0c7")
	var brace_seconds: float = minf(duration * 0.35, 0.18)
	_player_reaction_tween = create_tween()
	_player_reaction_tween.tween_property(
		visual,
		"skew",
		-away * 0.16,
		brace_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_player_reaction_tween.tween_property(
		visual,
		"skew",
		-away * 0.06,
		maxf(duration - brace_seconds, 0.01)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func commit_player_attack_reaction(attack_id: int, attacker_position: Vector2) -> void:
	if (
		not active
		or dead
		or visual == null
		or last_player_reaction_attack_id != attack_id
	):
		return
	_cancel_player_reaction_tween()
	player_strike_reaction_count += 1
	var away: float = signf(global_position.x - attacker_position.x)
	if is_zero_approx(away):
		away = float(-facing)
	visual.skew = away * 0.24
	visual.modulate = Color("fff7df")
	_player_reaction_tween = create_tween()
	_player_reaction_tween.set_parallel(true)
	_player_reaction_tween.tween_property(
		visual,
		"skew",
		0.0,
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_player_reaction_tween.tween_property(visual, "modulate", Color.WHITE, 0.16)


func _apply_dodge_wheel_slip(dodge_direction: int) -> bool:
	if not active or dead or visual == null:
		return false
	_cancel_player_reaction_tween()
	var direction: int = 1 if dodge_direction >= 0 else -1
	dodge_wheel_slip_count += 1
	last_dodge_wheel_slip_direction = direction
	visual.modulate = Color.WHITE
	visual.skew = -float(direction) * 0.08
	_player_reaction_tween = create_tween()
	_player_reaction_tween.tween_property(
		visual,
		"skew",
		float(direction) * 0.18,
		0.05
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_player_reaction_tween.tween_property(
		visual,
		"skew",
		0.0,
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


func set_attack_gate(enabled: bool) -> void:
	attack_gate_enabled = enabled
	if not enabled:
		cancel_telegraph()


func set_hidden_authority(enabled: bool) -> void:
	hidden_authority = enabled
	velocity = Vector2.ZERO
	set_physics_process(not enabled and active and not dead)
	if visual != null:
		visual.visible = not enabled and active and not dead
	var body_collision: CollisionShape2D = get_node_or_null(
		^"CollisionShape2D"
	) as CollisionShape2D
	if body_collision != null:
		body_collision.disabled = enabled
	var hurt_collision: CollisionShape2D = get_node_or_null(
		^"Hurtbox/CollisionShape2D"
	) as CollisionShape2D
	if hurt_collision != null:
		hurt_collision.disabled = enabled
	collision_layer = 0 if enabled else _base_collision_layer
	collision_mask = 0 if enabled else _base_collision_mask


func apply_profiles(
	role_profile: EnemyRoleProfile,
	trait_profile: EnemyTraitProfile
) -> void:
	role_id = role_profile.role_id if role_profile != null else &"BASE"
	trait_id = trait_profile.trait_id if trait_profile != null else &""
	movement_multiplier = (
		(role_profile.movement_multiplier if role_profile != null else 1.0)
		* _spawn_movement_multiplier
	)
	acceleration_multiplier = _spawn_acceleration_multiplier
	attack_interval_multiplier = (
		(role_profile.attack_interval_multiplier if role_profile != null else 1.0)
		* _spawn_attack_interval_multiplier
	)
	projectile_damage_multiplier = (
		role_profile.damage_multiplier if role_profile != null else 1.0
	)
	_profile_health_multiplier = (
		role_profile.health_multiplier if role_profile != null else 1.0
	)
	if trait_profile != null:
		_profile_health_multiplier *= trait_profile.health_multiplier
		movement_multiplier *= trait_profile.movement_multiplier
		attack_interval_multiplier *= trait_profile.attack_interval_multiplier
		projectile_damage_multiplier *= trait_profile.projectile_damage_multiplier
		telegraph_multiplier = trait_profile.telegraph_multiplier
	max_health = _base_max_health * _profile_health_multiplier * cycle_health_multiplier \
		* _spawn_health_multiplier
	current_health = max_health
	_shield_available = trait_profile != null and trait_profile.first_hit_damage_ratio < 1.0
	_shield_damage_ratio = (
		trait_profile.first_hit_damage_ratio if trait_profile != null else 1.0
	)
	role_badge.configure(role_profile, trait_profile)
	profile_changed.emit(self)


func clear_profiles() -> void:
	role_id = &"BASE"
	trait_id = &""
	movement_multiplier = 1.0
	acceleration_multiplier = 1.0
	attack_interval_multiplier = 1.0
	projectile_damage_multiplier = 1.0
	telegraph_multiplier = 1.0
	external_attack_interval_multiplier = 1.0
	aura_attack_interval_multiplier = 1.0
	aura_damage_multiplier = 1.0
	incoming_damage_multiplier = 1.0
	_profile_health_multiplier = 1.0
	max_health = _base_max_health * cycle_health_multiplier
	_shield_available = false
	_shield_damage_ratio = 1.0
	if role_badge != null:
		role_badge.configure(null, null)


func configure_boss(
	armor: float,
	exposed_health: float
) -> void:
	boss_mode = true
	_boss_base_health = maxf(exposed_health, 1.0)
	_boss_health_multiplier = float(RuntimeTweakAccess.next_spawn_value(
		&"boss.health_multiplier", 1.0
	))
	boss_max_armor = maxf(armor, 1.0) * float(RuntimeTweakAccess.next_spawn_value(
		&"boss.armor_multiplier", 1.0
	))
	boss_armor = boss_max_armor
	max_health = _boss_base_health * _boss_health_multiplier * cycle_health_multiplier \
		* _spawn_health_multiplier
	current_health = max_health
	boss_armor_changed.emit(boss_armor, boss_max_armor)


func activate(spawn_position: Vector2, p_target: GiantRobotController) -> void:
	_cancel_player_reaction_tween()
	clear_profiles()
	_capture_spawn_tuning()
	movement_multiplier = _spawn_movement_multiplier
	acceleration_multiplier = _spawn_acceleration_multiplier
	attack_interval_multiplier = _spawn_attack_interval_multiplier
	max_health = _base_max_health * cycle_health_multiplier * _spawn_health_multiplier
	activation_generation += 1
	active = true
	dead = false
	set_hidden_authority(false)
	visible = true
	global_position = spawn_position
	velocity = Vector2.ZERO
	current_health = max_health
	target = p_target
	_update_facing()
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	_seen_attacks.clear()
	attack_gate_enabled = true
	set_physics_process(true)
	if visual != null:
		visual.visible = true
		visual.modulate = Color.WHITE
		visual.position = _visual_rest_position
		visual.scale = _visual_rest_scale
		visual.rotation = 0.0
		visual.skew = 0.0
	_reset_archetype_state()


func deactivate() -> void:
	_cancel_player_reaction_tween()
	cancel_telegraph()
	clear_profiles()
	remove_meta(&"enemy_boss_id")
	boss_mode = false
	_boss_base_health = 0.0
	_boss_health_multiplier = 1.0
	boss_armor = 0.0
	boss_max_armor = 0.0
	hidden_authority = false
	active = false
	dead = false
	visible = false
	target = null
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	global_position = Vector2(-4096.0, -4096.0)


func begin_telegraph(
	kind: StringName,
	duration: float,
	origin: Vector2,
	target_point: Vector2,
	damage_output: float = 0.0,
	presentation_variant: StringName = &"",
	visual_key: StringName = &"",
	style_data: Dictionary = {}
) -> bool:
	if not attack_gate_enabled or _telegraph_id != 0:
		return false
	if not boss_mode and telegraph_presenter == null:
		return false
	if kind != &"support" and projectile_pool != null:
		_projectile_reservation_id = projectile_pool.reserve(kind)
		if _projectile_reservation_id == 0:
			return false
	_capture_attack_tuning()
	var adjusted_duration: float = maxf(
		duration * telegraph_multiplier * _attack_anticipation_multiplier
			* _attack_telegraph_duration_multiplier,
		MINIMUM_TELEGRAPH_SECONDS
	)
	if boss_mode:
		_telegraph_id = HIDDEN_BOSS_TELEGRAPH_ID
	else:
		_telegraph_id = telegraph_presenter.reserve(
			self,
			kind,
			origin,
			target_point,
			adjusted_duration,
			damage_output,
			presentation_variant,
			visual_key,
			style_data
		)
		if _telegraph_id == 0:
			if projectile_pool != null and _projectile_reservation_id != 0:
				projectile_pool.cancel_reservation(_projectile_reservation_id)
				_projectile_reservation_id = 0
			return false
	_telegraph_kind = kind
	_telegraph_remaining = adjusted_duration
	_telegraph_origin = origin
	_telegraph_target = target_point
	return true


func attack_telegraph_origin() -> Vector2:
	if visual != null and visual.texture != null:
		var content_rect: Rect2 = visual.get_meta(
			VISUAL_CONTENT_RECT_META,
			Rect2(-visual.texture.get_size() * 0.5, visual.texture.get_size())
		)
		var rendered_left: float = content_rect.position.x
		var rendered_right: float = content_rect.end.x
		var rendered_top: float = content_rect.position.y
		var rendered_bottom: float = content_rect.end.y
		if visual.flip_h:
			rendered_left = -content_rect.end.x
			rendered_right = -content_rect.position.x
		if visual.flip_v:
			rendered_top = -content_rect.end.y
			rendered_bottom = -content_rect.position.y
		var local_origin: Vector2 = Vector2(
			rendered_right if facing > 0 else rendered_left,
			(rendered_top + rendered_bottom) * 0.5
		)
		return visual.to_global(local_origin) + _attack_forward_direction() \
			* ATTACK_ORIGIN_FORWARD_CLEARANCE
	return global_position + _attack_forward_direction() * ATTACK_ORIGIN_FORWARD_CLEARANCE


func center_of_mass_world_position() -> Vector2:
	if visual == null or visual.texture == null:
		return global_position
	var content_rect: Rect2 = visual.get_meta(
		VISUAL_CONTENT_RECT_META,
		Rect2(-visual.texture.get_size() * 0.5, visual.texture.get_size())
	)
	var local_center: Vector2 = content_rect.get_center()
	if visual.flip_h:
		local_center.x = -local_center.x
	if visual.flip_v:
		local_center.y = -local_center.y
	return visual.to_global(local_center)


func _attack_forward_direction() -> Vector2:
	var actor_right: Vector2 = global_transform.x.normalized()
	if actor_right.is_zero_approx():
		actor_right = Vector2.RIGHT
	return actor_right * float(facing)


func attack_telegraph_thickness_scale() -> float:
	var rendered_span: float = TELEGRAPH_REFERENCE_SPAN
	var body_collision: CollisionShape2D = get_node_or_null(
		^"CollisionShape2D"
	) as CollisionShape2D
	if body_collision != null and body_collision.shape is RectangleShape2D:
		var rectangle: RectangleShape2D = body_collision.shape as RectangleShape2D
		var scaled_size: Vector2 = rectangle.size * body_collision.global_scale.abs()
		rendered_span = maxf(scaled_size.x, scaled_size.y)
	elif visual != null and visual.texture != null:
		var visual_size: Vector2 = visual.texture.get_size() * visual.global_scale.abs()
		rendered_span = maxf(visual_size.x, visual_size.y)
	return clampf(
		sqrt(rendered_span / TELEGRAPH_REFERENCE_SPAN),
		TELEGRAPH_MINIMUM_THICKNESS_SCALE,
		TELEGRAPH_MAXIMUM_THICKNESS_SCALE
	)


func attack_telegraph_color_intensity(damage_output: float) -> float:
	var effective_damage: float = _scale_outgoing_damage(damage_output)
	return clampf(
		sqrt(effective_damage / TELEGRAPH_REFERENCE_DAMAGE),
		TELEGRAPH_MINIMUM_COLOR_INTENSITY,
		TELEGRAPH_MAXIMUM_COLOR_INTENSITY
	)


func advance_telegraph(delta: float) -> bool:
	if _telegraph_id == 0:
		return false
	_telegraph_remaining = maxf(_telegraph_remaining - delta, 0.0)
	return is_zero_approx(_telegraph_remaining)


func telegraph_origin() -> Vector2:
	return _telegraph_origin


func telegraph_direction() -> Vector2:
	return _telegraph_origin.direction_to(_telegraph_target)


func _rebase_cached_world_state(offset: Vector2) -> void:
	if _telegraph_id == 0:
		return
	_telegraph_origin += offset
	_telegraph_target += offset


func fire_telegraphed_projectile(
	speed: float,
	damage: float,
	visual_key: StringName = &"",
	finish_after_fire: bool = true
) -> Projectile2D:
	var projectile: Projectile2D
	if projectile_pool != null and _projectile_reservation_id != 0:
		projectile = projectile_pool.acquire_reserved(
			_projectile_reservation_id,
			_telegraph_origin,
			telegraph_direction(),
			speed * _attack_projectile_speed_multiplier,
			_scale_outgoing_damage(damage),
			self,
			projectile_target_mask,
			_telegraph_kind,
			visual_key,
			1.0,
			_attack_projectile_lifetime
		)
	else:
		request_projectile(
			_telegraph_origin,
			telegraph_direction(),
			speed,
			damage,
			_telegraph_kind
		)
	_projectile_reservation_id = 0
	if finish_after_fire:
		finish_telegraph()
	return projectile
func cancel_telegraph() -> void:
	if telegraph_presenter != null and _telegraph_id > 0:
		telegraph_presenter.cancel(_telegraph_id)
	if projectile_pool != null and _projectile_reservation_id != 0:
		projectile_pool.cancel_reservation(_projectile_reservation_id)
	_projectile_reservation_id = 0
	_telegraph_id = 0
	_telegraph_remaining = 0.0
	_telegraph_kind = &""


func finish_telegraph() -> void:
	cancel_telegraph()


func is_telegraphing() -> bool:
	return _telegraph_id != 0


func _reset_archetype_state() -> void:
	pass


func _cancel_player_reaction_tween() -> void:
	if _player_reaction_tween != null and _player_reaction_tween.is_valid():
		_player_reaction_tween.kill()
	_player_reaction_tween = null


func _update_facing() -> void:
	if target == null:
		return
	facing = -1 if target.global_position.x < global_position.x else 1
	if visual != null:
		visual.flip_h = (facing > 0) != visual_faces_right_by_default


func _die(event: DamageEvent) -> void:
	dead = true
	cancel_telegraph()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	set_physics_process(false)
	if visual != null:
		visual.visible = false
	died.emit(self, event)
