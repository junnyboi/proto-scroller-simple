class_name BossDefeatSpectacle2D
extends Node2D

signal completed

const EXPLOSION_TEXTURE: Texture2D = preload(
	"res://assets/bosses/defeat_fx/boss-explosion-burst.webp"
)
const FIREWORK_TEXTURE: Texture2D = preload(
	"res://assets/bosses/defeat_fx/boss-firework-burst.webp"
)
const DEFEAT_SFX: AudioStream = preload(
	"res://assets/audio/sfx/boss/boss_defeat_spectacle.ogg"
)
const EXPLOSION_SLOT_CAPACITY: int = 12
const FIREWORK_SLOT_CAPACITY: int = 10
const EXPLOSION_EMITTER_CAPACITY: int = 8
const FIREWORK_EMITTER_CAPACITY: int = 6
const EXPLOSION_PARTICLES_PER_EMITTER: int = 34
const FIREWORK_PARTICLES_PER_EMITTER: int = 46
const EXPLOSION_LIFETIME: float = 0.76
const FIREWORK_LIFETIME: float = 1.08
const EXPLOSION_PARTICLE_LIFETIME: float = 1.18
const FIREWORK_PARTICLE_LIFETIME: float = 1.48
const COMPLETION_SETTLE_SECONDS: float = 0.12
const PRESENTATION_SECONDS: float = (
	2.00 + FIREWORK_PARTICLE_LIFETIME + COMPLETION_SETTLE_SECONDS
)
const EXPLOSION_TIMES: Array[float] = [
	0.00, 0.08, 0.17, 0.27, 0.39, 0.53,
	0.69, 0.87, 1.07, 1.29, 1.53, 1.79,
]
const FIREWORK_TIMES: Array[float] = [
	0.18, 0.31, 0.47, 0.64, 0.82,
	1.02, 1.24, 1.47, 1.72, 2.00,
]
const EXPLOSION_OFFSETS: Array[Vector2] = [
	Vector2(0.0, -118.0),
	Vector2(-176.0, -92.0),
	Vector2(166.0, -78.0),
	Vector2(-92.0, -218.0),
	Vector2(104.0, -236.0),
	Vector2(-224.0, -18.0),
	Vector2(224.0, -28.0),
	Vector2(-48.0, -72.0),
	Vector2(58.0, -126.0),
	Vector2(-136.0, -148.0),
	Vector2(142.0, -162.0),
	Vector2(0.0, -42.0),
]
const FIREWORK_OFFSETS: Array[Vector2] = [
	Vector2(-276.0, -322.0),
	Vector2(248.0, -354.0),
	Vector2(-88.0, -414.0),
	Vector2(106.0, -390.0),
	Vector2(-344.0, -226.0),
	Vector2(336.0, -242.0),
	Vector2(-184.0, -304.0),
	Vector2(190.0, -286.0),
	Vector2(-32.0, -348.0),
	Vector2(42.0, -272.0),
]

var active: bool = false
var elapsed: float = 0.0
var activation_count: int = 0
var explosion_trigger_count: int = 0
var firework_trigger_count: int = 0
var audio_play_count: int = 0
var post_warm_creation_count: int = 0
var explosion_sprites: Array[Sprite2D] = []
var firework_sprites: Array[Sprite2D] = []
var explosion_emitters: Array[GPUParticles2D] = []
var firework_emitters: Array[GPUParticles2D] = []
var audio_player: AudioStreamPlayer2D

var _next_explosion: int = 0
var _next_firework: int = 0
var _explosion_emitter_cursor: int = 0
var _firework_emitter_cursor: int = 0


func _init() -> void:
	name = "BossDefeatSpectacle2D"
	z_as_relative = false
	z_index = 94
	_prewarm()
	deactivate()


func activate(origin: Vector2, camera_rig: CameraRig = null) -> void:
	deactivate()
	global_position = origin
	active = true
	visible = true
	elapsed = 0.0
	activation_count += 1
	_next_explosion = 0
	_next_firework = 0
	_explosion_emitter_cursor = 0
	_firework_emitter_cursor = 0
	audio_player.global_position = origin
	audio_player.stop()
	audio_player.play()
	audio_play_count += 1
	if camera_rig != null:
		camera_rig.add_impact_impulse(Vector2(0.0, -26.0))
	_trigger_due_bursts()
	set_process(true)


func deactivate() -> void:
	active = false
	visible = false
	elapsed = 0.0
	set_process(false)
	for sprite: Sprite2D in explosion_sprites + firework_sprites:
		sprite.visible = false
	for particles: GPUParticles2D in explosion_emitters + firework_emitters:
		particles.emitting = false
	if audio_player != null:
		audio_player.stop()


func advance(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	elapsed += delta
	_trigger_due_bursts()
	_update_sprites()
	if elapsed >= PRESENTATION_SECONDS:
		deactivate()
		completed.emit()


func visual_slot_count() -> int:
	return explosion_sprites.size() + firework_sprites.size()


func particle_emitter_count() -> int:
	return explosion_emitters.size() + firework_emitters.size()


func particle_capacity() -> int:
	return (
		explosion_emitters.size() * EXPLOSION_PARTICLES_PER_EMITTER
		+ firework_emitters.size() * FIREWORK_PARTICLES_PER_EMITTER
	)


func audio_player_count() -> int:
	return 1 if audio_player != null else 0


func _process(delta: float) -> void:
	advance(delta)


func _prewarm() -> void:
	for index: int in range(EXPLOSION_SLOT_CAPACITY):
		var sprite: Sprite2D = _make_sprite(
			"Explosion%02d" % index,
			EXPLOSION_TEXTURE
		)
		add_child(sprite)
		explosion_sprites.append(sprite)
	for index: int in range(FIREWORK_SLOT_CAPACITY):
		var sprite: Sprite2D = _make_sprite(
			"Firework%02d" % index,
			FIREWORK_TEXTURE
		)
		add_child(sprite)
		firework_sprites.append(sprite)
	var explosion_material: ParticleProcessMaterial = _explosion_particle_material()
	for index: int in range(EXPLOSION_EMITTER_CAPACITY):
		var particles: GPUParticles2D = _make_particles(
			"ExplosionParticles%02d" % index,
			EXPLOSION_TEXTURE,
			EXPLOSION_PARTICLES_PER_EMITTER,
			EXPLOSION_PARTICLE_LIFETIME,
			explosion_material
		)
		add_child(particles)
		explosion_emitters.append(particles)
	var firework_material: ParticleProcessMaterial = _firework_particle_material()
	for index: int in range(FIREWORK_EMITTER_CAPACITY):
		var particles: GPUParticles2D = _make_particles(
			"FireworkParticles%02d" % index,
			FIREWORK_TEXTURE,
			FIREWORK_PARTICLES_PER_EMITTER,
			FIREWORK_PARTICLE_LIFETIME,
			firework_material
		)
		add_child(particles)
		firework_emitters.append(particles)
	audio_player = AudioStreamPlayer2D.new()
	audio_player.name = "BossDefeatAudio"
	audio_player.stream = DEFEAT_SFX
	audio_player.bus = GameAudioBus.SFX
	audio_player.volume_db = 3.0
	audio_player.max_distance = 2600.0
	audio_player.attenuation = 0.8
	add_child(audio_player)


func _make_sprite(sprite_name: String, texture: Texture2D) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.visible = false
	sprite.set_meta(&"started_at", -999.0)
	sprite.set_meta(&"base_scale", 1.0)
	return sprite


func _make_particles(
	particles_name: String,
	texture: Texture2D,
	amount: int,
	lifetime: float,
	material: ParticleProcessMaterial
) -> GPUParticles2D:
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = particles_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.randomness = 0.72
	particles.local_coords = true
	particles.texture = texture
	particles.process_material = material
	particles.visibility_rect = Rect2(-560.0, -560.0, 1120.0, 1120.0)
	particles.emitting = false
	return particles


func _explosion_particle_material() -> ParticleProcessMaterial:
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 160.0
	material.initial_velocity_max = 620.0
	material.gravity = Vector3(0.0, 340.0, 0.0)
	material.angular_velocity_min = -720.0
	material.angular_velocity_max = 720.0
	material.scale_min = 0.035
	material.scale_max = 0.12
	return material


func _firework_particle_material() -> ParticleProcessMaterial:
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 165.0
	material.initial_velocity_min = 210.0
	material.initial_velocity_max = 720.0
	material.gravity = Vector3(0.0, 210.0, 0.0)
	material.angular_velocity_min = -420.0
	material.angular_velocity_max = 420.0
	material.scale_min = 0.018
	material.scale_max = 0.060
	return material


func _trigger_due_bursts() -> void:
	while (
		_next_explosion < EXPLOSION_TIMES.size()
		and elapsed >= EXPLOSION_TIMES[_next_explosion]
	):
		_trigger_explosion(_next_explosion)
		_next_explosion += 1
	while (
		_next_firework < FIREWORK_TIMES.size()
		and elapsed >= FIREWORK_TIMES[_next_firework]
	):
		_trigger_firework(_next_firework)
		_next_firework += 1


func _trigger_explosion(index: int) -> void:
	var sprite: Sprite2D = explosion_sprites[index]
	var base_scale: float = 0.86 + float(index % 4) * 0.12
	_activate_sprite(sprite, EXPLOSION_OFFSETS[index], base_scale)
	var particles: GPUParticles2D = explosion_emitters[_explosion_emitter_cursor]
	particles.position = EXPLOSION_OFFSETS[index]
	particles.restart()
	particles.emitting = true
	_explosion_emitter_cursor = (
		(_explosion_emitter_cursor + 1) % explosion_emitters.size()
	)
	explosion_trigger_count += 1


func _trigger_firework(index: int) -> void:
	var sprite: Sprite2D = firework_sprites[index]
	var base_scale: float = 0.70 + float(index % 3) * 0.14
	_activate_sprite(sprite, FIREWORK_OFFSETS[index], base_scale)
	var particles: GPUParticles2D = firework_emitters[_firework_emitter_cursor]
	particles.position = FIREWORK_OFFSETS[index]
	particles.restart()
	particles.emitting = true
	_firework_emitter_cursor = (
		(_firework_emitter_cursor + 1) % firework_emitters.size()
	)
	firework_trigger_count += 1


func _activate_sprite(sprite: Sprite2D, offset: Vector2, base_scale: float) -> void:
	sprite.position = offset
	sprite.rotation = randf_range(-0.22, 0.22)
	sprite.scale = Vector2.ONE * base_scale * 0.12
	sprite.modulate = Color.WHITE
	sprite.visible = true
	sprite.set_meta(&"started_at", elapsed)
	sprite.set_meta(&"base_scale", base_scale)


func _update_sprites() -> void:
	for sprite: Sprite2D in explosion_sprites:
		_update_sprite(sprite, EXPLOSION_LIFETIME, 0.12, 1.32)
	for sprite: Sprite2D in firework_sprites:
		_update_sprite(sprite, FIREWORK_LIFETIME, 0.08, 1.18)


func _update_sprite(
	sprite: Sprite2D,
	lifetime: float,
	start_scale: float,
	end_scale: float
) -> void:
	if not sprite.visible:
		return
	var age: float = elapsed - float(sprite.get_meta(&"started_at", elapsed))
	if age >= lifetime:
		sprite.visible = false
		return
	var progress: float = clampf(age / lifetime, 0.0, 1.0)
	var base_scale: float = float(sprite.get_meta(&"base_scale", 1.0))
	var eased_scale: float = lerpf(start_scale, end_scale, 1.0 - pow(1.0 - progress, 3.0))
	sprite.scale = Vector2.ONE * base_scale * eased_scale
	sprite.modulate.a = clampf(1.0 - maxf(progress - 0.58, 0.0) / 0.42, 0.0, 1.0)
