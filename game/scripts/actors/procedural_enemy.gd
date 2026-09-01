class_name ProceduralEnemy
extends EnemyActor2D

enum State {
	APPROACH,
	HOLD,
	ANTICIPATE,
	BREAK,
}

const GRAVITY: float = 1400.0
const MARK_DURATION: float = 3.0
const SUPPORT_RADIUS: float = 520.0
const REPAIR_SUPPORT_PULSE: Texture2D = preload(
	"res://art/city/enemies/effects/repair-support-pulse.png"
)
const NEMESIS_MELEE_LANCE: Texture2D = preload(
	"res://art/presentation/choir_contact_brace.png"
)
const CHOIR_CONTACT_BRACE: Texture2D = preload(
	"res://art/presentation/choir_contact_brace.png"
)
const CHOIR_CONTACT_LEAP: Texture2D = preload(
	"res://art/presentation/choir_contact_leap.png"
)
const CHOIR_CONTACT_DROP: Texture2D = preload(
	"res://art/presentation/choir_contact_drop.png"
)
const CHOIR_CONTACT_FOOTPRINT: Texture2D = preload(
	"res://art/presentation/choir_contact_footprint.png"
)
const CONVENTIONAL_DEPLOYMENT: Texture2D = preload(
	"res://art/presentation/choir_contact_footprint.png"
)
const CHOIR_INCUBATION_PAYLOAD: Texture2D = preload(
	"res://art/player/vfx/photon_core_orb.png"
)
const MULE_RAMP_OPEN_REGION: Rect2 = Rect2(316.0, 4.0, 96.0, 84.0)
const SOLDIER_DISPATCH_REGION: Rect2 = Rect2(412.0, 16.0, 64.0, 64.0)
const HIVE_BAY_OPEN_REGION: Rect2 = Rect2(352.0, 100.0, 120.0, 92.0)
const HOUND_LAUNCH_POD_REGION: Rect2 = Rect2(168.0, 192.0, 88.0, 56.0)
const SERAPH_BAY_REGION: Rect2 = Rect2(56.0, 120.0, 152.0, 52.0)
const SERAPH_CLUTCH_REGIONS: Array[Rect2] = [
	Rect2(0.0, 0.0, 56.0, 112.0),
	Rect2(56.0, 0.0, 56.0, 112.0),
]
const PRESENTATION_SPRITE_COUNT: int = 5

var archetype_id: StringName = &""
var base_archetype_id: StringName = &""
var profile: Dictionary = {}
var family: StringName = &""
var airborne: bool = false
var display_name: String = ""
var move_speed: float = 90.0
var acceleration: float = 450.0
var preferred_range: float = 420.0
var minimum_range: float = 240.0
var attack_interval: float = 2.0
var projectile_kind: StringName = &"bullet"
var projectile_speed: float = 700.0
var projectile_damage: float = 8.0
var anticipation_duration: float = 0.6
var behavior: StringName = &"ground_standoff"
var movement_style: StringName = &"heavy_march"
var attack_style: StringName = &"turret_burst"
var xp_value: int = 500
var threat_cost: int = 1
var remains_family: StringName = &"vehicle"
var encounter_runtime: EncounterRuntime
var ablative_armor: float = 0.0
var maximum_ablative_armor: float = 0.0
var boss_support_id: StringName = &""

var state: State = State.APPROACH
var _cooldown: float = 0.4
var _state_time: float = 0.0
var _animation_phase: float = 0.0
var _attack_kick: float = 0.0
var _pass_side: int = 1
var _spawned_children: int = 0
var _attack_sequence: int = 0
var _lane_y: float = 190.0
var _extra_projectile_reservations: Array[int] = []
var _presentation_sprites: Array[Sprite2D] = []
var _presentation_remaining: float = 0.0
var _attack_vfx_id: StringName = &""


func configure_archetype(p_archetype_id: StringName, p_profile: Dictionary) -> void:
	_reset_presentation_sprites()
	archetype_id = p_archetype_id
	base_archetype_id = EnemyArchetypeCatalog.canonical_id(archetype_id)
	boss_support_id = &""
	profile = p_profile.duplicate(true)
	display_name = String(profile.get("display_name", String(archetype_id).to_upper()))
	family = StringName(profile.get("family", &""))
	airborne = bool(profile.get("airborne", false))
	visual_faces_right_by_default = bool(profile.get("faces_right", false))
	max_health = (
		float(profile.get("health", 60.0))
		* EnemyArchetypeCatalog.health_multiplier(archetype_id)
	)
	_base_max_health = max_health
	move_speed = float(profile.get("speed", 90.0))
	acceleration = float(profile.get("acceleration", 450.0))
	preferred_range = float(profile.get("preferred_range", 420.0))
	minimum_range = float(profile.get("minimum_range", 240.0))
	attack_interval = float(profile.get("attack_interval", 2.0))
	projectile_kind = StringName(profile.get("projectile_kind", &"bullet"))
	projectile_speed = float(profile.get("projectile_speed", 700.0))
	projectile_damage = float(profile.get("damage", 8.0))
	anticipation_duration = float(profile.get("anticipation", 0.6))
	behavior = StringName(profile.get("behavior", &"ground_standoff"))
	movement_style = StringName(profile.get("movement_style", &"heavy_march"))
	attack_style = StringName(profile.get("attack_style", &"turret_burst"))
	if attack_style in [&"incubation_drop", &"deploy", &"drone_launch"]:
		attack_interval = EnemySpawnTuning.scaled_interval(attack_interval)
	xp_value = int(profile.get("xp", 500))
	threat_cost = int(profile.get("threat", 1))
	remains_family = StringName(profile.get("remains", &"vehicle"))
	_attack_vfx_id = StringName(profile.get("attack_vfx_id", &""))
	_lane_y = float(profile.get("spawn_y", 190.0))
	maximum_ablative_armor = float(profile.get("ablative_armor", 0.0))
	ablative_armor = maximum_ablative_armor
	if airborne:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		add_to_group(AerialDebrisLauncher.AIRBORNE_GROUP)
	else:
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		remove_from_group(AerialDebrisLauncher.AIRBORNE_GROUP)
	set_meta(&"enemy_archetype", archetype_id)
	set_meta(&"enemy_canonical_archetype", base_archetype_id)
	set_meta(&"enemy_family", family)


func configure_boss_support(presentation_id: StringName) -> bool:
	if not presentation_id in [
		&"reclaimed_breacher", &"graft_runner", &"choir_siren",
	]:
		return false
	if (
		presentation_id == &"reclaimed_breacher" and family != &"siege"
	) or (
		presentation_id == &"graft_runner" and family != &"light"
	) or (
		presentation_id == &"choir_siren" and family != &"air"
	):
		return false
	var presentation: Dictionary = EnemyArchetypeCatalog.profile(presentation_id)
	if presentation.is_empty():
		return false
	boss_support_id = presentation_id
	display_name = String(presentation.display_name)
	move_speed = float(presentation.speed)
	acceleration = float(presentation.acceleration)
	preferred_range = float(presentation.preferred_range)
	minimum_range = float(presentation.minimum_range)
	attack_interval = float(presentation.attack_interval)
	projectile_kind = StringName(presentation.projectile_kind)
	projectile_speed = float(presentation.projectile_speed)
	projectile_damage = float(presentation.damage)
	anticipation_duration = float(presentation.anticipation)
	behavior = StringName(presentation.behavior)
	movement_style = StringName(presentation.movement_style)
	attack_style = StringName(presentation.attack_style)
	visual_faces_right_by_default = bool(presentation.get("faces_right", false))
	if visual != null:
		if (
			encounter_runtime == null
			or not encounter_runtime.configure_boss_support_visual(
				self,
				presentation_id,
				presentation
			)
		):
			var texture: Texture2D = load(String(presentation.texture)) as Texture2D
			if texture == null:
				return false
			visual.texture = texture
			var display_size: Vector2 = (
				presentation.display as Vector2
			) * EnemyArchetypeCatalog.presentation_scale(presentation_id)
			var texture_size: Vector2 = visual.texture.get_size()
			visual.scale = display_size / Vector2(
				maxf(texture_size.x, 1.0),
				maxf(texture_size.y, 1.0)
			)
			visual.set_meta(
				VISUAL_CONTENT_RECT_META,
				Rect2(-texture_size * 0.5, texture_size)
			)
			_visual_rest_position = visual.position
			set_authored_visual_scale(visual.scale)
	if target != null:
		_update_facing()
	set_meta(&"boss_support_id", boss_support_id)
	return true


func _ready() -> void:
	_create_presentation_sprites()
	super._ready()
	set_meta(&"enemy_archetype", archetype_id)
	set_meta(&"enemy_canonical_archetype", base_archetype_id)
	set_meta(&"enemy_family", family)


func _physics_process(delta: float) -> void:
	_update_completion_presentation(delta)
	if dead or not active:
		return
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if state == State.ANTICIPATE:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		if advance_telegraph(delta):
			_complete_attack()
			state = State.HOLD
			_state_time = 0.0
			_cooldown = (
				attack_interval
				* attack_interval_multiplier
				* external_attack_interval_multiplier
				* aura_attack_interval_multiplier
			)
		move_and_slide()
		_animate_visual(delta)
		return
	if target == null:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		if not airborne:
			velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
		move_and_slide()
		_animate_visual(delta)
		return
	_update_facing()
	if airborne:
		_update_air_movement(delta)
	else:
		_update_ground_movement(delta)
	if _cooldown <= 0.0 and _can_attack():
		_begin_attack()
	move_and_slide()
	_animate_visual(delta)


func receive_damage(event: DamageEvent) -> bool:
	if (
		(
			archetype_id in [&"bulwark", &"reclaimed_breacher"]
			or boss_support_id == &"reclaimed_breacher"
		)
		and event != null
		and event.damage_type != &"ground_smash"
	):
		var incoming_dot: float = event.direction.normalized().dot(Vector2(float(facing), 0.0))
		if incoming_dot < -0.35:
			var damage_ratio: float = (
				0.28 if archetype_id == &"bulwark" else 0.40
			)
			return super.receive_damage(event.scaled(damage_ratio))
	return super.receive_damage(event)


func _transform_incoming_damage(event: DamageEvent) -> DamageEvent:
	if archetype_id != &"pale_engine" or ablative_armor <= 0.0:
		return event
	var absorbed: float = minf(ablative_armor, event.amount)
	ablative_armor -= absorbed
	if visual != null:
		visual.modulate = Color("c6fff5")
	return event.scaled((event.amount - absorbed) / event.amount)


func _update_ground_movement(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	var distance_x: float = absf(target.global_position.x - global_position.x)
	var desired_speed: float = 0.0
	if behavior == &"ground_pass":
		if state != State.BREAK and distance_x < minimum_range + 80.0:
			state = State.BREAK
			_state_time = 0.0
			_pass_side = facing
		if state == State.BREAK:
			desired_speed = float(_pass_side) * move_speed * movement_multiplier
			if _state_time > 1.25:
				state = State.APPROACH
			else:
				desired_speed = float(facing) * move_speed * movement_multiplier
	elif behavior in [&"ground_close", &"ground_breacher"]:
		desired_speed = (
			float(facing) * move_speed * movement_multiplier
			if distance_x > minimum_range
			else 0.0
		)
	elif distance_x > preferred_range + 45.0:
		state = State.APPROACH
		desired_speed = float(facing) * move_speed * movement_multiplier
	elif distance_x < minimum_range:
		state = State.BREAK
		desired_speed = -float(facing) * move_speed * movement_multiplier
	else:
		state = State.HOLD
	velocity.x = move_toward(velocity.x, desired_speed, acceleration * delta)


func _update_air_movement(delta: float) -> void:
	var desired_point: Vector2
	if behavior == &"air_pass":
		if state != State.BREAK and absf(target.global_position.x - global_position.x) < 190.0:
			state = State.BREAK
			_state_time = 0.0
			_pass_side = facing
		if state == State.BREAK:
			desired_point = Vector2(
				target.global_position.x + float(_pass_side) * 760.0,
				_lane_y - 35.0
			)
			if _state_time > 1.6:
				state = State.APPROACH
		else:
			desired_point = Vector2(
				target.global_position.x + float(facing) * preferred_range,
				_lane_y
			)
	elif behavior == &"air_close":
		desired_point = target.global_position + Vector2(float(-facing) * minimum_range, -150.0)
	else:
		desired_point = Vector2(
			target.global_position.x - float(facing) * preferred_range,
			_lane_y
		)
	var desired_velocity: Vector2 = (
		global_position.direction_to(desired_point) * move_speed * movement_multiplier
	)
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func _can_attack() -> bool:
	if not attack_gate_enabled or state == State.ANTICIPATE:
		return false
	if (
		(archetype_id == &"graft_runner" or boss_support_id == &"graft_runner")
		and (encounter_runtime == null or encounter_runtime.target_mark_remaining <= 0.0)
	):
		return false
	var distance_x: float = absf(target.global_position.x - global_position.x)
	if behavior in [&"ground_pass", &"air_pass"]:
		return distance_x < preferred_range
	if behavior in [&"ground_close", &"air_close"]:
		return distance_x <= preferred_range + 80.0
	return distance_x <= preferred_range + 110.0


func _begin_attack() -> void:
	var origin: Vector2 = attack_telegraph_origin()
	if airborne:
		origin = global_position + Vector2(float(facing) * 52.0, 15.0)
	var target_point: Vector2 = target.global_position + Vector2(0.0, 30.0)
	if attack_style == &"bomb_drop":
		target_point += Vector2(target.velocity.x * 0.35, 55.0)
	var telegraph_kind: StringName = projectile_kind
	var presentation_variant: StringName = &""
	if attack_style in [
		&"scan", &"repair", &"jammer_pulse", &"shield_pulse", &"deploy", &"drone_launch",
		&"shock_brace", &"marked_leap", &"choir_ring", &"drop_lunge", &"incubation_drop",
		&"lance_thrust",
	]:
		telegraph_kind = &"support"
		presentation_variant = &"melee_lance" if attack_style == &"lance_thrust" else attack_style
	var damage_output: float = (
		projectile_damage * projectile_damage_multiplier * aura_damage_multiplier
	)
	var telegraph_visual_key: StringName = _attack_vfx_id
	var telegraph_style_data: Dictionary = {}
	var authored_attack_phase: Dictionary = _authored_attack_phase()
	if not authored_attack_phase.is_empty():
		telegraph_style_data = {
			"attack_vfx_id": _attack_vfx_id,
			"delivery": StringName(
				EnemyAttackVfxCatalog.spec(_attack_vfx_id).get("delivery", &"")
			),
			TelegraphPresenter2D.AUTHORED_TELEGRAPH_STYLE_KEY: true,
		}
	if not begin_telegraph(
		telegraph_kind,
		anticipation_duration,
		origin,
		target_point,
		damage_output,
		presentation_variant,
		telegraph_visual_key,
		telegraph_style_data
	):
		_cooldown = 0.2
		return
	var extra_shots: int = 0
	if attack_style == &"pod_salvo":
		extra_shots = 2
	elif attack_style == &"fortress_barrage":
		extra_shots = 3
	if extra_shots > 0 and not _reserve_extra_projectiles(extra_shots):
		cancel_telegraph()
		_cooldown = 0.2
		return
	state = State.ANTICIPATE
	_state_time = 0.0
	_attack_kick = 1.0
	_show_district_attack_anticipation(authored_attack_phase)


func _complete_attack() -> void:
	_attack_sequence += 1
	_attack_kick = 1.0
	if not _attack_vfx_id.is_empty():
		_reset_presentation_sprites()
	if _complete_support_attack() or _complete_melee_attack():
		return
	var visual_key: StringName = EnemyAttackVfxCatalog.projectile_key(_attack_vfx_id)
	if visual_key.is_empty() and attack_style in [&"pod_salvo", &"fortress_barrage"]:
		visual_key = ProjectileVisualCatalog.ENEMY_ROCKET_SALVO
	var first: Projectile2D = fire_telegraphed_projectile(
		projectile_speed,
		projectile_damage * projectile_damage_multiplier * aura_damage_multiplier,
		visual_key,
		not attack_style in [&"pod_salvo", &"fortress_barrage"]
	)
	if first == null:
		return
	if attack_style in [&"pod_salvo", &"fortress_barrage"]:
		_fire_spread_projectiles(2 if attack_style == &"pod_salvo" else 3)
		finish_telegraph()


func _complete_support_attack() -> bool:
	if attack_style == &"scan":
		if encounter_runtime != null:
			encounter_runtime.apply_target_mark(MARK_DURATION)
		finish_telegraph()
		_show_district_completion(target.global_position if target != null else global_position)
		return true
	if attack_style == &"repair":
		var repaired: EnemyActor2D = _repair_nearest_ally()
		if repaired != null and _attack_vfx_id.is_empty():
			_show_world_completion(
				REPAIR_SUPPORT_PULSE,
				repaired.global_position,
				Vector2(72.0, 36.0),
				0.20
			)
		finish_telegraph()
		if repaired != null:
			_show_district_completion(repaired.global_position)
		return true
	if attack_style in [&"jammer_pulse", &"shield_pulse"]:
		finish_telegraph()
		return true
	if attack_style == &"choir_ring":
		if encounter_runtime != null:
			encounter_runtime.apply_target_mark(MARK_DURATION + 1.0)
			encounter_runtime.emit_hybrid_event(&"choir_ring", self)
		finish_telegraph()
		_show_district_completion(target.global_position if target != null else global_position)
		return true
	return _complete_carrier_attack()


func _complete_carrier_attack() -> bool:
	if attack_style == &"incubation_drop":
		if encounter_runtime != null:
			encounter_runtime.apply_target_mark(MARK_DURATION + 2.0)
			encounter_runtime.emit_hybrid_event(&"seraph_payload", self)
		var deployed: int = _try_spawn_reinforcements(EnemySpawnTuning.scaled_count(3))
		_show_seraph_deployment(deployed)
		finish_telegraph()
		return true
	if attack_style in [&"deploy", &"drone_launch"]:
		var deployed: int = _try_spawn_reinforcements(EnemySpawnTuning.QUANTITY_MULTIPLIER)
		_show_conventional_deployment(deployed)
		finish_telegraph()
		return true
	return false


func _complete_melee_attack() -> bool:
	if attack_style in [&"shock_brace", &"marked_leap", &"drop_lunge"]:
		var committed_hit: bool = false
		if global_position.distance_to(target.global_position) <= preferred_range + 45.0:
			_commit_melee_damage(attack_style, 420.0)
			committed_hit = true
		if _attack_vfx_id.is_empty():
			_show_choir_contact(attack_style, committed_hit)
			finish_telegraph()
		else:
			finish_telegraph()
			_show_district_completion(
				target.global_position if target != null else global_position
			)
		return true
	if attack_style == &"lance_thrust":
		if global_position.distance_to(target.global_position) <= 245.0:
			_commit_melee_damage(&"lance", 520.0)
			_show_lance_completion()
		finish_telegraph()
		return true
	return false


func _commit_melee_damage(damage_type: StringName, impulse: float) -> void:
	var attack_id: int = activation_generation * 1000 + _attack_sequence
	target.receive_damage(DamageEvent.new(
		attack_id,
		self,
		_scale_outgoing_damage(
			projectile_damage * projectile_damage_multiplier * aura_damage_multiplier
		),
		damage_type,
		target.global_position,
		global_position.direction_to(target.global_position),
		impulse
	)
	)


func _fire_spread_projectiles(extra_count: int) -> void:
	if projectile_pool == null or target == null:
		_release_extra_projectile_reservations()
		return
	for shot_index: int in range(extra_count):
		if _extra_projectile_reservations.is_empty():
			return
		var reservation_id: int = _extra_projectile_reservations.pop_front()
		var offset: float = (float(shot_index) - float(extra_count - 1) * 0.5) * 95.0
		var destination: Vector2 = target.global_position + Vector2(offset, 30.0)
		projectile_pool.acquire_reserved(
			reservation_id,
			telegraph_origin(),
			telegraph_origin().direction_to(destination),
			projectile_speed * (0.92 + float(shot_index) * 0.06),
			_scale_outgoing_damage(
				projectile_damage
				* 0.72
				* projectile_damage_multiplier
				* aura_damage_multiplier
			),
			self,
			projectile_target_mask,
			projectile_kind,
			ProjectileVisualCatalog.ENEMY_ROCKET_SALVO
		)


func cancel_telegraph() -> void:
	_release_extra_projectile_reservations()
	super.cancel_telegraph()
	if not _attack_vfx_id.is_empty():
		_reset_presentation_sprites()


func deactivate() -> void:
	_reset_presentation_sprites()
	super.deactivate()


func _reserve_extra_projectiles(count: int) -> bool:
	_release_extra_projectile_reservations()
	for reservation_index: int in range(count):
		var reservation_id: int = projectile_pool.reserve(projectile_kind)
		if reservation_id == 0:
			_release_extra_projectile_reservations()
			return false
		_extra_projectile_reservations.append(reservation_id)
	return true


func _release_extra_projectile_reservations() -> void:
	if projectile_pool != null:
		for reservation_id: int in _extra_projectile_reservations:
			projectile_pool.cancel_reservation(reservation_id)
	_extra_projectile_reservations.clear()


func _try_spawn_reinforcement() -> bool:
	return _try_spawn_reinforcements(1) > 0


func _try_spawn_reinforcements(requested: int) -> int:
	if encounter_runtime == null:
		return 0
	var spawn_limit: int = EnemySpawnTuning.scaled_count(
		int(profile.get("spawn_limit", 0))
	)
	if _spawned_children >= spawn_limit:
		return 0
	var spawn_kind: StringName = StringName(profile.get("spawn_kind", &""))
	if spawn_kind.is_empty():
		return 0
	var available: int = encounter_runtime.available_count(spawn_kind)
	var deploy_count: int = mini(requested, mini(spawn_limit - _spawned_children, available))
	var deployed: int = 0
	for child_index: int in range(deploy_count):
		var spawn_position: Vector2 = global_position + Vector2(
			-float(facing) * (120.0 + float(child_index) * 78.0),
			35.0 if airborne else 0.0
		)
		var spawned: EnemyActor2D = encounter_runtime.acquire(spawn_kind, spawn_position)
		if spawned == null:
			break
		deployed += 1
	_spawned_children += deployed
	return deployed


func _repair_nearest_ally() -> EnemyActor2D:
	if encounter_runtime == null:
		return null
	var best: EnemyActor2D
	var best_distance: float = SUPPORT_RADIUS
	for actor: EnemyActor2D in encounter_runtime.all_actors():
		if (
			actor == self
			or not actor.active
			or actor.dead
			or actor.has_meta(&"enemy_boss_id")
			or actor.current_health >= actor.max_health
		):
			continue
		var distance: float = global_position.distance_to(actor.global_position)
		if distance < best_distance:
			best = actor
			best_distance = distance
	if best != null:
		best.current_health = minf(best.current_health + 22.0, best.max_health)
		if best.visual != null and _attack_vfx_id.is_empty():
			best.visual.modulate = Color("9bffd1")
			var tween: Tween = best.create_tween()
			tween.tween_property(best.visual, "modulate", Color.WHITE, 0.2)
	return best


func _create_presentation_sprites() -> void:
	if not _presentation_sprites.is_empty():
		return
	for index: int in range(PRESENTATION_SPRITE_COUNT):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "EmissionPresentation%02d" % index
		sprite.z_index = 3
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.visible = false
		add_child(sprite)
		_presentation_sprites.append(sprite)


func _reset_presentation_sprites() -> void:
	_presentation_remaining = 0.0
	for sprite: Sprite2D in _presentation_sprites:
		sprite.visible = false
		sprite.texture = null
		sprite.region_enabled = false
		sprite.region_rect = Rect2()
		sprite.position = Vector2.ZERO
		sprite.rotation = 0.0
		sprite.scale = Vector2.ONE
		sprite.flip_h = false
		sprite.modulate = Color.WHITE


func _configure_presentation_sprite(
	index: int,
	texture: Texture2D,
	display_size: Vector2,
	local_position: Vector2,
	region: Rect2 = Rect2()
) -> Sprite2D:
	var sprite: Sprite2D = _presentation_sprites[index]
	sprite.texture = texture
	sprite.region_enabled = region.size != Vector2.ZERO
	sprite.region_rect = region
	var source_size: Vector2 = region.size if sprite.region_enabled else texture.get_size()
	sprite.scale = display_size / source_size
	sprite.position = local_position
	sprite.rotation = 0.0
	sprite.flip_h = false
	sprite.modulate = Color.WHITE
	sprite.visible = true
	return sprite


func _show_world_completion(
	texture: Texture2D,
	world_position: Vector2,
	display_size: Vector2,
	duration: float
) -> void:
	_reset_presentation_sprites()
	_configure_presentation_sprite(
		0,
		texture,
		display_size,
		to_local(world_position)
	)
	_presentation_remaining = duration


func _authored_attack_phase() -> Dictionary:
	if _attack_vfx_id.is_empty():
		return {}
	var attack_phase: Dictionary = EnemyAttackVfxCatalog.phase_spec(
		_attack_vfx_id,
		&"attack"
	)
	if attack_phase.is_empty():
		return {}
	var texture: Texture2D = attack_phase.get("texture") as Texture2D
	var display_size: Vector2 = attack_phase.get("display_size", Vector2.ZERO) as Vector2
	var region: Rect2i = attack_phase.get("region", Rect2i()) as Rect2i
	if texture == null or display_size.x <= 0.0 or display_size.y <= 0.0:
		return {}
	if region.size.x <= 0 or region.size.y <= 0:
		return {}
	var texture_size: Vector2i = Vector2i(texture.get_size())
	if (
		region.position.x < 0
		or region.position.y < 0
		or region.end.x > texture_size.x
		or region.end.y > texture_size.y
	):
		return {}
	return attack_phase


func _show_district_attack_anticipation(attack_phase: Dictionary = {}) -> void:
	if attack_phase.is_empty():
		return
	_reset_presentation_sprites()
	var attack_offset: Vector2 = to_local(telegraph_origin())
	var attack_sprite: Sprite2D = _configure_presentation_sprite(
		0,
		attack_phase.texture as Texture2D,
		attack_phase.display_size as Vector2,
		attack_offset,
		Rect2(attack_phase.region as Rect2i)
	)
	attack_sprite.flip_h = facing < 0
	_center_presentation_visible_content(attack_sprite, attack_offset, attack_phase)
	if not EnemyAttackVfxCatalog.is_projectile_delivery(_attack_vfx_id):
		var payload_phase: Dictionary = EnemyAttackVfxCatalog.phase_spec(
			_attack_vfx_id,
			&"projectile"
		)
		var payload_offset: Vector2 = (
			attack_offset + Vector2(float(facing) * 36.0, 0.0)
		)
		var payload_sprite: Sprite2D = _configure_presentation_sprite(
			1,
			payload_phase.texture as Texture2D,
			payload_phase.display_size as Vector2,
			payload_offset,
			Rect2(payload_phase.region as Rect2i)
		)
		payload_sprite.flip_h = facing < 0
		_center_presentation_visible_content(payload_sprite, payload_offset, payload_phase)
	_presentation_remaining = maxf(
		anticipation_duration * telegraph_multiplier,
		MINIMUM_TELEGRAPH_SECONDS
	)


func _show_district_completion(world_position: Vector2) -> void:
	if _attack_vfx_id.is_empty():
		return
	var completion_phase: Dictionary = EnemyAttackVfxCatalog.phase_spec(
		_attack_vfx_id,
		&"impact"
	)
	if completion_phase.is_empty():
		return
	_reset_presentation_sprites()
	var completion: Sprite2D = _configure_presentation_sprite(
		0,
		completion_phase.texture as Texture2D,
		completion_phase.display_size as Vector2,
		to_local(world_position),
		Rect2(completion_phase.region as Rect2i)
	)
	completion.flip_h = facing < 0
	_center_presentation_visible_content(
		completion,
		to_local(world_position),
		completion_phase
	)
	_presentation_remaining = EnemyAttackVfxCatalog.HOSTILE_IMPACT_DURATION


func _center_presentation_visible_content(
	sprite: Sprite2D,
	local_anchor: Vector2,
	phase: Dictionary
) -> void:
	var source_offset: Vector2 = phase.get(
		"visible_center_offset",
		Vector2.ZERO
	) as Vector2
	if sprite.flip_h:
		source_offset.x = -source_offset.x
	if sprite.flip_v:
		source_offset.y = -source_offset.y
	sprite.position = local_anchor - source_offset * sprite.scale


func _presentation_visible_center_world(
	sprite: Sprite2D,
	phase: Dictionary
) -> Vector2:
	var source_offset: Vector2 = phase.get(
		"visible_center_offset",
		Vector2.ZERO
	) as Vector2
	if sprite.flip_h:
		source_offset.x = -source_offset.x
	if sprite.flip_v:
		source_offset.y = -source_offset.y
	return sprite.to_global(source_offset)


func _show_lance_completion() -> void:
	_reset_presentation_sprites()
	var lance: Sprite2D = _configure_presentation_sprite(
		0,
		NEMESIS_MELEE_LANCE,
		Vector2(245.0, 61.0),
		Vector2(float(facing) * 122.5, -18.0)
	)
	lance.flip_h = facing < 0
	_presentation_remaining = 0.20


func _show_choir_contact(style: StringName, committed_hit: bool) -> void:
	_reset_presentation_sprites()
	var texture: Texture2D = CHOIR_CONTACT_BRACE
	var display_size: Vector2 = Vector2(300.0, 120.0)
	if style == &"marked_leap":
		texture = CHOIR_CONTACT_LEAP
		display_size = Vector2(360.0, 175.0)
	elif style == &"drop_lunge":
		texture = CHOIR_CONTACT_DROP
		display_size = Vector2(140.0, 230.0)
	var contact: Sprite2D = _configure_presentation_sprite(
		0,
		texture,
		display_size,
		to_local((global_position + target.global_position) * 0.5)
	)
	contact.flip_h = facing < 0 and style != &"drop_lunge"
	if committed_hit:
		var footprint_size: Vector2 = (
			Vector2(220.0, 84.0)
			if style == &"drop_lunge"
			else Vector2(150.0, 64.0)
		)
		_configure_presentation_sprite(
			1,
			CHOIR_CONTACT_FOOTPRINT,
			footprint_size,
			to_local(target.global_position + Vector2(0.0, 38.0))
		)
	_presentation_remaining = 0.24


func _show_conventional_deployment(successful_count: int) -> void:
	_reset_presentation_sprites()
	var carrier_region: Rect2
	var carrier_size: Vector2
	var payload_region: Rect2
	var payload_size: Vector2
	if attack_style == &"deploy":
		carrier_region = MULE_RAMP_OPEN_REGION
		carrier_size = Vector2(150.0, 112.5)
		payload_region = SOLDIER_DISPATCH_REGION
		payload_size = Vector2(54.0, 96.0)
	else:
		carrier_region = HIVE_BAY_OPEN_REGION
		carrier_size = Vector2(145.0, 80.0)
		payload_region = HOUND_LAUNCH_POD_REGION
		payload_size = Vector2(110.0, 48.0)
	_configure_presentation_sprite(
		0,
		CONVENTIONAL_DEPLOYMENT,
		carrier_size,
		Vector2(0.0, 18.0),
		carrier_region
	)
	for index: int in range(mini(successful_count, 2)):
		var payload: Sprite2D = _configure_presentation_sprite(
			index + 1,
			CONVENTIONAL_DEPLOYMENT,
			payload_size,
			Vector2(-float(facing) * (70.0 + float(index) * 52.0), 42.0),
			payload_region
		)
		payload.flip_h = facing < 0
	_presentation_remaining = 0.30


func _show_seraph_deployment(successful_count: int) -> void:
	_reset_presentation_sprites()
	_configure_presentation_sprite(
		0,
		CHOIR_INCUBATION_PAYLOAD,
		Vector2(112.0, 48.0),
		Vector2(0.0, 30.0),
		SERAPH_BAY_REGION
	)
	# Each authored capsule represents one paired clutch; mechanics remain the current x2 count.
	var clutch_count: int = mini(ceili(float(successful_count) / 2.0), 3)
	for index: int in range(clutch_count):
		_configure_presentation_sprite(
			index + 1,
			CHOIR_INCUBATION_PAYLOAD,
			Vector2(56.0, 88.0),
			Vector2((float(index) - float(clutch_count - 1) * 0.5) * 62.0, 88.0),
			SERAPH_CLUTCH_REGIONS[index % SERAPH_CLUTCH_REGIONS.size()]
		)
	_presentation_remaining = 0.36


func _update_completion_presentation(delta: float) -> void:
	if _presentation_remaining <= 0.0:
		return
	_presentation_remaining = maxf(_presentation_remaining - delta, 0.0)
	var alpha: float = clampf(_presentation_remaining / 0.12, 0.0, 1.0)
	for sprite: Sprite2D in _presentation_sprites:
		if sprite.visible:
			sprite.modulate.a = alpha
	if is_zero_approx(_presentation_remaining):
		_reset_presentation_sprites()


func _animate_visual(delta: float) -> void:
	if visual == null:
		return
	var speed_ratio: float = clampf(velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0)
	_animation_phase = fmod(_animation_phase + delta * TAU * lerpf(1.3, 4.2, speed_ratio), TAU)
	_attack_kick = maxf(_attack_kick - delta * 2.8, 0.0)
	var attack_envelope: float = sin((1.0 - _attack_kick) * PI) if _attack_kick > 0.0 else 0.0
	var offset: Vector2 = Vector2.ZERO
	var scale_factor: Vector2 = Vector2.ONE
	var rotation_value: float = 0.0
	match movement_style:
		&"drone_hover":
			offset.y = sin(_animation_phase) * 6.0
			rotation_value = sin(_animation_phase * 0.7) * 0.025
		&"shield_march":
			offset.y = -absf(sin(_animation_phase)) * 3.0 * speed_ratio
			rotation_value = -0.035 * float(facing) * speed_ratio
		&"wheel_sprint":
			offset.y = sin(_animation_phase * 2.0) * 2.2 * speed_ratio
			rotation_value = -velocity.x / maxf(move_speed, 1.0) * 0.018
		&"heavy_march", &"utility_march", &"team_shuffle":
			offset.y = -absf(sin(_animation_phase)) * 4.0 * speed_ratio
			rotation_value = sin(_animation_phase) * 0.018 * float(facing)
		&"hunter_lunge":
			offset.y = sin(_animation_phase) * 8.0
			rotation_value = velocity.x / maxf(move_speed, 1.0) * 0.06
		&"apc_roll", &"tracked_heavy", &"capacitor_roll":
			offset.y = sin(_animation_phase * 2.0) * 1.4 * speed_ratio
			rotation_value = sin(_animation_phase) * 0.009 * speed_ratio
		&"antenna_sway", &"dish_pulse":
			offset.y = sin(_animation_phase) * 1.5
			rotation_value = sin(_animation_phase * 0.5) * 0.012
		&"bomber_bank", &"vtol_strafe":
			offset.y = sin(_animation_phase) * 5.0
			rotation_value = clampf(velocity.x / maxf(move_speed, 1.0), -1.0, 1.0) * 0.075
		&"flame_lurch":
			offset.y = -absf(sin(_animation_phase)) * 2.0 * speed_ratio
			rotation_value = -0.022 * float(facing) * speed_ratio
		&"carrier_hover":
			offset.y = sin(_animation_phase * 0.65) * 7.0
			rotation_value = sin(_animation_phase * 0.4) * 0.018
		&"breacher_sprint":
			offset.y = -absf(sin(_animation_phase)) * 7.0 * speed_ratio
			rotation_value = -0.045 * float(facing) * speed_ratio
		&"graft_circle", &"crawler_climb":
			offset.y = sin(_animation_phase * 1.7) * 5.0 * speed_ratio
			rotation_value = sin(_animation_phase) * 0.055 * float(facing)
		&"siren_hover":
			offset.y = sin(_animation_phase * 0.55) * 10.0
			rotation_value = sin(_animation_phase * 0.35) * 0.035
		&"seraph_hover":
			offset.y = sin(_animation_phase * 0.42) * 8.0
			rotation_value = sin(_animation_phase * 0.28) * 0.024
		&"pale_engine_stride":
			offset.y = -absf(sin(_animation_phase)) * 5.0 * speed_ratio
			rotation_value = sin(_animation_phase) * 0.018 * float(facing)
		&"walker_stride":
			offset.y = -absf(sin(_animation_phase)) * 6.0 * speed_ratio
			rotation_value = sin(_animation_phase) * 0.026 * float(facing)
		&"mech_stride":
			offset.y = -absf(sin(_animation_phase)) * 8.0 * speed_ratio
			rotation_value = -0.04 * float(facing) * speed_ratio
		&"landship_rumble":
			offset = Vector2(sin(_animation_phase * 2.0), cos(_animation_phase * 3.0)) * 1.5
	if attack_envelope > 0.0:
		match attack_style:
			&"scan", &"jammer_pulse", &"shield_pulse", &"choir_ring":
				scale_factor = Vector2.ONE * (1.0 + attack_envelope * 0.055)
			&"lob", &"mortar_recoil", &"missile_launch", &"pod_salvo", \
			&"wing_launch", &"bomb_drop", &"rail_recoil", &"fortress_barrage":
				offset.x -= float(facing) * attack_envelope * 12.0
				rotation_value -= float(facing) * attack_envelope * 0.045
			&"repair", &"deploy", &"drone_launch", &"incubation_drop":
				offset.y += attack_envelope * 5.0
				scale_factor = Vector2(1.0 + attack_envelope * 0.03, 1.0 - attack_envelope * 0.03)
			&"lance_thrust", &"flame_blast", &"autocannon", \
			&"shock_brace", &"marked_leap", &"drop_lunge":
				offset.x += float(facing) * attack_envelope * 14.0
				rotation_value += float(facing) * attack_envelope * 0.04
			_:
				offset.x -= float(facing) * attack_envelope * 5.0
	if EnemyArchetypeCatalog.is_human_enemy(archetype_id):
		scale_factor.y = 1.0
	visual.position = _visual_rest_position + offset
	visual.scale = _visual_rest_scale * scale_factor
	visual.rotation = rotation_value


func _reset_archetype_state() -> void:
	_release_extra_projectile_reservations()
	_reset_presentation_sprites()
	state = State.APPROACH
	_cooldown = 0.35
	_state_time = 0.0
	_animation_phase = 0.0
	_attack_kick = 0.0
	_pass_side = facing
	_spawned_children = 0
	_attack_sequence = 0
	ablative_armor = maximum_ablative_armor
	if visual != null:
		visual.position = _visual_rest_position
		visual.scale = _visual_rest_scale
		visual.rotation = 0.0
		visual.skew = 0.0
		visual.modulate = Color.WHITE
	set_meta(&"enemy_archetype", archetype_id)
	set_meta(&"enemy_canonical_archetype", base_archetype_id)
	set_meta(&"enemy_family", family)


func reset_debug_snapshot() -> Dictionary:
	return {
		"archetype_id": archetype_id,
		"base_archetype_id": base_archetype_id,
		"family": family,
		"state": state,
		"cooldown": _cooldown,
		"state_time": _state_time,
		"animation_phase": _animation_phase,
		"attack_kick": _attack_kick,
		"pass_side": _pass_side,
		"spawned_children": _spawned_children,
		"attack_sequence": _attack_sequence,
		"ablative_armor": ablative_armor,
		"extra_projectile_reservations": _extra_projectile_reservations.size(),
		"attack_vfx_id": _attack_vfx_id,
		"is_telegraphing": is_telegraphing(),
		"visual_position": visual.position if visual != null else Vector2.ZERO,
		"visual_scale": visual.scale if visual != null else Vector2.ONE,
		"visual_rotation": visual.rotation if visual != null else 0.0,
		"visual_modulate": visual.modulate if visual != null else Color.WHITE,
	}
