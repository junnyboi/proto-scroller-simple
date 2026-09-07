class_name ComboHeraldCatalog
extends RefCounted

const MILESTONE_COUNTS: Array = [2, 3, 4, 5, 7, 10]
const PROFILES: Dictionary = {
	2: {
		&"title_key": "hud.combo_herald.double",
		&"texture": preload("res://assets/ui/combo_herald/double_kill.png"),
		&"voice": preload("res://assets/audio/voice/combo/double_kill.wav"),
		&"accent": Color("7ae4ff"),
		&"intensity": 0.86,
	},
	3: {
		&"title_key": "hud.combo_herald.triple",
		&"texture": preload("res://assets/ui/combo_herald/triple_kill.png"),
		&"voice": preload("res://assets/audio/voice/combo/triple_kill.wav"),
		&"accent": Color("f1b36f"),
		&"intensity": 0.94,
	},
	4: {
		&"title_key": "hud.combo_herald.overkill",
		&"texture": preload("res://assets/ui/combo_herald/overkill.png"),
		&"voice": preload("res://assets/audio/voice/combo/overkill.wav"),
		&"accent": Color("ff695c"),
		&"intensity": 1.0,
	},
	5: {
		&"title_key": "hud.combo_herald.unstoppable",
		&"texture": preload("res://assets/ui/combo_herald/unstoppable.png"),
		&"voice": preload("res://assets/audio/voice/combo/unstoppable.wav"),
		&"accent": Color("fff0a8"),
		&"intensity": 1.08,
	},
	7: {
		&"title_key": "hud.combo_herald.annihilation",
		&"texture": preload("res://assets/ui/combo_herald/annihilation.png"),
		&"voice": preload("res://assets/audio/voice/combo/annihilation.wav"),
		&"accent": Color("ff9a61"),
		&"intensity": 1.15,
	},
	10: {
		&"title_key": "hud.combo_herald.extinction",
		&"texture": preload("res://assets/ui/combo_herald/extinction_event.png"),
		&"voice": preload("res://assets/audio/voice/combo/extinction_event.wav"),
		&"accent": Color("ffffff"),
		&"intensity": 1.24,
	},
}


static func profile_for(chain_count: int) -> Dictionary:
	return PROFILES.get(chain_count, {}) as Dictionary


static func is_milestone(chain_count: int) -> bool:
	return PROFILES.has(chain_count)


static func milestone_counts() -> Array:
	return MILESTONE_COUNTS.duplicate()
