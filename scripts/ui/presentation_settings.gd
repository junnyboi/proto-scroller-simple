class_name PresentationSettings
extends RefCounted

const PATH: String = "user://presentation.cfg"
static var preference_path: String = PATH
static var _loaded: bool = false
static var _reduced_motion: bool = false


static func reduced_motion() -> bool:
	if not _loaded:
		var config: ConfigFile = ConfigFile.new()
		if config.load(preference_path) == OK:
			_reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))
		_loaded = true
	return _reduced_motion or bool(RuntimeTweakAccess.live_value(&"interface.reduced_motion", false))


static func set_reduced_motion(enabled: bool) -> void:
	_loaded = true
	_reduced_motion = enabled
	var config: ConfigFile = ConfigFile.new()
	config.set_value("accessibility", "reduced_motion", enabled)
	config.save(preference_path)
