class_name EnemyRoleBadge
extends Node2D

var role_shape: StringName = &"circle"
var trait_shape: StringName = &""
var role_color: Color = Color("d7dde0")
var trait_color: Color = Color("ff815c")


func configure(
	role_profile: EnemyRoleProfile,
	trait_profile: EnemyTraitProfile
) -> void:
	role_shape = role_profile.badge_shape if role_profile != null else &"circle"
	role_color = role_profile.badge_color if role_profile != null else Color("d7dde0")
	trait_shape = trait_profile.badge_shape if trait_profile != null else &""
	trait_color = trait_profile.badge_color if trait_profile != null else Color("ff815c")
	visible = role_profile != null or trait_profile != null
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	_draw_shape(role_shape, Vector2.ZERO, 9.0, role_color)
	if not trait_shape.is_empty():
		_draw_shape(trait_shape, Vector2(14.0, 0.0), 7.0, trait_color)


func _draw_shape(shape: StringName, center: Vector2, radius: float, color: Color) -> void:
	if shape == &"triangle":
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, radius),
			center + Vector2(-radius, radius),
		]), color)
	elif shape == &"square":
		draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color)
	elif shape == &"chevron":
		draw_polyline(PackedVector2Array([
			center + Vector2(-radius, -radius * 0.5),
			center,
			center + Vector2(-radius, radius * 0.5),
		]), color, 4.0)
	elif shape == &"diamond":
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		]), color)
	else:
		draw_circle(center, radius, color)
