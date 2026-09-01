class_name CityRunLifecycle
extends Node

signal run_finished(completed: bool, summary: RunSummarySnapshot)

const ACT_COUNT: int = 2

var city: CitySlice
var _pending_ending_id: StringName = &"NONE"


func setup(p_city: CitySlice) -> void:
	city = p_city
	city.rampage_session.momentum_meter.momentum_changed.connect(_on_momentum_changed)
	city.rampage_session.rare_event_tracker.tags_changed.connect(_on_rare_tags_changed)
	city.rampage_session.combo_tracker.combo_broken.connect(_on_combo_broken)
	city.rampage_session.combo_tracker.milestone_reached.connect(_on_combo_milestone)
	city.overdrive_session.activated.connect(_on_overdrive_activated)
	city.overdrive_session.time_changed.connect(_on_overdrive_time_changed)
	city.overdrive_session.ended.connect(_on_overdrive_ended)
	city.encounter_director.phase_changed.connect(_on_encounter_phase_changed)
	if city.urban_siege != null:
		city.urban_siege.district_completed.connect(_on_district_completed)
		city.urban_siege.beat_changed.connect(_on_beat_changed)
		city.urban_siege.recovery_started.connect(_on_recovery_started)
		city.urban_siege.directives.selected.connect(_on_directive_selected)
		city.urban_siege.directives.choices_offered.connect(_on_directive_choices_offered)
		city.urban_siege.directives.progress_changed.connect(_on_directive_progress)
		city.urban_siege.directives.bank_changed.connect(
			city.gameplay_hud.set_directive_bank
		)
		city.urban_siege.directives.completed.connect(_on_directive_completed)
		city.urban_siege.directives.failed.connect(_on_directive_failed)
		city.urban_siege.directives.withdrawn.connect(_on_directive_withdrawn)
		city.gameplay_hud.directive_choice_overlay.profile_selected.connect(
			city.urban_siege.directives.select
		)
		city.gameplay_hud.extract_pressed.connect(_on_extract_pressed)
		city.gameplay_hud.continue_pressed.connect(_on_continue_pressed)
		city.urban_siege.boss_session.state_changed.connect(_on_boss_state_changed)
		city.urban_siege.boss_session.armor_changed.connect(_on_boss_armor_changed)
		city.urban_siege.finale_choice_requested.connect(_on_finale_choice_requested)
		city.urban_siege.finale_resolved.connect(_on_finale_resolved)
		city.gameplay_hud.purge_pressed.connect(_on_purge_pressed)
		city.gameplay_hud.disentangle_pressed.connect(_on_disentangle_pressed)
	else:
		city.encounter_director.district_completed.connect(_on_district_completed)
	_on_momentum_changed(
		city.rampage_session.momentum_value(),
		city.rampage_session.momentum_meter.band()
	)
	if city.encounter_director.running:
		_on_encounter_phase_changed(
			city.encounter_director.phase_index,
			city.encounter_director.current_phase_name()
		)


func robot_defeated() -> void:
	if (
		city.urban_siege != null
		and city.urban_siege.boss_campaign != null
		and city.urban_siege.boss_campaign.fail_attempt()
	):
		city.game_over_active = true
		city.mobile_controls.set_controls_enabled(true)
		city.gameplay_hud.show_game_over(_boss_attempt_summary())
		return
	_finish_run(false)


func _boss_attempt_summary() -> RunSummarySnapshot:
	var run_metrics: Dictionary = {
		"completed": false,
		"boss_result": &"ATTEMPT_FAILED",
		"contract_result": &"FAILED",
		"defeat_source_id": city.last_player_damage_source_id,
	}
	if city.urban_siege != null:
		var directive: DirectiveProfile = city.urban_siege.directives.selected_profile
		run_metrics.directive_path = (
			directive.directive_id if directive != null else &"NONE"
		)
		run_metrics.run_seed = city.urban_siege.run_seed
		run_metrics.cycle_count = city.urban_siege.cycle_count
	var waves_cleared: int = clampi(
		city.encounter_director.phase_index + 1,
		0,
		ACT_COUNT
	)
	var summary: RunSummarySnapshot = city.rampage_session.snapshot_summary(
		waves_cleared,
		city.overdrive_session.activation_count,
		run_metrics
	)
	summary = _with_tuning_provenance(summary)
	if city.combat_profile != null:
		summary = summary.with_career_result({
			"new_combo_record": false,
			"new_score_record": false,
			"career_snapshot": city.combat_profile.snapshot(),
		})
	return summary


func _on_momentum_changed(value: float, band: int) -> void:
	_apply_movement_modifier()
	city.gameplay_hud.set_momentum(value, band)


func _on_overdrive_activated(_attack_id: int) -> void:
	_apply_movement_modifier()
	city.impact_feedback_pool.play_cue(
		AudioCueRegistry.Cue.OVERDRIVE_ACTIVATION,
		city.robot.global_position
	)
	city.gameplay_hud.set_overdrive(true, city.overdrive_session.remaining)
	city.gameplay_hud.set_objective("objective.overdrive_breakthrough")


func _on_overdrive_time_changed(remaining: float) -> void:
	city.gameplay_hud.set_overdrive(true, remaining)


func _on_overdrive_ended() -> void:
	_apply_movement_modifier()
	city.gameplay_hud.set_overdrive(false, 0.0)
	city.gameplay_hud.set_momentum(
		city.rampage_session.momentum_value(),
		city.rampage_session.momentum_meter.band()
	)


func _apply_movement_modifier() -> void:
	city.robot.set_acceleration_multiplier(
		city.rampage_session.momentum_meter.acceleration_multiplier()
		* city.overdrive_session.acceleration_multiplier()
	)


func _on_rare_tags_changed(tags: PackedStringArray) -> void:
	city.gameplay_hud.set_rare_tags(tags)


func _on_combo_broken() -> void:
	city.gameplay_hud.dismiss_combo_herald()
	city.impact_feedback_pool.play_cue(
		AudioCueRegistry.Cue.COMBO_BREAK,
		city.robot.global_position
	)


func _on_combo_milestone(tier: int, _chain_count: int, _multiplier: int) -> void:
	city.gameplay_hud.show_combo_milestone(tier)


func _on_encounter_phase_changed(index: int, display_name: String) -> void:
	city.gameplay_hud.set_objective("objective.act", {
		"current": index + 1,
		"total": ACT_COUNT,
		"name": L10n.t(display_name),
	})
	city.gameplay_hud.set_siege_progress(index, ACT_COUNT, display_name, false)


func _on_beat_changed(act_index: int, _beat_index: int, _beat_id: StringName) -> void:
	city.gameplay_hud.set_siege_progress(
		act_index,
		ACT_COUNT,
		city.encounter_director.current_phase_name(),
		false
	)


func _on_recovery_started(_duration: float) -> void:
	city.gameplay_hud.set_siege_progress(
		city.encounter_director.phase_index,
		ACT_COUNT,
		city.encounter_director.current_phase_name(),
		true
	)


func _on_directive_selected(profile: DirectiveProfile) -> void:
	city.upgrade_assembler.session.set_presentation_blocked(false)
	city.gameplay_hud.show_directive(
		profile,
		0,
		profile.target_count,
		0,
		city.urban_siege.directives
	)


func _on_directive_choices_offered(profiles: Array[DirectiveProfile]) -> void:
	city.upgrade_assembler.session.set_presentation_blocked(true)
	city.gameplay_hud.directive_choice_overlay.show_choices(profiles)


func _on_boss_state_changed(state: StringName) -> void:
	if city.urban_siege.boss_campaign.owns_combat():
		return
	var boss: CommandBossSession = city.urban_siege.boss_session
	var armor: float = boss.boss.boss_armor if boss.boss != null else 0.0
	var boss_id: StringName = boss.active_definition.boss_id if boss.active_definition != null else &""
	var maximum: float = boss.boss.boss_max_armor if boss.boss != null else CommandBossSession.ARMOR
	city.gameplay_hud.set_boss_status(state, armor, maximum, boss_id)
	var objective_key: String = (
		"objective.choir_prime" if boss_id == &"CHOIR_PRIME" else "objective.command_unit"
	)
	city.gameplay_hud.set_objective(objective_key, {
		"state": L10n.t("boss.state.%s" % String(state).to_lower()),
	})


func _on_boss_armor_changed(current: float, maximum: float) -> void:
	if city.urban_siege.boss_campaign.owns_combat():
		return
	var boss: CommandBossSession = city.urban_siege.boss_session
	var boss_id: StringName = boss.active_definition.boss_id if boss.active_definition != null else &""
	city.gameplay_hud.set_boss_status(boss.state, current, maximum, boss_id)


func _on_directive_progress(
	profile: DirectiveProfile,
	current: int,
	target: int
) -> void:
	city.gameplay_hud.set_directive_progress(profile, current, target)


func _on_directive_completed(profile: DirectiveProfile, banked_score: int) -> void:
	city.gameplay_hud.show_directive_result(L10n.t("directive.complete", {
		"name": L10n.t(profile.display_name),
	}), true, banked_score)


func _on_directive_failed(profile: DirectiveProfile, penalty: int) -> void:
	city.gameplay_hud.show_directive_result(L10n.t("directive.failed", {
		"name": L10n.t(profile.display_name),
		}), false, penalty)


func _on_directive_withdrawn() -> void:
	city.gameplay_hud.directive_card.hide_card()


func _on_district_completed() -> void:
	_on_final_act_completed()


func _on_final_act_completed() -> void:
	city.urban_siege.prepare_terminal_choice()
	city.gameplay_hud.show_cycle_choice(
		city.urban_siege.cycle_count,
		city.urban_siege.cycle_count < 2
	)


func _on_extract_pressed() -> void:
	city.urban_siege.release_terminal_choice()
	_finish_run(true, _pending_ending_id)


func _on_continue_pressed() -> void:
	if city.urban_siege.cycle_count >= 2:
		return
	city.prepare_new_game_plus_world()
	if city.urban_siege.continue_cycle():
		_pending_ending_id = &"NONE"
		city.upgrade_assembler.session.continue_cycle()
		city.gameplay_hud.hide_terminal_overlay()
		var recipe_key: String = (
			"siege.recipe.%s" % String(city.urban_siege.selected_recipe.recipe_id).to_lower()
		)
		city.gameplay_hud.set_objective("objective.cycle", {
			"cycle": city.urban_siege.cycle_count,
			"recipe": L10n.t(recipe_key),
		})


func _on_finale_choice_requested(snapshot: FinaleEligibilitySnapshot) -> void:
	city.gameplay_hud._show_finale_choice(snapshot)


func _on_purge_pressed() -> void:
	# The world-space PURGE receiver owns the action; the overlay is informational.
	city.gameplay_hud.set_objective("finale.receiver.purge_visible")


func _on_disentangle_pressed() -> void:
	# The world-space severance receiver owns the action and its five windows.
	city.gameplay_hud.set_objective("finale.receiver.disentangle_visible")


func _on_finale_resolved(outcome: int, _snapshot: FinaleEligibilitySnapshot) -> void:
	_pending_ending_id = BossOutcome.id_for(outcome)
	city.gameplay_hud._show_finale_result(
		outcome,
		city.urban_siege.cycle_count,
		city.urban_siege.cycle_count < 2
	)


func _finish_run(completed: bool, ending_id: StringName = &"NONE") -> void:
	if city.game_over_active:
		return
	city.game_over_active = true
	city.upgrade_assembler.session.stop_run()
	var run_metrics: Dictionary = {"completed": completed}
	if not completed:
		run_metrics.defeat_source_id = city.last_player_damage_source_id
	if city.urban_siege != null:
		var directive: DirectiveProfile = city.urban_siege.directives.selected_profile
		run_metrics.directive_path = (
			directive.directive_id if directive != null else &"NONE"
		)
		run_metrics.boss_result = (
			&"WRECK_RESOLVED"
			if city.urban_siege.boss_session.state == CommandBossSession.STATE_COMPLETE
			else &"UNRESOLVED"
		)
		run_metrics.contract_succeeded = city.urban_siege.contract_succeeded()
		run_metrics.contract_result = (
			&"COMPLETE" if bool(run_metrics.contract_succeeded) else &"FAILED"
		)
		run_metrics.run_seed = city.urban_siege.run_seed
		run_metrics.cycle_count = city.urban_siege.cycle_count
		run_metrics.ending_id = ending_id
		city.urban_siege.stop_run()
	else:
		city.encounter_director.stop()
	city.telegraph_presenter.cancel_all()
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	city.impact_feedback_director.cancel_all()
	city.impact_feedback_pool.reset_runtime_state()
	city.overdrive_session.end_overdrive()
	city.mobile_controls.set_controls_enabled(true)
	var waves_cleared: int = ACT_COUNT if completed else clampi(
		city.encounter_director.phase_index + 1,
		0,
		ACT_COUNT
	)
	var summary: RunSummarySnapshot = city.rampage_session.freeze_summary(
		waves_cleared,
		city.overdrive_session.activation_count,
		run_metrics
	)
	summary = _with_tuning_provenance(summary)
	if city.combat_profile != null:
		summary = city.combat_profile.enrich_and_submit(summary)
		city.rampage_session.frozen_summary = summary
	if city.leaderboard_bridge != null:
		city.leaderboard_bridge.submit_summary(summary)
	run_finished.emit(completed, summary)
	if completed:
		city.gameplay_hud.show_district_complete(summary)
	else:
		city.gameplay_hud.show_game_over(summary)


func _with_tuning_provenance(summary: RunSummarySnapshot) -> RunSummarySnapshot:
	var authority: RuntimeTweakService = RuntimeTweakAccess.service()
	if authority == null:
		return summary
	return summary.with_tuning_provenance(authority.provenance_snapshot())
