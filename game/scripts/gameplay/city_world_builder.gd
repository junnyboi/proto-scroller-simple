class_name CityWorldBuilder
extends RefCounted
# gdlint: disable=function-arguments-number

const WORLD_LAYER: int = 1 << 0
const ROBOT_LAYER: int = 1 << 1
const ENEMY_LAYER: int = 1 << 2
const BUILDING_LAYER: int = 1 << 3
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const DEBRIS_LAYER: int = 1 << 8
const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const REAR_BARRIER_LAYER: int = 1 << 11
const LAND_VISUAL_BASELINE_Y: float = 655.0
const ROBOT_START_POSITION: Vector2 = Vector2(760.0, 466.5)
const ROBOT_ROAD_CLEARANCE_PIXELS: float = 35.0
const ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y: float = 27.5
const ROBOT_SCRIPT: Script = preload("res://scripts/player/giant_robot_controller.gd")
const CAMERA_RIG_SCRIPT: Script = preload("res://scripts/camera/camera_rig.gd")
const DISTRICT_PARALLAX_SCRIPT: Script = preload(
	"res://scripts/world/district_parallax_runtime.gd"
)
const DISTRICT_WEATHER_SCRIPT: Script = preload(
	"res://scripts/world/district_weather_runtime.gd"
)
const ROBOT_ATLAS: Texture2D = preload(
	"res://art/robot/grunt/grunt_horizontal_atlas.png"
)
const ROBOT_ANIMATION_PRESENTER: Script = preload(
	"res://scripts/player/robot_animation_presenter.gd"
)


static func build_environment(parent: Node2D) -> void:
	var backdrop: DistrictParallaxRuntime = (
		DISTRICT_PARALLAX_SCRIPT.new() as DistrictParallaxRuntime
	)
	backdrop.name = "ParallaxCity"
	parent.add_child(backdrop)
	var weather: DistrictWeatherRuntime = (
		DISTRICT_WEATHER_SCRIPT.new() as DistrictWeatherRuntime
	)
	weather.name = "DistrictWeather"
	parent.add_child(weather)


static func transition_environment(
	parent: Node2D,
	district_id: StringName,
	immediate: bool = false
) -> bool:
	var parallax_changed: bool = transition_parallax(parent, district_id, immediate)
	var weather: DistrictWeatherRuntime = _weather(parent)
	var weather_changed: bool = (
		weather.transition_to(district_id, immediate) if weather != null else false
	)
	return parallax_changed or weather_changed


static func transition_parallax(
	parent: Node2D,
	district_id: StringName,
	immediate: bool = false
) -> bool:
	var backdrop: DistrictParallaxRuntime = _parallax(parent)
	return backdrop.transition_to(district_id, immediate) if backdrop != null else false


static func compensate_parallax(parent: Node2D, offset: Vector2) -> void:
	var backdrop: DistrictParallaxRuntime = _parallax(parent)
	if backdrop != null:
		backdrop.compensate_origin(offset)


static func reset_parallax(parent: Node2D) -> void:
	var backdrop: DistrictParallaxRuntime = _parallax(parent)
	if backdrop != null:
		backdrop.reset_to_business()


static func reset_environment(parent: Node2D) -> void:
	reset_parallax(parent)
	var weather: DistrictWeatherRuntime = _weather(parent)
	if weather != null:
		weather.reset_to_business()


static func initial_run_seed(deterministic: bool) -> int:
	if deterministic or not OS.has_feature("web"):
		return 0
	var wall_clock_msec: int = int(Time.get_unix_time_from_system() * 1000.0)
	return maxi(wall_clock_msec ^ Time.get_ticks_msec(), 1)


static func build_robot(
	parent: Node2D,
	on_heavy_impact: Callable,
	on_health_changed: Callable,
	on_damage_received: Callable,
	on_defeated: Callable
) -> GiantRobotController:
	var robot: GiantRobotController = ROBOT_SCRIPT.new() as GiantRobotController
	robot.name = "Robot"
	robot.position = ROBOT_START_POSITION
	robot.max_health = 500.0
	robot.stomp_radius = 320.0
	robot.stomp_damage = 180.0
	robot.collision_layer = ROBOT_LAYER
	robot.collision_mask = WORLD_LAYER | BUILDING_LAYER | REAR_BARRIER_LAYER
	robot.z_index = 100
	robot.set_meta(&"combat_team", &"player")
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	body_shape.name = "BodyCollision"
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = 46.0
	capsule.height = 205.0
	body_shape.shape = capsule
	body_shape.position = Vector2(0.0, 21.0)
	robot.add_child(body_shape)
	var visual_root: Node2D = Node2D.new()
	visual_root.name = "VisualRoot"
	visual_root.position.y = ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y
	visual_root.set_meta(&"baked_directional_art", true)
	var robot_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	robot_sprite.name = "RobotAnimatedSprite"
	robot_sprite.sprite_frames = RobotSpriteFramesBuilder.build(ROBOT_ATLAS)
	robot_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	robot_sprite.scale = Vector2.ONE * 1.246
	robot_sprite.position.y = 72.0
	visual_root.add_child(robot_sprite)
	var visual_ground_origin: Marker2D = Marker2D.new()
	visual_ground_origin.name = "VisualGroundOrigin"
	visual_ground_origin.position = Vector2(0.0, 126.0)
	visual_root.add_child(visual_ground_origin)
	robot.add_child(visual_root)
	var impact_origin: Marker2D = Marker2D.new()
	impact_origin.name = "GroundImpactOrigin"
	impact_origin.position = Vector2(0.0, 126.0)
	robot.add_child(impact_origin)
	var laser_emitter: Marker2D = Marker2D.new()
	laser_emitter.name = "LaserEmitter"
	laser_emitter.position = Vector2(54.0, -32.0)
	visual_root.add_child(laser_emitter)
	var animation_presenter: RobotAnimationPresenter = ROBOT_ANIMATION_PRESENTER.new()
	animation_presenter.name = "RobotAnimationPresenter"
	animation_presenter.setup(robot, robot_sprite)
	robot.add_child(animation_presenter)
	var hurtbox: Area2D = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.collision_mask = 0
	var hurt_shape: CollisionShape2D = CollisionShape2D.new()
	var hurt_rectangle: RectangleShape2D = RectangleShape2D.new()
	hurt_rectangle.size = Vector2(205.0, 220.0)
	hurt_shape.shape = hurt_rectangle
	hurtbox.add_child(hurt_shape)
	robot.add_child(hurtbox)
	robot.heavy_impact_requested.connect(on_heavy_impact)
	robot.health_changed.connect(on_health_changed)
	robot.damage_received.connect(on_damage_received)
	robot.defeated.connect(on_defeated)
	parent.add_child(robot)
	return robot


static func build_camera(parent: Node2D, robot: GiantRobotController) -> void:
	var camera_rig: CameraRig = CAMERA_RIG_SCRIPT.new() as CameraRig
	camera_rig.name = "CameraRig"
	camera_rig.target = robot
	camera_rig.position = Vector2(640.0, 360.0)
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.position = Vector2.ZERO
	camera_rig.add_child(camera)
	parent.add_child(camera_rig)
	camera.make_current()
	camera.reset_smoothing()


static func fit_sprite(texture: Texture2D, display_size: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	sprite.scale = Vector2.ONE * fit_scale
	return sprite


static func _parallax(parent: Node2D) -> DistrictParallaxRuntime:
	return parent.get_node_or_null(^"ParallaxCity") as DistrictParallaxRuntime


static func _weather(parent: Node2D) -> DistrictWeatherRuntime:
	return parent.get_node_or_null(^"DistrictWeather") as DistrictWeatherRuntime
