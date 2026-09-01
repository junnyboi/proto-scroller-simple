class_name NarrativeDirector
extends Node

signal transmission_requested(
	event_id: StringName,
	speaker_key: String,
	line_key: String,
	duration: float,
	priority: int
)
signal dossier_collected(
	definition: DossierDefinition,
	total: int,
	district_total: int
)
signal district_arrived(district_id: StringName)
signal evidence_recovered(evidence_id: StringName, drop_id: StringName)

const DISTRICT_IDS: Array[StringName] = [
	&"BUSINESS", &"RESIDENTIAL",
]
const HYBRID_IDS: Array[StringName] = [
	&"reclaimed_breacher", &"graft_runner",
]

var campaign_progress: CampaignProgressStore
var run_seed: int = 0
var _fired_events: Dictionary[StringName, bool] = {}
var _arrived_districts: Dictionary[StringName, bool] = {}
var _active_boss: BossEncounterDefinition
var _elite_defeat_sequence: int = 0


func setup(progress: CampaignProgressStore) -> void:
	campaign_progress = progress


func begin_run(p_run_seed: int, initial_district_id: StringName = &"BUSINESS") -> void:
	run_seed = p_run_seed
	_fired_events.clear()
	_arrived_districts.clear()
	_active_boss = null
	_elite_defeat_sequence = 0
	handle_spatial_district_arrival(initial_district_id)


func handle_spatial_district_arrival(district_id: StringName) -> void:
	if not district_id in DISTRICT_IDS or _arrived_districts.has(district_id):
		return
	_arrived_districts[district_id] = true
	district_arrived.emit(district_id)
	_queue_transmission(
		StringName("district_%s_arrival" % String(district_id).to_lower()),
		"narrative.speaker.echo7",
		"narrative.district.%s.arrival" % String(district_id).to_lower(),
		4.2,
		2
	)


func handle_building_cell_destroyed(
	building: StructuralBuilding2D,
	column: int,
	row: int
) -> void:
	if campaign_progress == null or building == null:
		return
	var variant_id: StringName = building.current_variant_id()
	var definition: DossierDefinition = DossierCatalog.definition_for_variant(variant_id)
	if definition == null or not definition.trigger_matches(column, row):
		return
	if definition.is_boss_capstone or not campaign_progress.collect_dossier(
		definition.dossier_id
	):
		return
	dossier_collected.emit(
		definition,
		campaign_progress.dossier_count(),
		campaign_progress.district_dossier_count(definition.district_id)
	)
	_queue_transmission(
		StringName("recovered_%s" % definition.dossier_id),
		"narrative.speaker.protos",
		"narrative.transmission.dossier_recovered",
		3.2,
		3
	)


func handle_boss_attempt_started(definition: BossEncounterDefinition) -> void:
	_active_boss = definition
	if definition == null:
		return
	_queue_transmission(
		StringName("boss_%s_echo" % String(definition.boss_id).to_lower()),
		"narrative.speaker.echo7",
		String(definition.voice_caption_keys.get(&"echo", "")),
		4.4,
		4
	)


func handle_boss_state_changed(state: StringName) -> void:
	if _active_boss == null or state != CommandBossSession.STATE_EXPOSED:
		return
	_queue_transmission(
		StringName("boss_%s_veyr" % String(_active_boss.boss_id).to_lower()),
		"narrative.speaker.veyr",
		String(_active_boss.voice_caption_keys.get(&"veyr", "")),
		5.0,
		5
	)


func handle_boss_completed(
	definition: BossEncounterDefinition,
	canonical_evidence_event: Dictionary = {}
) -> bool:
	if campaign_progress == null or definition == null:
		return false
	var transaction_id: StringName = StringName("boss:%s:complete" % definition.boss_id)
	if campaign_progress.has_transaction(transaction_id):
		_active_boss = null
		return true
	var capstone: DossierDefinition = DossierCatalog.capstone_for_boss(definition.boss_id)
	if capstone == null:
		return false
	var evidence_ids: Array[StringName] = []
	var optional_result: Dictionary = {}
	if definition.boss_id == &"SETTLEMENT_ENGINE_S04":
		var archive_preserved: bool = bool(canonical_evidence_event.get(
			"archive_preserved", false
		))
		if archive_preserved:
			evidence_ids.append(&"LEDGER")
		optional_result = {"archive_preserved": archive_preserved}
	elif definition.boss_id == &"SAMARITAN_15":
		var central_preserved: bool = bool(canonical_evidence_event.get(
			"central_cradle_preserved", false
		))
		if central_preserved:
			evidence_ids.append(&"NURSERY")
		optional_result = {
			"central_cradle_preserved": central_preserved,
			"pod_loss_count": clampi(
				int(canonical_evidence_event.get("pod_loss_count", 0)), 0, 4
			),
			"rescue_tally": clampi(
				int(canonical_evidence_event.get("rescue_tally", 4)), 0, 4
			),
		}
	var committed: bool = campaign_progress.commit_boss_transaction({
		"transaction_id": transaction_id,
		"boss_id": definition.boss_id,
		"dossier_ids": [capstone.dossier_id],
		"evidence_ids": evidence_ids,
		"lost_evidence_ids": (
			[definition.evidence_flag_id]
			if definition.evidence_recovery_eligible and evidence_ids.is_empty()
			else []
		),
		"boss_result": optional_result,
		"unlock_chunk": definition.unlock_chunk,
		"reward_grant_id": StringName("boss:%s:reward" % definition.boss_id),
	})
	if committed:
		_active_boss = null
	return committed


func handle_enemy_defeated(enemy: EnemyActor2D, _event: DamageEvent, _points: int) -> void:
	if campaign_progress == null or enemy == null:
		return
	if not enemy.trait_id in EnemyArchetypeCatalog.RANDOM_AFFIXES:
		return
	var evidence_id: StringName = campaign_progress.next_recoverable_evidence(
		_elite_defeat_sequence
	)
	var drop_id: StringName = StringName(
		"%d:%d:%s:%d" % [
			run_seed,
			_elite_defeat_sequence,
			enemy.trait_id,
			enemy.activation_generation,
		]
	)
	_elite_defeat_sequence += 1
	if evidence_id.is_empty():
		return
	if campaign_progress.recover_evidence_from_elite(evidence_id, drop_id):
		evidence_recovered.emit(evidence_id, drop_id)
		_queue_transmission(
			StringName("elite_evidence_%s" % drop_id),
			"narrative.speaker.protos",
			"narrative.transmission.evidence_recovered",
			3.8,
			4
		)


func record_chassis_loss() -> int:
	if campaign_progress == null:
		return 0
	var generation: int = campaign_progress.increment_continuity()
	_queue_transmission(
		StringName("continuity_%d" % generation),
		"narrative.speaker.system",
		"narrative.transmission.continuity",
		4.0,
		5
	)
	return generation


func handle_enemy_acquired(enemy: EnemyActor2D) -> void:
	if not enemy is ProceduralEnemy:
		return
	var procedural: ProceduralEnemy = enemy as ProceduralEnemy
	var hybrid_id: StringName = procedural.base_archetype_id
	if hybrid_id.is_empty():
		hybrid_id = EnemyArchetypeCatalog.canonical_id(procedural.archetype_id)
	if not hybrid_id in HYBRID_IDS:
		return
	_queue_transmission(
		StringName("hybrid_%s_contact" % hybrid_id),
		"narrative.speaker.echo7",
		"narrative.enemy.%s.contact" % hybrid_id,
		4.6,
		3
	)


func echo7_status_key() -> String:
	if campaign_progress != null and campaign_progress.echo7_resolved():
		return "narrative.echo7.resolved"
	return "narrative.echo7.ambiguous"


func fired_event_count() -> int:
	return _fired_events.size()


func arrived_district_count() -> int:
	return _arrived_districts.size()


func _queue_transmission(
	event_id: StringName,
	speaker_key: String,
	line_key: String,
	duration: float,
	priority: int
) -> void:
	if event_id.is_empty() or line_key.is_empty() or _fired_events.has(event_id):
		return
	_fired_events[event_id] = true
	transmission_requested.emit(event_id, speaker_key, line_key, duration, priority)
