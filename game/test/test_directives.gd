extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const BREACH: DirectiveProfile = preload(
	"res://resources/directives/demolition_breach.tres"
)

var city: CitySlice
var session: DirectiveSession


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	session = city.urban_siege.directives


func test_breach_decorates_jab_cross_only_and_caps_multiplier() -> void:
	assert_true(session.select(BREACH))
	var jab_cross: AttackSpec = city.contextual_attacks.resolver.resolve(
		100,
		1,
		0.8,
		100.0,
		1000.0,
		96.0
	)
	var modified_jab_cross: AttackSpec = session.decorate_attack(jab_cross)
	assert_almost_eq(modified_jab_cross.structural_damage, 187.5, 0.01)
	assert_eq(modified_jab_cross.effect_flags, DamageEvent.FLAG_DIRECTIVE_BREACH)
	var smash: AttackSpec = city.contextual_attacks.resolver.resolve(
		101,
		1,
		0.2,
		100.0,
		1000.0,
		96.0
	)
	assert_almost_eq(session.decorate_attack(smash).structural_damage, 200.0, 0.01)


func test_failure_deducts_twenty_percent_of_secured_run_score() -> void:
	var penalties: Array[int] = []
	session.failed.connect(
		func(_profile: DirectiveProfile, penalty: int) -> void:
			penalties.append(penalty)
	)
	assert_true(session.select(BREACH))
	assert_true(city.rampage_session.publish(GameplayEvent.new(
		&"directive_score",
		401,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		100,
		6.0,
		true
	)))
	assert_eq(session.pending_score, 25)
	session._process(BREACH.duration_seconds)
	assert_eq(city.score, 80)
	assert_eq(penalties, [20])
	assert_eq(session.failure_count, 1)
	assert_false(session.is_active())
	assert_eq(city.gameplay_hud.directive_card.bank_label.text, "SCORE -20")


func test_failure_penalty_is_nonzero_when_directive_bank_is_empty() -> void:
	assert_true(city.rampage_session.publish(GameplayEvent.new(
		&"secured_score_before_directive",
		402,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		500,
		6.0,
		true
	)))
	assert_eq(city.score, 500)
	assert_true(session.select(BREACH))
	assert_eq(session.pending_score, 0)
	session._process(BREACH.duration_seconds)
	assert_eq(city.score, 400)
	assert_eq(city.gameplay_hud.directive_card.bank_label.text, "SCORE -100")


func test_mission_failure_never_despawns_enemies_or_stalls_empty_pressure() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	city.encounter_runtime.release_all()
	var survivor: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier", Vector2(1180.0, EncounterRuntime.LAND_ENEMY_VISUAL_BASELINE_Y)
	)
	assert_not_null(survivor)
	var act: DistrictAct = director.district.acts[0]
	director.running = true
	director.completed = false
	director.phase_index = 0
	director.beat_index = act.beats.size() - 1
	director.state = DistrictResponseDirector.STATE_WAITING
	director.act_elapsed = (
		director._scaled_target_duration(act)
		+ EnemySpawnTuning.scaled_interval(DistrictResponseDirector.MAXIMUM_ACT_OVERRUN)
		+ 0.01
	)
	director.hold_act_advance()
	assert_true(session.select(BREACH))
	session._process(BREACH.duration_seconds)
	director._try_start_next_beat()
	assert_true(survivor.active)
	assert_eq(city.encounter_runtime.active_count(), 1)
	city.encounter_runtime.release(survivor)
	var started_before: int = director.started_beat_count()
	director._try_start_next_beat()
	assert_gt(director.started_beat_count(), started_before)
	assert_gt(director.pending_count(), 0)
	for _step: int in range(120):
		director.advance(0.1)
		if city.encounter_runtime.active_count() > 0:
			break
	assert_gt(city.encounter_runtime.active_count(), 0)


func test_breach_completes_after_three_accepted_cells() -> void:
	assert_true(session.select(BREACH))
	for index: int in range(3):
		session._on_event_published(GameplayEvent.new(
			StringName("directive_cell_%d" % index),
			500 + index,
			GameplayEvent.Kind.CELL_DESTROYED,
			GameplayEvent.CELL_BREACH,
			300,
			12.0,
			true
		))
	assert_eq(session.completion_count, 1)
	assert_false(session.is_active())


func test_directive_card_is_noninteractive_and_above_mobile_smash() -> void:
	city.gameplay_hud.show_directive(BREACH, 0, BREACH.target_count, 0)
	var card: DirectiveCard = city.gameplay_hud.directive_card
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(card.get_global_rect().intersects(city.mobile_controls.smash_bounds()))
	assert_not_null(card.icon.texture)
	assert_eq(card.size, DirectiveCard.LANDSCAPE_SIZE)
	assert_lte(card.title_label.position.x + card.title_label.size.x, card.size.x)
	assert_lte(card.detail_label.position.x + card.detail_label.size.x, card.size.x)
	assert_lte(card.bank_label.position.x + card.bank_label.size.x, card.size.x)
	assert_lte(card.progress_track.position.x + card.progress_track.size.x, card.size.x)
	assert_lte(card.timer_track.position.x + card.timer_track.size.x, card.size.x)


func test_active_card_shows_authoritative_countdown_and_objective_ratio() -> void:
	assert_true(session.select(BREACH))
	var card: DirectiveCard = city.gameplay_hud.directive_card
	assert_true(card.visible)
	assert_eq(card.timer_label.text, "14s")
	assert_eq(card.progress_label.text, "OBJECTIVE 0/3")
	assert_almost_eq(card._timer_ratio, 1.0, 0.001)
	assert_almost_eq(card._progress_ratio, 0.0, 0.001)
	session._process(3.5)
	card._process(0.0)
	assert_eq(card.timer_label.text, "11s")
	assert_almost_eq(card._timer_ratio, 0.75, 0.001)
	session._on_event_published(GameplayEvent.new(
		&"directive_live_progress",
		601,
		GameplayEvent.Kind.CELL_DESTROYED,
		GameplayEvent.CELL_BREACH,
		100,
		4.0,
		true
	))
	assert_eq(card.progress_label.text, "OBJECTIVE 1/3")
	assert_almost_eq(card._progress_ratio, 1.0 / 3.0, 0.001)
	assert_almost_eq(
		card.progress_fill.size.x,
		card._progress_width / 3.0,
		0.01
	)


func test_countdown_freezes_during_pause_and_text_updates_by_second() -> void:
	assert_true(session.select(BREACH))
	var card: DirectiveCard = city.gameplay_hud.directive_card
	var assignments: int = card.countdown_text_assignment_count
	for frame: int in range(60):
		card._process(1.0 / 60.0)
	assert_eq(card.countdown_text_assignment_count, assignments)
	var remaining_before: float = session.remaining
	var token: int = city.urban_siege.pause_coordinator.acquire(&"directive_timer_test")
	session._process(2.0)
	card._process(2.0)
	assert_almost_eq(session.remaining, remaining_before, 0.001)
	assert_eq(card.timer_label.text, "14s")
	assert_true(city.urban_siege.pause_coordinator.release(token))
	session._process(1.1)
	card._process(0.0)
	assert_almost_eq(session.remaining, remaining_before - 1.1, 0.001)
	assert_eq(card.timer_label.text, "13s")
	assert_eq(card.countdown_text_assignment_count, assignments + 1)


func test_active_card_updates_in_place_without_node_growth() -> void:
	assert_true(session.select(BREACH))
	var card: DirectiveCard = city.gameplay_hud.directive_card
	var child_count: int = card.get_child_count()
	for frame: int in range(240):
		session._process(1.0 / 60.0)
		card._process(1.0 / 60.0)
	assert_eq(card.get_child_count(), child_count)
	assert_lte(card.countdown_text_assignment_count, ceili(BREACH.duration_seconds) + 1)


func test_directive_result_card_dismisses_after_bounded_hold() -> void:
	city.gameplay_hud.show_directive_result("DEMOLITION BREACH FAILED", false, 100)
	var card: DirectiveCard = city.gameplay_hud.directive_card
	assert_true(card.visible)
	assert_eq(card.bank_label.text, "SCORE -100")
	card._process(DirectiveCard.RESULT_DISPLAY_SECONDS + 0.01)
	assert_false(card.visible)


func test_choice_overlay_pauses_runtime_and_selects_exactly_once() -> void:
	var momentum_before: float = city.rampage_session.momentum_value()
	var projectile_process_before: int = city.projectile_root.process_mode
	session.offer(8)
	assert_true(city.urban_siege.is_simulation_paused())
	assert_true(city.gameplay_hud.directive_choice_overlay.visible)
	assert_eq(city.urban_siege.pause_coordinator.lease_count(), 1)
	assert_eq(city.projectile_root.process_mode, Node.PROCESS_MODE_DISABLED)
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	var paused_x: float = city.robot.global_position.x
	city.robot.physics_step(1.0, 0.2)
	assert_gt(city.robot.global_position.x, paused_x)
	city._process(1.0)
	assert_almost_eq(city.rampage_session.momentum_value(), momentum_before, 0.001)
	city.gameplay_hud.directive_choice_overlay.buttons[0].pressed.emit()
	assert_false(city.urban_siege.is_simulation_paused())
	assert_false(city.gameplay_hud.directive_choice_overlay.visible)
	assert_not_null(session.active_profile)
	assert_eq(city.projectile_root.process_mode, projectile_process_before)
	assert_false(session.select(BREACH))
