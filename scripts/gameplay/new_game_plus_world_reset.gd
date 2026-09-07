class_name NewGamePlusWorldReset
extends RefCounted


static func execute(city: CitySlice) -> void:
	city.rampage_session.begin_new_game_plus_cycle()
	city.overdrive_session.end_overdrive()
	city.telegraph_presenter.cancel_all()
	city.projectile_root.release_all()
	city.encounter_runtime.release_all()
	city.enemy_remains_factory.release_all()
	city.soldier_defeat_pool.release_all()
	city.debris_pool.release_all()
	city.building_section_burst_pool.reset_all()
	city.enemy_scrap_pool.release_all()
	city.impact_feedback_director.cancel_all()
	city.impact_feedback_pool.reset_runtime_state()
	CityWorldBuilder.reset_environment(city)
	city.world_stream.reset_stream(city.urban_siege.run_seed, true)
	city.streamed_destructibles.reset_run(city.urban_siege.run_seed)
	city._refresh_primary_destructibles()
	city.camera_rig.reset_presentation()
	city.gameplay_hud.set_score(city.rampage_session.current_score())
	city.gameplay_hud.set_pending_score(0)
	city.gameplay_hud.set_momentum(0.0, 0)
	city.gameplay_hud.set_health(city.robot.current_health, city.robot.max_health)
