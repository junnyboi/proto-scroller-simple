class_name BossAttackParticleCatalog
extends RefCounted

const IMPACT_SPARK_TEXTURE: Texture2D = preload(
	"res://assets/presentation/impact_spark.png"
)
const ENERGY_MOTE_TEXTURE: Texture2D = preload(
	"res://assets/player/vfx/photon_core_orb.png"
)

const SAMARITAN_ID: StringName = &"SAMARITAN_15"
const MIMESIS_ID: StringName = &"MIMESIS_04"
const CANTOR_ID: StringName = &"CANTOR_31_PALE_ENGINE"
const CHOIR_ID: StringName = &"CHOIR_PRIME"

const PROFILES: Dictionary = {
	SAMARITAN_ID: {
		"signature": &"TRIAGE_LIFT_MOTES",
		"district_index": 1,
		"texture": ENERGY_MOTE_TEXTURE,
		"primary": Color("64fff0"),
		"secondary": Color("d7ff73"),
		"area_amount": 34,
		"area_lifetime": 0.78,
		"direction": Vector2.UP,
		"spread": 34.0,
		"gravity": Vector2(0.0, -54.0),
		"velocity_min": 24.0,
		"velocity_max": 76.0,
		"radial_accel": -18.0,
		"tangential_accel": 26.0,
		"angular_velocity": 82.0,
		"scale_min": 0.022,
		"scale_max": 0.052,
		"telegraph_amount": 28,
		"release_amount": 38,
		"burst_velocity_min": 92.0,
		"burst_velocity_max": 210.0,
	},
	MIMESIS_ID: {
		"signature": &"AFTERIMAGE_SPIRAL",
		"district_index": 2,
		"texture": IMPACT_SPARK_TEXTURE,
		"primary": Color("ff4fdd"),
		"secondary": Color("45f5ff"),
		"area_amount": 42,
		"area_lifetime": 0.56,
		"direction": Vector2.RIGHT,
		"spread": 180.0,
		"gravity": Vector2.ZERO,
		"velocity_min": 38.0,
		"velocity_max": 112.0,
		"radial_accel": -74.0,
		"tangential_accel": 248.0,
		"angular_velocity": 680.0,
		"scale_min": 0.055,
		"scale_max": 0.125,
		"telegraph_amount": 34,
		"release_amount": 46,
		"burst_velocity_min": 148.0,
		"burst_velocity_max": 326.0,
	},
	CANTOR_ID: {
		"signature": &"ORDNANCE_SPARK_RAIN",
		"district_index": 3,
		"texture": IMPACT_SPARK_TEXTURE,
		"primary": Color("ffb52f"),
		"secondary": Color("ff3c24"),
		"area_amount": 38,
		"area_lifetime": 0.68,
		"direction": Vector2.UP,
		"spread": 24.0,
		"gravity": Vector2(0.0, 680.0),
		"velocity_min": 96.0,
		"velocity_max": 238.0,
		"radial_accel": 0.0,
		"tangential_accel": 0.0,
		"angular_velocity": 520.0,
		"scale_min": 0.060,
		"scale_max": 0.145,
		"telegraph_amount": 30,
		"release_amount": 52,
		"burst_velocity_min": 214.0,
		"burst_velocity_max": 470.0,
	},
	CHOIR_ID: {
		"signature": &"SOVEREIGN_HALO_EMBERS",
		"district_index": 4,
		"texture": ENERGY_MOTE_TEXTURE,
		"primary": Color("ffe46b"),
		"secondary": Color("b56dff"),
		"area_amount": 48,
		"area_lifetime": 0.92,
		"direction": Vector2.UP,
		"spread": 180.0,
		"gravity": Vector2(0.0, -24.0),
		"velocity_min": 28.0,
		"velocity_max": 86.0,
		"radial_accel": -96.0,
		"tangential_accel": 186.0,
		"angular_velocity": 260.0,
		"scale_min": 0.026,
		"scale_max": 0.064,
		"telegraph_amount": 42,
		"release_amount": 60,
		"burst_velocity_min": 126.0,
		"burst_velocity_max": 292.0,
	},
}

const ATTACK_BOSS_IDS: Dictionary = {
	&"TRIAGE_SWEEP": SAMARITAN_ID,
	&"PRESSURE_SENTENCE": SAMARITAN_ID,
	&"EXTRACTION_CLAMP": SAMARITAN_ID,
	&"BLACKOUT_HARVEST": SAMARITAN_ID,
	&"DEAD_AIR_SWEEP": MIMESIS_ID,
	&"MEMORY_BLOCKING": MIMESIS_ID,
	&"ARMED_AFTERIMAGE": MIMESIS_ID,
	&"ENCORE_IMPACT": MIMESIS_ID,
	&"SUTURE_SALVO": CANTOR_ID,
	&"DISPATCH_HARNESS": CANTOR_ID,
	&"PALE_RECLAMATION": CANTOR_ID,
	&"COMPRESSION_PSALM": CANTOR_ID,
	&"LEDGER_SETTLEMENT_SWEEP": CHOIR_ID,
	&"NURSERY_BRACED_SHOCK": CHOIR_ID,
	&"STAGE_ARMED_RING": CHOIR_ID,
	&"ARSENAL_PRODUCTION_LANES": CHOIR_ID,
	&"CROWN_RADIAL_VERDICT": CHOIR_ID,
}


static func profile_for_boss(boss_id: StringName) -> Dictionary:
	return PROFILES.get(boss_id, {}) as Dictionary


static func profile_for_attack(attack_id: StringName) -> Dictionary:
	var boss_id: StringName = StringName(ATTACK_BOSS_IDS.get(attack_id, &""))
	return profile_for_boss(boss_id)


static func signature_for_boss(boss_id: StringName) -> StringName:
	return StringName(profile_for_boss(boss_id).get("signature", &""))


static func boss_id_for_attack(attack_id: StringName) -> StringName:
	return StringName(ATTACK_BOSS_IDS.get(attack_id, &""))


static func color_ramp(profile: Dictionary, peak_alpha: float = 1.0) -> Gradient:
	var primary: Color = profile.get("primary", Color.WHITE) as Color
	var secondary: Color = profile.get("secondary", primary) as Color
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = PackedColorArray([
		Color(primary, 0.0),
		Color(primary.lerp(secondary, 0.34), peak_alpha),
		Color(secondary, 0.0),
	])
	return gradient
