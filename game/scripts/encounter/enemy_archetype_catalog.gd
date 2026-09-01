class_name EnemyArchetypeCatalog
extends RefCounted

const BASE_KINDS: Array[StringName] = [&"soldier", &"tank", &"helicopter"]
const HUMAN_KINDS: Array[StringName] = [
	&"soldier", &"bulwark", &"lobber", &"sapper", &"lancer",
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
	&"hound", &"mule", &"basilisk", &"lancer", &"static",
	&"kestrel", &"rainmaker", &"shrike", &"cinder", &"aegis",
	&"longbow", &"hive", &"goliath", &"nemesis", &"leviathan",
	&"reclaimed_breacher", &"graft_runner", &"choir_siren",
	&"ossuary_crawler", &"seraph_carrier", &"pale_engine",
]

const DISTRICT_VARIANT_IDS: Array[StringName] = [
	&"covenant_warden", &"mercy_recovery_cart", &"testament_kite",
	&"receivership_ambulance", &"intake_shepherd", &"evacuation_litter",
	&"rainvault_pressure_ward", &"balcony_recall_beacon", &"memorial_usher",
	&"glassback_double", &"recall_lantern", &"marquee_anesthetist",
	&"suture_marshal", &"mercy_raker", &"revetment_ward", &"triage_kite",
	&"privy_chirurgeon", &"laureate_courser", &"ninefold_witness",
	&"regency_conservator",
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
	&"ENTERTAINMENT": [
		&"memorial_usher", &"glassback_double", &"recall_lantern",
		&"marquee_anesthetist",
	],
	&"MILITARY": [
		&"suture_marshal", &"mercy_raker", &"revetment_ward", &"triage_kite",
	],
	&"ROYAL": [
		&"privy_chirurgeon", &"laureate_courser", &"ninefold_witness",
		&"regency_conservator",
	],
}

const DISTRICT_VARIANT_PROFILES: Dictionary = {
	&"covenant_warden": {
		"base_archetype_id": &"bulwark", "display_name": "COVENANT WARDEN",
		"texture": "res://art/city/enemies/archetypes/27-covenant-warden.png",
		"faces_right": false, "health": 125.0, "threat": 1, "score": 700,
		"district_id": &"BUSINESS", "district_weight": 8,
		"attack_vfx_id": &"covenant_warden",
	},
	&"mercy_recovery_cart": {
		"base_archetype_id": &"jackal", "display_name": "MERCY RECOVERY CART",
		"texture": "res://art/city/enemies/archetypes/28-mercy-recovery-cart.png",
		"faces_right": false, "health": 100.0, "threat": 2, "score": 950,
		"district_id": &"BUSINESS", "district_weight": 6,
		"attack_vfx_id": &"mercy_recovery_cart",
	},
	&"testament_kite": {
		"base_archetype_id": &"needle", "display_name": "TESTAMENT KITE",
		"texture": "res://art/city/enemies/archetypes/29-testament-kite.png",
		"faces_right": false, "display": Vector2(150.0, 150.0),
		"collision": Vector2(104.0, 104.0), "spawn_y": 175.0,
		"health": 45.0, "threat": 1, "score": 420,
		"district_id": &"BUSINESS", "district_weight": 5,
		"attack_vfx_id": &"testament_kite",
		"variant_tags": [&"marker"],
	},
	&"receivership_ambulance": {
		"base_archetype_id": &"aegis", "display_name": "RECEIVERSHIP AMBULANCE",
		"texture": "res://art/city/enemies/archetypes/30-receivership-ambulance.png",
		"faces_right": false, "display": Vector2(245.0, 115.0),
		"collision": Vector2(225.0, 85.0), "spawn_y": 547.5,
		"health": 230.0, "speed": 58.0, "attack_interval": 2.3,
		"behavior": &"support", "movement_style": &"apc_roll",
		"attack_style": &"repair", "damage": 0.0, "threat": 3, "score": 1900,
		"district_id": &"BUSINESS", "district_weight": 3,
		"attack_vfx_id": &"receivership_ambulance",
		"variant_tags": [&"healer"],
	},
	&"intake_shepherd": {
		"base_archetype_id": &"sapper", "display_name": "INTAKE SHEPHERD",
		"texture": "res://art/city/enemies/archetypes/31-intake-shepherd.png",
		"faces_right": false, "display": Vector2(125.0, 108.0),
		"collision": Vector2(48.0, 98.0), "health": 145.0,
		"threat": 2, "score": 1250, "district_id": &"RESIDENTIAL",
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
		"threat": 2, "score": 1800, "district_id": &"RESIDENTIAL",
		"district_weight": 11, "attack_vfx_id": &"evacuation_litter",
	},
	&"rainvault_pressure_ward": {
		"base_archetype_id": &"basilisk", "display_name": "RAINVAULT PRESSURE WARD",
		"texture": "res://art/city/enemies/archetypes/33-rainvault-pressure-ward.png",
		"faces_right": false, "display": Vector2(245.0, 140.0),
		"collision": Vector2(220.0, 90.0), "health": 255.0,
		"damage": 19.0, "threat": 3, "score": 2200,
		"district_id": &"RESIDENTIAL", "district_weight": 8,
		"attack_vfx_id": &"rainvault_pressure_ward",
		"variant_tags": [&"artillery"],
	},
	&"balcony_recall_beacon": {
		"base_archetype_id": &"needle", "display_name": "BALCONY RECALL BEACON",
		"texture": "res://art/city/enemies/archetypes/34-balcony-recall-beacon.png",
		"faces_right": false, "display": Vector2(150.0, 180.0),
		"collision": Vector2(104.0, 132.0), "spawn_y": 205.0,
		"health": 90.0, "threat": 1, "score": 800,
		"district_id": &"RESIDENTIAL", "district_weight": 10,
		"attack_vfx_id": &"balcony_recall_beacon",
		"variant_tags": [&"marker"],
	},
	&"memorial_usher": {
		"base_archetype_id": &"sapper", "display_name": "MEMORIAL USHER",
		"texture": "res://art/city/enemies/archetypes/35-memorial-usher.png",
		"faces_right": false, "display": Vector2(125.0, 108.0),
		"collision": Vector2(48.0, 98.0), "health": 135.0,
		"threat": 2, "score": 1400, "district_id": &"ENTERTAINMENT",
		"district_weight": 11, "attack_vfx_id": &"memorial_usher",
		"variant_tags": [&"healer"],
	},
	&"glassback_double": {
		"base_archetype_id": &"ossuary_crawler", "display_name": "GLASSBACK DOUBLE",
		"texture": "res://art/city/enemies/archetypes/36-glassback-double.png",
		"faces_right": false, "display": Vector2(220.0, 100.0),
		"collision": Vector2(190.0, 72.0), "presentation_scale": 1.0,
		"health": 185.0,
		"speed": 290.0, "acceleration": 780.0,
		"preferred_range": 340.0, "minimum_range": 170.0,
		"attack_interval": 1.1, "projectile_speed": 820.0, "damage": 6.0,
		"anticipation": 0.40, "behavior": &"ground_pass",
		"movement_style": &"wheel_sprint", "attack_style": &"turret_burst",
		"threat": 3, "score": 2400, "district_id": &"ENTERTAINMENT",
		"district_weight": 10, "attack_vfx_id": &"glassback_double",
	},
	&"recall_lantern": {
		"base_archetype_id": &"choir_siren", "display_name": "RECALL LANTERN",
		"texture": "res://art/city/enemies/archetypes/37-recall-lantern.png",
		"faces_right": false, "health": 280.0, "threat": 4, "score": 4000,
		"district_id": &"ENTERTAINMENT", "district_weight": 8,
		"attack_vfx_id": &"recall_lantern",
		"variant_tags": [&"marker"],
	},
	&"marquee_anesthetist": {
		"base_archetype_id": &"basilisk", "display_name": "MARQUEE ANESTHETIST",
		"texture": "res://art/city/enemies/archetypes/38-marquee-anesthetist.png",
		"faces_right": false, "display": Vector2(245.0, 135.0),
		"collision": Vector2(220.0, 90.0), "health": 275.0,
		"damage": 24.0, "threat": 4, "score": 3300,
		"district_id": &"ENTERTAINMENT", "district_weight": 6,
		"attack_vfx_id": &"marquee_anesthetist",
		"variant_tags": [&"artillery"],
	},
	&"suture_marshal": {
		"base_archetype_id": &"sapper", "display_name": "SUTURE MARSHAL",
		"texture": "res://art/city/enemies/archetypes/39-suture-marshal.png",
		"faces_right": false, "display": Vector2(125.0, 108.0),
		"collision": Vector2(48.0, 98.0), "health": 240.0,
		"threat": 3, "score": 2500, "district_id": &"MILITARY",
		"district_weight": 8, "attack_vfx_id": &"suture_marshal",
		"variant_tags": [&"healer"],
	},
	&"mercy_raker": {
		"base_archetype_id": &"jackal", "display_name": "MERCY RAKER",
		"texture": "res://art/city/enemies/archetypes/40-mercy-raker.png",
		"faces_right": false, "display": Vector2(230.0, 105.0),
		"collision": Vector2(202.0, 74.0), "health": 285.0,
		"damage": 10.0, "threat": 4, "score": 3600,
		"district_id": &"MILITARY", "district_weight": 7,
		"attack_vfx_id": &"mercy_raker",
	},
	&"revetment_ward": {
		"base_archetype_id": &"cinder", "display_name": "REVETMENT WARD",
		"texture": "res://art/city/enemies/archetypes/41-revetment-ward.png",
		"faces_right": false, "display": Vector2(255.0, 135.0),
		"collision": Vector2(230.0, 88.0), "health": 390.0,
		"damage": 20.0, "threat": 5, "score": 4400,
		"district_id": &"MILITARY", "district_weight": 5,
		"attack_vfx_id": &"revetment_ward",
	},
	&"triage_kite": {
		"base_archetype_id": &"kestrel", "display_name": "TRIAGE KITE",
		"texture": "res://art/city/enemies/archetypes/42-triage-kite.png",
		"faces_right": false, "display": Vector2(260.0, 130.0),
		"collision": Vector2(225.0, 78.0), "health": 275.0,
		"damage": 22.0, "threat": 4, "score": 4200,
		"district_id": &"MILITARY", "district_weight": 6,
		"attack_vfx_id": &"triage_kite",
		"variant_tags": [&"bomber"],
	},
	&"privy_chirurgeon": {
		"base_archetype_id": &"sapper", "display_name": "PRIVY CHIRURGEON",
		"texture": "res://art/city/enemies/archetypes/43-privy-chirurgeon.png",
		"faces_right": false, "display": Vector2(125.0, 108.0),
		"collision": Vector2(48.0, 98.0), "health": 175.0,
		"threat": 2, "score": 2600, "district_id": &"ROYAL",
		"district_weight": 8, "attack_vfx_id": &"privy_chirurgeon",
		"variant_tags": [&"healer"],
	},
	&"laureate_courser": {
		"base_archetype_id": &"ossuary_crawler", "display_name": "LAUREATE COURSER",
		"texture": "res://art/city/enemies/archetypes/44-laureate-courser.png",
		"faces_right": false, "display": Vector2(230.0, 118.0),
		"collision": Vector2(190.0, 76.0), "health": 285.0,
		"behavior": &"ground_pass", "threat": 4, "score": 4700,
		"district_id": &"ROYAL", "district_weight": 7,
		"attack_vfx_id": &"laureate_courser",
	},
	&"ninefold_witness": {
		"base_archetype_id": &"choir_siren", "display_name": "NINEFOLD WITNESS",
		"texture": "res://art/city/enemies/archetypes/45-ninefold-witness.png",
		"faces_right": false, "display": Vector2(205.0, 190.0),
		"collision": Vector2(132.0, 150.0), "health": 360.0,
		"threat": 5, "score": 6200, "district_id": &"ROYAL",
		"district_weight": 5, "attack_vfx_id": &"ninefold_witness",
		"variant_tags": [&"marker"],
	},
	&"regency_conservator": {
		"base_archetype_id": &"basilisk", "display_name": "REGENCY CONSERVATOR",
		"texture": "res://art/city/enemies/archetypes/46-regency-conservator.png",
		"faces_right": false, "display": Vector2(275.0, 145.0),
		"collision": Vector2(245.0, 94.0), "health": 395.0,
		"preferred_range": 720.0, "minimum_range": 450.0,
		"attack_interval": 3.0, "anticipation": 1.0, "damage": 30.0,
		"threat": 5, "score": 6500, "district_id": &"ROYAL",
		"district_weight": 4, "attack_vfx_id": &"regency_conservator",
		"variant_tags": [&"artillery"],
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
		"attack_style": &"scan", "score": 350, "threat": 1, "remains": &"air",
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
		"attack_style": &"shield_burst", "score": 650, "threat": 1, "remains": &"infantry",
	},
	&"jackal": {
		"display_name": "JACKAL RECON BUGGY", "family": &"light", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/03-jackal-recon-buggy.png",
		"display": Vector2(210.0, 100.0), "collision": Vector2(190.0, 72.0),
		"spawn_y": 554.0, "health": 90.0, "speed": 290.0, "acceleration": 780.0,
		"preferred_range": 340.0, "minimum_range": 170.0, "attack_interval": 1.1,
		"projectile_kind": &"bullet", "projectile_speed": 820.0, "damage": 6.0,
		"anticipation": 0.40, "behavior": &"ground_pass", "movement_style": &"wheel_sprint",
		"attack_style": &"turret_burst", "score": 900, "threat": 2, "remains": &"vehicle",
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
		"attack_style": &"lob", "score": 900, "threat": 2, "remains": &"infantry",
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
		"attack_style": &"repair", "score": 1050, "threat": 2, "remains": &"infantry",
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
		"attack_style": &"autocannon", "score": 1300, "threat": 3, "remains": &"air",
	},
	&"mule": {
		"display_name": "MULE ARMORED PERSONNEL CARRIER", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/07-mule-apc.png",
		"display": Vector2(245.0, 115.0), "collision": Vector2(225.0, 85.0),
		"spawn_y": 547.5, "health": 220.0, "speed": 72.0, "acceleration": 300.0,
		"preferred_range": 450.0, "minimum_range": 280.0, "attack_interval": 2.2,
		"projectile_kind": &"bullet", "projectile_speed": 720.0, "damage": 8.0,
		"anticipation": 0.62, "behavior": &"carrier", "movement_style": &"apc_roll",
		"attack_style": &"deploy", "spawn_kind": &"soldier", "spawn_limit": 2,
		"score": 1700, "threat": 3, "remains": &"vehicle",
	},
	&"basilisk": {
		"display_name": "BASILISK MORTAR CARRIER", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/08-basilisk-mortar-platform.png",
		"faces_right": true,
		"display": Vector2(230.0, 150.0), "collision": Vector2(215.0, 90.0),
		"spawn_y": 545.0, "health": 210.0, "speed": 54.0, "acceleration": 240.0,
		"preferred_range": 690.0, "minimum_range": 430.0, "attack_interval": 2.6,
		"projectile_kind": &"shell", "projectile_speed": 470.0, "damage": 20.0,
		"anticipation": 0.95, "behavior": &"ground_standoff", "movement_style": &"tracked_heavy",
		"attack_style": &"mortar_recoil", "score": 1900, "threat": 3, "remains": &"vehicle",
	},
	&"lancer": {
		"display_name": "LANCER MISSILE TEAM", "family": &"infantry", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/09-lancer-missile-team.png",
		"faces_right": true,
		"display": Vector2(128.81, 108.0), "collision": Vector2(120.0, 85.0),
		"spawn_y": 547.5, "health": 160.0, "speed": 58.0, "acceleration": 350.0,
		"preferred_range": 650.0, "minimum_range": 390.0, "attack_interval": 2.45,
		"projectile_kind": &"rocket", "projectile_speed": 520.0, "damage": 26.0,
		"anticipation": 0.90, "behavior": &"ground_standoff", "movement_style": &"team_shuffle",
		"attack_style": &"missile_launch", "score": 1800, "threat": 3, "remains": &"infantry",
	},
	&"static": {
		"display_name": "STATIC EW TRUCK", "family": &"light", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/10-static-ew-truck.png",
		"display": Vector2(230.0, 150.0), "collision": Vector2(205.0, 86.0),
		"spawn_y": 547.0, "health": 190.0, "speed": 52.0, "acceleration": 220.0,
		"preferred_range": 570.0, "minimum_range": 370.0, "attack_interval": 2.05,
		"projectile_kind": &"bullet", "projectile_speed": 700.0, "damage": 4.0,
		"anticipation": 0.55, "behavior": &"support", "movement_style": &"antenna_sway",
		"attack_style": &"jammer_pulse", "score": 2200, "threat": 4, "remains": &"vehicle",
	},
	&"kestrel": {
		"display_name": "KESTREL BOMBER DRONE", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/11-kestrel-bomber-drone.png",
		"faces_right": true,
		"display": Vector2(235.0, 120.0), "collision": Vector2(210.0, 72.0),
		"spawn_y": 145.0, "health": 170.0, "speed": 285.0, "acceleration": 580.0,
		"preferred_range": 360.0, "minimum_range": 160.0, "attack_interval": 2.1,
		"projectile_kind": &"rocket", "projectile_speed": 430.0, "damage": 18.0,
		"anticipation": 0.60, "behavior": &"air_pass", "movement_style": &"bomber_bank",
		"attack_style": &"bomb_drop", "score": 2300, "threat": 4, "remains": &"air",
	},
	&"rainmaker": {
		"display_name": "RAINMAKER MLRS", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/12-rainmaker-mlrs.png",
		"display": Vector2(260.0, 165.0), "collision": Vector2(230.0, 92.0),
		"spawn_y": 544.0, "health": 280.0, "speed": 48.0, "acceleration": 210.0,
		"preferred_range": 720.0, "minimum_range": 450.0, "attack_interval": 2.85,
		"projectile_kind": &"rocket", "projectile_speed": 500.0, "damage": 24.0,
		"anticipation": 1.05, "behavior": &"ground_standoff", "movement_style": &"tracked_heavy",
		"attack_style": &"pod_salvo", "score": 2900, "threat": 4, "remains": &"vehicle",
	},
	&"shrike": {
		"display_name": "SHRIKE ASSAULT VTOL", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/13-shrike-assault-vtol.png",
		"display": Vector2(260.0, 130.0), "collision": Vector2(225.0, 78.0),
		"spawn_y": 195.0, "health": 220.0, "speed": 260.0, "acceleration": 550.0,
		"preferred_range": 390.0, "minimum_range": 180.0, "attack_interval": 1.55,
		"projectile_kind": &"rocket", "projectile_speed": 560.0, "damage": 18.0,
		"anticipation": 0.52, "behavior": &"air_pass", "movement_style": &"vtol_strafe",
		"attack_style": &"wing_launch", "score": 3000, "threat": 4, "remains": &"air",
	},
	&"cinder": {
		"display_name": "CINDER FLAME TANK", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/14-cinder-flame-tank.png",
		"display": Vector2(240.0, 130.0), "collision": Vector2(220.0, 86.0),
		"spawn_y": 547.0, "health": 340.0, "speed": 68.0, "acceleration": 290.0,
		"preferred_range": 220.0, "minimum_range": 90.0, "attack_interval": 1.05,
		"projectile_kind": &"shell", "projectile_speed": 330.0, "damage": 18.0,
		"anticipation": 0.60, "behavior": &"ground_close", "movement_style": &"flame_lurch",
		"attack_style": &"flame_blast", "score": 3600, "threat": 5, "remains": &"vehicle",
	},
	&"aegis": {
		"display_name": "AEGIS SHIELD PROJECTOR", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/15-aegis-shield-projector.png",
		"display": Vector2(240.0, 165.0), "collision": Vector2(215.0, 92.0),
		"spawn_y": 544.0, "health": 260.0, "speed": 46.0, "acceleration": 200.0,
		"preferred_range": 500.0, "minimum_range": 320.0, "attack_interval": 2.35,
		"projectile_kind": &"bullet", "projectile_speed": 680.0, "damage": 5.0,
		"anticipation": 0.68, "behavior": &"support", "movement_style": &"dish_pulse",
		"attack_style": &"shield_pulse", "score": 4000, "threat": 5, "remains": &"vehicle",
	},
	&"longbow": {
		"display_name": "LONGBOW RAILGUN TANK", "family": &"heavy", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/16-longbow-railgun-tank.png",
		"display": Vector2(290.0, 150.0), "collision": Vector2(255.0, 92.0),
		"spawn_y": 544.0, "health": 420.0, "speed": 42.0, "acceleration": 190.0,
		"preferred_range": 760.0, "minimum_range": 500.0, "attack_interval": 3.3,
		"projectile_kind": &"shell", "projectile_speed": 980.0, "damage": 38.0,
		"anticipation": 1.20, "behavior": &"ground_standoff", "movement_style": &"capacitor_roll",
		"attack_style": &"rail_recoil", "score": 5100, "threat": 6, "remains": &"vehicle",
	},
	&"hive": {
		"display_name": "HIVE DRONE CARRIER", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/17-hive-drone-mothership.png",
		"display": Vector2(300.0, 190.0), "collision": Vector2(265.0, 135.0),
		"spawn_y": 185.0, "health": 400.0, "speed": 118.0, "acceleration": 270.0,
		"preferred_range": 600.0, "minimum_range": 400.0, "attack_interval": 2.45,
		"projectile_kind": &"rocket", "projectile_speed": 500.0, "damage": 12.0,
		"anticipation": 0.75, "behavior": &"carrier", "movement_style": &"carrier_hover",
		"attack_style": &"drone_launch", "spawn_kind": &"hound", "spawn_limit": 2,
		"score": 5600, "threat": 6, "remains": &"air",
	},
	&"goliath": {
		"display_name": "GOLIATH SIEGE WALKER", "family": &"siege", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/18-goliath-siege-walker.png",
		"faces_right": true,
		"display": Vector2(260.0, 240.0), "collision": Vector2(210.0, 210.0),
		"spawn_y": 485.0, "health": 650.0, "speed": 52.0, "acceleration": 210.0,
		"preferred_range": 550.0, "minimum_range": 300.0, "attack_interval": 2.75,
		"projectile_kind": &"shell", "projectile_speed": 600.0, "damage": 32.0,
		"anticipation": 1.0, "behavior": &"ground_standoff", "movement_style": &"walker_stride",
		"attack_style": &"siege_brace", "score": 7200, "threat": 7, "remains": &"vehicle",
	},
	&"nemesis": {
		"display_name": "NEMESIS TITAN-HUNTER MECH", "family": &"siege", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/19-nemesis-titan-hunter-mech.png",
		"faces_right": true,
		"display": Vector2(170.0, 240.0), "collision": Vector2(82.0, 215.0),
		"spawn_y": 482.5, "health": 850.0, "speed": 135.0, "acceleration": 520.0,
		"preferred_range": 180.0, "minimum_range": 70.0, "attack_interval": 1.1,
		"projectile_kind": &"shell", "projectile_speed": 760.0, "damage": 30.0,
		"anticipation": 0.48, "behavior": &"ground_close", "movement_style": &"mech_stride",
		"attack_style": &"lance_thrust", "score": 10000, "threat": 9, "remains": &"vehicle",
	},
	&"leviathan": {
		"display_name": "LEVIATHAN COMMAND LANDSHIP", "family": &"siege", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/20-leviathan-command-landship.png",
		"display": Vector2(360.0, 220.0), "collision": Vector2(330.0, 170.0),
		"spawn_y": 505.0, "health": 1800.0, "speed": 34.0, "acceleration": 150.0,
		"preferred_range": 660.0, "minimum_range": 380.0, "attack_interval": 2.3,
		"projectile_kind": &"rocket", "projectile_speed": 560.0, "damage": 32.0,
		"anticipation": 1.0, "behavior": &"ground_standoff", "movement_style": &"landship_rumble",
		"attack_style": &"fortress_barrage", "score": 20000, "threat": 12, "remains": &"vehicle",
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
		"score": 2600, "threat": 3, "remains": &"infantry",
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
		"score": 3000, "threat": 3, "remains": &"vehicle",
	},
	&"choir_siren": {
		"display_name": "CHOIR SIREN", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/23-choir-siren.png",
		"display": Vector2(195.0, 180.0), "collision": Vector2(120.0, 140.0),
		"spawn_y": 210.0, "health": 330.0, "speed": 145.0, "acceleration": 320.0,
		"preferred_range": 570.0, "minimum_range": 350.0, "attack_interval": 2.55,
		"projectile_kind": &"bullet", "projectile_speed": 0.0, "damage": 0.0,
		"anticipation": 1.05, "behavior": &"air_standoff",
		"movement_style": &"siren_hover", "attack_style": &"choir_ring",
		"score": 4300, "threat": 5, "remains": &"air",
	},
	&"ossuary_crawler": {
		"display_name": "OSSUARY CRAWLER", "family": &"light", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/24-ossuary-crawler.png",
		"display": Vector2(220.0, 118.0), "collision": Vector2(182.0, 76.0),
		"spawn_y": 552.0, "health": 300.0, "speed": 190.0, "acceleration": 700.0,
		"preferred_range": 270.0, "minimum_range": 90.0, "attack_interval": 1.45,
		"projectile_kind": &"bullet", "projectile_speed": 0.0, "damage": 22.0,
		"anticipation": 0.52, "behavior": &"ground_close",
		"movement_style": &"crawler_climb", "attack_style": &"drop_lunge",
		"score": 4500, "threat": 5, "remains": &"vehicle",
	},
	&"seraph_carrier": {
		"display_name": "SERAPH CARRIER", "family": &"air", "airborne": true,
		"texture": "res://art/city/enemies/archetypes/25-seraph-carrier.png",
		"display": Vector2(320.0, 205.0), "collision": Vector2(270.0, 145.0),
		"spawn_y": 180.0, "health": 650.0, "speed": 108.0, "acceleration": 250.0,
		"preferred_range": 610.0, "minimum_range": 410.0, "attack_interval": 3.1,
		"projectile_kind": &"bullet", "projectile_speed": 0.0, "damage": 0.0,
		"anticipation": 1.15, "behavior": &"carrier", "movement_style": &"seraph_hover",
		"attack_style": &"incubation_drop", "spawn_kind": &"graft_runner", "spawn_limit": 3,
		"score": 7600, "threat": 7, "remains": &"air",
	},
	&"pale_engine": {
		"display_name": "PALE ENGINE", "family": &"siege", "airborne": false,
		"texture": "res://art/city/enemies/archetypes/26-pale-engine.png",
		"display": Vector2(330.0, 245.0), "collision": Vector2(265.0, 215.0),
		"spawn_y": 482.0, "health": 1000.0, "speed": 42.0, "acceleration": 170.0,
		"preferred_range": 720.0, "minimum_range": 430.0, "attack_interval": 3.6,
		"projectile_kind": &"shell", "projectile_speed": 920.0, "damage": 44.0,
		"anticipation": 1.35, "behavior": &"ground_standoff",
		"movement_style": &"pale_engine_stride", "attack_style": &"spinal_charge",
		"ablative_armor": 180.0, "score": 12000, "threat": 9, "remains": &"vehicle",
	},
}


static func has(archetype_id: StringName) -> bool:
	return PROFILES.has(archetype_id) or DISTRICT_VARIANT_PROFILES.has(archetype_id)


static func profile(archetype_id: StringName) -> Dictionary:
	if PROFILES.has(archetype_id):
		return (PROFILES[archetype_id] as Dictionary).duplicate(true)
	if not DISTRICT_VARIANT_PROFILES.has(archetype_id):
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
	if not DISTRICT_VARIANT_PROFILES.has(archetype_id):
		return archetype_id
	return StringName(
		(DISTRICT_VARIANT_PROFILES[archetype_id] as Dictionary).get(
			"base_archetype_id",
			archetype_id
		)
	)


static func is_district_variant(archetype_id: StringName) -> bool:
	return DISTRICT_VARIANT_PROFILES.has(archetype_id)


static func variants_for_district(district_id: StringName) -> Array[StringName]:
	var variants: Array[StringName] = []
	for archetype_id: StringName in DISTRICT_VARIANTS.get(district_id, []):
		variants.append(archetype_id)
	return variants


static func district_for_variant(archetype_id: StringName) -> StringName:
	if not DISTRICT_VARIANT_PROFILES.has(archetype_id):
		return &""
	return StringName(
		(DISTRICT_VARIANT_PROFILES[archetype_id] as Dictionary).get("district_id", &"")
	)


static func has_variant_tag(archetype_id: StringName, tag: StringName) -> bool:
	if not DISTRICT_VARIANT_PROFILES.has(archetype_id):
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


static func score_value(kind: StringName) -> int:
	if kind == &"tank":
		return 1500
	if kind == &"helicopter":
		return 1200
	if kind == &"soldier":
		return 500
	return int(profile(kind).get("score", 500))


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
	if PROCEDURAL_IDS.size() != 26:
		errors.append("Expected 26 base procedural archetypes")
	if DISTRICT_VARIANT_IDS.size() != 20:
		errors.append("Expected 20 district variants")
	if ALL_SPAWNABLE_IDS.size() != 46:
		errors.append("Expected 46 all-spawnable archetypes")
	var seen: Dictionary[StringName, bool] = {}
	for archetype_id: StringName in ALL_SPAWNABLE_IDS:
		if seen.has(archetype_id):
			errors.append("Duplicate all-spawnable archetype: %s" % archetype_id)
		seen[archetype_id] = true
		if profile(archetype_id).is_empty():
			errors.append("Missing flattened profile: %s" % archetype_id)
	for district_id: StringName in [
		&"BUSINESS", &"RESIDENTIAL", &"ENTERTAINMENT", &"MILITARY", &"ROYAL",
	]:
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
