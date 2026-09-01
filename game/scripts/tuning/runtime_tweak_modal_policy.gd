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
	if city.gameplay_hud != null:
		if city.gameplay_hud.upgrade_choice_overlay != null and city.gameplay_hud.upgrade_choice_overlay.visible:
			return {"allowed": false, "reason": &"upgrade_choice"}
	if (
		city.weapon_shop_assembler != null
		and city.weapon_shop_assembler.overlay != null
		and city.weapon_shop_assembler.overlay.visible
	):
		return {"allowed": false, "reason": &"weapon_shop"}
	return {"allowed": true, "reason": &""}
