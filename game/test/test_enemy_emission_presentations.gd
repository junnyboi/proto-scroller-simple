extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice
var runtime: EncounterRuntime


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	runtime = city.encounter_runtime
	runtime.release_all()
	city.projectile_root.release_all()


func test_support_variants_keep_kind_and_reserve_zero_projectiles() -> void:
	var cases: Dictionary[StringName, StringName] = {
		&"needle": &"scan",
	}
	for archetype_id: StringName in cases:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var enemy: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1050.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(enemy, archetype_id)
		enemy.set_physics_process(false)
		enemy._begin_attack()
		assert_true(enemy.is_telegraphing(), archetype_id)
		assert_eq(city.projectile_root.reservation_count(), 0, archetype_id)
		var snapshot: Dictionary = city.telegraph_presenter.snapshot(enemy._telegraph_id)
		assert_eq(snapshot.get("kind"), &"support", archetype_id)
		assert_eq(snapshot.get("presentation_variant"), cases[archetype_id], archetype_id)
		assert_true(snapshot.has("visual_key"), archetype_id)
		assert_true(snapshot.has("style_data"), archetype_id)
		runtime.release(enemy)


func test_legacy_telegraph_reserve_has_backward_compatible_metadata() -> void:
	var enemy: ProceduralEnemy = runtime.acquire(
		&"bulwark", Vector2(1050.0, 542.5)
	) as ProceduralEnemy
	var record_id: int = city.telegraph_presenter.reserve(
		enemy,
		&"bullet",
		enemy.global_position,
		city.robot.global_position,
		0.4
	)
	var snapshot: Dictionary = city.telegraph_presenter.snapshot(record_id)
	assert_eq(snapshot.get("presentation_variant"), &"")
	assert_eq(snapshot.get("visual_key"), &"")
	assert_eq(snapshot.get("style_data"), {})


func test_every_current_enemy_identity_resolves_to_authored_emission_family() -> void:
	var authored_presentation_styles: Array[StringName] = [
		&"scan", &"repair", &"shock_brace", &"marked_leap",
	]
	assert_eq(EnemyArchetypeCatalog.PROCEDURAL_IDS.size(), 8)
	assert_eq(EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS.size(), 8)
	assert_eq(EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS.size(), 16)
	for archetype_id: StringName in EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_false(profile.is_empty(), archetype_id)
		var attack_style: StringName = StringName(profile.get("attack_style", &""))
		var projectile_kind: StringName = StringName(profile.get("projectile_kind", &""))
		if attack_style in authored_presentation_styles:
			assert_true(attack_style in authored_presentation_styles, archetype_id)
		else:
			assert_false(
				ProjectileVisualCatalog.default_key(projectile_kind).is_empty(),
				archetype_id
			)
	var base_actor_projectiles: Dictionary[StringName, StringName] = {
		&"soldier": &"bullet",
		&"tank": &"shell",
		&"helicopter": &"rocket",
	}
	for actor_id: StringName in base_actor_projectiles:
		assert_false(
			ProjectileVisualCatalog.default_key(base_actor_projectiles[actor_id]).is_empty(),
			actor_id
		)
