class_name BossOutcome
extends RefCounted


enum {
	PURGE,
	DISENTANGLE,
	ASCENSION_FAILURE,
}


static func values() -> PackedInt32Array:
	return PackedInt32Array([PURGE, DISENTANGLE, ASCENSION_FAILURE])


static func is_valid(value: int) -> bool:
	return value in values()


static func id_for(value: int) -> StringName:
	match value:
		PURGE:
			return &"PURGE"
		DISENTANGLE:
			return &"DISENTANGLE"
		ASCENSION_FAILURE:
			return &"ASCENSION_FAILURE"
	return &""
