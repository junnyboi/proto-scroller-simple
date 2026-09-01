extends Node

const EVENT_ID: int = 990_001
const MAX_WAIT_FRAMES: int = 600

var city: Node
var robot: GiantRobotController
var sprite: AnimatedSprite2D
var presenter: RobotAnimationPresenter
var _phase_index: int = 0


func setup(p_city: Node) -> void:
	name = "WebGameplaySmokeProbe"
	city = p_city
	robot = city.robot
	sprite = robot.get_node(^"VisualRoot/RobotAnimatedSprite") as AnimatedSprite2D
	presenter = robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	call_deferred(&"_run")


func _run() -> void:
	_prepare_environment()
	var main: Node = city.get_parent()
	var background_music_player: AudioStreamPlayer
	if main != null:
		background_music_player = main.get("background_music_player") as AudioStreamPlayer
	_publish(&"ready", {
		"animation": String(sprite.animation),
		"background_music_playing": (
			background_music_player != null and background_music_player.playing
		),
		"facing": robot.facing,
	})
	if not await _run_charged_input():
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


func _run_east_walk() -> bool:
	var servo_before: int = presenter.servo_play_count
	var footstep_before: int = presenter.footstep_play_count
	if not await _wait_until(_walking_east):
		_fail("east walking animation did not start")
		return false
	var east_start_frame: int = sprite.frame
	if not await _wait_for_frame_advance(&"walk_e", east_start_frame):
		_fail("east walking animation did not advance")
		return false
	if not await _wait_until(
		func() -> bool:
			return (
				presenter.servo_play_count > servo_before
				and presenter.footstep_play_count > footstep_before
			)
	):
		_fail("walk servo or footstep SFX did not play")
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
		_fail("west walking animation did not start")
		return false
	var west_start_frame: int = sprite.frame
	if not await _wait_for_frame_advance(&"walk_w", west_start_frame):
		_fail("west walking animation did not advance")
		return false
	_publish(&"pass", {
		"animation": String(sprite.animation),
		"frame_before": west_start_frame,
		"frame_after": sprite.frame,
	})
	return true


func _request_browser_defeat() -> void:
	if not OS.has_feature("web"):
		return
	if not await _wait_until(
		func() -> bool:
			return bool(JavaScriptBridge.eval(
				"Boolean(window.__PROTO_SCROLLER_TRIGGER_DEFEAT__)"
			))
	):
		_fail("browser did not arm the deterministic defeat transition")
		return
	var fatal_event: DamageEvent = DamageEvent.new(EVENT_ID + 1, null, 99_999.0)
	if not robot.receive_damage(fatal_event):
		_fail("browser fatal damage was rejected")
		return
	_publish(&"defeat_requested", {"health": robot.current_health})


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
