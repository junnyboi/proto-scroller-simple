extends GutTest

const COMPACT_PLAYER_SCENE: PackedScene = preload(
	"res://scenes/template/combat/compact_player.tscn"
)
const COMPACT_ENEMY_SCENE: PackedScene = preload(
	"res://scenes/template/combat/compact_enemy.tscn"
)


func test_stage_one_has_three_valid_waves_and_two_allowlisted_enemies() -> void:
	var definition: StageDefinition = preload(
		"res://resources/template/stages/stage_01.tres"
	)
	assert_not_null(definition)
	assert_true(definition.is_valid(), ", ".join(definition.validation_errors()))
	assert_eq(definition.waves.size(), 3)
	assert_eq(definition.allowed_enemy_ids, PackedStringArray(["soldier", "tank"]))
	var director: CompactWaveDirector = CompactWaveDirector.new()
	assert_true(director.definition(&"soldier").is_valid())
	assert_true(director.definition(&"tank").is_valid())
	assert_null(director.definition(&"unknown"))
	director.free()


func test_compact_player_charge_damage_and_dodge_invulnerability() -> void:
	var player: CompactPlayer = COMPACT_PLAYER_SCENE.instantiate() as CompactPlayer
	add_child_autofree(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	var attacks: Array[Dictionary] = []
	player.attack_released.connect(func(
		_origin: Vector2,
		radius: float,
		damage: float,
		facing: int,
		charge_ratio: float
	) -> void:
		attacks.append({
			"radius": radius,
			"damage": damage,
			"facing": facing,
			"charge_ratio": charge_ratio,
		})
	)
	assert_true(player.begin_attack_charge())
	player.physics_step(0.0, player.full_charge_seconds)
	assert_true(player.release_attack_charge())
	assert_eq(attacks.size(), 1)
	assert_almost_eq(float(attacks[0]["damage"]), player.charged_attack_damage, 0.01)
	assert_almost_eq(float(attacks[0]["radius"]), player.charged_attack_radius, 0.01)
	player.physics_step(0.0, player.attack_cooldown_seconds)
	assert_true(player.request_dodge(-1))
	assert_false(player.receive_damage(20.0))
	player.physics_step(0.0, player.dodge_invulnerability_seconds + 0.01)
	assert_true(player.receive_damage(20.0))
	assert_almost_eq(player.current_health, player.max_health - 20.0, 0.01)


func test_parameterized_enemy_moves_and_requests_bounded_damage() -> void:
	var player: CompactPlayer = COMPACT_PLAYER_SCENE.instantiate() as CompactPlayer
	var enemy: CompactEnemy = COMPACT_ENEMY_SCENE.instantiate() as CompactEnemy
	var tank_enemy: CompactEnemy = COMPACT_ENEMY_SCENE.instantiate() as CompactEnemy
	add_child_autofree(player)
	add_child_autofree(enemy)
	add_child_autofree(tank_enemy)
	await get_tree().process_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	var director: CompactWaveDirector = CompactWaveDirector.new()
	var soldier: CompactEnemyDefinition = director.definition(&"soldier")
	var tank: CompactEnemyDefinition = director.definition(&"tank")
	assert_gt(soldier.move_speed, tank.move_speed)
	assert_lt(soldier.max_health, tank.max_health)
	assert_true(enemy.configure(soldier))
	assert_true(tank_enemy.configure(tank))
	assert_not_same(enemy.collision_shape.shape, tank_enemy.collision_shape.shape)
	player.global_position = Vector2(200.0, 619.0)
	assert_true(enemy.activate(soldier, player, Vector2(600.0, 619.0)))
	enemy.set_physics_process(false)
	var initial_x: float = enemy.global_position.x
	enemy.simulation_step(0.25)
	assert_lt(enemy.global_position.x, initial_x)
	var requested_damage: Array[float] = []
	enemy.damage_requested.connect(func(amount: float) -> void: requested_damage.append(amount))
	enemy.global_position.x = player.global_position.x + soldier.attack_range - 1.0
	enemy.attack_cooldown_remaining = 0.0
	enemy.simulation_step(0.01)
	assert_eq(requested_damage, [soldier.contact_damage])
	director.free()


func test_stage_completes_three_waves_without_post_warm_node_growth() -> void:
	var runtime: TemplateMain = preload(
		"res://scenes/template/template_main.tscn"
	).instantiate() as TemplateMain
	add_child_autofree(runtime)
	await get_tree().process_frame
	runtime.start_stage()
	await get_tree().process_frame
	var stage: TemplateStage = runtime.current_stage
	stage.wave_director.set_physics_process(false)
	var warm_node_count: int = _subtree_node_count(stage)
	assert_eq(stage.wave_director.pool_node_count(), 8)
	assert_eq(stage.effect_pool.slot_count(), 8)
	for step: int in range(256):
		stage.wave_director.simulation_step(0.25)
		for enemy: CompactEnemy in stage.wave_director.active_enemies():
			enemy.set_physics_process(false)
			enemy.receive_damage(9999.0)
		if stage.lifecycle.finalized:
			break
	assert_true(stage.lifecycle.finalized)
	assert_true(stage.lifecycle.frozen_summary.completed)
	assert_eq(stage.lifecycle.frozen_summary.waves_cleared, 3)
	assert_gt(stage.lifecycle.frozen_summary.score, 0)
	assert_eq(stage.wave_director.pool_exhaustion_count, 0)
	assert_eq(_subtree_node_count(stage), warm_node_count)
	assert_true(stage.debrief.visible)


func test_player_defeat_finalizes_once_and_stops_the_wave_director() -> void:
	var runtime: TemplateMain = preload(
		"res://scenes/template/template_main.tscn"
	).instantiate() as TemplateMain
	add_child_autofree(runtime)
	await get_tree().process_frame
	runtime.start_stage()
	await get_tree().process_frame
	var stage: TemplateStage = runtime.current_stage
	assert_true(stage.player.receive_damage(stage.player.max_health))
	assert_true(stage.lifecycle.finalized)
	assert_false(stage.lifecycle.frozen_summary.completed)
	assert_false(stage.player.receive_damage(1.0))
	assert_false(stage.lifecycle.finish_victory(999, 3))
	assert_false(stage.wave_director.started)


func test_retained_destructible_and_fixed_effect_pool_are_reusable() -> void:
	var runtime: TemplateMain = preload(
		"res://scenes/template/template_main.tscn"
	).instantiate() as TemplateMain
	add_child_autofree(runtime)
	await get_tree().process_frame
	runtime.start_stage()
	await get_tree().process_frame
	var stage: TemplateStage = runtime.current_stage
	var effect_children: int = stage.effect_pool.get_child_count()
	assert_true(stage.destructible.receive_damage(stage.destructible.max_health))
	assert_true(stage.destructible.is_destroyed)
	assert_eq(stage.score, stage.destructible.score_value)
	for index: int in range(24):
		stage.effect_pool.spawn(Vector2(400.0 + index, 500.0), 1, 1.0)
	assert_eq(stage.effect_pool.get_child_count(), effect_children)
	assert_eq(stage.effect_pool.slot_count(), 8)
	assert_lte(stage.effect_pool.active_count(), 8)
	assert_gt(stage.camera_impulse.impulse_strength, 0.0)


func _subtree_node_count(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _subtree_node_count(child)
	return count
