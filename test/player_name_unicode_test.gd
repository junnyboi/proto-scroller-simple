extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print("PLAYER_NAME_UNICODE ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func clean(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

const Store := preload("res://scripts/rampage/player_combat_profile_store.gd")
const Bridge := preload("res://scripts/network/leaderboard_bridge.gd")

func run() -> void:
	var path := "user://unicode_names_%d.json" % Time.get_ticks_usec()
	var store := Store.new()
	root.add_child(store)
	store.setup(path)
	for value: String in ["张伟", "李娜", "王昊", "王𠮷", "张A", "Juń", "ABC_123-4"]:
		check(store.set_callsign(value) == &"ok", "accept " + value)
		check(store.callsign() == value, "preserve " + value)
		var restored := Store.new()
		root.add_child(restored)
		restored.setup(path)
		check(restored.callsign() == value, "persist " + value)
		var wire: Dictionary = JSON.parse_string(JSON.stringify({"callsign": restored.callsign()}))
		var bridge := Bridge.new()
		var rows: Array = bridge._sanitize_entries([{ "callsign": wire.callsign, "rank": 1, "score": 10 }])
		check(rows.size() == 1 and rows[0].callsign == value, "retrieved row " + value)
		bridge.free()
		restored.free()
	for value: String in ["x", "ab", "昊", "<张伟>", "张\n伟", "张\u200b伟", "\u0301AB", "王".repeat(21)]:
		check(store.validate_callsign(value) != &"ok", "reject " + value)
	check(store.validate_callsign("𠮷".repeat(20)) == &"ok", "astral length counts codepoints")
	check(store.validate_callsign("fuck") == &"inappropriate", "existing moderation remains active")
	store.free()
	clean(path)
	finish()
