class_name TuningSandboxRunner
extends RefCounted

const ENEMY_IDS: Array[StringName] = [
	&"soldier", &"tank", &"helicopter", &"scout", &"aegis", &"static",
]
const REPAIR_GRANT: float = 100.0

var main: Main
var service: RuntimeTweakService


func setup(owner: Main, authority: RuntimeTweakService) -> void:
	main = owner
	service = authority


func enemy_ids() -> Array[StringName]:
	return ENEMY_IDS.duplicate()


func hazard_ids() -> Array[StringName]:
	return EnvironmentalHazardCatalog.ACTIVE_IDS.duplicate()


func spawn_enemy(identifier: StringName) -> Dictionary:
	var city: CitySlice = _city()
	if city == null or identifier not in ENEMY_IDS:
		return _denied(&"invalid_enemy")
	if not EnemyArchetypeCatalog.is_valid_kind(identifier):
		return _denied(&"unavailable_enemy")
	var enemy: EnemyActor2D = city.encounter_runtime.acquire(
		identifier,
		city.robot.global_position + Vector2(620.0, -80.0 if EnemyArchetypeCatalog.is_airborne(identifier) else 0.0)
	)
	if enemy == null:
		return _denied(&"pool_exhausted")
	service.mark_sandbox(StringName("spawn_enemy:%s" % identifier))
	return _accepted(&"enemy_spawned")


func spawn_hazard(identifier: StringName) -> Dictionary:
	var city: CitySlice = _city()
	if city == null or identifier not in EnvironmentalHazardCatalog.ACTIVE_IDS:
		return _denied(&"invalid_hazard")
	var hazard: EnvironmentalHazard2D = city.urban_siege.hazards.activate(
		identifier,
		city.robot.global_position + Vector2(640.0, 0.0),
		-1,
		false
	)
	if hazard == null:
		return _denied(&"pool_exhausted")
	service.mark_sandbox(StringName("spawn_hazard:%s" % identifier))
	return _accepted(&"hazard_spawned")


func clear_transient() -> Dictionary:
	var city: CitySlice = _city()
	if city == null:
		return _denied(&"no_active_run")
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	city.urban_siege.hazards.release_all()
	city.urban_siege.catalysts.deactivate_all()
	service.mark_sandbox(&"clear_transient")
	return _accepted(&"transient_cleared")


func repair_chassis() -> Dictionary:
	var city: CitySlice = _city()
	if city == null or city.robot == null:
		return _denied(&"no_active_run")
	var repaired: float = city.robot.repair_chassis(REPAIR_GRANT)
	if repaired <= 0.0:
		return _denied(&"chassis_full")
	service.mark_sandbox(&"repair_chassis")
	return {"ok": true, "reason": &"chassis_repaired", "amount": repaired}


func restart_with_seed(seed: int) -> Dictionary:
	if main == null or _city() == null:
		return _denied(&"no_active_run")
	main.call_deferred(&"retry_game_with_tuning_seed", maxi(seed, 0))
	return _accepted(&"restart_queued")


func _city() -> CitySlice:
	return main.city_slice if main != null and is_instance_valid(main.city_slice) else null


func _accepted(reason: StringName) -> Dictionary:
	return {"ok": true, "reason": reason}


func _denied(reason: StringName) -> Dictionary:
	return {"ok": false, "reason": reason}
