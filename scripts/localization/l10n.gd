class_name L10n
extends RefCounted

const DEFAULT_LOCALE: String = "en"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "zh-CN"]
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/en.json",
	"zh-CN": "res://localization/zh-CN.json",
}
const LOCALE_OVERRIDE_ENV: String = "PROTO_SCROLLER_LOCALE"
const CJK_FONT_PATH: String = "res://assets/fonts/DroidSansFallbackFull-ProtoScroller.ttf"
const PREFERENCE_PATH: String = "user://localization.cfg"
const PREFERENCE_SECTION: String = "localization"
const PREFERENCE_KEY: String = "locale"

static var _catalogs: Dictionary = {}
static var _locale: String = ""
static var _loaded: bool = false
static var _cjk_font: Font


static func t(key: String, placeholders: Dictionary = {}) -> String:
	_ensure_loaded()
	var catalog: Dictionary = _catalogs.get(_locale, {}) as Dictionary
	var fallback: Dictionary = _catalogs.get(DEFAULT_LOCALE, {}) as Dictionary
	var value: String = String(catalog.get(key, fallback.get(key, key)))
	if not fallback.has(key):
		push_warning("Missing English localization key: %s" % key)
	if placeholders.is_empty():
		return value
	return value.format(placeholders)


static func set_locale(
	locale: String,
	persist: bool = false,
	preference_path: String = PREFERENCE_PATH
) -> bool:
	_ensure_loaded()
	var normalized: String = _normalize_locale(locale)
	if not SUPPORTED_LOCALES.has(normalized):
		return false
	_locale = normalized
	_sync_web_locale(false)
	if persist and not _save_preferred_locale(normalized, preference_path):
		push_warning("Unable to persist localization preference: %s" % preference_path)
	return true


static func current_locale() -> String:
	_ensure_loaded()
	return _locale


static func available_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES.duplicate()


static func automatic_locale() -> String:
	return _detect_automatic_locale()


static func use_automatic_locale(preference_path: String = PREFERENCE_PATH) -> bool:
	_ensure_loaded()
	if not clear_locale_preference(preference_path):
		return false
	_locale = _detect_automatic_locale()
	_sync_web_locale(true)
	return true


static func uses_automatic_locale(preference_path: String = PREFERENCE_PATH) -> bool:
	return preferred_locale(preference_path).is_empty()


static func preferred_locale(preference_path: String = PREFERENCE_PATH) -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(preference_path) != OK:
		return ""
	var normalized: String = _normalize_locale(
		String(config.get_value(PREFERENCE_SECTION, PREFERENCE_KEY, ""))
	)
	return normalized if SUPPORTED_LOCALES.has(normalized) else ""


static func clear_locale_preference(preference_path: String = PREFERENCE_PATH) -> bool:
	if not FileAccess.file_exists(preference_path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(preference_path)) == OK


static func apply_locale_font(root: Node) -> void:
	_ensure_loaded()
	if _locale == "zh-CN" and not _load_cjk_font():
		return
	_apply_font_to_control(root as Control if root is Control else null)
	for node: Node in root.find_children("*", "Control", true, false):
		_apply_font_to_control(node as Control)


static func apply_cjk_font(control: Control) -> bool:
	if control == null or not _load_cjk_font():
		return false
	control.add_theme_font_override(&"font", _cjk_font)
	return true


static func apply_locale_popup_font(popup: PopupMenu) -> void:
	if popup == null:
		return
	_ensure_loaded()
	if _locale == "zh-CN":
		if _load_cjk_font():
			popup.add_theme_font_override(&"font", _cjk_font)
	else:
		popup.remove_theme_font_override(&"font")


static func keys_for_locale(locale: String) -> PackedStringArray:
	_ensure_loaded()
	var normalized: String = _normalize_locale(locale)
	var catalog: Dictionary = _catalogs.get(normalized, {}) as Dictionary
	var keys: PackedStringArray = []
	for key: Variant in catalog.keys():
		keys.append(String(key))
	keys.sort()
	return keys


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_load_catalogs()
	_locale = _detect_locale()
	_loaded = true


static func _load_catalogs() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var path: String = String(CATALOG_PATHS[locale])
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Unable to open localization catalog: %s" % path)
			_catalogs[locale] = {}
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			push_error("Localization catalog must be a JSON object: %s" % path)
			_catalogs[locale] = {}
			continue
		_catalogs[locale] = parsed


static func _detect_locale() -> String:
	var override: String = OS.get_environment(LOCALE_OVERRIDE_ENV)
	if not override.is_empty():
		var normalized_override: String = _normalize_locale(override)
		if SUPPORTED_LOCALES.has(normalized_override):
			return normalized_override
	if OS.has_feature("web"):
		var web_locale: Variant = JavaScriptBridge.eval("window.protoScrollerLocale || ''", true)
		if web_locale is String and SUPPORTED_LOCALES.has(web_locale):
			return String(web_locale)
	var persisted: String = preferred_locale()
	if not persisted.is_empty():
		return persisted
	return _detect_automatic_locale()


static func _detect_automatic_locale() -> String:
	var override: String = OS.get_environment(LOCALE_OVERRIDE_ENV)
	if not override.is_empty():
		var normalized_override: String = _normalize_locale(override)
		if SUPPORTED_LOCALES.has(normalized_override):
			return normalized_override
	var detected: String = _normalize_locale(OS.get_locale())
	return detected if SUPPORTED_LOCALES.has(detected) else DEFAULT_LOCALE


static func _save_preferred_locale(locale: String, preference_path: String) -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(PREFERENCE_SECTION, PREFERENCE_KEY, locale)
	return config.save(preference_path) == OK


static func _load_cjk_font() -> bool:
	if _cjk_font == null:
		_cjk_font = load(CJK_FONT_PATH) as Font
	if _cjk_font == null:
		push_error("Unable to load Simplified Chinese font: %s" % CJK_FONT_PATH)
		return false
	if _cjk_font.fallbacks.is_empty() and ThemeDB.fallback_font != null:
		_cjk_font.fallbacks = [ThemeDB.fallback_font]
	return true


static func _apply_font_to_control(control: Control) -> void:
	if control == null:
		return
	if _locale == "zh-CN":
		control.add_theme_font_override(&"font", _cjk_font)
	else:
		control.remove_theme_font_override(&"font")


static func _normalize_locale(locale: String) -> String:
	var normalized: String = locale.strip_edges().replace("_", "-").to_lower()
	if (
		normalized == "zh"
		or normalized.begins_with("zh-cn")
		or normalized.begins_with("zh-sg")
		or normalized.begins_with("zh-hans")
	):
		return "zh-CN"
	if normalized.begins_with("en"):
		return "en"
	return locale


static func _sync_web_locale(automatic: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.protoScrollerSetLocale && window.protoScrollerSetLocale(%s, %s)" % [JSON.stringify(_locale), "true" if automatic else "false"], true)
