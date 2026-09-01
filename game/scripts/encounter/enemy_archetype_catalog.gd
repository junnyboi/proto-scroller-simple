class_name EnemyArchetypeCatalog
extends RefCounted

const BASE_KINDS: Array[StringName] = [&"soldier", &"tank", &"helicopter"]
const HUMAN_KINDS: Array[StringName] = [
	&"soldier", &"bulwark", &"lobber", &"sapper",
]
const HUMAN_SPAWN_MULTIPLIER: int = 2
const HUMAN_RENDER_HEIGHT_PIXELS: float = 108.0
const GROUND_VEHICLE_SCALE: float = 2.0
const GROUND_VEHICLE_HEALTH_MULTIPLIER: float = 2.0
const VEHICLE_WEIGHT_NONE: StringName = &""
const VEHICLE_WEIGHT_LIGHT: StringName = &"light"
const VEHICLE_WEIGHT_HEAVY: StringName = &"heavy"
const RANDOM_AFFIXES: Array[StringName] = [&"BLITZ", &"BRUTAL", &"PHASED"]
const PROCEDURAL_IDS: Array[StringName] = [
	&"needle", &"bulwark", &"jackal", &"lobber", &"sapper",
	&"hound", &"reclaimed_breacher", &"graft_runner",
]

const DISTRICT_VARIANT_IDS: Array[StringName] = [
	&"covenant_warden", &"mercy_recovery_cart", &"testament_kite",
	&"receivership_ambulance", &"intake_shepherd", &"evacuation_litter",
	&"rainvault_pressure_ward", &"balcony_recall_beacon",
]
const ALL_SPAWNABLE_IDS: Array[StringName] = PROCEDURAL_IDS + DISTRICT_VARIANT_IDS
const DISTRICT_VARIANTS: Dictionary = {
	&"BUSINESS": [
		&"covenant_warden", &"mercy_recovery_cart", &"testament_kite",
		&"receivership_ambulance",
	],
	&"RESIDENTIAL": [
		&"intake_shepherd", &"evacuation_litter", &"rainvault_pressure_ward",
		&"balcony_recall_beacon",
	],
}

const DISTRICT_VARIANT_PROFILES: Dictionary = {
	&"covenant_warden": {
		"base_archetype_id": &"bulwark", "display_name": "COVENANT WARDEN",
		"texture": "res://art/city/enemies/archetypes/27-covenant-warden.png",
		"faces_right": false, "health": 125.0, "threat": 1, "xp": 700,
		"district_id": &"BUSINESS", "district_weight": 8,
		"attack_vfx_id": &"covenant_warden",
	},
	&"mercy_recovery_cart": {
		"base_archetype_id": &"jackal", "display_name": "MERCY RECOVERY CART",
		"texture": "res://art/city/enemies/archetypes/28-mercy-recovery-cart.png",
		"faces_right": false, "health": 100.0, "threat": 2, "xp": 950,
		"district_id": &"BUSINESS", "district_weight": 6,
		"attack_vfx_id": &"mercy_recovery_cart",
	},
	&"testament_kite": {
		"base_archetype_id": &"needle", "display_name": "TESTAMENT KITE",
		"texture": "res://art/city/enemies/archetypes/29-testament-kite.png",
		"faces_right": false, "display": Vector2(150.0, 150.0),
		"collision": Vector2(104.0, 104.0), "spawn_y": 175.0,
		"health": 45.0, "threat": 1, "xp": 420,
		"district_id": &"BUSINESS", "district_weight": 5,
		"attack_vfx_id": &"testament_kite",
		"variant_tags": [&"marker"],
	},
	&"receivership_ambulance": {
		"base_archetype_id": &"jackal", "display_name": "RECEIVERSHIP AMBULANCE",
		"texture": "res://art/city/enemies/archetypes/30-receivership-ambulance.png",
		"faces_right": false, "display": Vector2(245.0, 115.0),
		"collision": Vector2(225.0, 85.0), "spawn_y": 547.5,
		"health": 230.0, "speed": 58.0, "attack_interval": 2.3,
		"behavior": &"support", "movement_style": &"apc_roll",
		"attack_style": &"repair", "damage": 0.0, "threat": 3, "xp": 1900,
		"district_id": &"BUSINESS", "district_weight": 3,
		"attack_vfx_id": &"receivership_ambulance",
		"variant_tags": [&"healer"],
	},
	&"intake_shepherd": {
		"base_archetype_id": &"sapper", "display_name": "INTAKE SHEPHERD",
		"texture": "res://art/city/enemies/archetypes/31-intake-shepherd.png",
		"faces_right": false, "display": Vector2(125.0, 108.0),
		"collision": Vector2(48.0, 98.0), "health": 145.0,
		"threat": 2, "xp": 1250, "district_id": &"RESIDENTIAL",
		"district_weight": 13, "attack_vfx_id": &"intake_shepherd",
		"variant_tags": [&"healer"],
	},
	&"evacuation_litter": {
		"base_archetype_id": &"jackal", "display_name": "EVACUATION LITTER",
		"texture": "res://art/city/enemies/archetypes/32-evacuation-litter.png",
		"faces_right": false, "display": Vector2(215.0, 105.0),
		"collision": Vector2(184.0, 72.0), "spawn_y": 554.0,
		"health": 190.0, "projectile_speed": 0.0, "damage": 18.0,
		"anticipation": 0.52, "attack_style": &"shock_brace",
		"threat": 2, "xp": 1800, "district_id": &"RESIDENTIAL",
		"district_weight": 11, "attack_vfx_id": &"evacuation_litter",
	},
	&"rainvault_pressure_ward": {
		"base_archetype_id": &"lobber", "display_name": "RAINVAULT PRESSURE WARD",
		"texture": "res://art/city/enemies/archetypes/33-rainvault-pressure-ward.png",
		"faces_right": false, "display": Vector2(245.0, 140.0),
		"collision": Vector2(220.0, 90.0), "health": 255.0,
		"damage": 19.0, "threat": 3, "xp": 2200,
		"district_id": &"RESIDENTIAL", "district_weight": 8,
		"attack_vfx_id": &"rainvault_pressure_ward",
		"variant_tags": [&"artillery"],
	},
	&"balcony_recall_beacon": {
		"base_archetype_id": &"needle", "display_name": "BALCONY RECALL BEACON",
		"texture": "res://art/city/enemies/archetypes/34-balcony-recall-beacon.png",
		"faces_right": false, "display": Vector2(150.0, 180.0),
		"collision": Vector2(104.0, 132.0), "spawn_y": 205.0,
		"health": 90.0, "threat": 1, "xp": 800,
		"district_id": &"RESIDENTIAL", "district_weight": 10,
		"attack_vfx_id": &"balcony_recall_beacon",
		"variant_tags": [&"marker"],
	},
}

const PROFILES: Dictionary = {
	&"needle": {
		"display_name": "NEEDLE SPOTTER DRONE", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/01-needle-spotter-drone.png",
		"display": Vector2(120.0, 86.0), "collision": Vector2(98.0, 54.0),
		"spawn_y": 155.0, "health": 35.0, "speed": 205.0, "acceleration": 390.0,
		"preferred_range": 560.0, "minimum_range": 390.0, "attack_interval": 2.3,
		"projectile_kind": &"bullet", "projectile_speed": 760.0, "damage": 5.0,
		"anticipation": 0.68, "behavior": &"air_standoff", "movement_style": &"drone_hover",
		"attack_style": &"scan", "xp": 350, "threat": 1, "remains": &"air",
	},
	&"bulwark": {
		"display_name": "BULWARK RIOT TROOPER", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/02-bulwark-riot-trooper.png",
		"faces_right": true,
		"display": Vector2(116.85, 108.0), "collision": Vector2(48.0, 100.0),
		"spawn_y": 540.0, "health": 110.0, "speed": 64.0, "acceleration": 430.0,
		"preferred_range": 230.0, "minimum_range": 120.0, "attack_interval": 1.45,
		"projectile_kind": &"bullet", "projectile_speed": 690.0, "damage": 7.0,
		"anticipation": 0.48, "behavior": &"ground_standoff", "movement_style": &"shield_march",
		"attack_style": &"shield_burst", "xp": 650, "threat": 1, "remains": &"infantry",
	},
	&"jackal": {
		"display_name": "JACKAL RECON BUGGY", "family": &"light", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/03-jackal-recon-buggy.png",
		"display": Vector2(210.0, 100.0), "collision": Vector2(190.0, 72.0),
		"spawn_y": 554.0, "health": 90.0, "speed": 290.0, "acceleration": 780.0,
		"preferred_range": 340.0, "minimum_range": 170.0, "attack_interval": 1.1,
		"projectile_kind": &"bullet", "projectile_speed": 820.0, "damage": 6.0,
		"anticipation": 0.40, "behavior": &"ground_pass", "movement_style": &"wheel_sprint",
		"attack_style": &"turret_burst", "xp": 900, "threat": 2, "remains": &"vehicle",
	},
	&"lobber": {
		"display_name": "LOBBER GRENADIER", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/04-lobber-grenadier.png",
		"faces_right": true,
		"display": Vector2(110.07, 108.0), "collision": Vector2(44.0, 96.0),
		"spawn_y": 542.0, "health": 105.0, "speed": 82.0, "acceleration": 500.0,
		"preferred_range": 500.0, "minimum_range": 300.0, "attack_interval": 1.9,
		"projectile_kind": &"shell", "projectile_speed": 410.0, "damage": 14.0,
		"anticipation": 0.75, "behavior": &"ground_standoff", "movement_style": &"heavy_march",
		"attack_style": &"lob", "xp": 900, "threat": 2, "remains": &"infantry",
	},
	&"sapper": {
		"display_name": "SAPPER COMBAT ENGINEER", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/05-sapper-combat-engineer.png",
		"faces_right": true,
		"display": Vector2(109.24, 108.0), "collision": Vector2(46.0, 98.0),
		"spawn_y": 541.0, "health": 130.0, "speed": 76.0, "acceleration": 470.0,
		"preferred_range": 420.0, "minimum_range": 240.0, "attack_interval": 2.1,
		"projectile_kind": &"bullet", "projectile_speed": 670.0, "damage": 5.0,
		"anticipation": 0.60, "behavior": &"support", "movement_style": &"utility_march",
		"attack_style": &"repair", "xp": 1050, "threat": 2, "remains": &"infantry",
	},
	&"hound": {
		"display_name": "HOUND HUNTER DRONE", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/06-hound-hunter-drone.png",
		"faces_right": true,
		"display": Vector2(180.0, 150.0), "collision": Vector2(150.0, 104.0),
		"spawn_y": 230.0, "health": 170.0, "speed": 235.0, "acceleration": 520.0,
		"preferred_range": 250.0, "minimum_range": 110.0, "attack_interval": 1.2,
		"projectile_kind": &"bullet", "projectile_speed": 850.0, "damage": 9.0,
		"anticipation": 0.40, "behavior": &"air_close", "movement_style": &"hunter_lunge",
		"attack_style": &"autocannon", "xp": 1300, "threat": 3, "remains": &"air",
	},
	&"reclaimed_breacher": {
		"display_name": "RECLAIMED BREACHER", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/21-reclaimed-breacher.png",
		"display": Vector2(125.0, 108.0), "collision": Vector2(58.0, 100.0),
		"spawn_y": 540.0, "health": 420.0, "speed": 155.0, "acceleration": 620.0,
		"preferred_range": 250.0, "minimum_range": 105.0, "attack_interval": 1.65,
		"projectile_kind": &"bullet", "projectile_speed": 0.0, "damage": 24.0,
		"anticipation": 0.72, "behavior": &"ground_breacher",
		"movement_style": &"breacher_sprint", "attack_style": &"shock_brace",
		"xp": 2600, "threat": 3, "remains": &"infantry",
	},
	&"graft_runner": {
		"display_name": "GRAFT RUNNER", "family": &"light", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/22-graft-runner.png",
		"display": Vector2(195.0, 105.0), "collision": Vector2(158.0, 72.0),
		"spawn_y": 554.0, "health": 220.0, "speed": 315.0, "acceleration": 880.0,
		"preferred_range": 310.0, "minimum_range": 115.0, "attack_interval": 1.25,
		"projectile_kind": &"bullet", "projectile_speed": 0.0, "damage": 18.0,
		"anticipation": 0.44, "behavior": &"ground_pass",
		"movement_style": &"graft_circle", "attack_style": &"marked_leap",
		"xp": 3000, "threat": 3, "remains": &"vehicle",
	},
}


static func has(archetype_id: StringName) -> bool:
	return archetype_id in PROCEDURAL_IDS or archetype_id in DISTRICT_VARIANT_IDS


static func profile(archetype_id: StringName) -> Dictionary:
	if archetype_id in PROCEDURAL_IDS:
		return (PROFILES[archetype_id] as Dictionary).duplicate(true)
	if not archetype_id in DISTRICT_VARIANT_IDS:
		return {}
	var overlay: Dictionary = DISTRICT_VARIANT_PROFILES[archetype_id] as Dictionary
	var base_archetype_id: StringName = StringName(overlay.get("base_archetype_id", &""))
	if not PROFILES.has(base_archetype_id):
		return {}
	var flattened: Dictionary = (PROFILES[base_archetype_id] as Dictionary).duplicate(true)
	for key: Variant in overlay:
		flattened[key] = overlay[key]
	flattened["concrete_archetype_id"] = archetype_id
	return flattened


static func canonical_id(archetype_id: StringName) -> StringName:
	if not archetype_id in DISTRICT_VARIANT_IDS:
		return archetype_id
	return StringName(
		(DISTRICT_VARIANT_PROFILES[archetype_id] as Dictionary).get(
			"base_archetype_id",
			archetype_id
		)
	)


static func is_district_variant(archetype_id: StringName) -> bool:
	return archetype_id in DISTRICT_VARIANT_IDS


static func variants_for_district(district_id: StringName) -> Array[StringName]:
	var variants: Array[StringName] = []
	for archetype_id: StringName in DISTRICT_VARIANTS.get(district_id, []):
		variants.append(archetype_id)
	return variants


static func district_for_variant(archetype_id: StringName) -> StringName:
	if not archetype_id in DISTRICT_VARIANT_IDS:
		return &""
	return StringName(
		(DISTRICT_VARIANT_PROFILES[archetype_id] as Dictionary).get("district_id", &"")
	)


static func has_variant_tag(archetype_id: StringName, tag: StringName) -> bool:
	if not archetype_id in DISTRICT_VARIANT_IDS:
		return false
	var tags: Array = (DISTRICT_VARIANT_PROFILES[archetype_id] as Dictionary).get(
		"variant_tags",
		[]
	)
	return tag in tags


static func family_for(kind: StringName) -> StringName:
	if kind == &"soldier":
		return &"infantry"
	if kind == &"tank":
		return &"heavy"
	if kind == &"helicopter":
		return &"air"
	return StringName(profile(kind).get("family", &""))


static func reservation_key(kind: StringName) -> StringName:
	if kind in BASE_KINDS:
		return kind
	var family: StringName = family_for(kind)
	return StringName("procedural_%s" % family) if not family.is_empty() else &""


static func threat_cost(kind: StringName) -> int:
	if kind == &"tank":
		return 3
	if kind == &"helicopter":
		return 2
	if kind == &"soldier":
		return 1
	return int(profile(kind).get("threat", 0))


static func xp_value(kind: StringName) -> int:
	if kind == &"tank":
		return 1500
	if kind == &"helicopter":
		return 1200
	if kind == &"soldier":
		return 500
	return int(profile(kind).get("xp", 500))


static func score_value(kind: StringName) -> int:
	return xp_value(kind)


static func is_valid_kind(kind: StringName) -> bool:
	return kind in BASE_KINDS or has(kind)


static func is_human_enemy(kind: StringName) -> bool:
	return canonical_id(kind) in HUMAN_KINDS


static func is_ground_vehicle(kind: StringName) -> bool:
	if kind == &"tank":
		return true
	if not has(kind):
		return false
	var profile_value: Dictionary = profile(kind)
	return (
		not bool(profile_value.get("airborne", false))
		and StringName(profile_value.get("remains", &"")) == &"vehicle"
	)


static func vehicle_weight_class(kind: StringName) -> StringName:
	if not is_ground_vehicle(kind):
		return VEHICLE_WEIGHT_NONE
	return (
		VEHICLE_WEIGHT_LIGHT
		if family_for(kind) == &"light"
		else VEHICLE_WEIGHT_HEAVY
	)


static func is_airborne(kind: StringName) -> bool:
	if kind == &"helicopter":
		return true
	return bool(profile(kind).get("airborne", false))


static func presentation_scale(kind: StringName) -> float:
	var configured_scale: float = float(profile(kind).get("presentation_scale", 0.0))
	if configured_scale > 0.0:
		return configured_scale
	return GROUND_VEHICLE_SCALE if is_ground_vehicle(kind) else 1.0


static func health_multiplier(kind: StringName) -> float:
	return GROUND_VEHICLE_HEALTH_MULTIPLIER if is_ground_vehicle(kind) else 1.0


static func spawn_multiplier(kind: StringName) -> int:
	return HUMAN_SPAWN_MULTIPLIER if is_human_enemy(kind) else 1


static func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if PROCEDURAL_IDS.size() != 8:
		errors.append("Expected 8 procedural archetypes")
	if DISTRICT_VARIANT_IDS.size() != 8:
		errors.append("Expected 8 district variants")
	if ALL_SPAWNABLE_IDS.size() != 16:
		errors.append("Expected 16 all-spawnable archetypes")
	var seen: Dictionary[StringName, bool] = {}
	for archetype_id: StringName in ALL_SPAWNABLE_IDS:
		if seen.has(archetype_id):
			errors.append("Duplicate all-spawnable archetype: %s" % archetype_id)
		seen[archetype_id] = true
		if profile(archetype_id).is_empty():
			errors.append("Missing flattened profile: %s" % archetype_id)
	for district_id: StringName in [&"BUSINESS", &"RESIDENTIAL"]:
		var district_variants: Array[StringName] = variants_for_district(district_id)
		if district_variants.size() != 4:
			errors.append("Expected four variants for %s" % district_id)
		for archetype_id: StringName in district_variants:
			if district_for_variant(archetype_id) != district_id:
				errors.append("District mismatch for %s" % archetype_id)
				var base_archetype_id: StringName = canonical_id(archetype_id)
				if not PROFILES.has(base_archetype_id):
					errors.append("Missing base archetype for %s" % archetype_id)
				elif family_for(archetype_id) != family_for(base_archetype_id):
					errors.append("Family override is not allowed for %s" % archetype_id)
				var flattened: Dictionary = profile(archetype_id)
				var attack_vfx_id: StringName = StringName(
					flattened.get("attack_vfx_id", &"")
				)
				if attack_vfx_id != archetype_id:
					errors.append("Attack VFX identity mismatch for %s" % archetype_id)
				elif not EnemyAttackVfxCatalog.has(attack_vfx_id):
					errors.append("Missing attack VFX catalog entry for %s" % archetype_id)
	return errors
