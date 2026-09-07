class_name ProjectileVisualCatalog
extends RefCounted

enum TrailMode {
	NONE,
	PROCEDURAL_LINE,
	EXHAUST_FLICKER,
}

const ENEMY_BULLET: StringName = &"enemy_bullet"
const ENEMY_SHELL: StringName = &"enemy_shell"
const ENEMY_ROCKET_DIRECT: StringName = &"enemy_rocket_direct"
const ENEMY_ROCKET_SALVO: StringName = &"enemy_rocket_salvo"

const SPECS: Dictionary = {
	ENEMY_BULLET: {
		"texture": preload("res://assets/enemies/projectiles/straight_bullet_tracer.png"),
		"source_size": Vector2i(96, 32),
		"display_size": Vector2(36.0, 12.0),
		"collision_radius_contract": 5.0,
		"canonical_angle": 0.0,
		"trail_mode": TrailMode.NONE,
		"impact_key": &"enemy_bullet_impact",
	},
	ENEMY_SHELL: {
		"texture": preload("res://assets/combat/projectiles/straight_shell.png"),
		"source_size": Vector2i(256, 128),
		"display_size": Vector2(36.0, 18.0),
		"collision_radius_contract": 9.0,
		"canonical_angle": 0.0,
		"trail_mode": TrailMode.NONE,
		"impact_key": &"enemy_shell_impact",
	},
	ENEMY_ROCKET_DIRECT: {
		"texture": preload("res://assets/city/projectiles/enemy_direct_rocket.png"),
		"source_size": Vector2i(256, 96),
		"display_size": Vector2(42.0, 16.0),
		"collision_radius_contract": 7.0,
		"canonical_angle": 0.0,
		"trail_mode": TrailMode.NONE,
		"impact_key": &"enemy_rocket_direct_impact",
	},
	ENEMY_ROCKET_SALVO: {
		"texture": preload("res://assets/city/projectiles/hostile-spread-rocket.png"),
		"source_size": Vector2i(192, 72),
		"display_size": Vector2(36.0, 14.0),
		"collision_radius_contract": 7.0,
		"canonical_angle": 0.0,
		"trail_mode": TrailMode.NONE,
		"impact_key": &"enemy_rocket_salvo_impact",
	},
}


static func has(visual_key: StringName) -> bool:
	return SPECS.has(visual_key) or not (
		EnemyAttackVfxCatalog.projectile_spec_for_key(visual_key).is_empty()
	)


static func spec(visual_key: StringName) -> Dictionary:
	if SPECS.has(visual_key):
		return SPECS[visual_key] as Dictionary
	return EnemyAttackVfxCatalog.projectile_spec_for_key(visual_key)


static func default_key(damage_type: StringName) -> StringName:
	match damage_type:
		&"bullet":
			return ENEMY_BULLET
		&"shell":
			return ENEMY_SHELL
		&"rocket":
			return ENEMY_ROCKET_DIRECT
		_:
			return &""


static func debug_validate() -> bool:
	var visual_keys: Array[StringName] = []
	for visual_key: StringName in SPECS:
		visual_keys.append(visual_key)
	for archetype_id: StringName in EnemyAttackVfxCatalog.RANGED_IDS:
		visual_keys.append(EnemyAttackVfxCatalog.projectile_key(archetype_id))
	for visual_key: StringName in visual_keys:
		var item: Dictionary = spec(visual_key)
		var texture: Texture2D = item.get("texture") as Texture2D
		var source_size: Vector2i = item.get("source_size", Vector2i.ZERO)
		var display_size: Vector2 = item.get("display_size", Vector2.ZERO)
		var region: Rect2i = item.get("region", Rect2i())
		var radius: float = float(item.get("collision_radius_contract", 0.0))
		var impact_key: StringName = StringName(item.get("impact_key", &""))
		if texture == null or Vector2i(texture.get_size()) != source_size:
			return false
		if source_size.x <= 0 or source_size.y <= 0:
			return false
		if display_size.x <= 0.0 or display_size.y <= 0.0:
			return false
		if region.size != Vector2i.ZERO:
			if region.position.x < 0 or region.position.y < 0:
				return false
			if region.end.x > source_size.x or region.end.y > source_size.y:
				return false
		if not is_equal_approx(radius, _expected_collision_radius(visual_key)):
			return false
		if impact_key.is_empty() or EnemyAttackVfxCatalog.impact_spec_for_key(impact_key).is_empty():
			return false
	return true


static func _expected_collision_radius(visual_key: StringName) -> float:
	match visual_key:
		ENEMY_BULLET:
			return 5.0
		ENEMY_SHELL:
			return 9.0
		ENEMY_ROCKET_DIRECT, ENEMY_ROCKET_SALVO:
			return 7.0
		_:
			var item: Dictionary = EnemyAttackVfxCatalog.projectile_spec_for_key(visual_key)
			match StringName(item.get("damage_kind", &"")):
				&"shell":
					return 9.0
				&"rocket":
					return 7.0
				&"bullet":
					return 5.0
			return 0.0
