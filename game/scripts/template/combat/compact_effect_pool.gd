class_name CompactEffectPool
extends Node2D

const SLOT_COUNT: int = 8
const IMPACT_TEXTURE: Texture2D = preload(
	"res://art/city/destructibles/debris/impact_flash.png"
)
const DEBRIS_TEXTURE: Texture2D = preload(
	"res://art/city/destructibles/debris/concrete_chunk.png"
)

var _slots: Array[Dictionary] = []
var _next_slot: int = 0


func _ready() -> void:
	for index: int in range(SLOT_COUNT):
		var root: Node2D = Node2D.new()
		root.name = "EffectSlot%02d" % [index]
		var flash: Sprite2D = Sprite2D.new()
		flash.texture = IMPACT_TEXTURE
		flash.scale = Vector2(0.45, 0.45)
		var debris: Sprite2D = Sprite2D.new()
		debris.texture = DEBRIS_TEXTURE
		debris.scale = Vector2(0.22, 0.22)
		root.add_child(flash)
		root.add_child(debris)
		root.visible = false
		add_child(root)
		_slots.append({
			"root": root,
			"flash": flash,
			"debris": debris,
			"remaining": 0.0,
			"lifetime": 0.0,
			"velocity": Vector2.ZERO,
		})


func _process(delta: float) -> void:
	for slot: Dictionary in _slots:
		var remaining: float = float(slot["remaining"])
		if remaining <= 0.0:
			continue
		remaining = maxf(remaining - delta, 0.0)
		slot["remaining"] = remaining
		var root: Node2D = slot["root"] as Node2D
		var velocity: Vector2 = slot["velocity"] as Vector2
		velocity.y += 420.0 * delta
		slot["velocity"] = velocity
		root.position += velocity * delta
		root.rotation += delta * 4.0
		var lifetime: float = maxf(float(slot["lifetime"]), 0.01)
		root.modulate.a = remaining / lifetime
		if is_zero_approx(remaining):
			root.visible = false


func spawn(world_position: Vector2, facing: int = 1, strength: float = 1.0) -> void:
	var slot: Dictionary = _slots[_next_slot]
	_next_slot = (_next_slot + 1) % _slots.size()
	var root: Node2D = slot["root"] as Node2D
	var flash: Sprite2D = slot["flash"] as Sprite2D
	var debris: Sprite2D = slot["debris"] as Sprite2D
	var clamped_strength: float = clampf(strength, 0.5, 1.5)
	root.position = world_position
	root.rotation = 0.0
	root.modulate = Color.WHITE
	root.visible = true
	flash.scale = Vector2.ONE * (0.36 + 0.18 * clamped_strength)
	debris.position = Vector2(float(facing) * 22.0, -10.0)
	debris.scale = Vector2.ONE * (0.16 + 0.08 * clamped_strength)
	slot["lifetime"] = 0.34
	slot["remaining"] = 0.34
	slot["velocity"] = Vector2(float(facing) * 95.0, -150.0) * clamped_strength


func slot_count() -> int:
	return _slots.size()


func active_count() -> int:
	var count: int = 0
	for slot: Dictionary in _slots:
		if float(slot["remaining"]) > 0.0:
			count += 1
	return count
