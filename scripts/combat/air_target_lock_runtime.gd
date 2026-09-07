class_name AirTargetLockRuntime
extends Node

const TARGET_ACQUIRED_SFX: AudioStream = preload(
	"res://assets/audio/voice/air_target_acquired.wav"
)
const TARGET_LOST_SFX: AudioStream = preload(
	"res://assets/audio/voice/target_lost.wav"
)
const TARGET_DESTROYED_SFX: AudioStream = preload(
	"res://assets/audio/voice/target_destroyed.wav"
)

var target_acquired_play_count: int = 0
var target_lost_play_count: int = 0
var target_destroyed_play_count: int = 0
var last_voice_cue: StringName = &""
var _robot: GiantRobotController
var _attacks: ContextualAttackController
var _locked_target: EnemyActor2D
var _locked_attack_id: int = 0
var _monitoring: bool = false
var _telegraph_elapsed: float = 0.0
var _telegraph_duration: float = 0.0
var _voice_player: AudioStreamPlayer
var _reticle: AirTargetReticle2D


func setup(
	robot: GiantRobotController,
	attacks: ContextualAttackController
) -> void:
	_robot = robot
	_attacks = attacks


func _ready() -> void:
	_reticle = AirTargetReticle2D.new()
	_reticle.name = "AirTargetReticle"
	add_child(_reticle)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "AirTargetVoice"
	_voice_player.volume_db = -3.0
	_voice_player.bus = GameAudioBus.VOICE
	add_child(_voice_player)
	set_process(false)
	if _attacks != null:
		_attacks.attack_started.connect(_on_attack_started)
		_attacks.attack_active.connect(_on_attack_active)
		_attacks.attack_finished.connect(_on_attack_finished)


func _process(delta: float) -> void:
	if not _monitoring:
		return
	if (
		_attacks == null
		or not _attacks.is_busy()
		or _attacks.current_spec == null
		or _attacks.current_spec.attack_id != _locked_attack_id
	):
		_clear_lock()
		return
	_telegraph_elapsed = minf(
		_telegraph_elapsed + maxf(delta, 0.0),
		_telegraph_duration
	)
	_reticle.set_telegraph_progress(
		_telegraph_elapsed / maxf(_telegraph_duration, 0.001)
	)
	var origin: Vector2 = _impact_origin()
	if _locked_target != null and not AerialDebrisLauncher.is_valid_focused_target(
		_locked_target,
		origin
	):
		var invalid_target: EnemyActor2D = _locked_target
		_locked_target = null
		_reticle.clear_lock()
		_play_invalid_target_voice(invalid_target)
		return
	if _locked_target != null:
		return
	var nearest: EnemyActor2D = AerialDebrisLauncher.nearest_overhead_target(
		get_tree(),
		origin
	)
	if nearest == null:
		return
	_locked_target = nearest
	_reticle.acquire(nearest)
	_reticle.set_telegraph_progress(
		_telegraph_elapsed / maxf(_telegraph_duration, 0.001)
	)
	_play_voice(TARGET_ACQUIRED_SFX, &"air_target_acquired")


func current_target() -> EnemyActor2D:
	return _locked_target


func voice_player_count() -> int:
	return 1 if _voice_player != null else 0


func reticle_count() -> int:
	return 1 if _reticle != null else 0


func reticle_visible() -> bool:
	return _reticle != null and _reticle.visible


func reticle_target() -> EnemyActor2D:
	return _reticle.current_target() if _reticle != null else null


func consume_volley_target(attack_id: int) -> EnemyActor2D:
	if not _monitoring or attack_id != _locked_attack_id:
		return null
	var target: EnemyActor2D = _locked_target
	if not AerialDebrisLauncher.is_valid_focused_target(target, _impact_origin()):
		if target != null:
			_play_invalid_target_voice(target)
		target = null
	_clear_lock()
	return target


func _on_attack_started(spec: AttackSpec) -> void:
	_clear_lock()
	if spec == null or not spec.is_ground_smash():
		return
	_locked_attack_id = spec.attack_id
	_telegraph_elapsed = 0.0
	_telegraph_duration = spec.anticipation_seconds
	_monitoring = true
	set_process(true)
	_process(0.0)


func _on_attack_active(spec: AttackSpec) -> void:
	if spec != null and spec.attack_id == _locked_attack_id:
		_clear_lock()


func _on_attack_finished(spec: AttackSpec) -> void:
	if spec != null and spec.attack_id == _locked_attack_id:
		_clear_lock()


func _clear_lock() -> void:
	_locked_target = null
	_locked_attack_id = 0
	_telegraph_elapsed = 0.0
	_telegraph_duration = 0.0
	_monitoring = false
	set_process(false)
	if _reticle != null:
		_reticle.clear_lock()


func _impact_origin() -> Vector2:
	if _robot == null:
		return Vector2.ZERO
	var marker: Node2D = _robot.get_node_or_null(^"GroundImpactOrigin") as Node2D
	return marker.global_position if marker != null else _robot.global_position


func _play_voice(stream: AudioStream, cue: StringName) -> void:
	if _voice_player == null or stream == null:
		return
	_voice_player.stop()
	_voice_player.stream = stream
	_voice_player.play()
	last_voice_cue = cue
	if cue == &"air_target_acquired":
		target_acquired_play_count += 1
	elif cue == &"target_lost":
		target_lost_play_count += 1
	elif cue == &"target_destroyed":
		target_destroyed_play_count += 1


func _play_invalid_target_voice(target: EnemyActor2D) -> void:
	if is_instance_valid(target) and target.dead:
		_play_voice(TARGET_DESTROYED_SFX, &"target_destroyed")
	else:
		_play_voice(TARGET_LOST_SFX, &"target_lost")
