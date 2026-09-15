# ------------------------------------------------------------------------------
# There was an error that someone found in Godot 4.4.1, but ended up being a
# different error in Godot 4.5.  The fix was to hold a reference to the font
# so that TextEdit control did not lose the font when switching.  This is
# the solution I came up with.  Just hold a reference to all fonts we use,
# but only when we use them.  Basically a lazy loader with some semantics for
# font names and location.
#
# https://github.com/bitwes/Gut/issues/749
#
# An instance of this could be used to allow users to specify their own fonts.
# It's not perect for that yet, but it is feasible.
# ------------------------------------------------------------------------------
const DEFAULT_CUSTOM_FONT_NAME = 'ManusCC0'
const THEME_FONT_TO_FONT_TYPES_MAP = {
	'font':FONT_TYPES.REGULAR,
	'normal_font': FONT_TYPES.REGULAR,
	'bold_font': FONT_TYPES.BOLD,
	'italics_font':FONT_TYPES.ITALIC,
	'bold_italics_font':FONT_TYPES.BOLD_ITALIC
}


# Keep GUT's semantic font roles while using only approved ManusCC0 faces.
const FONT_TYPES = {
	REGULAR = 'Regular',
	BOLD = 'Bold',
	ITALIC = 'Italic',
	BOLD_ITALIC = 'BoldItalic'
}


const FONT_RESOURCE_PATHS = {
	'Regular': 'res://resources/manuscc0_font.tres',
	'Bold': 'res://resources/manuscc0_bold_font.tres',
	# The pack has no italic faces; emphasis uses upright Medium or Bold.
	'Italic': 'res://resources/manuscc0_medium_font.tres',
	'BoldItalic': 'res://resources/manuscc0_bold_font.tres'
}


var fonts = {'ManusCC0': {}}


func _load_font(font_name, font_type, font_path):
	fonts[font_name][font_type] = load(font_path)


func get_font(font_name, font_type='Regular'):
	# Preserve the requested weight when migrating saved GUT preferences.
	if(font_name == null or font_name in ['Default', 'AnonymousPro', 'CourierPrime', 'LobsterTwo']):
		font_name = DEFAULT_CUSTOM_FONT_NAME
	if(!fonts.has(font_name)):
		push_error(str("Invalid font name '", font_name, "'"))
		return get_font(DEFAULT_CUSTOM_FONT_NAME)

	if(!FONT_TYPES.values().has(font_type)):
		push_error(str("Invalid font type '", font_type, "'"))
		return get_font(DEFAULT_CUSTOM_FONT_NAME)

	if(!fonts[font_name].has(font_type)):
		_load_font(font_name, font_type, FONT_RESOURCE_PATHS[font_type])

	return fonts.get(font_name, {}).get(font_type, null)


func get_font_names():
	return fonts.keys()


# Maps the various theme font names (font, normal_font, italics_font etc) to
# a FONT_TYPE.
func get_font_for_theme_font_name(theme_font_name, custom_font_name):
	if(!THEME_FONT_TO_FONT_TYPES_MAP.has(theme_font_name)):
		push_error(str("Unknown theme font name ", theme_font_name))
		return get_font(custom_font_name)
	return get_font(custom_font_name, THEME_FONT_TO_FONT_TYPES_MAP[theme_font_name])
