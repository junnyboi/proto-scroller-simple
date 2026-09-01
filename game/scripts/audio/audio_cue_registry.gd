class_name AudioCueRegistry
extends RefCounted

enum Cue {
	INVALID,
	OVERDRIVE_ACTIVATION,
	COMBO_BREAK,
	POWER_BOX_DETONATION,
	ENEMY_BULLET_IMPACT,
	ENEMY_SHELL_IMPACT,
	ENEMY_ROCKET_DIRECT_IMPACT,
	ENEMY_ROCKET_SALVO_IMPACT,
}

const OVERDRIVE_ACTIVATION_SFX: AudioStream = preload(
	"res://audio/sfx/rampage/overdrive_activation.wav"
)
const COMBO_BREAK_SFX: AudioStream = preload(
	"res://audio/sfx/rampage/combo_break.wav"
)
const POWER_BOX_DETONATION_SFX: AudioStream = preload(
	"res://audio/sfx/city/power_box_detonation.wav"
)
const ENEMY_BULLET_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/enemy_projectiles/enemy_bullet_impact.wav"
)
const ENEMY_SHELL_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/enemy_projectiles/enemy_shell_impact.wav"
)
const ENEMY_ROCKET_DIRECT_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/enemy_projectiles/enemy_rocket_direct_impact.wav"
)
const ENEMY_ROCKET_SALVO_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/enemy_projectiles/enemy_rocket_salvo_impact.wav"
)
const PROFILES: Dictionary = {
	Cue.OVERDRIVE_ACTIVATION: {
		&"id": &"overdrive",
		&"stream": OVERDRIVE_ACTIVATION_SFX,
		&"bus": &"SFX",
		&"volume_db": -3.0,
		&"priority": AudioVoicePriority.SIGNATURE,
	},
	Cue.COMBO_BREAK: {
		&"id": &"combo_break",
		&"stream": COMBO_BREAK_SFX,
		&"bus": &"SFX",
		&"volume_db": -5.0,
		&"priority": AudioVoicePriority.MAJOR,
	},
	Cue.POWER_BOX_DETONATION: {
		&"id": &"power_box_detonation",
		&"stream": POWER_BOX_DETONATION_SFX,
		&"bus": &"SFX",
		&"volume_db": -2.0,
		&"priority": AudioVoicePriority.SIGNATURE,
	},
	Cue.ENEMY_BULLET_IMPACT: {
		&"id": &"enemy_bullet_impact",
		&"stream": ENEMY_BULLET_IMPACT_SFX,
		&"bus": &"SFX",
		&"volume_db": -8.0,
		&"priority": AudioVoicePriority.ORDINARY,
	},
	Cue.ENEMY_SHELL_IMPACT: {
		&"id": &"enemy_shell_impact",
		&"stream": ENEMY_SHELL_IMPACT_SFX,
		&"bus": &"SFX",
		&"volume_db": -6.0,
		&"priority": AudioVoicePriority.MAJOR,
	},
	Cue.ENEMY_ROCKET_DIRECT_IMPACT: {
		&"id": &"enemy_rocket_direct_impact",
		&"stream": ENEMY_ROCKET_DIRECT_IMPACT_SFX,
		&"bus": &"SFX",
		&"volume_db": -4.0,
		&"priority": AudioVoicePriority.THREAT,
	},
	Cue.ENEMY_ROCKET_SALVO_IMPACT: {
		&"id": &"enemy_rocket_salvo_impact",
		&"stream": ENEMY_ROCKET_SALVO_IMPACT_SFX,
		&"bus": &"SFX",
		&"volume_db": -6.0,
		&"priority": AudioVoicePriority.MAJOR,
	},
}


static func profile(cue: Cue) -> Dictionary:
	return PROFILES.get(cue, {}) as Dictionary


static func is_valid(cue: Cue) -> bool:
	return PROFILES.has(cue)
