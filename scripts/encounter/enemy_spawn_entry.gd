class_name EnemySpawnEntry
extends Resource

@export_enum(
	"soldier", "tank", "helicopter",
	"needle", "bulwark", "jackal", "lobber", "sapper",
	"hound", "mule", "basilisk", "lancer", "static",
	"kestrel", "rainmaker", "shrike", "cinder", "aegis",
	"longbow", "hive", "goliath", "nemesis", "leviathan",
	"reclaimed_breacher", "graft_runner", "choir_siren",
	"ossuary_crawler", "seraph_carrier", "pale_engine",
	"covenant_warden", "mercy_recovery_cart", "testament_kite",
	"receivership_ambulance", "intake_shepherd", "evacuation_litter",
	"rainvault_pressure_ward", "balcony_recall_beacon", "memorial_usher",
	"glassback_double", "recall_lantern", "marquee_anesthetist",
	"suture_marshal", "mercy_raker", "revetment_ward", "triage_kite",
	"privy_chirurgeon", "laureate_courser", "ninefold_witness",
	"regency_conservator"
) var kind: String = "soldier"
@export var delay: float = 0.0
@export var position: Vector2 = Vector2.ZERO
@export_enum(
	"WORLD",
	"AHEAD",
	"BEHIND",
	"CAMERA_LEFT",
	"CAMERA_RIGHT"
) var spawn_anchor: String = "WORLD"
@export var offset: Vector2 = Vector2.ZERO
@export var role_id: StringName = &"BASE"
@export var trait_id: StringName = &""
