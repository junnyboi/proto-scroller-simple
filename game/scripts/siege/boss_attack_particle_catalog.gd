class_name BossAttackParticleCatalog
extends RefCounted

const ENERGY_MOTE_TEXTURE: Texture2D = preload(
	"res://art/player/vfx/photon_core_orb.png"
)

const SAMARITAN_ID: StringName = &"SAMARITAN_15"

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
}

const ATTACK_BOSS_IDS: Dictionary = {
	&"TRIAGE_SWEEP": SAMARITAN_ID,
	&"PRESSURE_SENTENCE": SAMARITAN_ID,
	&"EXTRACTION_CLAMP": SAMARITAN_ID,
	&"BLACKOUT_HARVEST": SAMARITAN_ID,
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
