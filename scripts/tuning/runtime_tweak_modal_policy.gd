class_name RuntimeTweakModalPolicy
extends RefCounted


static func entry_status(city: CitySlice) -> Dictionary:
	if city == null or not is_instance_valid(city):
		return {"allowed": true, "reason": &"title"}
	if city.urban_siege == null or city.urban_siege.pause_coordinator == null:
		return {"allowed": false, "reason": &"simulation_unavailable"}
	return {"allowed": true, "reason": &""}