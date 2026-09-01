extends GutTest

const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_PREFERENCE_PATH: String = "user://test-l10n-preference.cfg"
const INVARIANT_ABBREVIATION_KEYS: PackedStringArray = [
	"weapon.machine_gun",
	"weapon.missile",
	"weapon.laser",
	"weapon.flamethrower",
]


func before_each() -> void:
	L10n.clear_locale_preference(TEST_PREFERENCE_PATH)
	L10n.set_locale("en")


func after_each() -> void:
	L10n.set_locale("en")
	L10n.clear_locale_preference(TEST_PREFERENCE_PATH)


func test_catalogs_have_identical_keys() -> void:
	var english_keys: PackedStringArray = L10n.keys_for_locale("en")
	var chinese_keys: PackedStringArray = L10n.keys_for_locale("zh-CN")
	assert_gt(english_keys.size(), 100)
	assert_eq(chinese_keys, english_keys)
	var english_placeholders: Dictionary[String, PackedStringArray] = {}
	var english_values: Dictionary[String, String] = {}
	L10n.set_locale("en")
	for key: String in english_keys:
		var english_value: String = L10n.t(key)
		english_values[key] = english_value
		english_placeholders[key] = _placeholders(english_value)
	L10n.set_locale("zh-CN")
	for key: String in chinese_keys:
		var chinese_value: String = L10n.t(key)
		assert_eq(_placeholders(chinese_value), english_placeholders[key], key)
		if INVARIANT_ABBREVIATION_KEYS.has(key):
			assert_eq(chinese_value, english_values[key], "Invariant abbreviation: %s" % key)
		for token: String in _neutral_tokens(chinese_value):
			assert_true(
				english_values[key].contains(token),
				"Neutral token changed for %s: %s" % [key, token]
			)


func test_named_placeholders_are_substituted() -> void:
	assert_eq(
		L10n.t("hud.health", {"current": "080", "maximum": "100"}),
		"CHASSIS 080 / 100"
	)
	assert_true(L10n.set_locale("zh-CN"))
	assert_eq(
		L10n.t("hud.health", {"current": "080", "maximum": "100"}),
		"机体 080 / 100"
	)


func test_tuning_launcher_has_exact_bilingual_copy() -> void:
	assert_eq(L10n.t("tuning.action.open"), "TWEAK CONTROLS")
	assert_true(L10n.set_locale("zh-CN"))
	assert_eq(L10n.t("tuning.action.open"), "调校控制")


func test_unsupported_locale_is_rejected_without_mutation() -> void:
	assert_false(L10n.set_locale("fr-FR"))
	assert_eq(L10n.current_locale(), "en")
	assert_false(L10n.set_locale("zh-TW"))
	assert_eq(L10n.current_locale(), "en")
	assert_true(L10n.set_locale("zh_Hans_CN"))
	assert_eq(L10n.current_locale(), "zh-CN")
	assert_true(L10n.set_locale("zh-CN", true, TEST_PREFERENCE_PATH))
	assert_eq(L10n.preferred_locale(TEST_PREFERENCE_PATH), "zh-CN")
	assert_false(L10n.uses_automatic_locale(TEST_PREFERENCE_PATH))
	assert_true(FileAccess.file_exists(TEST_PREFERENCE_PATH))
	var detected_locale: String = L10n.automatic_locale()
	assert_true(L10n.use_automatic_locale(TEST_PREFERENCE_PATH))
	assert_eq(L10n.current_locale(), detected_locale)
	assert_true(L10n.uses_automatic_locale(TEST_PREFERENCE_PATH))
	assert_eq(L10n.preferred_locale(TEST_PREFERENCE_PATH), "")
	assert_false(FileAccess.file_exists(TEST_PREFERENCE_PATH))


func test_simplified_chinese_title_screen_uses_catalog_copy() -> void:
	L10n.set_locale("zh-CN")
	var screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	screen.locale_preference_path = TEST_PREFERENCE_PATH
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq((screen.get_node("%TitleLabel") as Label).text, L10n.t("title.command_heading"))
	assert_true(
		(screen.get_node("%InitializeButton") as Button).text.contains(L10n.t("title.begin"))
	)
	assert_eq(
		(screen.get_node("%InstructionLabel") as Label).text,
		L10n.t("title.command_hook")
	)
	assert_null(screen.get_node_or_null("%BriefingArt"))
	assert_eq(
		screen.campaign_panel.codex_button.text,
		L10n.t("narrative.campaign.open_codex")
	)
	var title_font: Font = (screen.get_node("%TitleLabel") as Label).get_theme_font(&"font")
	assert_true(title_font.has_char("中".unicode_at(0)))
	for token_character: String in ">ADENSPCTB[]/·":
		assert_true(
			title_font.has_char(token_character.unicode_at(0)),
			"Missing invariant control glyph: %s" % token_character
		)
	assert_null(screen.get_node_or_null("HintLabel"))
	assert_eq((screen.get_node("%TitleLabel") as Label).text, "PROTOS")
	assert_eq(
		(screen.get_node("%InstructionLabel") as Label).text,
		"他们杀尽了你爱的人，并用纳米技术，以义体替代人体的体液与组织，"
		+ "还将其称作人类进化……是时候终结他们的恐怖统治了！"
	)
	assert_null(screen.get_node_or_null("StatusRail"))
	assert_null(screen.get_node_or_null("%ControlsLabel"))
	var briefing_controls: String = (
		screen.get_node("SemanticContract/BriefingControlsLabel") as Label
	).text
	assert_eq(
		briefing_controls,
		L10n.t("title.controls_body", InputBindingSettings.display_placeholders())
	)
	assert_eq((screen.get_node("%EnglishButton") as Button).text, "EN")
	assert_eq((screen.get_node("%ChineseButton") as Button).text, "CN")
	assert_null(screen.get_node_or_null("%AutomaticButton"))
	assert_true((screen.get_node("%BriefingToggle") as Button).text.contains("[TAB]"))
	_assert_locale_font_coverage("zh-CN", title_font)
	_assert_locale_font_coverage("en", ThemeDB.fallback_font, [&"title.language_zh_cn"])


func _placeholders(value: String) -> PackedStringArray:
	var matcher: RegEx = RegEx.new()
	matcher.compile("\\{([a-zA-Z0-9_]+)\\}")
	var names: PackedStringArray = []
	for result: RegExMatch in matcher.search_all(value):
		names.append(result.get_string(1))
	names.sort()
	return names


func _neutral_tokens(value: String) -> PackedStringArray:
	var matcher: RegEx = RegEx.new()
	matcher.compile("[A-Za-z0-9]+(?:[./:+_-][A-Za-z0-9]+)*")
	var letter_matcher: RegEx = RegEx.new()
	letter_matcher.compile("[A-Za-z]")
	var tokens: PackedStringArray = []
	for result: RegExMatch in matcher.search_all(_without_placeholders(value)):
		var token: String = result.get_string()
		if letter_matcher.search(token) != null:
			tokens.append(token)
	return tokens


func _without_placeholders(value: String) -> String:
	var matcher: RegEx = RegEx.new()
	matcher.compile("\\{[a-zA-Z0-9_]+\\}")
	return matcher.sub(value, "", true)


func _assert_locale_font_coverage(
	locale: String,
	font: Font,
	excluded_keys: Array[StringName] = []
) -> void:
	assert_not_null(font, "%s locale font must exist" % locale)
	assert_true(L10n.set_locale(locale))
	var glyph_sources: Dictionary[int, String] = {}
	for key: String in L10n.keys_for_locale(locale):
		if excluded_keys.has(StringName(key)):
			continue
		var value: String = _without_placeholders(L10n.t(key))
		for index: int in value.length():
			var codepoint: int = value.unicode_at(index)
			if codepoint <= 32:
				continue
			glyph_sources[codepoint] = key
	var codepoints: Array = glyph_sources.keys()
	codepoints.sort()
	for codepoint: int in codepoints:
		assert_true(
			font.has_char(codepoint),
			"%s font missing U+%04X from %s" % [locale, codepoint, glyph_sources[codepoint]]
		)
