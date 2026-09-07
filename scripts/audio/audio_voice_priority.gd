class_name AudioVoicePriority
extends RefCounted

const UNUSED: int = 0
const AMBIENCE: int = 1
const LOCOMOTION: int = 2
const UI_NAVIGATION: int = 3
const ORDINARY: int = 4
const DEFEAT: int = 5
const MAJOR: int = 6
const SIGNATURE: int = 7
const THREAT: int = 8
const CRITICAL: int = 9
const MANDATORY: int = 10

const PRIORITY_META: StringName = &"priority"
const STARTED_ORDER_META: StringName = &"started_order"
const STARTED_MSEC_META: StringName = &"started_msec"


static func select_2d(
	voices: Array[AudioStreamPlayer2D],
	requested_priority: int
) -> AudioStreamPlayer2D:
	for voice: AudioStreamPlayer2D in voices:
		if not voice.playing:
			return voice
	if voices.is_empty():
		return null
	var candidate: AudioStreamPlayer2D = voices[0]
	for voice: AudioStreamPlayer2D in voices:
		if _precedes(voice, candidate):
			candidate = voice
	if priority_of(candidate) > requested_priority:
		return null
	return candidate


static func stamp(voice: AudioStreamPlayer2D, priority: int, started_order: int) -> void:
	voice.set_meta(PRIORITY_META, priority)
	voice.set_meta(STARTED_ORDER_META, started_order)
	voice.set_meta(STARTED_MSEC_META, Time.get_ticks_msec())


static func priority_of(voice: AudioStreamPlayer2D) -> int:
	return int(voice.get_meta(PRIORITY_META, UNUSED))


static func _precedes(a: AudioStreamPlayer2D, b: AudioStreamPlayer2D) -> bool:
	var a_priority: int = priority_of(a)
	var b_priority: int = priority_of(b)
	if a_priority != b_priority:
		return a_priority < b_priority
	return int(a.get_meta(STARTED_ORDER_META, 0)) < int(
		b.get_meta(STARTED_ORDER_META, 0)
	)
