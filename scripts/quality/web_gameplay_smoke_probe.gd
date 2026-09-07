extends Node

const EVENT_ID: int = 990_001
const MAX_WAIT_FRAMES: int = 600

var city: Node
var robot: GiantRobotController
var sprite: AnimatedSprite2D
var presenter: RobotAnimationPresenter
var session: UpgradeSession
var overlay: UpgradeChoiceOverlay
var _phase_index: int = 0


func setup(p_city: Node) -> void:
	name = "WebGameplaySmokeProbe"
	city = p_city
	robot = city.robot
	sprite = robot.get_node(^"VisualRoot/RobotAnimatedSprite") as AnimatedSprite2D
	presenter = robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	session = city.upgrade_assembler.session
	overlay = city.gameplay_hud.upgrade_choice_overlay
	call_deferred(&"_run")


func _run() -> void:
	_prepare_environment()
	var main: Node = city.get_parent()
	var background_music_player: AudioStreamPlayer = null
	if main != null:
		background_music_player = main.get("background_music_player") as AudioStreamPlayer
	_publish(&"ready", {
		"animation": String(sprite.animation),
		"background_music_playing": (
			background_music_player != null
			and background_music_player.playing
		),
		"facing": robot.facing,
	})
	if not await _run_charged_input():
		return
	if not await _run_upgrade_transition():
		return
	if not await _run_post_upgrade_sfx():
		return
	if not _run_kill_combo():
		return
	if not await _run_east_walk():
		return
	if not await _run_west_walk():
		return
	await _request_browser_defeat()


func _prepare_environment() -> void:
	if city.gameplay_hud.first_run_tutorial != null:
		city.gameplay_hud.first_run_tutorial._finish_tutorial(true)
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	robot.collision_mask = 0
	robot.gravity = 0.0
	robot.velocity = Vector2.ZERO


func _run_charged_input() -> bool:
	if not await _wait_until(func() -> bool: return city.contextual_attacks.is_charging()):
		_fail("browser smash key-down did not begin charging")
		return false
	_publish(&"charge_started", {
		"animation": String(sprite.animation),
		"frame": sprite.frame,
		"particles": presenter.charge_particles_emitting(),
	})
	if not await _wait_until(
		func() -> bool: return city.contextual_attacks.charge_progress() >= 0.35
	):
		_fail("held browser smash did not advance charge progress")
		return false
	_publish(&"charge_progress", {
		"duration": city.contextual_attacks.charge_duration(),
		"progress": city.contextual_attacks.charge_progress(),
		"multiplier": city.contextual_attacks.charge_damage_multiplier(),
		"frame": sprite.frame,
		"particles": presenter.charge_particles_emitting(),
	})
	if not await _wait_until(func() -> bool: return not city.contextual_attacks.is_charging()):
		_fail("browser smash key-up did not release charge")
		return false
	var released_spec: AttackSpec = city.contextual_attacks.current_spec
	if released_spec == null:
		_fail("released browser charge lost its attack specification")
		return false
	_publish(&"charge_released", {
		"damage": released_spec.actor_damage,
		"animation": String(sprite.animation),
		"frame": sprite.frame,
		"playing": sprite.is_playing(),
	})
	if not await _wait_until(func() -> bool: return not city.contextual_attacks.is_busy()):
		_fail("released browser charge did not finish its melee animation")
		return false
	return true


func _run_upgrade_transition() -> bool:
	if not await _begin_upgrade_transition():
		return false
	if not await _finish_upgrade_transition():
		return false
	return true


func _begin_upgrade_transition() -> bool:
	if robot.request_attack() <= 0:
		_fail("initial melee request was rejected")
		return false
	if not await _wait_until(func() -> bool: return presenter.attacking):
		_fail("initial melee animation did not start")
		return false
	_publish(&"attack_started", {
		"animation": String(sprite.animation),
		"attack_id": presenter.selected_attack_id,
	})
	if not session.queue_level(2, EVENT_ID):
		_fail("upgrade entitlement was rejected")
		return false
	if not await _wait_until(_upgrade_is_interactive):
		_fail("upgrade overlay did not become interactive")
		return false
	if presenter.attacking or city.contextual_attacks.is_busy():
		_fail("upgrade pause retained the cancelled melee animation")
		return false
	_publish(&"upgrade_visible", {
		"animation": String(sprite.animation),
		"choices": Array(session.active_offer.choice_ids),
		"offer_sequence": session.active_offer.sequence,
	})
	return true


func _finish_upgrade_transition() -> bool:
	if not await _wait_until(_upgrade_has_resolved):
		_fail("browser did not resolve the upgrade offer")
		return false
	if presenter.attacking:
		_fail("animation presenter remained attack-locked after upgrade resolution")
		return false
	_publish(&"upgrade_resolved", {
		"animation": String(sprite.animation),
		"rank_total": _rank_total(),
	})
	return true


func _run_post_upgrade_sfx() -> bool:
	robot.global_position.x = 2800.0
	var ground: Dictionary = await _capture_attack_sfx(
		false,
		RobotAnimationPresenter.GROUND_SLAM_IMPACT_SFX,
		&"ground_slam_impact"
	)
	if not bool(ground.get("ok", false)):
		_fail("post-upgrade ground slam SFX did not play at the robot")
		return false
	var punch: Dictionary = await _capture_attack_sfx(
		true,
		RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX,
		&"double_punch_impact"
	)
	if not bool(punch.get("ok", false)):
		_fail("post-upgrade punch SFX did not play at the robot")
		return false
	var dash: Dictionary = await _capture_dash_sfx()
	if not bool(dash.get("ok", false)):
		_fail("post-upgrade Dash or recharge SFX did not play")
		return false
	var feedback: ImpactFeedbackPool = city.impact_feedback_pool
	_publish(&"post_upgrade_sfx_ok", {
		"ground": ground,
		"punch": punch,
		"dash": dash,
		"upgrade_confirm_count": feedback.cue_play_count,
		"upgrade_confirm_cue": feedback.last_cue,
		"audio_drop_count": presenter.audio_drop_count,
	})
	return feedback.cue_play_count >= 1 and presenter.audio_drop_count == 0


func _run_kill_combo() -> bool:
	var score_before: int = city.score
	var targets: Array[EnemyActor2D] = [city.soldier, city.tank, city.helicopter]
	for index: int in range(targets.size()):
		if not city.rampage_events.enemy_defeated(
			targets[index],
			DamageEvent.new(EVENT_ID + 100 + index, robot, 999.0, &"smoke_kill"),
			100,
			robot
		):
			_fail("exported runtime rejected deterministic kill combo event")
			return false
	var awarded: int = city.score - score_before
	if city.rampage_session.current_multiplier() != 2 or awarded != 200:
		_fail("exported runtime did not normalize three physical kills to 200 score at x2")
		return false
	var herald: ComboHerald = city.gameplay_hud.combo_herald
	if (
		herald.last_tier != 2
		or herald.title_label.text != "DOUBLE KILL"
		or herald.presentation_count != 1
		or herald.audio_play_count != 1
		or not herald.is_presenting()
	):
		_fail("exported runtime did not present the Double Kill combat herald")
		return false
	_publish(&"kill_combo_ok", {
		"awarded": awarded,
		"multiplier": city.rampage_session.current_multiplier(),
		"label": city.gameplay_hud.combo_label.text,
		"herald_tier": herald.last_tier,
		"herald_title": herald.title_label.text,
		"herald_presentations": herald.presentation_count,
		"herald_audio_plays": herald.audio_play_count,
		"herald_voice_bus": String(herald.voice_player.bus),
	})
	var pending_before: int = city.rampage_session.run_score.pending_bank.value
	if not robot.receive_damage(DamageEvent.new(
		EVENT_ID + 200,
		city.soldier,
		1.0,
		&"smoke_damage"
	)):
		_fail("exported runtime rejected deterministic combo-break damage")
		return false
	if (
		city.rampage_session.current_multiplier() != 1
		or city.rampage_session.combo_tracker.current_chain_count != 0
		or city.rampage_session.run_score.pending_bank.value != pending_before
		or herald.is_presenting()
		or herald.voice_player.playing
	):
		_fail("accepted light damage did not break only the kill combo")
		return false
	_publish(&"kill_combo_reset_ok", {
		"multiplier": city.rampage_session.current_multiplier(),
		"pending": pending_before,
		"health": robot.current_health,
	})
	return true


func _capture_attack_sfx(
	punch: bool,
	stream: AudioStream,
	expected_cue: StringName
) -> Dictionary:
	var impact_before: int = presenter.attack_impact_play_count
	robot.velocity.x = robot.max_speed if punch else 0.0
	var attack_id: int = robot.request_attack()
	if attack_id <= 0:
		return {"ok": false, "reason": "attack_rejected"}
	if not await _wait_until(
		func() -> bool: return presenter.attack_impact_play_count > impact_before
	):
		return {"ok": false, "reason": "impact_timeout"}
	var voice: AudioStreamPlayer2D = _voice_for_stream(stream)
	var snapshot: Dictionary = _voice_snapshot(voice)
	snapshot.ok = (
		voice != null
		and voice.playing
		and presenter.last_audio_cue == expected_cue
		and float(snapshot.distance_to_robot) <= 1.0
	)
	snapshot.attack_id = attack_id
	snapshot.cue = String(presenter.last_audio_cue)
	snapshot.length_seconds = stream.get_length()
	if not await _wait_until(func() -> bool: return not city.contextual_attacks.is_busy()):
		snapshot.ok = false
		snapshot.reason = "attack_finish_timeout"
	return snapshot


func _capture_dash_sfx() -> Dictionary:
	var warp_before: int = presenter.dash_warp_sfx_play_count
	var recharge_before: int = presenter.dodge_recharged_sfx_play_count
	robot.velocity = Vector2.ZERO
	if not robot._start_dodge(1):
		return {"ok": false, "reason": "dash_rejected"}
	if not await _wait_until(
		func() -> bool: return presenter.dash_warp_sfx_play_count > warp_before
	):
		return {"ok": false, "reason": "warp_timeout"}
	var voice: AudioStreamPlayer2D = _voice_for_stream(
		RobotAnimationPresenter.DASH_WARP_SFX
	)
	var snapshot: Dictionary = _voice_snapshot(voice)
	if not await _wait_until(
		func() -> bool:
			return presenter.dodge_recharged_sfx_play_count > recharge_before
	):
		snapshot.ok = false
		snapshot.reason = "recharge_timeout"
		return snapshot
	snapshot.ok = voice != null and float(snapshot.distance_to_robot) <= 1.0
	snapshot.warp_count = presenter.dash_warp_sfx_play_count
	snapshot.recharge_count = presenter.dodge_recharged_sfx_play_count
	return snapshot


func _voice_for_stream(stream: AudioStream) -> AudioStreamPlayer2D:
	for voice: AudioStreamPlayer2D in presenter._audio_players:
		if voice.stream == stream:
			return voice
	return null


func _voice_snapshot(voice: AudioStreamPlayer2D) -> Dictionary:
	if voice == null:
		return {"playing": false, "distance_to_robot": INF, "stream": ""}
	return {
		"playing": voice.playing,
		"distance_to_robot": voice.global_position.distance_to(robot.global_position),
		"max_distance": voice.max_distance,
		"volume_db": voice.volume_db,
		"stream": voice.stream.resource_path if voice.stream != null else "",
	}


func _run_east_walk() -> bool:
	var servo_before: int = presenter.servo_play_count
	var footstep_before: int = presenter.footstep_play_count
	if not await _wait_until(_walking_east):
		_fail("east walking animation did not start after the upgrade")
		return false
	var east_start_frame: int = sprite.frame
	if not await _wait_for_frame_advance(&"walk_e", east_start_frame):
		_fail("east walking animation did not advance after the upgrade")
		return false
	if not await _wait_until(
		func() -> bool:
			return (
				presenter.servo_play_count > servo_before
				and presenter.footstep_play_count > footstep_before
			)
	):
		_fail("post-upgrade walk servo or footstep SFX did not play")
		return false
	_publish(&"east_walk_ok", {
		"animation": String(sprite.animation),
		"frame_before": east_start_frame,
		"frame_after": sprite.frame,
		"servo_count": presenter.servo_play_count,
		"footstep_count": presenter.footstep_play_count,
	})
	return true


func _run_west_walk() -> bool:
	if not await _wait_until(_walking_west):
		_fail("west walking animation did not start after the upgrade")
		return false
	var west_start_frame: int = sprite.frame
	if not await _wait_for_frame_advance(&"walk_w", west_start_frame):
		_fail("west walking animation did not advance after the upgrade")
		return false
	_publish(&"pass", {
		"animation": String(sprite.animation),
		"frame_before": west_start_frame,
		"frame_after": sprite.frame,
		"rank_total": _rank_total(),
	})
	return true


func _request_browser_defeat() -> void:
	if not OS.has_feature("web"):
		return
	if not await _wait_until(
		func() -> bool:
			return bool(JavaScriptBridge.eval("Boolean(window.__PROTO_SCROLLER_TRIGGER_DEFEAT__)"))
	):
		_fail("browser did not arm the deterministic defeat transition")
		return
	var fatal_event: DamageEvent = DamageEvent.new(EVENT_ID + 1, null, 99_999.0)
	if not robot.receive_damage(fatal_event):
		_fail("browser fatal damage was rejected")
		return
	_publish(&"defeat_requested", {"health": robot.current_health})


func _upgrade_is_interactive() -> bool:
	return (
		overlay.active
		and session.active_offer != null
		and not overlay.cards.is_empty()
		and not overlay.cards[0].disabled
	)


func _upgrade_has_resolved() -> bool:
	return (
		not overlay.active
		and session.active_offer == null
		and session.state == UpgradeSession.State.IDLE
		and not city.urban_siege.pause_coordinator.is_paused()
	)


func _walking_east() -> bool:
	return (
		robot.locomotion_state == GiantRobotController.LocomotionState.WALK
		and robot.facing > 0
		and sprite.animation == &"walk_e"
		and sprite.is_playing()
	)


func _walking_west() -> bool:
	return (
		robot.locomotion_state == GiantRobotController.LocomotionState.WALK
		and robot.facing < 0
		and sprite.animation == &"walk_w"
		and sprite.is_playing()
	)


func _wait_until(predicate: Callable) -> bool:
	for _frame: int in range(MAX_WAIT_FRAMES):
		if predicate.call():
			return true
		await get_tree().process_frame
	return false


func _wait_for_frame_advance(animation: StringName, start_frame: int) -> bool:
	for _frame: int in range(MAX_WAIT_FRAMES):
		if sprite.animation == animation and sprite.is_playing() and sprite.frame != start_frame:
			return true
		await get_tree().process_frame
	return false


func _rank_total() -> int:
	var total: int = 0
	for rank: int in session.ranks.values():
		total += rank
	return total


func _publish(status: StringName, details: Dictionary = {}) -> void:
	_phase_index += 1
	var payload: Dictionary = {
		"status": String(status),
		"phase_index": _phase_index,
		"details": details,
	}
	print("[WEB-GAMEPLAY-SMOKE] %s" % JSON.stringify(payload))
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			(
				"window.__PROTO_SCROLLER_SMOKE_HISTORY__ ??= []; "
				+ "window.__PROTO_SCROLLER_SMOKE_HISTORY__.push(%s); "
				+ "window.__PROTO_SCROLLER_SMOKE__ = %s; "
				+ "document.body.dataset.webSmoke = %s;"
			) % [
				JSON.stringify(payload),
				JSON.stringify(payload),
				JSON.stringify(String(status)),
			]
		)


func _fail(message: String) -> void:
	_publish(&"fail", {"message": message})
	push_error("Web gameplay smoke failed: %s" % message)
