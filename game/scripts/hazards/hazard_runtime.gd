class_name HazardRuntime
extends Node2D

signal hazard_activated(hazard_id: StringName, world_position: Vector2)
signal hazard_triggered(hazard_id: StringName, world_position: Vector2)
signal hazard_released(hazard_id: StringName)
signal hazard_chained(source_id: StringName, target_id: StringName, causal_depth: int)

const HAZARD_SCRIPT: Script = preload(
	"res://scripts/hazards/environmental_hazard_2d.gd"
)
const VFX_SCRIPT: Script = preload("res://scripts/hazards/hazard_vfx_pool.gd")
const AUDIO_SCRIPT: Script = preload("res://scripts/hazards/hazard_audio_pool.gd")
const BASE_ATTACK_ID: int = 2_400_000
const MAX_CHAIN_TARGETS_PER_IMPACT: int = 2

var dependencies: UrbanSiegeDependencies
var actors: Array[EnvironmentalHazard2D] = []
var vfx_pool: HazardVfxPool
var audio_pool: HazardAudioPool
var post_warm_creation_count: int = 0
var activation_count: int = 0
var impact_count: int = 0
var recycle_count: int = 0
var activation_denial_count: int = 0
var chain_trigger_count: int = 0
var last_hazard_id: StringName = &""
var last_chain_source: StringName = &""
var last_chain_target: StringName = &""
var _next_attack_id: int = BASE_ATTACK_ID


func setup(p_dependencies: UrbanSiegeDependencies) -> void:
	dependencies = p_dependencies


func _ready() -> void:
	vfx_pool = VFX_SCRIPT.new() as HazardVfxPool
	vfx_pool.name = "HazardVfxPool"
	add_child(vfx_pool)
	audio_pool = AUDIO_SCRIPT.new() as HazardAudioPool
	audio_pool.name = "HazardAudioPool"
	add_child(audio_pool)
	for hazard_id: StringName in EnvironmentalHazardCatalog.ACTIVE_IDS:
		var actor: EnvironmentalHazard2D = _build_actor(hazard_id)
		add_child(actor)
		actor.reset_hazard()
		actors.append(actor)


func activate(
	hazard_id: StringName,
	world_position: Vector2,
	facing: int = 1,
	auto_trigger: bool = true
) -> EnvironmentalHazard2D:
	if not EnvironmentalHazardCatalog.ACTIVE_IDS.has(hazard_id):
		return null
	var actor: EnvironmentalHazard2D = actor_for(hazard_id)
	if actor == null:
		post_warm_creation_count += 1
		return null
	if actor.active:
		activation_denial_count += 1
		return null
	if active_count() >= RuntimeBudget.ACTIVE_HAZARDS:
		activation_denial_count += 1
		return null
	var position_value: Vector2 = world_position
	position_value.y = CitySlice.LAND_VISUAL_BASELINE_Y
	var tuned_profile: Dictionary = EnvironmentalHazardCatalog.profile(hazard_id).duplicate(true)
	tuned_profile.telegraph = float(tuned_profile.telegraph) * float(
		RuntimeTweakAccess.next_spawn_value(
			&"environment.hazard.telegraph_multiplier", 1.0
		)
	)
	tuned_profile.enemy_damage = float(tuned_profile.enemy_damage) * float(
		RuntimeTweakAccess.next_spawn_value(
			&"environment.hazard.damage_multiplier", 1.0
		)
	)
	tuned_profile.radius = float(tuned_profile.radius) * float(
		RuntimeTweakAccess.next_spawn_value(
			&"environment.hazard.radius_multiplier", 1.0
		)
	)
	tuned_profile.impulse = float(tuned_profile.impulse) * float(
		RuntimeTweakAccess.next_spawn_value(
			&"environment.hazard.impulse_multiplier", 1.0
		)
	)
	actor.activate(
		hazard_id,
		tuned_profile,
		position_value,
		facing,
		auto_trigger
	)
	activation_count += 1
	last_hazard_id = hazard_id
	hazard_activated.emit(hazard_id, position_value)
	return actor


func resolve_telegraph(hazard: EnvironmentalHazard2D) -> void:
	if hazard == null or not hazard.active or audio_pool == null:
		return
	audio_pool.play_warning(hazard.hazard_id, hazard.impact_origin())


func resolve_impact(
	hazard: EnvironmentalHazard2D,
	trigger_event: DamageEvent,
	primary: bool
) -> void:
	if hazard == null or not hazard.active or dependencies == null:
		return
	var profile: Dictionary = hazard.profile
	var attack_id: int = _next_attack_id
	_next_attack_id += 1
	var root_attack_id: int = attack_id
	var causal_depth: int = 0
	if trigger_event != null:
		root_attack_id = trigger_event.root_attack_id
		causal_depth = mini(trigger_event.causal_depth + 1, DamageEvent.MAX_CAUSAL_DEPTH)
	var options: DamageQueryOptions = DamageQueryOptions.new()
	options.root_attack_id = root_attack_id
	options.causal_depth = causal_depth
	options.effect_flags = DamageEvent.FLAG_HAZARD
	options.result_limit = 32
	options.structural_limit = 1
	options.debris_limit = 4
	options.damage_type = StringName(profile.damage_type)
	options.player_damage_scale = float(profile.player_scale)
	var direction: Vector2 = _impact_direction(hazard)
	dependencies.destruction_director.queue_explosion(
		hazard.impact_origin(),
		float(profile.radius),
		float(profile.enemy_damage),
		float(profile.impulse),
		attack_id,
		hazard,
		options
	)
	vfx_pool.play(hazard.hazard_id, hazard.impact_origin(), direction)
	if audio_pool != null:
		audio_pool.play_impact(hazard.hazard_id, hazard.impact_origin(), primary)
	_apply_screen_shake(hazard, primary)
	impact_count += 1
	if primary:
		hazard_triggered.emit(hazard.hazard_id, hazard.impact_origin())
		_propagate_chain(hazard, attack_id, root_attack_id, causal_depth)


func release(hazard: EnvironmentalHazard2D) -> void:
	if hazard == null or not hazard.active:
		return
	var released_id: StringName = hazard.hazard_id
	hazard.reset_hazard()
	hazard_released.emit(released_id)


func release_all() -> void:
	for actor: EnvironmentalHazard2D in actors:
		actor.reset_hazard()
	if vfx_pool != null:
		vfx_pool.reset_all()
	if audio_pool != null:
		audio_pool.reset_all()
	if dependencies != null and dependencies.destruction_director != null:
		dependencies.destruction_director.cancel_effect_flags(DamageEvent.FLAG_HAZARD)
	chain_trigger_count = 0
	last_chain_source = &""
	last_chain_target = &""


func set_paused(paused: bool) -> void:
	if audio_pool != null:
		audio_pool.set_paused(paused)


func actor_for(hazard_id: StringName) -> EnvironmentalHazard2D:
	for actor: EnvironmentalHazard2D in actors:
		if StringName(actor.get_meta(&"pool_hazard_id", &"")) == hazard_id:
			return actor
	return null


func active_count() -> int:
	var count: int = 0
	for actor: EnvironmentalHazard2D in actors:
		count += 1 if actor.active else 0
	return count


func total_count() -> int:
	return actors.size()


func _build_actor(hazard_id: StringName) -> EnvironmentalHazard2D:
	var actor: EnvironmentalHazard2D = HAZARD_SCRIPT.new() as EnvironmentalHazard2D
	actor.name = String(hazard_id).to_pascal_case()
	actor.runtime = self
	actor.z_index = 26
	actor.set_meta(&"pool_hazard_id", hazard_id)
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	actor.add_child(visual)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = RectangleShape2D.new()
	actor.add_child(collision)
	actor.finished.connect(release)
	return actor


func _impact_direction(hazard: EnvironmentalHazard2D) -> Vector2:
	var result: Vector2 = Vector2(float(hazard.facing), -0.28)
	match StringName(hazard.profile.behavior):
		&"steam":
			result = Vector2(float(hazard.facing), -0.55)
		&"electric":
			result = Vector2(float(hazard.facing), -0.10)
		&"ramp":
			result = Vector2(float(hazard.facing), -0.82)
		&"drop", &"shear":
			result = Vector2(float(hazard.facing) * 0.18, 1.0)
		&"fireline":
			result = Vector2(float(hazard.facing), -0.16)
		&"vent":
			result = Vector2(float(hazard.facing) * 0.12, -1.0)
		&"metro_crash":
			result = Vector2(float(hazard.facing), -0.34)
		&"flood":
			result = Vector2(float(hazard.facing) * 0.10, -0.22)
		&"skybridge":
			result = Vector2(float(hazard.facing) * 0.10, 1.0)
		&"convoy":
			result = Vector2(float(hazard.facing), -0.64)
	return result.normalized()


func _propagate_chain(
	source: EnvironmentalHazard2D,
	attack_id: int,
	root_attack_id: int,
	causal_depth: int
) -> void:
	if causal_depth >= DamageEvent.MAX_CAUSAL_DEPTH:
		return
	var targets: Array = source.profile.get("chain_targets", []) as Array
	var chain_radius: float = float(source.profile.get("chain_radius", 0.0))
	var chained: int = 0
	for target_id_value: Variant in targets:
		var target_id: StringName = StringName(target_id_value)
		var target: EnvironmentalHazard2D = actor_for(target_id)
		if target == null or not target.active or target.state != EnvironmentalHazard2D.STATE_ARMED:
			continue
		if source.global_position.distance_to(target.global_position) > chain_radius:
			continue
		var direction: Vector2 = target.global_position - source.global_position
		var chain_event: DamageEvent = DamageEvent.new(
			attack_id,
			source,
			999.0,
			&"hazard_chain",
			target.global_position,
			direction,
			float(source.profile.impulse),
			root_attack_id,
			causal_depth,
			DamageEvent.FLAG_HAZARD
		)
		if not target.receive_damage(chain_event):
			continue
		chain_trigger_count += 1
		chained += 1
		last_chain_source = source.hazard_id
		last_chain_target = target_id
		if audio_pool != null:
			audio_pool.play_chain(
				source.hazard_id,
				target_id,
				target.global_position,
				causal_depth + 1
			)
		hazard_chained.emit(source.hazard_id, target_id, causal_depth + 1)
		if chained >= MAX_CHAIN_TARGETS_PER_IMPACT:
			break


func _apply_screen_shake(hazard: EnvironmentalHazard2D, primary: bool) -> void:
	if dependencies.city == null or dependencies.city.camera_rig == null:
		return
	var profile: Dictionary = hazard.profile
	var normalized: Vector2 = profile.shake as Vector2
	var shake_pulses: int = clampi(int(profile.shake_pulses), 1, 8)
	var impulse_scale: float = (
		16.0 + float(shake_pulses)
		if primary
		else 4.0 + float(shake_pulses) * 0.5
	)
	var impulse: Vector2 = Vector2(
		normalized.x * float(hazard.facing),
		normalized.y
	) * impulse_scale
	dependencies.city.camera_rig.add_impact_impulse(impulse)
