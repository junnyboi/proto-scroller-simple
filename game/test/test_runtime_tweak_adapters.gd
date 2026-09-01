extends GutTest

const SAVE_ROOT: String = "user://runtime_tweak_adapter_tests"
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var service: RuntimeTweakService


func before_each() -> void:
	_cleanup()
	service = RuntimeTweakService.new()
	add_child_autofree(service)
	assert_eq(
		service.setup(
			RuntimeTweakCatalog.DEFAULT_PATH,
			SAVE_ROOT + "/current.json"
		),
		PackedStringArray()
	)


func after_each() -> void:
	RuntimeTweakAccess.unbind_service()
	_cleanup()


func test_next_run_spawn_score_and_combo_adapters_share_one_snapshot() -> void:
	assert_true(bool(service.set_values({
		&"spawn.quantity_multiplier": 1,
		&"spawn.interval_scale": 1.0,
		&"progression.combo.base_grace_seconds": 4.0,
		&"progression.combo.max_multiplier": 3,
		&"progression.score.bank_base_seconds": 2.0,
		&"progression.rewards.named_boss_multiplier": 4,
	}).ok))
	service.freeze_run(101)
	assert_eq(EnemySpawnTuning.quantity_multiplier(), 1)
	assert_almost_eq(EnemySpawnTuning.interval_scale(), 1.0, 0.001)
	assert_almost_eq(RampageRewardTuning.combo_grace_seconds(), 4.0, 0.001)
	assert_almost_eq(RampageRewardTuning.pending_bank_seconds(), 2.0, 0.001)
	assert_eq(RampageRewardTuning.enemy_reward_points(100, true), 400)
	assert_eq(RampageRewardTuning.multiplier_for_progress_units(20), 3)


func test_next_attack_enemy_snapshot_is_reused_for_damage_and_projectile_lifetime() -> void:
	service.freeze_run(102)
	assert_true(bool(service.set_values({
		&"enemy.outgoing_damage_multiplier": 0.5,
		&"projectile.hostile_lifetime": 3.0,
	}).ok))
	var enemy: EnemyActor2D = EnemyActor2D.new()
	autofree(enemy)
	var captured_damage: Array[float] = []
	enemy.projectile_requested.connect(func(
		_origin: Vector2,
		_direction: Vector2,
		_speed: float,
		damage: float,
		_kind: StringName,
		_source: Node
	) -> void:
		captured_damage.append(damage)
	)
	enemy.request_projectile(Vector2.ZERO, Vector2.RIGHT, 400.0, 10.0, &"bullet")
	assert_eq(captured_damage.size(), 1)
	assert_almost_eq(captured_damage[0], 5.0, 0.001)
	assert_almost_eq(enemy.attack_projectile_lifetime(), 3.0, 0.001)
	assert_eq(service.provenance.status, RunTuningProvenance.TUNED)


func test_next_spawn_repair_pickup_normalizes_amount_and_captures_lifetime() -> void:
	service.freeze_run(103)
	assert_true(bool(service.set_values({
		&"world.repair_drop.amount": 80.0,
		&"world.repair_drop.lifetime_seconds": 20.0,
	}).ok))
	var runtime: CatalystRuntime = CatalystRuntime.new()
	add_child_autofree(runtime)
	await get_tree().process_frame
	var pickup: ChassisRepairPickup2D = runtime.spawn_repair_pickup(
		Vector2(100.0, 200.0),
		ChassisRepairPickup2D.REPAIR_AMOUNT * 3.0
	)
	assert_not_null(pickup)
	assert_almost_eq(pickup.repair_amount, 240.0, 0.001)
	assert_almost_eq(pickup.remaining_lifetime(), 20.0, 0.001)


func test_live_weather_and_sky_values_apply_without_rebuilding_fixed_pools() -> void:
	service.freeze_run(104)
	assert_true(bool(service.set_values({
		&"world.weather.density_multiplier": 0.5,
		&"world.sky.day_night_cycle_seconds": 120.0,
		&"world.sky.traffic_speed_multiplier": 1.25,
	}).ok))
	var weather: DistrictWeatherSurface = DistrictWeatherSurface.new()
	autofree(weather)
	assert_eq(weather.particle_count_for_profile(100.0, Vector2(1280.0, 720.0)), 50)
	var sky: DistrictSkyLifeRuntime = DistrictSkyLifeRuntime.new()
	add_child_autofree(sky)
	await get_tree().process_frame
	var phase_before: float = sky.time_phase
	var offset_before: float = sky._traffic_band.scroll_offset.x
	sky.advance(1.0)
	assert_almost_eq(
		fposmod(sky.time_phase - phase_before, 1.0),
		1.0 / 120.0,
		0.0001
	)
	assert_gt(sky._traffic_band.scroll_offset.x, offset_before)
	assert_eq(sky.get_child_count(), 1)


func test_facade_attack_snapshot_captures_three_values_once_for_chain_reuse() -> void:
	service.freeze_run(105)
	assert_true(bool(service.set_values({
		&"world.facade.damaged_stage_ratio": 0.75,
		&"world.facade.support_transfer_ratio": 0.6,
		&"world.facade.chain_delay_multiplier": 0.5,
	}).ok))
	var facade: StructuralBuilding2D = StructuralBuilding2D.new()
	autofree(facade)
	var event: DamageEvent = DamageEvent.new(
		9001, null, 10.0, &"jab_cross", Vector2.ZERO, Vector2.RIGHT, 1.0, 9001
	)
	var snapshot: Dictionary = facade.tuning_snapshot_for_event(event)
	assert_almost_eq(float(snapshot.damaged_stage_ratio), 0.75, 0.001)
	assert_almost_eq(float(snapshot.support_transfer_ratio), 0.6, 0.001)
	assert_almost_eq(float(snapshot.chain_delay_multiplier), 0.5, 0.001)
	service.set_values({
		&"world.facade.damaged_stage_ratio": 0.65,
		&"world.facade.support_transfer_ratio": 0.5,
		&"world.facade.chain_delay_multiplier": 1.0,
	})
	var generated_chain: DamageEvent = DamageEvent.new(
		0, null, 10.0, &"floor_chain", Vector2.ZERO
	)
	var reused: Dictionary = facade.tuning_snapshot_for_event(generated_chain)
	assert_eq(reused, snapshot)


func test_live_visual_tint_and_size_adapters_preserve_gameplay_geometry() -> void:
	assert_true(bool(service.set_values({
		&"player.visual.scale": 1.2,
		&"player.visual.tint": "#62f5df",
		&"enemy.visual.scale": 1.4,
		&"enemy.visual.tint": "#ff8040",
		&"interface.hud.scale": 1.15,
		&"interface.hud.tint": "#80a0ff",
	}).ok))
	service.freeze_run(106)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame

	var presenter: RobotAnimationPresenter = city.robot.get_node(
		^"RobotAnimationPresenter"
	) as RobotAnimationPresenter
	var player_sprite: AnimatedSprite2D = presenter.sprite
	presenter._apply_live_visual_tuning()
	assert_eq(player_sprite.self_modulate, Color("62f5df"))
	assert_eq(player_sprite.scale, presenter._authored_sprite_scale * 1.2)
	var body_shape: CapsuleShape2D = (
		city.robot.get_node(^"BodyCollision") as CollisionShape2D
	).shape as CapsuleShape2D
	assert_almost_eq(body_shape.height, 205.0, 0.001)

	city.encounter_runtime._process(0.0)
	var enemy: EnemyActor2D = city.encounter_runtime.soldiers[0]
	assert_eq(enemy.visual.self_modulate, Color("ff8040"))
	assert_eq(enemy._visual_rest_scale, enemy._visual_authored_scale * 1.4)
	var enemy_shape: RectangleShape2D = (
		enemy.get_node(^"CollisionShape2D") as CollisionShape2D
	).shape as RectangleShape2D
	assert_eq(enemy_shape.size, Vector2(42.0, 95.0))

	city.gameplay_hud._apply_live_visual_tuning()
	assert_almost_eq(city.gameplay_hud.transform.x.length(), 1.15, 0.001)
	assert_eq(city.gameplay_hud.status_panel.self_modulate, Color("80a0ff"))
	assert_true(service.provenance.ranked_eligible())


func _cleanup() -> void:
	var global: String = ProjectSettings.globalize_path(SAVE_ROOT)
	if DirAccess.dir_exists_absolute(global):
		OS.move_to_trash(global)
