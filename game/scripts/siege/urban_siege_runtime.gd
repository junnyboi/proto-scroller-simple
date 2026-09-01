class_name UrbanSiegeRuntime
extends Node

signal act_changed(index: int, act_id: StringName, display_name: String)
signal act_completed(index: int, act_id: StringName, display_name: String)
signal beat_changed(act_index: int, beat_index: int, beat_id: StringName)
signal recovery_started(duration: float)
signal milestone_reached(milestone: StringName)
signal district_completed
signal finale_choice_requested(snapshot: FinaleEligibilitySnapshot)
signal finale_resolved(outcome: int, snapshot: FinaleEligibilitySnapshot)

const DIRECTOR_SCRIPT: Script = preload("res://scripts/siege/district_response_director.gd")
const CATALYST_RUNTIME_SCRIPT: Script = preload(
	"res://scripts/destruction/catalysts/catalyst_runtime.gd"
)
const HAZARD_RUNTIME_SCRIPT: Script = preload("res://scripts/hazards/hazard_runtime.gd")
const NEW_GAME_PLUS_ENEMY_MULTIPLIER: float = 2.0
const ROLE_PROFILES: Array[EnemyRoleProfile] = [
	preload("res://resources/roles/advancing_soldier.tres"),
	preload("res://resources/roles/suppressor.tres"),
	preload("res://resources/roles/anchor_tank.tres"),
	preload("res://resources/roles/support_breaker.tres"),
	preload("res://resources/roles/strafe_helicopter.tres"),
	preload("res://resources/roles/catalyst_marker.tres"),
]
const TRAIT_PROFILES: Array[EnemyTraitProfile] = [
	preload("res://resources/traits/command.tres"),
	preload("res://resources/traits/volatile.tres"),
	preload("res://resources/traits/shielded.tres"),
	preload("res://resources/traits/blitz.tres"),
	preload("res://resources/traits/brutal.tres"),
	preload("res://resources/traits/phased.tres"),
]
const DISTRICT_DECK: DistrictDeck = preload("res://resources/siege/district_deck.tres")
const RUN_CONTRACTS: Array[RunContract] = [
	preload("res://resources/contracts/no_heavy_hits.tres"),
	preload("res://resources/contracts/controlled_damage.tres"),
	preload("res://resources/contracts/deep_chain.tres"),
]

var dependencies: UrbanSiegeDependencies
var base_district: DistrictDefinition
var district: DistrictDefinition
var director: DistrictResponseDirector
var catalysts: CatalystRuntime
var hazards: HazardRuntime
var hazard_pressure: HazardPressureController
var directives: DirectiveSession
var pause_coordinator: RunPauseCoordinator
var trait_runtime: EnemyTraitRuntime
var boss_session: CommandBossSession
var boss_campaign: BossCampaignDirector
var run_seed: int = 0
var cycle_count: int = 1
var run_active: bool = false
var selected_recipe: DistrictRecipe
var selected_contract: RunContract
var finale_pending: bool = false
var finale_snapshot: FinaleEligibilitySnapshot
var finale_arc_completed: bool = false
var finale_boss_completed: bool = false
var _directive_pause_token: int = 0
var _terminal_pause_token: int = 0
var _offered_district_keys: Dictionary[StringName, bool] = {}
var _pending_district_offer: StringName = &""


func setup(p_dependencies: UrbanSiegeDependencies, p_district: DistrictDefinition) -> void:
	dependencies = p_dependencies
	base_district = p_district
	district = p_district.duplicate(true) as DistrictDefinition
	director = DIRECTOR_SCRIPT.new() as DistrictResponseDirector
	director.name = "DistrictResponseDirector"
	director.setup_district(
		dependencies.encounter_runtime,
		district
	)
	director.phase_changed.connect(_on_phase_changed)
	director.act_completed.connect(act_completed.emit)
	director.beat_changed.connect(beat_changed.emit)
	director.recovery_started.connect(recovery_started.emit)
	director.milestone_reached.connect(milestone_reached.emit)
	director.milestone_reached.connect(_on_milestone_reached)
	director.district_completed.connect(_on_arc_completed)
	add_child(director)
	hazards = HAZARD_RUNTIME_SCRIPT.new() as HazardRuntime
	hazards.name = "HazardRuntime"
	hazards.setup(dependencies)
	add_child(hazards)
	hazard_pressure = HazardPressureController.new()
	hazard_pressure.setup(hazards)
	hazard_pressure.configure(0, 1)
	director.configure_hazards(hazards, hazard_pressure)
	catalysts = CATALYST_RUNTIME_SCRIPT.new() as CatalystRuntime
	catalysts.name = "CatalystRuntime"
	catalysts.setup(dependencies)
	add_child(catalysts)
	directives = DirectiveSession.new()
	directives.name = "DirectiveSession"
	directives.setup(
		dependencies,
		DistrictMissionCatalog.all_profiles()
	)
	add_child(directives)
	dependencies.city.contextual_attacks.set_directive_session(directives)
	dependencies.encounter_runtime.configure_profiles(ROLE_PROFILES, TRAIT_PROFILES)
	trait_runtime = EnemyTraitRuntime.new()
	trait_runtime.name = "EnemyTraitRuntime"
	trait_runtime.setup(dependencies)
	add_child(trait_runtime)
	boss_session = CommandBossSession.new()
	boss_session.name = "CommandBossSession"
	boss_session.setup(dependencies)
	boss_session.completed.connect(_on_boss_completed)
	add_child(boss_session)
	boss_campaign = BossCampaignDirector.new()
	boss_campaign.name = "BossCampaignDirector"
	boss_campaign.setup(self)
	boss_campaign.boss_completed.connect(_on_campaign_boss_completed)
	add_child(boss_campaign)
	pause_coordinator = RunPauseCoordinator.new()
	pause_coordinator.name = "RunPauseCoordinator"
	pause_coordinator.setup(dependencies, director, catalysts, hazards)
	add_child(pause_coordinator)
	pause_coordinator.pause_changed.connect(directives.set_paused)
	directives.choices_offered.connect(_on_directive_choices_offered)
	directives.selected.connect(_on_directive_selected)
	if dependencies.city.world_stream != null:
		dependencies.city.world_stream.district_changed.connect(
			_on_spatial_district_changed
		)
		dependencies.city.world_stream.window_changed.connect(
			_on_world_window_changed
		)
	_select_configuration(false)


func start_run(p_seed: int = 0) -> void:
	run_active = true
	run_seed = p_seed
	cycle_count = 1
	_offered_district_keys.clear()
	_pending_district_offer = &""
	finale_pending = false
	finale_snapshot = null
	finale_arc_completed = false
	finale_boss_completed = false
	directives.reset_run_state()
	if boss_campaign != null:
		boss_campaign.reset_run()
	if dependencies.city.world_stream != null:
		dependencies.city.world_stream.configure_run(run_seed)
	_prepare_cycle()


func prepare_terminal_choice() -> void:
	if _terminal_pause_token == 0:
		_terminal_pause_token = pause_coordinator.acquire(&"extract_continue")


func continue_cycle() -> bool:
	if cycle_count >= 2:
		return false
	if _terminal_pause_token != 0:
		pause_coordinator.release(_terminal_pause_token)
		_terminal_pause_token = 0
	cycle_count += 1
	_offered_district_keys.clear()
	_pending_district_offer = &""
	dependencies.telegraphs.cancel_all()
	dependencies.projectile_pool.release_all()
	dependencies.encounter_runtime.release_all()
	hazards.release_all()
	trait_runtime.reset_all()
	boss_session.reset_state()
	finale_pending = false
	finale_snapshot = null
	finale_arc_completed = false
	finale_boss_completed = false
	if boss_campaign != null:
		boss_campaign.reset_run(true)
	_prepare_cycle()
	return true


func release_terminal_choice() -> void:
	if _terminal_pause_token != 0:
		pause_coordinator.release(_terminal_pause_token)
		_terminal_pause_token = 0


func present_finale_choice() -> bool:
	if not finale_pending or finale_snapshot == null:
		return false
	prepare_terminal_choice()
	finale_choice_requested.emit(finale_snapshot)
	return true


func resolve_finale(requested_outcome: int) -> int:
	if not finale_pending or finale_snapshot == null:
		return -1
	if not requested_outcome in [
		BossOutcome.PURGE, BossOutcome.DISENTANGLE, BossOutcome.ASCENSION_FAILURE,
	]:
		return -1
	var outcome: int = requested_outcome
	if requested_outcome == BossOutcome.DISENTANGLE and not finale_snapshot.disentangle_eligible:
		outcome = BossOutcome.ASCENSION_FAILURE
	var choir: ProjectChoirRuntime = dependencies.city.project_choir_runtime
	if choir == null or not choir.commit_finale_ending(
		outcome, boss_session.completion_payload()
	):
		return -1
	finale_pending = false
	finale_resolved.emit(outcome, finale_snapshot)
	return outcome


func contract_succeeded() -> bool:
	if selected_contract == null:
		return false
	if selected_contract.metric == &"heavy_hits":
		return dependencies.rampage_session.heavy_hit_count <= selected_contract.maximum_value
	if selected_contract.metric == &"causal_depth":
		return (
			dependencies.rampage_session.causal_chain_tracker.best_depth
			>= absi(selected_contract.maximum_value)
		)
	return false


func _process(delta: float) -> void:
	if boss_session != null:
		boss_session.advance(delta)
	_try_present_pending_district_offer()


func stop_run() -> void:
	run_active = false
	_pending_district_offer = &""
	if boss_campaign != null:
		boss_campaign.stop()
	if director != null:
		director.stop()
	if catalysts != null:
		catalysts.deactivate_all()
	if hazards != null:
		hazards.release_all()
	if directives != null:
		directives.stop()
	if pause_coordinator != null:
		pause_coordinator.release_all()
	if trait_runtime != null:
		trait_runtime.reset_all()
	if boss_session != null:
		boss_session.stop()
	release_terminal_choice()
	_directive_pause_token = 0


func reset_run() -> void:
	stop_run()
	if boss_session != null:
		boss_session.reset_state()
	if director != null:
		director.reset_to_contact()
	if boss_campaign != null:
		boss_campaign.reset_run()


func is_simulation_paused() -> bool:
	return pause_coordinator != null and pause_coordinator.is_paused()


func set_boss_gate_owned(owned: bool) -> void:
	if owned:
		_pending_district_offer = &""
		_withdraw_directive_presentation()
	elif run_active:
		_try_present_pending_district_offer()


func withdraw_directive_for_boss() -> void:
	_withdraw_directive_presentation()


func _on_phase_changed(index: int, display_name: String) -> void:
	var act_id: StringName = &""
	if district != null and index >= 0 and index < district.acts.size():
		act_id = district.acts[index].act_id
	act_changed.emit(index, act_id, display_name)


func _on_milestone_reached(milestone: StringName) -> void:
	if milestone == &"DIRECTIVE_CHOICE":
		_offer_current_district_once()


func _on_directive_choices_offered(_profiles: Array[DirectiveProfile]) -> void:
	if _directive_pause_token == 0:
		_directive_pause_token = pause_coordinator.acquire(&"directive_choice")


func _on_directive_selected(_profile: DirectiveProfile) -> void:
	if _directive_pause_token != 0:
		pause_coordinator.release(_directive_pause_token)
		_directive_pause_token = 0


func _on_spatial_district_changed(
	_previous_district_id: StringName,
	district_id: StringName,
	_logical_chunk: int
) -> void:
	_withdraw_directive_presentation()
	_pending_district_offer = district_id
	_try_present_pending_district_offer()


func _on_world_window_changed(logical_chunk: int) -> void:
	if director != null:
		director.request_facade_reinforcement(logical_chunk)


func _offer_current_district_once() -> void:
	_offer_district_once(_current_district_id())


func _current_district_id() -> StringName:
	if dependencies.city.world_stream != null:
		return dependencies.city.world_stream.current_district_id
	return &"BUSINESS"


func _offer_district_once(district_id: StringName) -> void:
	var key: StringName = StringName("%d:%s" % [cycle_count, district_id])
	if _offered_district_keys.has(key):
		return
	_offered_district_keys[key] = true
	directives.offer_district(run_seed, cycle_count, district_id)


func _try_present_pending_district_offer() -> void:
	if _pending_district_offer.is_empty():
		return
	if boss_campaign != null and boss_campaign.owns_combat():
		return
	if pause_coordinator != null and pause_coordinator.is_paused():
		return
	if dependencies.telegraphs != null and dependencies.telegraphs.active_count() > 0:
		return
	var district_id: StringName = _pending_district_offer
	_pending_district_offer = &""
	_offer_district_once(district_id)


func _withdraw_directive_presentation() -> void:
	directives.withdraw()
	if dependencies.gameplay_hud != null:
		dependencies.gameplay_hud.directive_choice_overlay.hide_choices()
	if _directive_pause_token != 0:
		pause_coordinator.release(_directive_pause_token)
		_directive_pause_token = 0


func _on_arc_completed() -> void:
	finale_arc_completed = true
	district_completed.emit()


func _on_boss_completed(_elapsed_seconds: float) -> void:
	if boss_campaign != null and boss_campaign.owns_combat():
		return
	if boss_session.active_definition != null:
		finale_boss_completed = boss_session.active_definition.boss_id == &"CHOIR_PRIME"
	_try_complete_finale_gate()


func _on_campaign_boss_completed(definition: BossEncounterDefinition) -> void:
	if definition != null and definition.boss_id == &"CHOIR_PRIME":
		finale_boss_completed = true
		finale_arc_completed = true
		_try_complete_finale_gate()


func _try_complete_finale_gate() -> void:
	if finale_pending or not finale_arc_completed or not finale_boss_completed:
		return
	var choir: ProjectChoirRuntime = dependencies.city.project_choir_runtime
	var persisted_snapshot: FinaleEligibilitySnapshot = (
		choir.campaign_progress.finale_snapshot() if choir != null else null
	)
	finale_snapshot = (
		persisted_snapshot
		if persisted_snapshot != null
		else choir.snapshot_finale_eligibility()
		if choir != null
		else FinaleEligibilitySnapshot.new()
	)
	finale_pending = true
	district_completed.emit()


func _prepare_cycle() -> void:
	_select_configuration(true)
	var difficulty_multiplier: float = (
		NEW_GAME_PLUS_ENEMY_MULTIPLIER if cycle_count >= 2 else 1.0
	)
	dependencies.encounter_runtime.configure_cycle_difficulty(
		difficulty_multiplier,
		difficulty_multiplier
	)
	director.configure_elite_affixes(run_seed, cycle_count)
	hazard_pressure.configure(run_seed, cycle_count)
	hazards.release_all()
	catalysts.deactivate_all()
	var transformer: Catalyst2D = catalysts.activate(
		0,
		preload("res://resources/catalysts/transformer.tres"),
		dependencies.encounter_runtime.resolve_spawn_position(
			selected_recipe.transformer_position,
			&"WORLD"
		),
		_current_district_id()
	)
	dependencies.encounter_runtime.set_catalyst_target(transformer)
	director.start()
	director.hold_act_advance()


func _select_configuration(apply_to_director: bool) -> void:
	var selection: Dictionary = DistrictDeckSelector.select(
		base_district,
		DISTRICT_DECK,
		RUN_CONTRACTS,
		run_seed,
		cycle_count
	)
	selected_recipe = selection.recipe as DistrictRecipe
	selected_contract = selection.contract as RunContract
	if apply_to_director:
		district = selection.district as DistrictDefinition
		director.district = district
