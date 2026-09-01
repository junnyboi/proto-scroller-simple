class_name RuntimeTweakModalPolicy
extends RefCounted


static func entry_status(city: CitySlice) -> Dictionary:
	if city == null or not is_instance_valid(city):
		return {"allowed": false, "reason": &"no_active_run"}
	if city.game_over_active:
		return {"allowed": false, "reason": &"debrief_active"}
	if city.urban_siege == null or city.urban_siege.pause_coordinator == null:
		return {"allowed": false, "reason": &"simulation_unavailable"}
	var coordinator: RunPauseCoordinator = city.urban_siege.pause_coordinator
	if coordinator.is_paused():
		return {
			"allowed": false,
			"reason": coordinator.lease_reasons()[0] if not coordinator.lease_reasons().is_empty() else &"modal_active",
		}
	return {"allowed": true, "reason": &""}
