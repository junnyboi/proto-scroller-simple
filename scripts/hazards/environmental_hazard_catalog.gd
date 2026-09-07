class_name EnvironmentalHazardCatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"traffic_signal", &"steam_main", &"powerline", &"road_plate",
	&"crane_drop", &"gas_fireline", &"facade_shear", &"metro_vent",
	&"metro_car", &"flooded_lane", &"skybridge", &"ammo_convoy",
]
const MVP_IDS: Array[StringName] = [
	&"traffic_signal", &"steam_main", &"powerline", &"road_plate",
]
const TIER2_IDS: Array[StringName] = [
	&"crane_drop", &"gas_fireline", &"facade_shear", &"metro_vent",
]
const APEX_IDS: Array[StringName] = [
	&"metro_car", &"flooded_lane", &"skybridge", &"ammo_convoy",
]
const ACTIVE_IDS: Array[StringName] = [
	&"traffic_signal", &"steam_main", &"powerline", &"road_plate",
	&"crane_drop", &"gas_fireline", &"facade_shear", &"metro_vent",
	&"metro_car", &"flooded_lane", &"skybridge", &"ammo_convoy",
]
const AUDIO_PROFILES: Dictionary = {
	&"traffic_signal": {
		"stream": "res://assets/audio/sfx/hazards/traffic_signal.wav",
		"warning_gain_db": -12.0, "warning_pitch": 0.88,
		"impact_gain_db": -3.0, "impact_pitch": 0.90,
		"pulse_gain_db": -13.0, "pulse_pitch": 0.96,
		"priority": 7, "retrigger_ms": 720,
	},
	&"steam_main": {
		"stream": "res://assets/audio/sfx/hazards/steam_main.wav",
		"warning_gain_db": -14.0, "warning_pitch": 1.16,
		"impact_gain_db": -6.0, "impact_pitch": 1.08,
		"pulse_gain_db": -14.0, "pulse_pitch": 1.18,
		"priority": 4, "retrigger_ms": 520,
	},
	&"powerline": {
		"stream": "res://assets/audio/sfx/hazards/powerline.wav",
		"warning_gain_db": -13.0, "warning_pitch": 1.28,
		"impact_gain_db": -5.0, "impact_pitch": 1.18,
		"pulse_gain_db": -13.0, "pulse_pitch": 1.32,
		"priority": 6, "retrigger_ms": 480,
	},
	&"road_plate": {
		"stream": "res://assets/audio/sfx/hazards/road_plate.wav",
		"warning_gain_db": -12.0, "warning_pitch": 0.96,
		"impact_gain_db": -4.0, "impact_pitch": 1.04,
		"pulse_gain_db": -14.0, "pulse_pitch": 1.08,
		"priority": 6, "retrigger_ms": 700,
	},
	&"crane_drop": {
		"stream": "res://assets/audio/sfx/hazards/crane_drop.wav",
		"warning_gain_db": -9.0, "warning_pitch": 0.72,
		"impact_gain_db": -2.0, "impact_pitch": 0.78,
		"pulse_gain_db": -12.0, "pulse_pitch": 0.82,
		"priority": 8, "retrigger_ms": 900,
	},
	&"gas_fireline": {
		"stream": "res://assets/audio/sfx/hazards/gas_fireline.wav",
		"warning_gain_db": -12.0, "warning_pitch": 1.08,
		"impact_gain_db": -5.0, "impact_pitch": 0.94,
		"pulse_gain_db": -13.0, "pulse_pitch": 1.02,
		"priority": 6, "retrigger_ms": 520,
	},
	&"facade_shear": {
		"stream": "res://assets/audio/sfx/hazards/facade_shear.wav",
		"warning_gain_db": -9.0, "warning_pitch": 0.76,
		"impact_gain_db": -2.5, "impact_pitch": 0.82,
		"pulse_gain_db": -12.0, "pulse_pitch": 0.86,
		"priority": 8, "retrigger_ms": 900,
	},
	&"metro_vent": {
		"stream": "res://assets/audio/sfx/hazards/metro_vent.wav",
		"warning_gain_db": -13.0, "warning_pitch": 1.12,
		"impact_gain_db": -6.0, "impact_pitch": 1.08,
		"pulse_gain_db": -14.0, "pulse_pitch": 1.14,
		"priority": 5, "retrigger_ms": 480,
	},
	&"metro_car": {
		"stream": "res://assets/audio/sfx/hazards/metro_car.wav",
		"warning_gain_db": -8.0, "warning_pitch": 0.68,
		"impact_gain_db": -1.0, "impact_pitch": 0.74,
		"pulse_gain_db": -11.0, "pulse_pitch": 0.78,
		"priority": 9, "retrigger_ms": 1000,
	},
	&"flooded_lane": {
		"stream": "res://assets/audio/sfx/hazards/flooded_lane.wav",
		"warning_gain_db": -11.0, "warning_pitch": 1.28,
		"impact_gain_db": -5.0, "impact_pitch": 1.20,
		"pulse_gain_db": -12.0, "pulse_pitch": 1.30,
		"priority": 7, "retrigger_ms": 450,
	},
	&"skybridge": {
		"stream": "res://assets/audio/sfx/hazards/skybridge.wav",
		"warning_gain_db": -7.0, "warning_pitch": 0.62,
		"impact_gain_db": -1.0, "impact_pitch": 0.68,
		"pulse_gain_db": -10.0, "pulse_pitch": 0.72,
		"priority": 10, "retrigger_ms": 1000,
	},
	&"ammo_convoy": {
		"stream": "res://assets/audio/sfx/hazards/ammo_convoy.wav",
		"warning_gain_db": -9.0, "warning_pitch": 1.06,
		"impact_gain_db": -1.5, "impact_pitch": 0.90,
		"pulse_gain_db": -8.0, "pulse_pitch": 0.94,
		"priority": 9, "retrigger_ms": 420,
	},
}
const PROFILES: Dictionary = {
	&"traffic_signal": {
		"display_name": "TRAFFIC SIGNAL KILLZONE", "cost": 1,
		"texture": "res://assets/city/hazards/traffic_signal_gantry.png",
		"display": Vector2(360.0, 245.0), "collision": Vector2(340.0, 190.0),
		"telegraph": 0.80, "active": 0.25, "aftermath": 2.75,
		"radius": 250.0, "enemy_damage": 120.0, "player_scale": 0.58,
		"impulse": 760.0, "behavior": &"collapse", "damage_type": &"hazard_crush",
		"warning": Color("ffb24a"), "impact": Color("ff6b32"),
		"particles": 30, "particle_lifetime": 1.10, "spread": 42.0,
		"gravity": Vector2(0.0, 720.0), "particle_speed": Vector2(170.0, 520.0),
		"particle_scale": Vector2(0.34, 0.82), "shake": Vector2(0.62, -0.88),
		"shake_pulses": 2,
	},
	&"steam_main": {
		"display_name": "STEAM MAIN BURST", "cost": 1,
		"texture": "res://assets/city/hazards/steam_main_valve.png",
		"display": Vector2(150.0, 133.0), "collision": Vector2(132.0, 108.0),
		"telegraph": 0.75, "active": 1.50, "aftermath": 0.75,
		"radius": 205.0, "enemy_damage": 32.0, "player_scale": 0.55,
		"impulse": 560.0, "behavior": &"steam", "damage_type": &"hazard_steam",
		"warning": Color("f6bd62"), "impact": Color("dff8ff"),
		"particles": 38, "particle_lifetime": 1.35, "spread": 22.0,
		"gravity": Vector2(0.0, -180.0), "particle_speed": Vector2(210.0, 430.0),
		"particle_scale": Vector2(0.48, 1.18), "shake": Vector2(0.28, -0.42),
		"shake_pulses": 3,
	},
	&"powerline": {
		"display_name": "POWERLINE SNAP", "cost": 2,
		"texture": "res://assets/city/hazards/powerline_pole.png",
		"display": Vector2(83.0, 320.0), "collision": Vector2(70.0, 300.0),
		"telegraph": 0.95, "active": 3.00, "aftermath": 0.60,
		"radius": 235.0, "enemy_damage": 44.0, "player_scale": 0.48,
		"impulse": 220.0, "behavior": &"electric", "damage_type": &"hazard_electric",
		"warning": Color("65cfff"), "impact": Color("79efff"),
		"particles": 26, "particle_lifetime": 0.72, "spread": 165.0,
		"gravity": Vector2.ZERO, "particle_speed": Vector2(90.0, 250.0),
		"particle_scale": Vector2(0.22, 0.62), "shake": Vector2(0.34, -0.30),
		"shake_pulses": 4,
	},
	&"road_plate": {
		"display_name": "BUCKLED ROAD PLATE", "cost": 2,
		"texture": "res://assets/city/hazards/buckled_road_plate.png",
		"display": Vector2(280.0, 55.0), "collision": Vector2(265.0, 46.0),
		"telegraph": 0.70, "active": 0.30, "aftermath": 3.00,
		"radius": 220.0, "enemy_damage": 90.0, "player_scale": 0.50,
		"impulse": 920.0, "behavior": &"ramp", "damage_type": &"hazard_launch",
		"warning": Color("ffd15a"), "impact": Color("ef9c45"),
		"particles": 34, "particle_lifetime": 0.92, "spread": 58.0,
		"gravity": Vector2(0.0, 860.0), "particle_speed": Vector2(190.0, 590.0),
		"particle_scale": Vector2(0.28, 0.76), "shake": Vector2(0.52, -0.72),
		"shake_pulses": 2,
	},
	&"crane_drop": {
		"display_name": "CRANE COUNTERWEIGHT DROP", "cost": 3,
		"texture": "res://assets/city/hazards/crane_counterweight.png",
		"display": Vector2(185.0, 220.0), "collision": Vector2(170.0, 205.0),
		"telegraph": 1.25, "active": 0.24, "aftermath": 3.20,
		"radius": 270.0, "enemy_damage": 185.0, "player_scale": 0.56,
		"impulse": 1050.0, "behavior": &"drop", "damage_type": &"hazard_crush",
		"warning": Color("ffca5a"),
		"impact": Color("f4a64d"), "particles": 42, "particle_lifetime": 1.30,
		"spread": 48.0, "gravity": Vector2(0.0, 920.0),
		"particle_speed": Vector2(260.0, 690.0), "particle_scale": Vector2(0.44, 1.10),
		"shake": Vector2(0.82, -1.00), "shake_pulses": 3,
	},
	&"gas_fireline": {
		"display_name": "GAS MAIN FIRELINE", "cost": 3,
		"texture": "res://assets/city/hazards/gas_fireline_manifold.png",
		"display": Vector2(200.0, 95.0), "collision": Vector2(184.0, 78.0),
		"telegraph": 0.45, "active": 3.50, "aftermath": 1.00,
		"radius": 315.0, "enemy_damage": 27.0, "player_scale": 0.50,
		"impulse": 190.0, "behavior": &"fireline", "damage_type": &"hazard_fire",
		"pulse_interval": 0.38, "warning": Color("ffad3d"),
		"impact": Color("ff7a35"), "particles": 46, "particle_lifetime": 1.10,
		"spread": 72.0, "gravity": Vector2(0.0, -260.0),
		"particle_speed": Vector2(170.0, 480.0), "particle_scale": Vector2(0.36, 1.26),
		"shake": Vector2(0.42, -0.54), "shake_pulses": 5,
	},
	&"facade_shear": {
		"display_name": "FACADE SHEAR", "cost": 3,
		"texture": "res://assets/city/hazards/facade_shear_slab.png",
		"display": Vector2(220.0, 315.0), "collision": Vector2(198.0, 286.0),
		"telegraph": 1.40, "active": 0.55, "aftermath": 3.50,
		"radius": 285.0, "enemy_damage": 165.0, "player_scale": 0.54,
		"impulse": 940.0, "behavior": &"shear", "damage_type": &"hazard_crush",
		"warning": Color("e0c49d"),
		"impact": Color("c6aa87"), "particles": 54, "particle_lifetime": 1.45,
		"spread": 38.0, "gravity": Vector2(0.0, 980.0),
		"particle_speed": Vector2(240.0, 740.0), "particle_scale": Vector2(0.40, 1.24),
		"shake": Vector2(0.76, -0.92), "shake_pulses": 4,
	},
	&"metro_vent": {
		"display_name": "METRO VENT SURGE", "cost": 2,
		"texture": "res://assets/city/hazards/metro_vent_grate.png",
		"display": Vector2(235.0, 70.0), "collision": Vector2(220.0, 52.0),
		"telegraph": 0.70, "active": 1.00, "aftermath": 0.60,
		"radius": 190.0, "enemy_damage": 42.0, "player_scale": 0.48,
		"impulse": 1220.0, "behavior": &"vent", "damage_type": &"hazard_launch",
		"pulse_interval": 0.26, "warning": Color("f8dfac"),
		"impact": Color("f2d1a2"), "particles": 40, "particle_lifetime": 1.25,
		"spread": 18.0, "gravity": Vector2(0.0, -420.0),
		"particle_speed": Vector2(260.0, 620.0), "particle_scale": Vector2(0.30, 0.84),
		"shake": Vector2(0.22, -0.58), "shake_pulses": 3,
	},
	&"metro_car": {
		"display_name": "DERAILED METRO CAR", "cost": 4,
		"texture": "res://assets/city/hazards/derailed_metro_car.png",
		"display": Vector2(540.0, 230.0), "collision": Vector2(510.0, 190.0),
		"telegraph": 2.00, "active": 0.70, "aftermath": 4.00,
		"radius": 390.0, "enemy_damage": 230.0, "player_scale": 0.52,
		"impulse": 1380.0, "behavior": &"metro_crash", "damage_type": &"hazard_crush",
		"warning": Color("f0c37a"), "impact": Color("e3b26d"),
		"chain_targets": [&"ammo_convoy", &"road_plate"], "chain_radius": 520.0,
		"particles": 64, "particle_lifetime": 1.70,
		"spread": 46.0, "gravity": Vector2(0.0, 1040.0),
		"particle_speed": Vector2(320.0, 860.0), "particle_scale": Vector2(0.54, 1.46),
		"shake": Vector2(1.00, -0.94), "shake_pulses": 6,
	},
	&"flooded_lane": {
		"display_name": "FLOODED ELECTRIFIED LANE", "cost": 4,
		"texture": "res://assets/city/hazards/electrified_flood_lane.png",
		"display": Vector2(520.0, 120.0), "collision": Vector2(500.0, 92.0),
		"telegraph": 1.00, "active": 2.00, "aftermath": 2.00,
		"radius": 360.0, "enemy_damage": 38.0, "player_scale": 0.45,
		"impulse": 260.0, "behavior": &"flood", "damage_type": &"hazard_electric",
		"pulse_interval": 0.32, "warning": Color("8cecff"),
		"impact": Color("67dfff"),
		"chain_targets": [&"metro_car", &"powerline"], "chain_radius": 520.0,
		"particles": 36, "particle_lifetime": 0.82,
		"spread": 175.0, "gravity": Vector2.ZERO,
		"particle_speed": Vector2(130.0, 330.0), "particle_scale": Vector2(0.24, 0.72),
		"shake": Vector2(0.38, -0.34), "shake_pulses": 6,
	},
	&"skybridge": {
		"display_name": "COLLAPSING SKYBRIDGE", "cost": 5,
		"texture": "res://assets/city/hazards/collapsing_skybridge.png",
		"display": Vector2(610.0, 145.0), "collision": Vector2(580.0, 122.0),
		"telegraph": 1.80, "active": 0.65, "aftermath": 4.50,
		"radius": 430.0, "enemy_damage": 260.0, "player_scale": 0.50,
		"impulse": 1520.0, "behavior": &"skybridge", "damage_type": &"hazard_crush",
		"warning": Color("e8cc9c"), "impact": Color("d5b487"),
		"chain_targets": [&"flooded_lane", &"ammo_convoy"], "chain_radius": 560.0,
		"particles": 70, "particle_lifetime": 1.85,
		"spread": 42.0, "gravity": Vector2(0.0, 1120.0),
		"particle_speed": Vector2(340.0, 930.0), "particle_scale": Vector2(0.60, 1.62),
		"shake": Vector2(1.00, -1.00), "shake_pulses": 7,
	},
	&"ammo_convoy": {
		"display_name": "AMMUNITION CONVOY CHAIN", "cost": 5,
		"texture": "res://assets/city/hazards/ammunition_convoy.png",
		"display": Vector2(620.0, 160.0), "collision": Vector2(590.0, 132.0),
		"telegraph": 0.35, "active": 2.10, "aftermath": 3.50,
		"radius": 300.0, "enemy_damage": 76.0, "player_scale": 0.48,
		"impulse": 1180.0, "behavior": &"convoy", "damage_type": &"hazard_fire",
		"pulse_interval": 0.40, "warning": Color("ffb247"),
		"impact": Color("ff7138"),
		"chain_targets": [&"skybridge", &"gas_fireline"], "chain_radius": 560.0,
		"particles": 72, "particle_lifetime": 1.55,
		"spread": 88.0, "gravity": Vector2(0.0, 820.0),
		"particle_speed": Vector2(290.0, 880.0), "particle_scale": Vector2(0.52, 1.55),
		"shake": Vector2(0.88, -0.82), "shake_pulses": 8,
	},
}


static func has(hazard_id: StringName) -> bool:
	return PROFILES.has(hazard_id)


static func profile(hazard_id: StringName) -> Dictionary:
	return PROFILES.get(hazard_id, {})


static func pressure_cost(hazard_id: StringName) -> int:
	return int(profile(hazard_id).get("cost", 0))


static func audio_profile(hazard_id: StringName) -> Dictionary:
	return AUDIO_PROFILES.get(hazard_id, {})


static func mvp_profiles_valid() -> bool:
	for hazard_id: StringName in MVP_IDS:
		var item: Dictionary = profile(hazard_id)
		if item.is_empty() or not item.has("texture") or not item.has("behavior"):
			return false
	return true


static func active_profiles_valid() -> bool:
	for hazard_id: StringName in ACTIVE_IDS:
		var item: Dictionary = profile(hazard_id)
		if item.is_empty() or not item.has("texture") or not item.has("behavior"):
			return false
		if not item.has("display") or not item.has("collision"):
			return false
		if not item.has("radius") or not item.has("enemy_damage"):
			return false
		var audio: Dictionary = audio_profile(hazard_id)
		if audio.is_empty() or not audio.has("stream") or not audio.has("priority"):
			return false
	return true
