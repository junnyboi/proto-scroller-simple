extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_SAVE_PATH: String = "user://test_project_choir_campaign.cfg"


func before_each() -> void:
	_remove_test_save()
	L10n.set_locale("en")


func after_each() -> void:
	_remove_test_save()
	L10n.set_locale("en")


func test_dossier_catalog_is_a_complete_facade_bijection() -> void:
	assert_eq(DossierCatalog.validation_errors(), PackedStringArray())
	var definitions: Array[DossierDefinition] = DossierCatalog.definitions()
	assert_eq(definitions.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)
	var dossier_ids: Dictionary[StringName, bool] = {}
	var variant_ids: Dictionary[StringName, bool] = {}
	for definition: DossierDefinition in definitions:
		assert_false(dossier_ids.has(definition.dossier_id))
		assert_false(variant_ids.has(definition.building_variant_id))
		dossier_ids[definition.dossier_id] = true
		variant_ids[definition.building_variant_id] = true
		assert_not_null(CityDistrictCatalog.variant_by_id(definition.building_variant_id))
		assert_true(definition.trigger_column in range(StructuralBuilding2D.COLUMNS))
		assert_true(definition.trigger_row in range(StructuralBuilding2D.ROWS))
		assert_not_null(definition.image)
		assert_false(_has_property(definition, &"reveal_id"))
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		assert_eq(DossierCatalog.district_definitions(district.district_id).size(), 5)


func test_campaign_progress_round_trips_and_ignores_duplicate_dossiers() -> void:
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.setup(TEST_SAVE_PATH)
	add_child_autofree(store)
	var dossier_id: StringName = &"dossier_business_mercy_exchange_annex"
	assert_true(store.collect_dossier(dossier_id))
	assert_false(store.collect_dossier(dossier_id))
	assert_true(store.preserve_evidence(&"LEDGER"))
	assert_false(store.preserve_evidence(&"LEDGER"))
	assert_eq(store.increment_continuity(), 1)
	assert_true(store.mark_ending_seen(&"BURN_THE_CHOIR"))
	assert_eq(store.save_count, 4)
	var restored: CampaignProgressStore = CampaignProgressStore.new()
	restored.setup(TEST_SAVE_PATH)
	add_child_autofree(restored)
	assert_true(restored.has_dossier(dossier_id))
	assert_eq(restored.dossier_count(), 1)
	assert_eq(restored.district_dossier_count(&"BUSINESS"), 1)
	assert_eq(restored.evidence_count(), 1)
	assert_eq(restored.continuity_generation(), 1)
	assert_true(restored.has_ending(&"BURN_THE_CHOIR"))


func test_campaign_progress_rejects_corrupt_and_future_saves_safely() -> void:
	var invalid: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	invalid.store_string("not a ConfigFile")
	invalid.close()
	var corrupt_store: CampaignProgressStore = CampaignProgressStore.new()
	add_child_autofree(corrupt_store)
	corrupt_store.setup(TEST_SAVE_PATH)
	assert_ne(corrupt_store.last_error, OK)
	assert_eq(corrupt_store.dossier_count(), 0)
	var future: ConfigFile = ConfigFile.new()
	future.set_value("meta", "schema_version", CampaignProgressStore.SCHEMA_VERSION + 1)
	future.set_value(
		"progress",
		"collected_dossiers",
		PackedStringArray(["dossier_business_mercy_exchange_annex"])
	)
	assert_eq(future.save(TEST_SAVE_PATH), OK)
	var future_store: CampaignProgressStore = CampaignProgressStore.new()
	add_child_autofree(future_store)
	future_store.setup(TEST_SAVE_PATH)
	assert_eq(future_store.last_error, ERR_INVALID_DATA)
	assert_eq(future_store.dossier_count(), 0)


func test_city_narrative_collects_once_without_background_and_survives_finish() -> void:
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.setup(TEST_SAVE_PATH)
	add_child_autofree(store)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.campaign_progress = store
	add_child_autofree(city)
	await get_tree().process_frame
	var definition: DossierDefinition = DossierCatalog.definition_for_variant(
		city.building.current_variant_id()
	)
	assert_not_null(definition)
	var building_child_count: int = city.building.get_child_count()
	assert_null(city.project_choir_runtime.get_node_or_null(^"FacadeRevealRuntime"))
	city.project_choir_runtime.director.handle_building_cell_destroyed(
		city.building,
		definition.trigger_column,
		definition.trigger_row
	)
	assert_eq(store.dossier_count(), 1)
	assert_eq(city.building.get_child_count(), building_child_count)
	_assert_no_cross_section_backgrounds(city)
	city.project_choir_runtime.director.handle_building_cell_destroyed(
		city.building,
		definition.trigger_column,
		definition.trigger_row
	)
	assert_eq(store.dossier_count(), 1)
	assert_lte(
		city.gameplay_hud.transmission_toast.pending_count(),
		TransmissionToast.QUEUE_CAPACITY
	)
	city.run_lifecycle.robot_defeated()
	city.run_lifecycle.robot_defeated()
	assert_eq(store.continuity_generation(), 1)
	assert_true(city.game_over_active)
	assert_true(city.gameplay_hud.overlay_summary.text.contains("DOSSIERS 1/10"))
	assert_true(city.gameplay_hud.overlay_summary.text.contains("GENERATION 1"))


func test_all_district_facades_have_no_cross_section_background_nodes() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			assert_true(city.building.apply_variant(variant))
			assert_eq(
				city.building.get_child_count(),
				StructuralBuilding2D.CELL_COUNT,
				String(variant.variant_id)
			)
			_assert_no_cross_section_backgrounds(city)


func test_transmission_toast_is_bounded_deduped_and_nonblocking() -> void:
	var toast: TransmissionToast = TransmissionToast.new()
	add_child_autofree(toast)
	await get_tree().process_frame
	var baseline_nodes: int = _count_nodes(toast)
	for index: int in range(100):
		toast.present(
			StringName("event_%d" % index),
			"narrative.speaker.echo7",
			"narrative.transmission.dossier_recovered",
			1.0,
			posmod(index, 5)
		)
	assert_lte(toast.pending_count(), TransmissionToast.QUEUE_CAPACITY)
	assert_eq(_count_nodes(toast), baseline_nodes)
	assert_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(toast.focus_mode, Control.FOCUS_NONE)
	assert_false(get_tree().paused)
	var current: StringName = toast.active_event_id()
	assert_false(toast.present(
		current,
		"narrative.speaker.echo7",
		"narrative.transmission.dossier_recovered",
		1.0,
		5
	))
	for _step: int in range(8):
		toast._process(2.0)
	assert_eq(toast.pending_count(), 0)
	assert_eq(_count_nodes(toast), baseline_nodes)


func test_transmission_toast_stays_top_left_in_both_orientations() -> void:
	var toast: TransmissionToast = TransmissionToast.new()
	add_child_autofree(toast)
	await get_tree().process_frame
	toast.apply_responsive_layout(Vector2(1280.0, 720.0))
	assert_eq(toast.position, Vector2(24.0, 172.0))
	assert_eq(toast.size, Vector2(620.0, 104.0))
	assert_lt(toast.position.x + toast.size.x, 1280.0 * 0.75)
	toast.apply_responsive_layout(Vector2(720.0, 1280.0))
	assert_eq(toast.position, Vector2(24.0, 170.0))
	assert_eq(toast.size, Vector2(672.0, 122.0))


func test_project_choir_localization_exists_in_both_supported_locales() -> void:
	for locale: String in L10n.available_locales():
		assert_true(L10n.set_locale(locale))
		for definition: DossierDefinition in DossierCatalog.definitions():
			assert_ne(L10n.t(definition.title_key), definition.title_key)
			assert_ne(L10n.t(definition.body_primary_key), definition.body_primary_key)
			assert_ne(L10n.t(definition.body_secondary_key), definition.body_secondary_key)


func _remove_test_save() -> void:
	for path: String in [TEST_SAVE_PATH, TEST_SAVE_PATH + ".tmp", TEST_SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _count_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_nodes(child)
	return count


func _assert_no_cross_section_backgrounds(city: CitySlice) -> void:
	assert_null(city.project_choir_runtime.get_node_or_null(^"FacadeRevealRuntime"))
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		assert_null(building.get_node_or_null(^"ChoirLabReveal"))


func _has_property(value: Object, property_name: StringName) -> bool:
	for property: Dictionary in value.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false
