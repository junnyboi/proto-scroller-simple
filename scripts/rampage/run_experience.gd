class_name RunExperience
extends Node

signal experience_changed(level: int, current: int, required: int)
signal level_gained(level: int, accepted_event_id: int)

const BASE_REQUIREMENT: int = 500
const GROWTH_FACTOR: float = 1.35
const REQUIREMENT_MULTIPLIER: int = 18
const REQUIREMENT_REDUCTION: float = 0.10
const MAX_LEVEL: int = 999
const MAX_EXPERIENCE: int = 2_000_000_000

var level: int = 1
var current_experience: int = 0
var total_experience: int = 0


static func required_for_level(source_level: int) -> int:
	var exponent: int = maxi(source_level - 1, 0)
	var base_requirement: int = int(RuntimeTweakAccess.run_value(
		&"progression.xp.base_requirement", BASE_REQUIREMENT
	))
	var growth_factor: float = float(RuntimeTweakAccess.run_value(
		&"progression.xp.growth_factor", GROWTH_FACTOR
	))
	var curve_requirement: int = maxi(
		roundi(float(base_requirement) * pow(growth_factor, exponent)),
		1
	)
	var reduced_requirement: int = roundi(
		float(curve_requirement * REQUIREMENT_MULTIPLIER)
		* (1.0 - REQUIREMENT_REDUCTION)
	)
	return mini(maxi(reduced_requirement, 1), MAX_EXPERIENCE)


func apply_event(event: GameplayEvent) -> int:
	if event == null or event.event_id <= 0:
		return 0
	return add_experience(event.base_points, event.event_id)


func add_experience(amount: int, accepted_event_id: int = 0) -> int:
	var accepted: int = mini(maxi(amount, 0), MAX_EXPERIENCE - total_experience)
	if accepted <= 0 or level >= MAX_LEVEL:
		return 0
	total_experience += accepted
	current_experience += accepted
	var levels_gained: int = 0
	while level < MAX_LEVEL and current_experience >= required_for_level(level):
		current_experience -= required_for_level(level)
		level += 1
		levels_gained += 1
		if accepted_event_id > 0:
			level_gained.emit(level, accepted_event_id)
	if level >= MAX_LEVEL:
		current_experience = 0
	experience_changed.emit(level, current_experience, experience_required())
	return levels_gained


func capture_attempt_state() -> Dictionary:
	return {
		"level": level,
		"current": current_experience,
		"total": total_experience,
	}


func restore_attempt_state(state: Dictionary) -> void:
	level = int(state.get("level", level))
	current_experience = int(state.get("current", current_experience))
	total_experience = int(state.get("total", total_experience))
	experience_changed.emit(level, current_experience, experience_required())


func experience_required() -> int:
	return required_for_level(level) if level < MAX_LEVEL else 0


func progress_ratio() -> float:
	var required: int = experience_required()
	return clampf(float(current_experience) / float(required), 0.0, 1.0) if required > 0 else 1.0


func reset_run() -> void:
	level = 1
	current_experience = 0
	total_experience = 0
	experience_changed.emit(level, current_experience, experience_required())
