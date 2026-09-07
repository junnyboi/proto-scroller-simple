class_name CallsignModeration
extends RefCounted

const BLOCKED_TERMS: PackedStringArray = [
	"arse",
	"bastard",
	"bitch",
	"bollocks",
	"cocksucker",
	"cunt",
	"dick",
	"fag",
	"faggot",
	"fuck",
	"fuckface",
	"motherfucker",
	"nazi",
	"nigger",
	"piss",
	"porn",
	"rape",
	"rapist",
	"retard",
	"shit",
	"slut",
	"whore",
]

static func validate(candidate: String) -> StringName:
	var canonical: String = _canonicalize(candidate)
	if canonical.is_empty():
		return &"ok"
	for token: String in canonical.split(" ", false):
		if token in BLOCKED_TERMS:
			return &"inappropriate"
	var compact: String = canonical.replace(" ", "")
	if compact in BLOCKED_TERMS:
		return &"inappropriate"
	return &"ok"


static func is_allowed(candidate: String) -> bool:
	return validate(candidate) == &"ok"


static func _canonicalize(candidate: String) -> String:
	var canonical: String = ""
	var previous_was_separator: bool = true
	for index: int in range(candidate.length()):
		var character: String = candidate.substr(index, 1).to_lower()
		match character:
			"0":
				character = "o"
			"1", "!":
				character = "i"
			"3":
				character = "e"
			"4", "@":
				character = "a"
			"5", "$":
				character = "s"
			"7":
				character = "t"
			"8":
				character = "b"
		var codepoint: int = character.unicode_at(0)
		var is_ascii_alphanumeric: bool = (
			(codepoint >= 48 and codepoint <= 57)
			or (codepoint >= 97 and codepoint <= 122)
		)
		if is_ascii_alphanumeric:
			canonical += character
			previous_was_separator = false
		elif not previous_was_separator:
			canonical += " "
			previous_was_separator = true
	return canonical.strip_edges()
