class_name ContextualAttackController
extends Node

signal attack_started(spec: AttackSpec)
signal attack_active(spec: AttackSpec)
signal attack_finished(spec: AttackSpec)
signal dodge_buffered(attack_id: int, direction: int)
signal charge_started(spec: AttackSpec)
signal charge_updated(spec: AttackSpec, duration: float, progress: float, multiplier: float)
signal charge_released(spec: AttackSpec, duration: float, multiplier: float)
signal attack_cancelled(spec: AttackSpec)
signal full_charge_enemy_hit(spec: AttackSpec, world_position: Vector2, enemy_count: int)

enum Phase {
	READY,
	CHARGING,
	ANTICIPATION,
	ACTIVE,
	RECOVERY,
}

const DODGE_CANCEL_MELEE_MOMENTUM_RATIO: float = 0.50
const MAX_CHARGE_SECONDS: float = 2.0
const MAX_CHARGE_DAMAGE_MULTIPLIER: float = 2.0
const FULL_CHARGE_RELEASE_GRACE_SECONDS: float = 0.05

var current_spec: AttackSpec
var resolver: AttackResolver
var jab_cross_impact: JabCrossImpact
var overdrive_session: OverdriveSession
var directive_session: DirectiveSession
var kinetic_field_runtime: KineticFieldRuntime
var shop_upgrade_runtime: WeaponShopUpgradeRuntime
var phase: Phase = Phase.READY
var buffered_dodge_count: int = 0
var _robot: GiantRobotController
var _visual_root: Node2D
var _rest_position: Vector2
var _rest_scale: Vector2 = Vector2.ONE
var _rest_rotation: float = 0.0
var _busy: bool = false
var _buffered_dodge_direction: int = 0
var _charging: bool = false
var _charge_duration: float = 0.0
var _active_charge_limit: float = MAX_CHARGE_SECONDS
var _last_full_charge_hit_attack_id: int = 0


func setup(robot: GiantRobotController) -> void:
	_robot = robot


func set_overdrive_session(session: OverdriveSession) -> void:
	overdrive_session = session


func set_directive_session(session: DirectiveSession) -> void:
	directive_session = session


func set_kinetic_field_runtime(runtime: KineticFieldRuntime) -> void:
	kinetic_field_runtime = runtime


func set_shop_upgrade_runtime(runtime: WeaponShopUpgradeRuntime) -> void:
	shop_upgrade_runtime = runtime


func _ready() -> void:
	resolver = AttackResolver.new()
	resolver.name = "AttackResolver"
	add_child(resolver)
	jab_cross_impact = JabCrossImpact.new()
	jab_cross_impact.name = "JabCrossImpact"
	jab_cross_impact.enemy_hit_resolved.connect(_on_jab_cross_enemy_hit_resolved)
	add_child(jab_cross_impact)
	if _robot != null:
		_robot.set_attack_controller(self)
		_robot.defeated.connect(cancel_attack)
		_visual_root = _robot.get_node_or_null(_robot.visual_root_path) as Node2D
		if _visual_root != null:
			_rest_position = _visual_root.position
			_rest_scale = _visual_root.scale
			_rest_rotation = _visual_root.rotation
		var presenter: RobotAnimationPresenter = (
			_robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
		)
		if presenter != null:
			presenter.bind_attacks(self)


func _process(delta: float) -> void:
	if not _charging or current_spec == null:
		return
	var previous_duration: float = _charge_duration
	_charge_duration = minf(
		_charge_duration + maxf(delta, 0.0),
		_active_charge_limit
	)
	if not is_equal_approx(previous_duration, _charge_duration):
		charge_updated.emit(
			current_spec,
			_charge_duration,
			charge_progress(),
			charge_damage_multiplier()
		)


func request_attack() -> int:
	var attack_id: int = begin_charge()
	if attack_id > 0:
		release_charge()
	return attack_id


func begin_charge() -> int:
	if _busy:
		return 0
	if _robot == null:
		return 0
	var dodge_cancel_direction: int = 0
	if _robot.locomotion_state == GiantRobotController.LocomotionState.DODGE:
		dodge_cancel_direction = _robot.facing
		if not _robot.cancel_dodge():
			return 0
	if not _robot.can_request_attack():
		return 0
	var attack_id: int = _robot.reserve_attack_id()
	_active_charge_limit = float(RuntimeTweakAccess.next_attack_value(
		&"player.melee.charge_duration", MAX_CHARGE_SECONDS
	))
	var tuned_ground_damage: float = float(RuntimeTweakAccess.next_attack_value(
		&"player.melee.ground_smash_damage", _robot.stomp_damage
	))
	var tuned_ground_radius: float = float(RuntimeTweakAccess.next_attack_value(
		&"player.melee.ground_smash_radius", _robot.stomp_radius
	))
	var overdrive_started: bool = (
		overdrive_session.consume_ready_for_attack(attack_id)
		if overdrive_session != null
		else false
	)
	var speed_ratio: float = absf(_robot.velocity.x) / maxf(_robot.max_speed, 1.0)
	var force_multiplier: float = (
		overdrive_session.force_multiplier() if overdrive_session != null else 1.0
	)
	var structure_multiplier: float = (
		overdrive_session.structure_multiplier() if overdrive_session != null else 1.0
	)
	current_spec = (
		resolver.resolve_jab_cross(
			attack_id,
			dodge_cancel_direction,
			DODGE_CANCEL_MELEE_MOMENTUM_RATIO,
			force_multiplier,
			structure_multiplier,
			overdrive_started,
			DODGE_CANCEL_MELEE_MOMENTUM_RATIO
		)
		if dodge_cancel_direction != 0
		else resolver.resolve(
			attack_id,
			_robot.facing,
			speed_ratio,
				tuned_ground_damage,
			_robot.stomp_impulse_per_mass,
				tuned_ground_radius,
			force_multiplier,
			structure_multiplier,
			overdrive_started
		)
	)
	if shop_upgrade_runtime != null:
		current_spec = shop_upgrade_runtime.decorate_attack(current_spec)
	if kinetic_field_runtime != null:
		current_spec = kinetic_field_runtime.decorate_attack(current_spec)
	if directive_session != null:
		current_spec = directive_session.decorate_attack(current_spec)
	_busy = true
	_charging = true
	_charge_duration = 0.0
	_last_full_charge_hit_attack_id = 0
	_buffered_dodge_direction = 0
	phase = Phase.CHARGING
	_robot._set_attack_locked(true)
	_robot.notify_attack_selected(current_spec.mode, current_spec.attack_id)
	attack_started.emit(current_spec)
	charge_started.emit(current_spec)
	charge_updated.emit(current_spec, 0.0, 0.0, 1.0)
	return attack_id


func release_charge() -> bool:
	if not _charging or current_spec == null:
		return false
	_snap_full_charge_within_release_grace()
	_charging = false
	var release_duration: float = _charge_duration
	var multiplier: float = charge_damage_multiplier()
	current_spec = current_spec.with_damage_multiplier(multiplier)
	phase = Phase.ANTICIPATION
	charge_released.emit(current_spec, release_duration, multiplier)
	_run_attack(current_spec)
	return true


func _snap_full_charge_within_release_grace() -> void:
	if _charge_duration >= _active_charge_limit:
		return
	var remaining_seconds: float = _active_charge_limit - _charge_duration
	if remaining_seconds > FULL_CHARGE_RELEASE_GRACE_SECONDS:
		return
	_charge_duration = _active_charge_limit
	charge_updated.emit(
		current_spec,
		_charge_duration,
		charge_progress(),
		charge_damage_multiplier()
	)


func is_charging() -> bool:
	return _charging


func charge_duration() -> float:
	return _charge_duration


func charge_progress() -> float:
	return clampf(_charge_duration / maxf(_active_charge_limit, 0.001), 0.0, 1.0)


func charge_damage_multiplier() -> float:
	return lerpf(1.0, MAX_CHARGE_DAMAGE_MULTIPLIER, charge_progress())


func report_enemy_hit(attack_id: int, world_position: Vector2, enemy_count: int) -> bool:
	if (
		current_spec == null
		or current_spec.attack_id != attack_id
		or not current_spec.is_fully_charged()
		or enemy_count <= 0
		or _last_full_charge_hit_attack_id == attack_id
	):
		return false
	_last_full_charge_hit_attack_id = attack_id
	full_charge_enemy_hit.emit(current_spec, world_position, enemy_count)
	return true


func request_dodge(direction: int) -> bool:
	var normalized_direction: int = clampi(direction, -1, 1)
	if _robot == null or normalized_direction == 0 or not _robot.dodge_ready:
		return false
	if not _busy:
		return _robot._start_dodge(normalized_direction)
	if phase != Phase.RECOVERY or _buffered_dodge_direction != 0:
		return false
	_buffered_dodge_direction = normalized_direction
	buffered_dodge_count += 1
	dodge_buffered.emit(current_spec.attack_id, normalized_direction)
	return true


func is_busy() -> bool:
	return _busy


func cancel_attack() -> void:
	var cancelled_spec: AttackSpec = current_spec
	current_spec = null
	_busy = false
	_charging = false
	_charge_duration = 0.0
	_buffered_dodge_direction = 0
	phase = Phase.READY
	if _robot != null:
		_robot._set_attack_locked(false)
	_restore_pose()
	if cancelled_spec != null:
		attack_cancelled.emit(cancelled_spec)
		attack_finished.emit(cancelled_spec)


func _run_attack(spec: AttackSpec) -> void:
	_apply_windup_pose(spec)
	if spec.anticipation_seconds > 0.0:
		await get_tree().create_timer(spec.anticipation_seconds, false).timeout
	if current_spec != spec:
		return
	phase = Phase.ACTIVE
	_apply_active_pose(spec)
	if spec.is_ground_smash():
		_robot.velocity.x = 0.0
		_robot.execute_ground_smash(
			spec.attack_id,
			spec.actor_damage,
			spec.structural_damage,
			spec.impulse_per_mass,
			spec.hit_size.x * 0.5
		)
	else:
		_robot.velocity.x = 0.0
		jab_cross_impact.resolve(spec, _robot)
	if directive_session != null:
		directive_session.attack_active(spec)
	_robot.notify_attack_committed(spec.mode, spec.attack_id)
	attack_active.emit(spec)
	if spec.active_seconds > 0.0:
		await get_tree().create_timer(spec.active_seconds, false).timeout
	if current_spec != spec:
		return
	phase = Phase.RECOVERY
	_apply_recovery_pose(spec)
	if spec.recovery_seconds > 0.0:
		await get_tree().create_timer(spec.recovery_seconds, false).timeout
	if current_spec != spec:
		return
	_restore_pose()
	current_spec = null
	_busy = false
	_charge_duration = 0.0
	phase = Phase.READY
	_robot._set_attack_locked(false)
	attack_finished.emit(spec)
	if _buffered_dodge_direction != 0:
		var dodge_direction: int = _buffered_dodge_direction
		_buffered_dodge_direction = 0
		_robot._start_dodge(dodge_direction)

func _apply_windup_pose(spec: AttackSpec) -> void:
	if _visual_root == null:
		return
	var facing_scale: float = _visual_scale_x(spec.facing)
	_visual_root.position = _rest_position + Vector2(-5.0 * float(spec.facing), 5.0)
	_visual_root.scale = Vector2(facing_scale * 0.98, _rest_scale.y * 0.94)
	_visual_root.rotation = 0.045 * float(spec.facing) if spec.is_jab_cross() else 0.0


func _apply_active_pose(spec: AttackSpec) -> void:
	if _visual_root == null:
		return
	var facing_scale: float = _visual_scale_x(spec.facing)
	if spec.is_jab_cross():
		_visual_root.position = _rest_position + Vector2(16.0 * float(spec.facing), 9.0)
		_visual_root.scale = Vector2(facing_scale * 1.05, _rest_scale.y * 0.90)
		_visual_root.rotation = 0.095 * float(spec.facing)
	else:
		_visual_root.position = _rest_position + Vector2(0.0, 8.0)
		_visual_root.scale = Vector2(facing_scale * 1.04, _rest_scale.y * 0.88)
		_visual_root.rotation = 0.0


func _apply_recovery_pose(spec: AttackSpec) -> void:
	if _visual_root == null:
		return
	var facing_scale: float = _visual_scale_x(_robot.facing)
	_visual_root.position = _rest_position + Vector2(4.0 * float(spec.facing), 3.0)
	_visual_root.scale = Vector2(facing_scale, _rest_scale.y * 0.97)
	_visual_root.rotation = 0.025 * float(spec.facing)


func _restore_pose() -> void:
	if _visual_root == null:
		return
	_visual_root.position = _rest_position
	_visual_root.scale = Vector2(
		_visual_scale_x(_robot.facing),
		_rest_scale.y
	)
	_visual_root.rotation = _rest_rotation


func _on_jab_cross_enemy_hit_resolved(
	spec: AttackSpec,
	enemy_count: int,
	world_position: Vector2
) -> void:
	if spec != null:
		report_enemy_hit(spec.attack_id, world_position, enemy_count)


func _visual_scale_x(facing: int) -> float:
	var baked_facing: bool = bool(
		_visual_root.get_meta(&"baked_directional_art", false)
	)
	return absf(_rest_scale.x) * (1.0 if baked_facing else float(facing))
