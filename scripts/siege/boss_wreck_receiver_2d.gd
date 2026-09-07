class_name BossWreckReceiver2D
extends Area2D

const HURTBOX_LAYER: int = 1 << 6

var outcome_id: int = BossOutcome.PURGE
var wreck: EnemyWreck2D
var active: bool = false
var receiver_callback: Callable
var display_label: String = "SMASH"
var display_color: Color = Color(1.0, 0.78, 0.18, 1.0)
var warning: bool = false


func configure(
	p_wreck: EnemyWreck2D,
	p_outcome_id: int,
	world_position: Vector2,
	p_receiver_callback: Callable = Callable()
) -> void:
	wreck = p_wreck
	outcome_id = p_outcome_id
	receiver_callback = p_receiver_callback
	global_position = world_position
	active = wreck != null
	collision_layer = HURTBOX_LAYER if active else 0
	monitorable = active
	var collision: CollisionShape2D = get_node(^"Collision") as CollisionShape2D
	collision.disabled = not active
	visible = active
	queue_redraw()


func configure_presentation(label_value: String, color_value: Color, warned: bool = false) -> void:
	display_label = label_value
	display_color = color_value
	warning = warned
	queue_redraw()


func deactivate() -> void:
	wreck = null
	receiver_callback = Callable()
	active = false
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	visible = false
	var collision: CollisionShape2D = get_node_or_null(^"Collision") as CollisionShape2D
	if collision != null:
		collision.disabled = true
	queue_redraw()


func receive_damage(event: DamageEvent) -> bool:
	if not active or wreck == null or not is_instance_valid(wreck):
		return false
	if receiver_callback.is_valid():
		return bool(receiver_callback.call(self, event))
	return wreck.receive_damage(event)


func _draw() -> void:
	if not active:
		return
	var collision: CollisionShape2D = get_node_or_null(^"Collision") as CollisionShape2D
	var circle: CircleShape2D = (
		collision.shape as CircleShape2D if collision != null else null
	)
	var radius: float = circle.radius if circle != null else 40.0
	var color: Color = Color(1.0, 0.22, 0.18, 1.0) if warning else display_color
	draw_circle(Vector2.ZERO, radius * 0.82, Color(color, 0.28))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 6.0)
	draw_line(Vector2(-radius * 0.55, 0.0), Vector2(radius * 0.55, 0.0), color, 5.0)
	draw_line(Vector2(0.0, -radius * 0.55), Vector2(0.0, radius * 0.55), color, 5.0)
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(display_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, radius + 24.0),
		display_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		16,
		color
	)
