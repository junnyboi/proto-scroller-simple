class_name CityRuntimeServices
extends RefCounted

const TANK_TEXTURE: Texture2D = preload("res://assets/city/enemies/tank.png")
const HELICOPTER_TEXTURE: Texture2D = preload("res://assets/city/enemies/helicopter.png")
const ENEMY_LAYER: int = 1 << 2
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const DEBRIS_LAYER: int = 1 << 8
const REMAINS_LAYER: int = 1 << 9

var rampage_session: RampageSession
var rampage_events: RampageEventAdapter
var projectile_root: ProjectilePool
var impact_audio_root: Node2D
var enemy_remains_root: Node2D
var impact_feedback_pool: ImpactFeedbackPool
var hit_stop: HitStopLease
var simulation_pause: SimulationPause
var destruction_director: DestructionDirector
var debris_pool: DebrisPool
var building_section_burst_pool: BuildingSectionBurstPool
var enemy_scrap_pool: DebrisPool
var soldier_defeat_pool: SoldierDefeatPool
var enemy_remains_factory: EnemyRemainsFactory
var music_duck_controller: MusicDuckController


func build(
	root: Node2D,
	score_changed: Callable,
	pending_score_changed: Callable,
	combo_changed: Callable,
	aerial_impact_accepted: Callable,
	ground_impact_accepted: Callable,
	wreck_scrapped: Callable
) -> void:
	_build_rampage(root, score_changed, pending_score_changed, combo_changed)
	_build_projectiles(root)
	_build_feedback(root)
	_build_destruction(root, aerial_impact_accepted, ground_impact_accepted)
	_build_remains(root, wreck_scrapped)
	music_duck_controller = MusicDuckController.new()
	root.add_child(music_duck_controller)


func _build_rampage(
	root: Node2D,
	score_changed: Callable,
	pending_score_changed: Callable,
	combo_changed: Callable
) -> void:
	rampage_session = RampageSession.new()
	rampage_session.name = "RampageSession"
	rampage_session.run_score.score_changed.connect(score_changed)
	rampage_session.run_score.pending_changed.connect(pending_score_changed)
	rampage_session.combo_tracker.combo_changed.connect(combo_changed)
	root.add_child(rampage_session)
	rampage_events = RampageEventAdapter.new(rampage_session)


func _build_projectiles(root: Node2D) -> void:
	projectile_root = ProjectilePool.new()
	projectile_root.name = "ProjectileRoot"
	projectile_root.capacity = (
		RuntimeBudget.BULLETS + RuntimeBudget.SHELLS + RuntimeBudget.ROCKETS
	)
	projectile_root.z_index = 45
	root.add_child(projectile_root)


func _build_feedback(root: Node2D) -> void:
	simulation_pause = SimulationPause.new()
	simulation_pause.name = "SimulationPause"
	root.add_child(simulation_pause)
	impact_audio_root = Node2D.new()
	impact_audio_root.name = "ImpactAudioRoot"
	root.add_child(impact_audio_root)
	impact_feedback_pool = ImpactFeedbackPool.new()
	impact_feedback_pool.name = "ImpactFeedbackPool"
	impact_feedback_pool.setup(root, impact_audio_root)
	root.add_child(impact_feedback_pool)
	projectile_root.set_impact_feedback_pool(impact_feedback_pool)
	hit_stop = HitStopLease.new()
	hit_stop.name = "HitStopLease"
	hit_stop.enabled = DisplayServer.get_name() != "headless"
	hit_stop.simulation_pause = simulation_pause
	root.add_child(hit_stop)


func _build_destruction(
	root: Node2D,
	aerial_impact_accepted: Callable,
	ground_impact_accepted: Callable
) -> void:
	destruction_director = DestructionDirector.new()
	destruction_director.name = "DestructionDirector"
	destruction_director.max_results = 64
	destruction_director.blast_mask = (
		HURTBOX_LAYER | PROP_LAYER | ENEMY_LAYER | DEBRIS_LAYER | REMAINS_LAYER
	)
	root.add_child(destruction_director)
	debris_pool = DebrisPool.new()
	debris_pool.name = "BuildingDebrisPool"
	debris_pool.capacity = RuntimeBudget.STRUCTURAL_DEBRIS
	debris_pool.z_index = 20
	debris_pool.aerial_impact_accepted.connect(aerial_impact_accepted)
	debris_pool.ground_impact_accepted.connect(ground_impact_accepted)
	root.add_child(debris_pool)
	building_section_burst_pool = BuildingSectionBurstPool.new()
	building_section_burst_pool.name = "BuildingSectionBurstPool"
	building_section_burst_pool.capacity = RuntimeBudget.BUILDING_SECTION_BURST_SLOTS
	root.add_child(building_section_burst_pool)
	enemy_scrap_pool = DebrisPool.new()
	enemy_scrap_pool.name = "EnemyScrapPool"
	enemy_scrap_pool.capacity = RuntimeBudget.ENEMY_SCRAP
	enemy_scrap_pool.use_generated_visuals = false
	enemy_scrap_pool.z_index = 20
	enemy_scrap_pool.ground_impact_accepted.connect(ground_impact_accepted)
	root.add_child(enemy_scrap_pool)


func _build_remains(root: Node2D, wreck_scrapped: Callable) -> void:
	enemy_remains_root = Node2D.new()
	enemy_remains_root.name = "EnemyRemainsRoot"
	enemy_remains_root.z_index = 28
	root.add_child(enemy_remains_root)
	soldier_defeat_pool = SoldierDefeatPool.new()
	soldier_defeat_pool.name = "SoldierDefeatPool"
	soldier_defeat_pool.capacity = RuntimeBudget.SOLDIER_DEFEATS
	soldier_defeat_pool.z_index = 28
	enemy_remains_root.add_child(soldier_defeat_pool)
	enemy_remains_factory = EnemyRemainsFactory.new()
	enemy_remains_factory.name = "EnemyRemainsFactory"
	enemy_remains_factory.setup(
		enemy_remains_root,
		enemy_scrap_pool,
		TANK_TEXTURE,
		HELICOPTER_TEXTURE
	)
	enemy_remains_factory.wreck_scrapped.connect(wreck_scrapped)
	root.add_child(enemy_remains_factory)
