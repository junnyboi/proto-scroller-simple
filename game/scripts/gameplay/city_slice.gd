class_name CitySlice
extends Node2D

signal retry_requested
signal defeat_requested
signal title_requested
const WORLD_LAYER: int = 1 << 0
const ROBOT_LAYER: int = 1 << 1
const BUILDING_LAYER: int = 1 << 3
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const LAND_VISUAL_BASELINE_Y: float = 655.0
const GROUND_SMASH_WRECK_RADIUS_BONUS: float = 100.0
const MOBILE_CONTROLS_SCRIPT: Script = preload("res://scripts/input/mobile_controls.gd")
const GAMEPLAY_HUD_SCRIPT: Script = preload("res://scripts/ui/gameplay_hud.gd")
const HAPTICS_SCRIPT: Script = preload("res://scripts/input/haptics_adapter.gd")
const FEEDBACK_DIRECTOR_SCRIPT: Script = preload(
	"res://scripts/feedback/impact_feedback_director.gd"
)
const OVERDRIVE_SCRIPT: Script = preload("res://scripts/rampage/overdrive_session.gd")
const RUN_LIFECYCLE_SCRIPT: Script = preload(
	"res://scripts/gameplay/city_run_lifecycle.gd"
)
const WORLD_STREAM_SCRIPT: Script = preload("res://scripts/world/city_world_stream.gd")
const DISTRICT_TRANSITION_SCRIPT: Script = preload(
	"res://scripts/world/district_transition_banner.gd"
)
const STREAMED_DESTRUCTIBLES_SCRIPT: Script = preload(
	"res://scripts/world/streamed_destructible_runtime.gd"
)
const ENCOUNTER_RUNTIME_SCRIPT: Script = preload(
	"res://scripts/encounter/encounter_runtime.gd"
)
const URBAN_SIEGE_SCRIPT: Script = preload("res://scripts/siege/urban_siege_runtime.gd")
const TELEGRAPH_SCRIPT: Script = preload(
	"res://scripts/encounter/telegraph_presenter_2d.gd"
)
const WEB_GAMEPLAY_SMOKE_PROBE_SCRIPT: Script = preload(
	"res://scripts/quality/web_gameplay_smoke_probe.gd"
)
const LEADERBOARD_BRIDGE_SCRIPT: Script = preload(
	"res://scripts/network/leaderboard_bridge.gd"
)
const CONTACT_DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")
const GLASS_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/glass_shatter.wav"
)

@export_range(-1, 1, 1) var mobile_detection_override: int = -1

var robot: GiantRobotController
var runtime_services: CityRuntimeServices
var destruction_director: DestructionDirector
var debris_pool: DebrisPool
var building_section_burst_pool: BuildingSectionBurstPool
var enemy_scrap_pool: DebrisPool
var soldier_defeat_pool: SoldierDefeatPool
var mobile_controls: MobileControls
var gameplay_hud: GameplayHud
var leaderboard_bridge: LeaderboardBridge
var projectile_root: ProjectilePool
var impact_audio_root: Node2D
var impact_feedback_pool: ImpactFeedbackPool
var hit_stop: HitStopLease
var haptics_adapter: HapticsAdapter
var impact_feedback_director: ImpactFeedbackDirector
var camera_rig: CameraRig
var enemy_remains_root: Node2D
var enemy_remains_factory: EnemyRemainsFactory
var rampage_session: RampageSession
var rampage_events: RampageEventAdapter
var overdrive_session: OverdriveSession
var run_lifecycle: CityRunLifecycle
var music_duck_controller: MusicDuckController
var contextual_attacks: ContextualAttackController
var air_target_lock_runtime: AirTargetLockRuntime
var world_stream: CityWorldStream
var district_transition_banner: DistrictTransitionBanner
var streamed_destructibles: StreamedDestructibleRuntime
var landmark_root: Node2D
var telegraph_presenter: TelegraphPresenter2D
var encounter_runtime: EncounterRuntime
var encounter_director: EncounterDirector
var urban_siege: UrbanSiegeRuntime
var campaign_progress: CampaignProgressStore
var combat_profile: PlayerCombatProfileStore
var launch_run_seed: int = -1
var launch_district_index: int = 0
var project_choir_runtime: ProjectChoirRuntime
var building: StructuralBuilding2D
var streetlamp: DestructibleProp2D
var car: DestructibleProp2D
var soldier: SoldierEnemy
var tank: TankEnemy
var helicopter: HelicopterEnemy
var soldier_defeat_body: SoldierDefeatBody2D
var tank_wreck: EnemyWreck2D
var helicopter_wreck: EnemyWreck2D
var game_over_active: bool = false
var last_player_damage_source_id: StringName = DefeatSourceResolver.UNKNOWN
var score: int:
	get:
		return rampage_session.current_score() if rampage_session != null else 0
var last_material_audio: StringName:
	get:
		return (
			impact_feedback_pool.last_material_audio
			if impact_feedback_pool != null
			else &""
		)
var material_audio_play_count: int:
	get:
		return (
			impact_feedback_pool.material_audio_play_count
			if impact_feedback_pool != null
			else 0
		)

func _ready() -> void:
	CityWorldBuilder.build_environment(self)
	_build_services()
	robot = CityWorldBuilder.build_robot(
		self,
		_on_robot_heavy_impact,
		_on_robot_health_changed,
		_on_robot_damage_received,
		_on_robot_defeated
	)
	enemy_remains_factory.set_player(robot)
	_build_world_stream()
	contextual_attacks = ContextualAttackController.new()
	contextual_attacks.name = "ContextualAttackController"
	contextual_attacks.setup(robot)
	add_child(contextual_attacks)
	destruction_director.enemy_hits_resolved.connect(contextual_attacks.report_enemy_hit)
	air_target_lock_runtime = AirTargetLockRuntime.new()
	air_target_lock_runtime.name = "AirTargetLockRuntime"
	air_target_lock_runtime.setup(robot, contextual_attacks)
	add_child(air_target_lock_runtime)
	overdrive_session = OVERDRIVE_SCRIPT.new() as OverdriveSession
	overdrive_session.name = "OverdriveSession"
	overdrive_session.setup(rampage_session.momentum_meter, robot)
	add_child(overdrive_session)
	contextual_attacks.set_overdrive_session(overdrive_session)
	_build_destructibles()
	_build_enemies()
	CityWorldBuilder.build_camera(self, robot)
	camera_rig = get_node(^"CameraRig") as CameraRig
	debris_pool.set_culling_camera(camera_rig)
	enemy_scrap_pool.set_culling_camera(camera_rig)
	_build_hud()
	_bind_player_attack_feedback()
	_build_leaderboard_bridge()
	_build_urban_siege()
	run_lifecycle = RUN_LIFECYCLE_SCRIPT.new() as CityRunLifecycle
	run_lifecycle.name = "CityRunLifecycle"
	run_lifecycle.setup(self)
	add_child(run_lifecycle)
	project_choir_runtime = ProjectChoirRuntime.mount(self, campaign_progress)
	if _web_gameplay_smoke_requested():
		var smoke_probe: Node = WEB_GAMEPLAY_SMOKE_PROBE_SCRIPT.new() as Node
		add_child(smoke_probe)
		smoke_probe.call(&"setup", self)

func _process(delta: float) -> void:
	if game_over_active or rampage_session == null or robot == null:
		return
	if urban_siege != null and urban_siege.is_simulation_paused():
		return
	var speed_ratio: float = absf(robot.velocity.x) / maxf(robot.max_speed, 1.0)
	rampage_session.advance(speed_ratio, delta)

func _web_gameplay_smoke_requested() -> bool:
	if OS.has_feature("web"):
		var query: String = String(JavaScriptBridge.eval("window.location.search"))
		return query.contains("webSmoke=1")
	return OS.get_environment("PROTO_SCROLLER_WEB_SMOKE") == "1"

func trigger_test_stomp() -> int: return robot.request_stomp()
func prepare_new_game_plus_world() -> void: NewGamePlusWorldReset.execute(self)

func all_destructibles_broken() -> bool:
	return (
		building != null
		and car != null
		and streetlamp != null
		and building.is_destroyed()
		and streetlamp.is_broken
		and car.is_broken
	)

func _build_services() -> void:
	runtime_services = CityRuntimeServices.new()
	runtime_services.build(
		self,
		_on_score_changed,
		_on_pending_score_changed,
		_on_combo_changed,
		_on_aerial_impact_accepted,
		_on_ground_debris_impact_accepted,
		_on_enemy_wreck_scrapped
	)
	rampage_session = runtime_services.rampage_session
	rampage_events = runtime_services.rampage_events
	projectile_root = runtime_services.projectile_root
	impact_audio_root = runtime_services.impact_audio_root
	enemy_remains_root = runtime_services.enemy_remains_root
	impact_feedback_pool = runtime_services.impact_feedback_pool
	hit_stop = runtime_services.hit_stop
	destruction_director = runtime_services.destruction_director
	debris_pool = runtime_services.debris_pool
	building_section_burst_pool = runtime_services.building_section_burst_pool
	enemy_scrap_pool = runtime_services.enemy_scrap_pool
	soldier_defeat_pool = runtime_services.soldier_defeat_pool
	enemy_remains_factory = runtime_services.enemy_remains_factory
	music_duck_controller = runtime_services.music_duck_controller
func _build_destructibles() -> void:
	landmark_root = Node2D.new()
	landmark_root.name = "LandmarkRoot"
	add_child(landmark_root)
	world_stream.set_landmark_root(landmark_root)
	streamed_destructibles = (
		STREAMED_DESTRUCTIBLES_SCRIPT.new() as StreamedDestructibleRuntime
	)
	streamed_destructibles.name = "StreamedDestructibleRuntime"
	streamed_destructibles.setup(world_stream)
	streamed_destructibles.building_damage_applied.connect(
		_on_streamed_building_damage_applied
	)
	streamed_destructibles.building_cell_destroyed.connect(
		_on_streamed_building_cell_destroyed
	)
	streamed_destructibles.building_chain_started.connect(
		_on_streamed_building_chain_started
	)
	streamed_destructibles.building_chain_step.connect(
		_on_streamed_building_chain_step
	)
	streamed_destructibles.building_chain_completed.connect(
		_on_streamed_building_chain_completed
	)
	streamed_destructibles.building_destroyed.connect(_on_streamed_building_destroyed)
	streamed_destructibles.prop_destroyed.connect(_on_streamed_prop_destroyed)
	add_child(streamed_destructibles)
	_refresh_primary_destructibles()

func _build_world_stream() -> void:
	world_stream = WORLD_STREAM_SCRIPT.new() as CityWorldStream
	world_stream.name = "CityWorldStream"
	var districts: Array[CityDistrictProfile] = CityDistrictCatalog.districts()
	var district: CityDistrictProfile = districts[clampi(
		launch_district_index,
		0,
		districts.size() - 1
	)]
	world_stream.setup(
		robot,
		maxi(launch_run_seed, 0),
		district.start_chunk
	)
	world_stream.origin_shift_requested.connect(_on_origin_shift_requested)
	world_stream.window_changed.connect(_on_stream_window_changed)
	add_child(world_stream)
	CityWorldBuilder.transition_environment(self, district.district_id, true)
	district_transition_banner = DISTRICT_TRANSITION_SCRIPT.new()
	add_child(district_transition_banner)
	world_stream.district_changed.connect(_on_spatial_district_changed)

func _build_enemies() -> void:
	telegraph_presenter = TELEGRAPH_SCRIPT.new() as TelegraphPresenter2D
	telegraph_presenter.name = "TelegraphPresenter"
	add_child(telegraph_presenter)
	encounter_runtime = ENCOUNTER_RUNTIME_SCRIPT.new() as EncounterRuntime
	encounter_runtime.name = "EncounterRuntime"
	encounter_runtime.setup(robot, telegraph_presenter, projectile_root, building, world_stream)
	encounter_runtime.projectile_requested.connect(_on_projectile_requested)
	encounter_runtime.enemy_died.connect(_on_enemy_died)
	add_child(encounter_runtime)
	world_stream.rear_frontier_changed.connect(encounter_runtime.cull_behind)
	soldier = encounter_runtime.soldiers[0]
	tank = encounter_runtime.tanks[0]
	helicopter = encounter_runtime.helicopters[0]
	if DisplayServer.get_name() == "headless":
		encounter_runtime.acquire(&"soldier", Vector2(1320.0, 542.5))
		encounter_runtime.acquire(&"tank", Vector2(1700.0, 551.0))
		encounter_runtime.acquire(&"helicopter", Vector2(1500.0, 180.0))

func _build_urban_siege() -> void:
	var dependencies: UrbanSiegeDependencies = UrbanSiegeDependencies.new()
	dependencies.city = self
	dependencies.robot = robot
	dependencies.encounter_runtime = encounter_runtime
	dependencies.projectile_pool = projectile_root
	dependencies.telegraphs = telegraph_presenter
	dependencies.destruction_director = destruction_director
	dependencies.rampage_session = rampage_session
	dependencies.gameplay_hud = gameplay_hud
	dependencies.mobile_controls = mobile_controls
	dependencies.debris_pool = debris_pool
	dependencies.building_section_burst_pool = building_section_burst_pool
	dependencies.impact_feedback_pool = impact_feedback_pool
	dependencies.remains_factory = enemy_remains_factory
	urban_siege = URBAN_SIEGE_SCRIPT.new() as UrbanSiegeRuntime
	urban_siege.name = "UrbanSiegeRuntime"
	urban_siege.setup(dependencies, CONTACT_DISTRICT)
	add_child(urban_siege)
	gameplay_hud.field_briefing.configure(
		urban_siege.pause_coordinator,
		robot,
		mobile_controls
	)
	encounter_director = urban_siege.director
	if DisplayServer.get_name() != "headless":
		var active_seed: int = (
			launch_run_seed
			if launch_run_seed >= 0
			else CityWorldBuilder.initial_run_seed(_web_gameplay_smoke_requested())
		)
		urban_siege.start_run(active_seed)

func _on_origin_shift_requested(offset: Vector2, _chunk_delta: int) -> void:
	var parallax: Node = get_node_or_null(^"ParallaxCity")
	var excluded: Array[Node] = [world_stream, landmark_root, parallax]
	world_stream.floating_origin.apply_to_scene(self, offset, excluded)
	CityWorldBuilder.compensate_parallax(self, offset)
	if urban_siege != null and urban_siege.hazard_pressure != null:
		urban_siege.hazard_pressure.rebase_cached_world_state(offset)
	if camera_rig != null:
		camera_rig.reset_after_origin_shift(offset)
func _on_stream_window_changed(_logical_index: int) -> void:
	_refresh_primary_destructibles()
	var target: StructuralBuilding2D = building
	if target != null and target.is_destroyed():
		target = streamed_destructibles.nearest_intact_building(robot.global_position.x)
	encounter_runtime.structural_target = target
	for enemy: EnemyActor2D in encounter_runtime.all_actors():
		enemy.structural_target = target
func _on_spatial_district_changed(
	_previous_district_id: StringName,
	_district_id: StringName,
	logical_chunk: int
) -> void:
	var tuning_service: RuntimeTweakService = RuntimeTweakAccess.service()
	if tuning_service != null:
		tuning_service.begin_district()
	var district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(logical_chunk)
	CityWorldBuilder.transition_environment(self, district.district_id)
	district_transition_banner.present(district, logical_chunk)

func _refresh_primary_destructibles() -> void:
	if streamed_destructibles == null:
		return
	building = streamed_destructibles.primary_building()
	car = streamed_destructibles.primary_car()
	streetlamp = streamed_destructibles.primary_streetlamp()
func _build_hud() -> void:
	gameplay_hud = GAMEPLAY_HUD_SCRIPT.new() as GameplayHud
	gameplay_hud.setup(robot, contextual_attacks, combat_profile)
	world_stream.district_clear_progress.connect(gameplay_hud.set_district_clear_progress)
	world_stream.district_exit_unlocked.connect(gameplay_hud.set_district_exit_unlocked)
	world_stream.rear_barrier_contact.connect(gameplay_hud.show_rear_barrier_warning)
	gameplay_hud.retry_pressed.connect(_on_retry_pressed)
	gameplay_hud.title_pressed.connect(_on_title_pressed)
	add_child(gameplay_hud)
	haptics_adapter = HAPTICS_SCRIPT.new() as HapticsAdapter
	haptics_adapter.name = "HapticsAdapter"
	haptics_adapter.setup(mobile_detection_override)
	add_child(haptics_adapter)
	mobile_controls = MOBILE_CONTROLS_SCRIPT.new() as MobileControls
	mobile_controls.setup(robot, mobile_detection_override)
	gameplay_hud.add_child(mobile_controls)
	impact_feedback_director = FEEDBACK_DIRECTOR_SCRIPT.new() as ImpactFeedbackDirector
	impact_feedback_director.name = "ImpactFeedbackDirector"
	impact_feedback_director.setup(
		rampage_session.event_hub,
		hit_stop,
		camera_rig,
		haptics_adapter,
		robot
	)
	add_child(impact_feedback_director)


func _bind_player_attack_feedback() -> void:
	impact_feedback_director.bind_player_attacks(contextual_attacks)
	var reactions: PlayerAttackReactionRuntime = PlayerAttackReactionRuntime.new()
	reactions.name = "PlayerAttackReactionRuntime"
	reactions.setup(contextual_attacks, robot, encounter_runtime)
	add_child(reactions)


func _build_leaderboard_bridge() -> void:
	leaderboard_bridge = LEADERBOARD_BRIDGE_SCRIPT.new() as LeaderboardBridge
	leaderboard_bridge.name = "LeaderboardBridge"
	add_child(leaderboard_bridge)
	leaderboard_bridge.setup(combat_profile, gameplay_hud.match_debrief)


func _on_robot_heavy_impact(
	origin: Vector2,
	radius: float,
	actor_damage: float,
	structural_damage: float,
	impulse_per_mass: float,
	attack_id: int
) -> void:
	var options: DamageQueryOptions = DamageQueryOptions.new()
	options.damage_type = &"ground_smash"
	options.structural_damage_scale = structural_damage / maxf(actor_damage, 0.001)
	_reduce_enemy_wrecks_to_rubble(
		origin,
		radius + GROUND_SMASH_WRECK_RADIUS_BONUS,
		actor_damage,
		impulse_per_mass,
		attack_id,
		options
	)
	destruction_director.queue_explosion(
		origin,
		radius,
		actor_damage,
		impulse_per_mass,
		attack_id,
		robot,
		options
	)
	AerialDebrisLauncher.launch(
		get_tree(),
		debris_pool,
		robot,
		origin,
		impulse_per_mass,
		attack_id,
		options,
		air_target_lock_runtime.consume_volley_target(attack_id)
	)
	gameplay_hud.set_objective("objective.impact_registered")


func _reduce_enemy_wrecks_to_rubble(
	origin: Vector2,
	radius: float,
	damage: float,
	impulse_per_mass: float,
	attack_id: int,
	options: DamageQueryOptions
) -> int:
	if enemy_remains_factory == null or radius <= 0.0 or damage <= 0.0:
		return 0
	var candidates: Array[EnemyWreck2D] = []
	for index: int in range(enemy_remains_factory.active_count()):
		var wreck: EnemyWreck2D = enemy_remains_factory.active_wreck_at(index)
		if wreck != null:
			candidates.append(wreck)
	var reduced_count: int = 0
	var radius_squared: float = radius * radius
	for wreck: EnemyWreck2D in candidates:
		if origin.distance_squared_to(wreck.global_position) > radius_squared:
			continue
		var direction: Vector2 = origin.direction_to(wreck.global_position)
		if direction.is_zero_approx():
			direction = Vector2.UP
		var event: DamageEvent = DamageEvent.new(
			attack_id,
			robot,
			damage,
			&"ground_smash",
			origin,
			direction,
			impulse_per_mass,
			options.root_attack_id,
			options.causal_depth,
			options.effect_flags,
			options.kinetic_debris_bonus
		)
		if wreck.reduce_to_rubble(event):
			reduced_count += 1
	return reduced_count


func _material_for_target(
	target: Node,
	hit_position: Vector2
) -> StructuralMaterialProfile:
	if target is Destructible2D:
		var cell_profile: StructuralMaterialProfile = (
			(target as Destructible2D).get_material_profile()
		)
		if cell_profile != null:
			return cell_profile
	if target is StructuralBuilding2D:
		var cell: Destructible2D = (
			(target as StructuralBuilding2D).cell_at_world_point(hit_position)
		)
		if cell != null and cell.get_material_profile() != null:
			return cell.get_material_profile()
	if target is EnemyWreck2D:
		return (target as EnemyWreck2D).get_material_profile()
	return StructuralMaterialProfile.concrete()

func _on_streamed_building_damage_applied(
	streamed_building: StructuralBuilding2D,
	amount: float,
	event: DamageEvent
) -> void:
	rampage_events.building_damage(amount, event, streamed_building, robot)
	if event.damage_type in [&"floor_chain", &"steel_support_chain"]:
		return
	var material_profile: StructuralMaterialProfile = _material_for_target(
		streamed_building,
		event.hit_position
	)
	impact_feedback_pool.play_audio(
		material_profile,
		event.hit_position,
		event.impulse_per_mass
	)
	impact_feedback_pool.spawn_particles(
		event.hit_position,
		event.direction,
		event.impulse_per_mass,
		material_profile
	)

func _on_streamed_building_cell_destroyed(
	streamed_building: StructuralBuilding2D,
	column: int,
	row: int,
	event: DamageEvent
) -> void:
	rampage_events.cell_destroyed(column, row, event, streamed_building, robot)

func _on_streamed_building_chain_started(
	streamed_building: StructuralBuilding2D,
	kind: StringName,
	event: DamageEvent
) -> void:
	rampage_events.chain_started(kind, event, streamed_building, robot)
	gameplay_hud.set_objective(
		"objective.steel_failure" if kind == &"steel_support_chain" else "objective.floor_lost"
	)

func _on_streamed_building_chain_step(
	streamed_building: StructuralBuilding2D,
	_kind: StringName,
	column: int,
	row: int,
	event: DamageEvent
) -> void:
	var profile: StructuralMaterialProfile = streamed_building.get_material_profile(
		column,
		row
	)
	impact_feedback_pool.play_audio(
		profile,
		event.hit_position,
		event.impulse_per_mass,
		true,
		AudioVoicePriority.MAJOR
	)
	impact_feedback_pool.spawn_particles(
		event.hit_position,
		event.direction,
		event.impulse_per_mass * 0.62,
		profile
	)


func _on_streamed_building_chain_completed(
	streamed_building: StructuralBuilding2D,
	kind: StringName
) -> void:
	if streamed_building.is_destroyed():
		return
	gameplay_hud.set_objective(
		"objective.steel_cascade_complete"
		if kind == &"steel_support_chain"
		else "objective.floor_collapse_complete"
	)


func _on_streamed_building_destroyed(
	streamed_building: StructuralBuilding2D,
	event: DamageEvent
) -> void:
	rampage_events.building_destroyed(event, streamed_building, robot)


func _on_streamed_prop_destroyed(
	prop: DestructibleProp2D,
	event: DamageEvent,
	points: int,
	is_car: bool
) -> void:
	rampage_events.prop_destroyed(prop, event, points, robot, is_car)


func _on_enemy_died(enemy: EnemyActor2D, event: DamageEvent, points: int) -> void:
	rampage_events.enemy_defeated(enemy, event, points, robot)
	var procedural: ProceduralEnemy = enemy as ProceduralEnemy
	if enemy is SoldierEnemy or (procedural != null and procedural.remains_family == &"infantry"):
		_spawn_soldier_defeat_body(enemy, event)
		encounter_runtime.release_deferred(enemy)
		return
	if urban_siege.boss_session.boss == enemy:
		_spawn_enemy_wreck(enemy, event)
	else:
		call_deferred("_spawn_enemy_wreck", enemy, event)
	encounter_runtime.release_deferred(enemy)


func _spawn_enemy_wreck(enemy: EnemyActor2D, event: DamageEvent) -> void:
	var wreck: EnemyWreck2D = enemy_remains_factory.spawn_wreck(enemy, event)
	if enemy is TankEnemy:
		tank_wreck = wreck
	else:
		helicopter_wreck = wreck


func _spawn_soldier_defeat_body(enemy: EnemyActor2D, event: DamageEvent) -> void:
	var display_size: Vector2 = Vector2(68.0, 108.0)
	if enemy is ProceduralEnemy:
		display_size = (enemy as ProceduralEnemy).profile.get("display", display_size) as Vector2
	soldier_defeat_body = soldier_defeat_pool.acquire(
		enemy.global_position,
		enemy.facing,
		event,
		enemy.visual.texture,
		display_size
	)


func _on_enemy_wreck_scrapped(
	wreck: EnemyWreck2D,
	event: DamageEvent,
	points: int
) -> void:
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.steel()
	rampage_events.wreck_scrapped(wreck, event, points, robot)
	impact_feedback_pool.play_audio(
		profile,
		wreck.global_position,
		maxf(event.impulse_per_mass, 220.0),
		true,
		AudioVoicePriority.MAJOR
	)
	impact_feedback_pool.spawn_particles(
		wreck.global_position,
		event.direction,
		maxf(event.impulse_per_mass, 220.0),
		profile
	)


func _add_score(points: int) -> void:
	rampage_events.legacy_score(points)


func _on_aerial_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D
) -> void:
	rampage_events.aerial_hit(body, event, target, robot)


func _on_ground_debris_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	_target: EnemyActor2D,
	impact_speed: float
) -> void:
	impact_feedback_pool.play_debris_enemy_impact(
		event.hit_position,
		event.direction,
		impact_speed,
		body.mass
	)


func _on_robot_damage_received(event: DamageEvent, accepted_damage: float) -> void:
	last_player_damage_source_id = DefeatSourceResolver.resolve(event, self)
	rampage_events.player_damage_received(event, accepted_damage, robot)


func _on_score_changed(next_score: int, _awarded: int) -> void:
	if gameplay_hud != null:
		gameplay_hud.set_score(next_score)


func _on_pending_score_changed(value: int) -> void:
	if gameplay_hud != null:
		gameplay_hud.set_pending_score(value)


func _on_combo_changed(multiplier: int, grace_remaining: float) -> void:
	if gameplay_hud != null:
		gameplay_hud.set_combo(multiplier, grace_remaining)


func _on_projectile_requested(
	origin: Vector2, direction: Vector2, speed: float, damage: float,
	kind: StringName, source: Node
) -> void:
	var delivery_lifetime: float = (
		(source as EnemyActor2D).attack_projectile_lifetime()
		if source is EnemyActor2D
		else 2.5
	)
	projectile_root.acquire(
		origin,
		direction,
		speed,
		damage,
		source,
		ROBOT_LAYER | BUILDING_LAYER,
		kind,
		&"",
		1.0,
		delivery_lifetime
	)

func _on_robot_health_changed(current: float, maximum: float) -> void:
	if gameplay_hud != null:
		gameplay_hud.set_health(current, maximum)


func _on_robot_defeated() -> void:
	if defeat_requested.get_connections().is_empty():
		present_defeat()
	else:
		defeat_requested.emit()


func present_defeat() -> void:
	if run_lifecycle != null:
		run_lifecycle.robot_defeated()


func _on_retry_pressed() -> void:
	if not game_over_active:
		return
	retry_requested.emit()


func _on_title_pressed() -> void:
	if not game_over_active:
		return
	title_requested.emit()
