class_name ProjectChoirRuntime
extends Node

const CROWN_PYLON_TRANSACTION_ID: StringName = &"boss:CHOIR_PRIME:crown_pylon"

var campaign_progress: CampaignProgressStore
var director: NarrativeDirector
var _city: CitySlice
var _released_containment: Dictionary[StringName, bool] = {}


static func mount(city: CitySlice, progress: CampaignProgressStore) -> ProjectChoirRuntime:
	var runtime: ProjectChoirRuntime = ProjectChoirRuntime.new()
	runtime.name = "ProjectChoirRuntime"
	city.add_child(runtime)
	runtime.setup(city, progress)
	return runtime


func setup(city: CitySlice, progress: CampaignProgressStore) -> void:
	_city = city
	_released_containment.clear()
	campaign_progress = progress
	if campaign_progress == null:
		campaign_progress = CampaignProgressStore.new()
		campaign_progress.name = "EphemeralCampaignProgressStore"
		add_child(campaign_progress)
		campaign_progress.reset_memory()
	assert(DossierCatalog.validation_errors().is_empty())
	director = NarrativeDirector.new()
	director.name = "NarrativeDirector"
	director.setup(campaign_progress)
	director.transmission_requested.connect(city.gameplay_hud.transmission_toast.present)
	add_child(director)
	city.world_stream.district_changed.connect(_on_spatial_district_changed)
	city.streamed_destructibles.building_cell_destroyed.connect(_on_building_cell_destroyed)
	city.encounter_runtime.enemy_acquired.connect(director.handle_enemy_acquired)
	city.encounter_runtime.enemy_died.connect(director.handle_enemy_defeated)
	city.run_lifecycle.run_finished.connect(_on_run_finished)
	var boss_campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	boss_campaign.attempt_started.connect(director.handle_boss_attempt_started)
	city.urban_siege.boss_session.state_changed.connect(director.handle_boss_state_changed)
	var initial_district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(
		city.world_stream.current_logical_chunk
	)
	director.begin_run(city.world_stream.run_seed, initial_district.district_id)


func _on_spatial_district_changed(
	_previous_district_id: StringName,
	district_id: StringName,
	_logical_chunk: int
) -> void:
	director.handle_spatial_district_arrival(district_id)


func _on_building_cell_destroyed(
	building: StructuralBuilding2D,
	column: int,
	row: int,
	_event: DamageEvent
) -> void:
	director.handle_building_cell_destroyed(building, column, row)
	_try_release_containment(building, column, row)


func containment_release_count() -> int:
	return _released_containment.size()


func commit_boss_completion(
	definition: BossEncounterDefinition,
	canonical_evidence_event: Dictionary
) -> bool:
	return director.handle_boss_completed(definition, canonical_evidence_event)


func commit_crown_pylon_transaction() -> bool:
	if campaign_progress == null:
		return false
	if campaign_progress.has_transaction(CROWN_PYLON_TRANSACTION_ID):
		return true
	return campaign_progress.commit_boss_transaction({
		"transaction_id": CROWN_PYLON_TRANSACTION_ID,
		"dossier_ids": [&"CROWN_05_CONSENT_EXCISION_ORDER"],
		"evidence_ids": [&"CROWN"],
		"boss_result": {
			"crown_pylon_severed": true,
			"armor_connection": BossRoyalFinaleController.CONNECTION_COUNT,
		},
	})


func snapshot_finale_eligibility() -> FinaleEligibilitySnapshot:
	if campaign_progress == null:
		return FinaleEligibilitySnapshot.new()
	var persisted: FinaleEligibilitySnapshot = campaign_progress.finale_snapshot()
	if persisted != null:
		return persisted
	if not commit_crown_pylon_transaction():
		return FinaleEligibilitySnapshot.new()
	var snapshot: FinaleEligibilitySnapshot = FinaleEligibilitySnapshot.from_store(
		campaign_progress
	)
	if not campaign_progress.commit_finale_snapshot(
		snapshot, CROWN_PYLON_TRANSACTION_ID
	):
		return FinaleEligibilitySnapshot.new()
	return campaign_progress.finale_snapshot()


func commit_finale_ending(outcome: int, boss_result: Dictionary) -> bool:
	if campaign_progress == null:
		return false
	return campaign_progress.commit_finale_ending_transaction(
		outcome, boss_result, CROWN_PYLON_TRANSACTION_ID
	)


func _try_release_containment(
	building: StructuralBuilding2D,
	column: int,
	row: int
) -> void:
	if building == null:
		return
	var definition: DossierDefinition = DossierCatalog.definition_for_variant(
		building.current_variant_id()
	)
	if (
		definition == null
		or definition.district_id != &"ENTERTAINMENT"
		or not definition.trigger_matches(column, row)
		or _released_containment.has(definition.building_variant_id)
	):
		return
	var release_key: StringName = definition.building_variant_id
	var spawn_position: Vector2 = building.global_position + Vector2(0.0, 50.0)
	var release_id: StringName = _containment_variant_id(release_key, column, row)
	if release_id.is_empty():
		return
	var released: int = 0
	for copy_index: int in range(EnemySpawnTuning.QUANTITY_MULTIPLIER):
		var crawler: EnemyActor2D = _city.encounter_runtime.acquire(
			release_id,
			spawn_position + EnemySpawnTuning.offset_for_copy(copy_index, 90.0)
		)
		released += 1 if crawler != null else 0
	if released > 0:
		_released_containment[release_key] = true


func _containment_variant_id(
	building_variant_id: StringName,
	column: int,
	row: int
) -> StringName:
	var eligible: Array[StringName] = []
	for candidate: StringName in EnemyArchetypeCatalog.variants_for_district(
		&"ENTERTAINMENT"
	):
		if (
			EnemyArchetypeCatalog.family_for(candidate) == &"light"
			and EnemyArchetypeCatalog.canonical_id(candidate) == &"ossuary_crawler"
		):
			eligible.append(candidate)
	if eligible.is_empty():
		return &""
	var seed_value: int = column * 97 + row * 53
	if _city != null and _city.world_stream != null:
		seed_value += _city.world_stream.run_seed
	for character_index: int in range(String(building_variant_id).length()):
		seed_value += String(building_variant_id).unicode_at(character_index) * 7
	return eligible[posmod(seed_value, eligible.size())]


func _on_run_finished(completed: bool, _summary: RunSummarySnapshot) -> void:
	if not completed:
		director.record_chassis_loss()
	_city.gameplay_hud._set_campaign_summary(
		campaign_progress.dossier_count(),
		campaign_progress.continuity_generation()
	)
