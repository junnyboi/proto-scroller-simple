class_name HazardPressureController
extends RefCounted

const SYSTEM_SALT: int = 0x48A2A4D
const MINIMUM_DISTANCE: float = 300.0
const MAXIMUM_DISTANCE: float = 520.0
const APEX_PAIRS: Array[Array] = [
	[&"skybridge", &"flooded_lane"],
	[&"metro_car", &"ammo_convoy"],
	[&"flooded_lane", &"metro_car"],
	[&"ammo_convoy", &"skybridge"],
]
const CHAIN_PAIR_SPACING: float = 160.0
const MINIMUM_EVENT_SPACING: float = 0.75

var runtime: HazardRuntime
var assignments: Array[Dictionary] = []
var roll_count: int = 0
var last_used_budget: int = 0
var peak_used_budget: int = 0
var last_progression_tier: int = 0
var last_pressure_profile_id: StringName = &"BUSINESS"
var _seed: int = SYSTEM_SALT
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(p_runtime: HazardRuntime) -> void:
	runtime = p_runtime


func configure(run_seed: int, cycle: int) -> void:
	_seed = run_seed ^ SYSTEM_SALT ^ maxi(cycle, 1) * 1237
	_rng.seed = _seed
	assignments.clear()
	roll_count = 0
	last_used_budget = 0
	peak_used_budget = 0
	last_progression_tier = 0
	last_pressure_profile_id = &"BUSINESS"


func reset_sequence() -> void:
	_rng.seed = _seed
	assignments.clear()
	roll_count = 0
	last_used_budget = 0


func rebase_cached_world_state(offset: Vector2) -> void:
	for record: Dictionary in assignments:
		if record.has("position"):
			record.position = (record.position as Vector2) + offset


func plan_for_beat(
	act_index: int,
	beat_index: int,
	act: DistrictAct,
	beat: DistrictBeat,
	robot_x: float,
	pressure_source: Variant = 0
) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	last_used_budget = 0
	var pressure_profile: DistrictPressureProfile = DistrictPressureCatalog.coerce_profile(
		pressure_source
	)
	last_progression_tier = pressure_profile.district_index
	last_pressure_profile_id = pressure_profile.district_id
	var budget_limit: int = mini(
		RuntimeBudget.HAZARD_PRESSURE,
		act.hazard_pressure_budget + pressure_profile.hazard_pressure_bonus
	)
	var event_limit: int = mini(
		RuntimeBudget.PENDING_HAZARDS,
		act.hazard_events_per_beat + pressure_profile.hazard_event_bonus
	)
	if (
		runtime == null
		or not act.chaos_enabled
		or budget_limit <= 0
		or event_limit <= 0
	):
		return plan
	var candidates: Array[StringName] = _eligible_ids(act_index)
	for actor: EnvironmentalHazard2D in runtime.actors:
		if actor.active:
			candidates.erase(StringName(actor.get_meta(&"pool_hazard_id", &"")))
	if act_index == 4:
		var tier2_id: StringName = (
			EnvironmentalHazardCatalog.TIER2_IDS[
				beat_index % EnvironmentalHazardCatalog.TIER2_IDS.size()
			]
		)
		if candidates.has(tier2_id):
			var side: int = -1 if beat_index % 2 == 0 else 1
			var world_x: float = robot_x + float(side) * 390.0
			var record: Dictionary = {
				"hazard_id": tier2_id,
				"remaining": 0.55,
				"position": Vector2(world_x, CitySlice.LAND_VISUAL_BASELINE_Y),
				"facing": -side,
				"cost": EnvironmentalHazardCatalog.pressure_cost(tier2_id),
				"act_index": act_index,
				"beat_index": beat_index,
				"beat_id": beat.beat_id,
			}
			plan.append(record)
			assignments.append(record.duplicate())
			last_used_budget += int(record.cost)
			candidates.erase(tier2_id)
	elif act_index >= 5 and event_limit >= 2:
		var pair_plan: Array[Dictionary] = _plan_apex_pair(
			beat_index,
			budget_limit,
			robot_x
		)
		for record: Dictionary in pair_plan:
			plan.append(record)
			assignments.append(record.duplicate())
			last_used_budget += int(record.cost)
			candidates.erase(StringName(record.hazard_id))
	for event_index: int in range(plan.size(), event_limit):
		var affordable: Array[StringName] = []
		for hazard_id: StringName in candidates:
			var candidate_cost: int = EnvironmentalHazardCatalog.pressure_cost(hazard_id)
			if last_used_budget + candidate_cost <= budget_limit:
				affordable.append(hazard_id)
		if affordable.is_empty():
			break
		var draw: int = _rng.randi_range(0, affordable.size() - 1)
		var hazard_id: StringName = affordable[draw]
		roll_count += 1
		candidates.erase(hazard_id)
		var side: int = -1 if _rng.randf() < 0.5 else 1
		var distance: float = _rng.randf_range(MINIMUM_DISTANCE, MAXIMUM_DISTANCE)
		var world_x: float = robot_x + float(side) * distance
		var random_delay: float = 0.55 + float(event_index) * 0.88 + _rng.randf_range(
			0.0,
			0.38
		)
		var delay: float = maxf(
			random_delay,
			_last_damage_window_delay(plan) + MINIMUM_EVENT_SPACING
		)
		roll_count += 3
		var selected_cost: int = EnvironmentalHazardCatalog.pressure_cost(hazard_id)
		last_used_budget += selected_cost
		var record: Dictionary = {
			"hazard_id": hazard_id,
			"remaining": delay,
			"position": Vector2(world_x, CitySlice.LAND_VISUAL_BASELINE_Y),
			"facing": -side,
			"cost": selected_cost,
			"act_index": act_index,
			"beat_index": beat_index,
			"beat_id": beat.beat_id,
		}
		plan.append(record)
		assignments.append(record.duplicate())
	peak_used_budget = maxi(peak_used_budget, last_used_budget)
	return plan


func _last_damage_window_delay(plan: Array[Dictionary]) -> float:
	var latest: float = -MINIMUM_EVENT_SPACING
	for record: Dictionary in plan:
		latest = maxf(latest, float(record.remaining))
	return latest


func _plan_apex_pair(
	beat_index: int,
	budget_limit: int,
	robot_x: float
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pair: Array = APEX_PAIRS[beat_index % APEX_PAIRS.size()]
	var source_id: StringName = StringName(pair[0])
	var target_id: StringName = StringName(pair[1])
	var pair_cost: int = (
		EnvironmentalHazardCatalog.pressure_cost(source_id)
		+ EnvironmentalHazardCatalog.pressure_cost(target_id)
	)
	if pair_cost > budget_limit:
		return result
	var side: int = -1 if beat_index % 2 == 0 else 1
	var source_x: float = robot_x + float(side) * 320.0
	var target_x: float = source_x + float(side) * CHAIN_PAIR_SPACING
	var delay: float = 0.52 + _rng.randf_range(0.0, 0.18)
	roll_count += 1
	result.append(_record(source_id, delay, source_x, -side, beat_index, true))
	result.append(_record(target_id, delay, target_x, side, beat_index, false))
	return result


func _record(
	hazard_id: StringName,
	delay: float,
	world_x: float,
	facing: int,
	beat_index: int,
	auto_trigger: bool
) -> Dictionary:
	return {
		"hazard_id": hazard_id,
		"remaining": delay,
		"position": Vector2(world_x, CitySlice.LAND_VISUAL_BASELINE_Y),
		"facing": facing,
		"cost": EnvironmentalHazardCatalog.pressure_cost(hazard_id),
		"act_index": 5,
		"beat_index": beat_index,
		"beat_id": &"APEX_CHAIN",
		"auto_trigger": auto_trigger,
		"chain_pair": true,
	}


func _eligible_ids(act_index: int) -> Array[StringName]:
	if act_index <= 3:
		return [&"traffic_signal", &"steam_main", &"road_plate", &"metro_vent"]
	if act_index == 4:
		return [
			&"traffic_signal", &"steam_main", &"powerline", &"road_plate",
			&"crane_drop", &"gas_fireline", &"facade_shear", &"metro_vent",
		]
	return EnvironmentalHazardCatalog.ACTIVE_IDS.duplicate()
