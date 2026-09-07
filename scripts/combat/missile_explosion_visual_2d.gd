class_name MissileExplosionVisual2D
extends Node2D

const FLASH_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/missile_explosion_flash.png"
)
const FIRE_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/missile_explosion_fire.png"
)
const SMOKE_TEXTURE: Texture2D = preload(
	"res://assets/player/weapons/missile_explosion_smoke.png"
)

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 0.68
var activation_count: int = 0
var flash_sprite: Sprite2D
var fire_sprite: Sprite2D
var smoke_sprite: Sprite2D
var particles: GPUParticles2D


func _ready() -> void:
	z_as_relative = false
	z_index = 82
	flash_sprite = _make_sprite("Flash", FLASH_TEXTURE, Vector2(120.0, 120.0))
	fire_sprite = _make_sprite("Fireball", FIRE_TEXTURE, Vector2(180.0, 180.0))
	smoke_sprite = _make_sprite("Smoke", SMOKE_TEXTURE, Vector2(210.0, 210.0))
	add_child(smoke_sprite)
	add_child(fire_sprite)
	add_child(flash_sprite)
	particles = GPUParticles2D.new()
	particles.name = "ExplosionParticles"
	particles.amount = 12
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.45
	particles.texture = FLASH_TEXTURE
	particles.visibility_rect = Rect2(-220.0, -220.0, 440.0, 440.0)
	var particle_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_material.direction = Vector3(1.0, 0.0, 0.0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 150.0
	particle_material.initial_velocity_max = 390.0
	particle_material.gravity = Vector3(0.0, 260.0, 0.0)
	particle_material.scale_min = 0.025
	particle_material.scale_max = 0.055
	particles.process_material = particle_material
	add_child(particles)
	deactivate()


func activate(world_position: Vector2, scale_multiplier: float = 1.0) -> void:
	global_position = world_position
	rotation = 0.0
	scale = Vector2.ONE * clampf(scale_multiplier, 0.1, 3.0)
	age = 0.0
	active = true
	visible = true
	flash_sprite.visible = true
	fire_sprite.visible = true
	smoke_sprite.visible = true
	particles.restart()
	particles.emitting = true
	activation_count += 1
	set_process(true)
	_update_visuals()


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)
	if particles != null:
		particles.emitting = false


func _process(delta: float) -> void:
	if not active or paused:
		return
	age += delta
	_update_visuals()
	if age >= lifetime:
		deactivate()


func _update_visuals() -> void:
	var progress: float = clampf(age / lifetime, 0.0, 1.0)
	var flash_progress: float = clampf(age / 0.16, 0.0, 1.0)
	flash_sprite.scale = Vector2.ONE * lerpf(0.55, 1.0, flash_progress)
	flash_sprite.modulate.a = 1.0 - flash_progress
	fire_sprite.scale = Vector2.ONE * lerpf(0.40, 0.92, minf(progress * 1.8, 1.0))
	fire_sprite.modulate.a = clampf(1.0 - maxf(progress - 0.48, 0.0) / 0.52, 0.0, 1.0)
	smoke_sprite.scale = Vector2.ONE * lerpf(0.30, 1.06, progress)
	smoke_sprite.modulate.a = sin(progress * PI) * 0.86


func _make_sprite(
	node_name: String,
	texture: Texture2D,
	display_size: Vector2
) -> Sprite2D:
	var result: Sprite2D = Sprite2D.new()
	result.name = node_name
	result.texture = texture
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	result.scale = Vector2.ONE * fit_scale
	return result
