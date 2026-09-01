class_name MasteryEvaluator
extends RefCounted


static func evaluate(metrics: Dictionary) -> Dictionary:
	var sections: Dictionary[StringName, float] = {
		&"DISTRICT": 25.0 if bool(metrics.get("completed", false)) else 0.0,
		&"ACTS": clampf(float(metrics.get("highest_act", 0)) / 2.0, 0.0, 1.0) * 15.0,
		&"DEFENSE": maxf(20.0 - float(metrics.get("heavy_hits", 0)) * 4.0, 0.0),
		&"VARIETY": minf(float(metrics.get("unique_actions", 0)), 5.0) * 3.0,
		&"CAUSALITY": minf(float(metrics.get("causal_depth", 0)), 5.0) * 3.0,
		&"OVERDRIVE": minf(float(metrics.get("overdrives", 0)), 2.0) * 2.5,
		&"CONTRACT": 5.0 if bool(metrics.get("contract_succeeded", false)) else 0.0,
	}
	var points: int = 0
	var strongest: StringName = &"DISTRICT"
	var weakest: StringName = &"DISTRICT"
	var strongest_ratio: float = -1.0
	var weakest_ratio: float = 2.0
	var maximums: Dictionary[StringName, float] = {
		&"DISTRICT": 25.0, &"ACTS": 15.0, &"DEFENSE": 20.0,
		&"VARIETY": 15.0, &"CAUSALITY": 15.0, &"OVERDRIVE": 5.0,
		&"CONTRACT": 5.0,
	}
	for section: StringName in sections:
		points += roundi(sections[section])
		var ratio: float = sections[section] / maximums[section]
		if ratio > strongest_ratio:
			strongest = section
			strongest_ratio = ratio
		if ratio < weakest_ratio:
			weakest = section
			weakest_ratio = ratio
	var grade: StringName = grade_for(points, bool(metrics.get("completed", false)))
	return {
		"points": points,
		"grade": grade,
		"strongest": strongest,
		"weakest": weakest,
		"objective": _objective_for(weakest),
	}


static func grade_for(points: int, completed: bool) -> StringName:
	var grade: StringName = &"D"
	if points >= 90:
		grade = &"S"
	elif points >= 75:
		grade = &"A"
	elif points >= 60:
		grade = &"B"
	elif points >= 40:
		grade = &"C"
	if not completed and (grade == &"S" or grade == &"A" or grade == &"B"):
		grade = &"C"
	return grade


static func _objective_for(weakest: StringName) -> String:
	match weakest:
		&"DISTRICT":
			return "summary.retry.resolve_command_wreck"
		&"ACTS":
			return "summary.retry.reach_next_act"
		&"DEFENSE":
			return "summary.retry.take_fewer_heavy_hits"
		&"VARIETY":
			return "summary.retry.mix_actions"
		&"CAUSALITY":
			return "summary.retry.deeper_chain"
		&"OVERDRIVE":
			return "summary.retry.use_overdrive"
		_:
			return "summary.retry.complete_contract"
