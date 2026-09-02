class_name TemplateStage
extends Control

signal run_finished(completed: bool, summary: TemplateRunSummary)
signal retry_requested
signal title_requested

var definition: StageDefinition
var run_seed: int = 0
var score: int = 0

@onready var lifecycle: CompactRunLifecycle = %CompactRunLifecycle
@onready var hud: BasicHud = %BasicHud
@onready var debrief: CompactDebrief = %CompactDebrief
@onready var player: CompactPlayer = %CompactPlayer
@onready var destructible: CompactDestructible = %CompactDestructible
@onready var wave_director: CompactWaveDirector = %CompactWaveDirector
@onready var effect_pool: CompactEffectPool = %EffectPool
@onready var camera_impulse: CompactCameraImpulse = %CameraImpulse


func configure(p_definition: StageDefinition, p_run_seed: int = 0) -> void:
	definition = p_definition
	run_seed = p_run_seed


func _ready() -> void:
	assert(definition != null and definition.is_valid(), "TemplateStage requires a valid definition")
	lifecycle.setup(definition.stage_id, run_seed)
	lifecycle.run_finished.connect(_on_run_finished)
	debrief.retry_requested.connect(func() -> void: retry_requested.emit())
	debrief.title_requested.connect(func() -> void: title_requested.emit())
	player.health_changed.connect(hud.set_health)
	player.defeated.connect(_on_player_defeated)
	player.attack_released.connect(_on_player_attack_released)
	destructible.destroyed.connect(_on_destructible_destroyed)
	wave_director.wave_started.connect(hud.set_wave)
	wave_director.wave_cleared.connect(_on_wave_cleared)
	wave_director.score_awarded.connect(_on_score_awarded)
	wave_director.victory.connect(_on_victory)
	hud.configure(definition)
	hud.set_health(player.current_health, player.max_health)
	hud.set_score(score)
	debrief.dismiss()
	var markers: Dictionary = {
		&"right_ground": Vector2(1120.0, 619.0),
		&"right_armor": Vector2(1180.0, 619.0),
	}
	assert(wave_director.configure(definition, player, markers))
	assert(wave_director.start())


func _on_player_attack_released(
	origin: Vector2,
	radius: float,
	damage: float,
	facing: int,
	charge_ratio: float
) -> void:
	var hit_count: int = 0
	for enemy: CompactEnemy in wave_director.active_enemies():
		var enemy_offset: Vector2 = enemy.global_position - origin
		if enemy_offset.length() > radius or enemy_offset.x * float(facing) < -28.0:
			continue
		if enemy.receive_damage(damage):
			hit_count += 1
			effect_pool.spawn(enemy.global_position + Vector2(0.0, -48.0), facing, 1.0)
	var destructible_offset: Vector2 = destructible.global_position - origin
	if (
		not destructible.is_destroyed
		and destructible_offset.length() <= radius
		and destructible_offset.x * float(facing) >= -28.0
		and destructible.receive_damage(damage)
	):
		hit_count += 1
		effect_pool.spawn(destructible.global_position + Vector2(0.0, -42.0), facing, 1.2)
	if hit_count > 0:
		camera_impulse.kick(5.0 + charge_ratio * 7.0, facing)


func _on_score_awarded(points: int, world_position: Vector2) -> void:
	score += maxi(points, 0)
	hud.set_score(score)
	effect_pool.spawn(world_position + Vector2(0.0, -40.0), player.facing, 0.9)


func _on_destructible_destroyed(points: int, world_position: Vector2) -> void:
	_on_score_awarded(points, world_position)
	camera_impulse.kick(10.0, player.facing)


func _on_wave_cleared(cleared_waves: int, total_waves: int) -> void:
	hud.set_wave(cleared_waves, total_waves)


func _on_player_defeated() -> void:
	lifecycle.finish_defeat(score, wave_director.completed_waves)


func _on_victory() -> void:
	lifecycle.finish_victory(score, wave_director.completed_waves)


func _on_run_finished(completed: bool, summary: TemplateRunSummary) -> void:
	player.set_combat_disabled(true)
	wave_director.stop()
	hud.set_status("VICTORY" if completed else "DEFEAT")
	debrief.present(summary)
	run_finished.emit(completed, summary)
