class_name EnemyAttackVfxCatalog
extends RefCounted

const PROJECTILE_ATLAS: Texture2D = preload(
	"res://art/city/enemies/choir-attacks/district-projectile-vfx.webp"
)
const IMPACT_ATLAS: Texture2D = preload(
	"res://art/city/enemies/choir-attacks/district-impact-vfx.webp"
)
const ATTACK_ATLAS: Texture2D = preload(
	"res://art/city/enemies/choir-attacks/district-attack-vfx.webp"
)
const ENEMY_BULLET_IMPACT_ATLAS: Texture2D = preload(
	"res://art/enemies/impacts/enemy_bullet_impact.png"
)
const ENEMY_SHELL_IMPACT_ATLAS: Texture2D = preload(
	"res://art/enemies/impacts/enemy_shell_impact.png"
)
const ENEMY_ROCKET_DIRECT_IMPACT_ATLAS: Texture2D = preload(
	"res://art/enemies/impacts/enemy_rocket_direct_impact.png"
)
const ENEMY_ROCKET_SALVO_IMPACT_ATLAS: Texture2D = preload(
	"res://art/enemies/impacts/enemy_rocket_salvo_impact.png"
)
const ATLAS_SIZE: Vector2i = Vector2i(360, 288)
const CELL_SIZE: Vector2i = Vector2i(72, 72)
const COLUMNS: int = 5
const HOSTILE_IMPACT_DURATION: float = 0.24
const ATTACK_VISIBLE_CENTER_OFFSETS: Array[Vector2] = [
	Vector2(-0.5, -3.5), Vector2(0.0, -8.0), Vector2(-2.0, -3.0),
	Vector2(-2.0, -3.5), Vector2(-2.5, -2.0), Vector2(-1.0, -13.5),
	Vector2(-0.5, -2.0), Vector2(-2.5, -1.0),
]
const PROJECTILE_VISIBLE_CENTER_OFFSETS: Array[Vector2] = [
	Vector2(-5.0, -3.5), Vector2(-6.5, -2.0), Vector2(1.5, -2.5),
	Vector2(1.0, -3.0), Vector2(3.5, -3.5), Vector2(0.0, -9.5),
	Vector2(-2.5, -4.0), Vector2(-0.5, -2.0),
]
const IMPACT_VISIBLE_CENTER_OFFSETS: Array[Vector2] = [
	Vector2(-0.5, 0.0), Vector2(-3.0, 0.0), Vector2(-0.5, 0.0),
	Vector2(-0.5, 0.0), Vector2(0.0, 0.0), Vector2(-0.5, -0.5),
	Vector2(0.0, 0.0), Vector2(0.0, 0.0),
]

const CANONICAL_IMPACT_SPECS: Dictionary = {
	&"enemy_bullet_impact": {
		"visual_key": &"enemy_bullet_impact",
		"texture": ENEMY_BULLET_IMPACT_ATLAS,
		"frame_cell_size": Vector2i(48, 32),
		"frame_count": 10,
		"columns": 5,
		"playback_fps": 30.0,
		"display_size": Vector2(44.0, 32.0),
		"pivot_normalized": Vector2(0.68, 0.5),
		"tint": Color.WHITE,
		"reference_damage": 7.0,
		"audio_cue": AudioCueRegistry.Cue.ENEMY_BULLET_IMPACT,
	},
	&"enemy_shell_impact": {
		"visual_key": &"enemy_shell_impact",
		"texture": ENEMY_SHELL_IMPACT_ATLAS,
		"frame_cell_size": Vector2i(64, 48),
		"frame_count": 10,
		"columns": 5,
		"playback_fps": 24.0,
		"display_size": Vector2(64.0, 48.0),
		"pivot_normalized": Vector2(0.65, 0.5),
		"tint": Color.WHITE,
		"reference_damage": 24.0,
		"audio_cue": AudioCueRegistry.Cue.ENEMY_SHELL_IMPACT,
	},
	&"enemy_rocket_direct_impact": {
		"visual_key": &"enemy_rocket_direct_impact",
		"texture": ENEMY_ROCKET_DIRECT_IMPACT_ATLAS,
		"frame_cell_size": Vector2i(96, 64),
		"frame_count": 10,
		"columns": 5,
		"playback_fps": 30.0,
		"display_size": Vector2(84.0, 56.0),
		"pivot_normalized": Vector2(0.78, 0.5),
		"tint": Color.WHITE,
		"reference_damage": 22.0,
		"audio_cue": AudioCueRegistry.Cue.ENEMY_ROCKET_DIRECT_IMPACT,
	},
	&"enemy_rocket_salvo_impact": {
		"visual_key": &"enemy_rocket_salvo_impact",
		"texture": ENEMY_ROCKET_SALVO_IMPACT_ATLAS,
		"frame_cell_size": Vector2i(72, 56),
		"frame_count": 10,
		"columns": 5,
		"playback_fps": 30.0,
		"display_size": Vector2(60.0, 44.0),
		"pivot_normalized": Vector2(0.5, 0.5),
		"tint": Color.WHITE,
		"reference_damage": 24.0,
		"audio_cue": AudioCueRegistry.Cue.ENEMY_ROCKET_SALVO_IMPACT,
	},
}

const RANGED_IDS: Array[StringName] = [
	&"covenant_warden",
	&"mercy_recovery_cart",
	&"rainvault_pressure_ward",
]

const SPECS: Dictionary = {
	&"covenant_warden": {
		"index": 0, "delivery": &"projectile", "kind": &"bullet",
		"projectile_key": &"choir_covenant_warden_shot",
		"impact_key": &"choir_covenant_warden_impact",
		"projectile_display": Vector2(42.0, 16.0),
		"impact_display": Vector2(104.0, 92.0),
		"attack_display": Vector2(132.0, 108.0),
	},
	&"mercy_recovery_cart": {
		"index": 1, "delivery": &"projectile", "kind": &"bullet",
		"projectile_key": &"choir_mercy_recovery_cart_shot",
		"impact_key": &"choir_mercy_recovery_cart_impact",
		"projectile_display": Vector2(40.0, 16.0),
		"impact_display": Vector2(102.0, 102.0),
		"attack_display": Vector2(118.0, 96.0),
	},
	&"testament_kite": {
		"index": 2, "delivery": &"actor", "kind": &"support",
		"projectile_display": Vector2(68.0, 84.0),
		"impact_display": Vector2(112.0, 112.0),
		"attack_display": Vector2(116.0, 128.0),
	},
	&"receivership_ambulance": {
		"index": 3, "delivery": &"actor", "kind": &"support",
		"projectile_display": Vector2(88.0, 80.0),
		"impact_display": Vector2(118.0, 100.0),
		"attack_display": Vector2(126.0, 112.0),
	},
	&"intake_shepherd": {
		"index": 4, "delivery": &"actor", "kind": &"support",
		"projectile_display": Vector2(58.0, 92.0),
		"impact_display": Vector2(104.0, 112.0),
		"attack_display": Vector2(108.0, 124.0),
	},
	&"evacuation_litter": {
		"index": 5, "delivery": &"actor", "kind": &"support",
		"projectile_display": Vector2(110.0, 72.0),
		"impact_display": Vector2(150.0, 104.0),
		"attack_display": Vector2(152.0, 104.0),
	},
	&"rainvault_pressure_ward": {
		"index": 6, "delivery": &"projectile", "kind": &"shell",
		"projectile_key": &"choir_rainvault_pressure_ward_shot",
		"impact_key": &"choir_rainvault_pressure_ward_impact",
		"projectile_display": Vector2(50.0, 24.0),
		"impact_display": Vector2(132.0, 124.0),
		"attack_display": Vector2(142.0, 128.0),
	},
	&"balcony_recall_beacon": {
		"index": 7, "delivery": &"actor", "kind": &"support",
		"projectile_display": Vector2(54.0, 92.0),
		"impact_display": Vector2(116.0, 116.0),
		"attack_display": Vector2(112.0, 138.0),
	},
}

static var _projectile_specs: Dictionary = {}
static var _impact_specs: Dictionary = {}


static func has(archetype_id: StringName) -> bool:
	return SPECS.has(archetype_id)


static func spec(archetype_id: StringName) -> Dictionary:
	return SPECS.get(archetype_id, {})


static func is_projectile_delivery(archetype_id: StringName) -> bool:
	return StringName(spec(archetype_id).get("delivery", &"")) == &"projectile"


static func projectile_key(archetype_id: StringName) -> StringName:
	return StringName(spec(archetype_id).get("projectile_key", &""))


static func impact_key(archetype_id: StringName) -> StringName:
	return StringName(spec(archetype_id).get("impact_key", &""))


static func phase_spec(archetype_id: StringName, phase: StringName) -> Dictionary:
	var item: Dictionary = spec(archetype_id)
	if item.is_empty() or not phase in [&"projectile", &"impact", &"attack"]:
		return {}
	var texture: Texture2D = PROJECTILE_ATLAS
	if phase == &"impact":
		texture = IMPACT_ATLAS
	elif phase == &"attack":
		texture = ATTACK_ATLAS
	return {
		"texture": texture,
		"region": _region_for_index(int(item.get("index", -1))),
		"display_size": item.get("%s_display" % phase, Vector2.ZERO),
		"visible_center_offset": _visible_center_offset(
			int(item.get("index", -1)),
			phase
		),
	}


static func projectile_spec_for_key(visual_key: StringName) -> Dictionary:
	_build_cached_specs()
	return _projectile_specs.get(visual_key, {})


static func impact_spec_for_key(visual_key: StringName) -> Dictionary:
	_build_cached_specs()
	return _impact_specs.get(visual_key, {})


static func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if SPECS.size() != 8:
		errors.append("Expected exactly 8 district attack VFX specs")
	if ATTACK_VISIBLE_CENTER_OFFSETS.size() != SPECS.size():
		errors.append("Attack visible-center metadata must cover every VFX spec")
	if PROJECTILE_VISIBLE_CENTER_OFFSETS.size() != SPECS.size():
		errors.append("Projectile visible-center metadata must cover every VFX spec")
	if IMPACT_VISIBLE_CENTER_OFFSETS.size() != SPECS.size():
		errors.append("Impact visible-center metadata must cover every VFX spec")
	var expected: Dictionary[StringName, bool] = {}
	for archetype_id: StringName in EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS:
		expected[archetype_id] = true
		if not SPECS.has(archetype_id):
			errors.append("Missing district attack VFX spec: %s" % archetype_id)
	for archetype_id: StringName in SPECS:
		if not expected.has(archetype_id):
			errors.append("Unexpected district attack VFX spec: %s" % archetype_id)
		_validate_item(archetype_id, SPECS[archetype_id] as Dictionary, errors)
	if RANGED_IDS.size() != 3:
		errors.append("Expected exactly three ranged district attack VFX specs")
	var projectile_count: int = 0
	var actor_count: int = 0
	var projectile_keys: Dictionary[StringName, bool] = {}
	var impact_keys: Dictionary[StringName, bool] = {}
	for archetype_id: StringName in SPECS:
		var item: Dictionary = SPECS[archetype_id] as Dictionary
		if is_projectile_delivery(archetype_id):
			projectile_count += 1
			var shot_key: StringName = StringName(item.get("projectile_key", &""))
			var hit_key: StringName = StringName(item.get("impact_key", &""))
			if projectile_keys.has(shot_key):
				errors.append("Duplicate projectile VFX key: %s" % shot_key)
			if impact_keys.has(hit_key):
				errors.append("Duplicate impact VFX key: %s" % hit_key)
			projectile_keys[shot_key] = true
			impact_keys[hit_key] = true
		else:
			actor_count += 1
			if not StringName(item.get("projectile_key", &"")).is_empty():
				errors.append("Actor-only VFX has projectile key: %s" % archetype_id)
			if not StringName(item.get("impact_key", &"")).is_empty():
				errors.append("Actor-only VFX has impact key: %s" % archetype_id)
	if projectile_count != 3 or actor_count != 5:
		errors.append("Expected 3 projectile and 5 actor attack VFX specs")
	return errors


static func _build_cached_specs() -> void:
	if not _projectile_specs.is_empty():
		return
	for impact_key: StringName in CANONICAL_IMPACT_SPECS:
		_impact_specs[impact_key] = CANONICAL_IMPACT_SPECS[impact_key]
	for archetype_id: StringName in RANGED_IDS:
		var item: Dictionary = spec(archetype_id)
		var shot_key: StringName = StringName(item.projectile_key)
		var hit_key: StringName = StringName(item.impact_key)
		var projectile_phase: Dictionary = phase_spec(archetype_id, &"projectile")
		_projectile_specs[shot_key] = {
			"texture": projectile_phase.texture,
			"region": projectile_phase.region,
			"source_size": ATLAS_SIZE,
			"display_size": projectile_phase.display_size,
			"visible_center_offset": projectile_phase.visible_center_offset,
			"collision_radius_contract": _radius_for_kind(StringName(item.kind)),
			"canonical_angle": 0.0,
			"trail_mode": ProjectileVisualCatalog.TrailMode.NONE,
			"impact_key": hit_key,
			"damage_kind": StringName(item.kind),
		}
		var impact_phase: Dictionary = phase_spec(archetype_id, &"impact")
		var damage_kind: StringName = StringName(item.kind)
		var reference_damage: float = maxf(
			float(EnemyArchetypeCatalog.profile(archetype_id).get("damage", 1.0)),
			1.0
		)
		_impact_specs[hit_key] = {
			"texture": impact_phase.texture,
			"region": impact_phase.region,
			"display_size": impact_phase.display_size,
			"visible_center_offset": impact_phase.visible_center_offset,
			"lifetime": HOSTILE_IMPACT_DURATION,
			"tint": Color.WHITE,
			"visual_key": hit_key,
			"reference_damage": reference_damage,
			"audio_cue": _audio_cue_for_kind(damage_kind),
		}


static func _validate_item(
	archetype_id: StringName,
	item: Dictionary,
	errors: PackedStringArray
) -> void:
	var item_index: int = int(item.get("index", -1))
	if item_index < 0 or item_index >= SPECS.size():
		errors.append("Invalid atlas index for %s" % archetype_id)
	var region: Rect2i = _region_for_index(item_index)
	if region.position.x < 0 or region.position.y < 0:
		errors.append("Invalid atlas region for %s" % archetype_id)
	if region.end.x > ATLAS_SIZE.x or region.end.y > ATLAS_SIZE.y:
		errors.append("Atlas region outside bounds for %s" % archetype_id)
	for phase: StringName in [&"projectile", &"impact", &"attack"]:
		var display_size: Vector2 = item.get("%s_display" % phase, Vector2.ZERO)
		if display_size.x <= 0.0 or display_size.y <= 0.0:
			errors.append("Invalid %s display size for %s" % [phase, archetype_id])
	var expected_index: int = EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS.find(archetype_id)
	if item_index != expected_index:
		errors.append("Atlas order mismatch for %s" % archetype_id)
	if is_projectile_delivery(archetype_id):
		if not archetype_id in RANGED_IDS:
			errors.append("Projectile delivery missing ranged classification: %s" % archetype_id)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		if StringName(item.get("kind", &"")) != StringName(profile.get("projectile_kind", &"")):
			errors.append("Projectile kind mismatch for %s" % archetype_id)
		if StringName(item.get("projectile_key", &"")).is_empty():
			errors.append("Missing projectile key for %s" % archetype_id)
		if StringName(item.get("impact_key", &"")).is_empty():
			errors.append("Missing impact key for %s" % archetype_id)


static func _region_for_index(index: int) -> Rect2i:
	if index < 0:
		return Rect2i(-1, -1, 0, 0)
	return Rect2i(
		(index % COLUMNS) * CELL_SIZE.x,
		(index / COLUMNS) * CELL_SIZE.y,
		CELL_SIZE.x,
		CELL_SIZE.y
	)


static func _visible_center_offset(index: int, phase: StringName) -> Vector2:
	if index < 0:
		return Vector2.ZERO
	var offsets: Array[Vector2] = ATTACK_VISIBLE_CENTER_OFFSETS
	if phase == &"projectile":
		offsets = PROJECTILE_VISIBLE_CENTER_OFFSETS
	elif phase == &"impact":
		offsets = IMPACT_VISIBLE_CENTER_OFFSETS
	return offsets[index] if index < offsets.size() else Vector2.ZERO


static func _radius_for_kind(kind: StringName) -> float:
	match kind:
		&"shell":
			return 9.0
		&"rocket":
			return 7.0
		_:
			return 5.0


static func _audio_cue_for_kind(kind: StringName) -> AudioCueRegistry.Cue:
	match kind:
		&"shell":
			return AudioCueRegistry.Cue.ENEMY_SHELL_IMPACT
		&"rocket":
			return AudioCueRegistry.Cue.ENEMY_ROCKET_DIRECT_IMPACT
		_:
			return AudioCueRegistry.Cue.ENEMY_BULLET_IMPACT
