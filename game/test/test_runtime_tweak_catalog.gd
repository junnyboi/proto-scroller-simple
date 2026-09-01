extends GutTest


func test_catalog_has_fifty_two_unique_sorted_enabled_descriptors() -> void:
	var catalog: RuntimeTweakCatalog = RuntimeTweakCatalog.load_catalog()
	assert_true(catalog.is_valid(), str(catalog.errors))
	assert_eq(catalog.enabled_count(), 52)
	var ids: Array[StringName] = catalog.ids()
	var sorted: Array[StringName] = ids.duplicate()
	sorted.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second)
	)
	assert_eq(ids, sorted)
	var unique: Dictionary[StringName, bool] = {}
	for identifier: StringName in ids:
		assert_false(unique.has(identifier), identifier)
		unique[identifier] = true
	assert_eq(unique.size(), 52)
	assert_eq(catalog.categories().size(), 7)


func test_every_descriptor_has_valid_metadata_and_default() -> void:
	var catalog: RuntimeTweakCatalog = RuntimeTweakCatalog.load_catalog()
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		assert_false(entry.id.is_empty())
		assert_false(entry.category.is_empty(), entry.id)
		assert_has(RuntimeTweakDescriptor.SUPPORTED_TYPES, entry.value_type, entry.id)
		assert_has(RuntimeTweakDescriptor.APPLY_MODES, entry.apply_mode, entry.id)
		assert_has(RuntimeTweakDescriptor.INTEGRITY_CLASSES, entry.integrity, entry.id)
		assert_true(bool(entry.sanitize(entry.default_value).ok), entry.id)
		assert_false(entry.label_key.is_empty(), entry.id)
		assert_false(entry.description_key.is_empty(), entry.id)


func test_catalog_defaults_match_current_runtime_authorities() -> void:
	var catalog: RuntimeTweakCatalog = RuntimeTweakCatalog.load_catalog()
	assert_eq(catalog.descriptor(&"player.move.max_speed").default_value, 260.0)
	assert_eq(catalog.descriptor(&"player.melee.ground_smash_damage").default_value, 180.0)
	assert_eq(catalog.descriptor(&"player.melee.ground_smash_radius").default_value, 320.0)
	assert_eq(
		catalog.descriptor(&"enemy.outgoing_damage_multiplier").default_value,
		EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER
	)
	assert_eq(
		catalog.descriptor(&"spawn.quantity_multiplier").default_value,
		EnemySpawnTuning.QUANTITY_MULTIPLIER
	)
	assert_eq(
		catalog.descriptor(&"spawn.interval_scale").default_value,
		EnemySpawnTuning.INTERVAL_SCALE
	)
	assert_eq(
		catalog.descriptor(&"world.repair_drop.amount").default_value,
		ChassisRepairPickup2D.REPAIR_AMOUNT
	)
	assert_eq(
		catalog.descriptor(&"world.repair_drop.lifetime_seconds").default_value,
		ChassisRepairPickup2D.LIFETIME_SECONDS
	)


func test_validation_rejects_unknown_types_and_non_finite_numbers() -> void:
	var catalog: RuntimeTweakCatalog = RuntimeTweakCatalog.load_catalog()
	assert_false(bool(catalog.validate_value(&"missing.parameter", 1).ok))
	assert_false(bool(catalog.validate_value(&"player.move.max_speed", "fast").ok))
	assert_false(bool(catalog.validate_value(&"player.move.max_speed", INF).ok))
	assert_eq(catalog.validate_value(&"player.move.max_speed", 333.0).value, 330.0)
	assert_eq(catalog.validate_value(&"spawn.quantity_multiplier", 1.8).value, 2)
	assert_false(bool(catalog.validate_value(&"player.visual.tint", "laser kiwi").ok))
	assert_eq(catalog.validate_value(&"player.visual.tint", "62f5df").value, "#62f5df")
	assert_eq(catalog.validate_value(&"enemy.visual.tint", Color("ff8040")).value, "#ff8040")
