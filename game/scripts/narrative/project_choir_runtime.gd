class_name ProjectChoirRuntime
extends Node

const CROWN_PYLON_TRANSACTION_ID: StringName = &"boss:CHOIR_PRIME:crown_pylon"

var campaign_progress: CampaignProgressStore
var director: NarrativeDirector
var _city: CitySlice


static func mount(city: CitySlice, progress: CampaignProgressStore) -> ProjectChoirRuntime:
	var runtime: ProjectChoirRuntime = ProjectChoirRuntime.new()
	runtime.name = "ProjectChoirRuntime"
	city.add_child(runtime)
	runtime.setup(city, progress)
	return runtime


func setup(city: CitySlice, progress: CampaignProgressStore) -> void:
	_city = city
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


func _on_run_finished(completed: bool, _summary: RunSummarySnapshot) -> void:
	if not completed:
		director.record_chassis_loss()
	_city.gameplay_hud._set_campaign_summary(
		campaign_progress.dossier_count(),
		campaign_progress.continuity_generation()
	)
