class_name TemplateRuntimeSelector
extends RefCounted

const NATIVE_ARGUMENT: String = "--template-runtime"
const WEB_QUERY_KEY: String = "templateRuntime"


static func requested() -> bool:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var web_query: String = ""
	if OS.has_feature("web"):
		var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		if window != null and window.location != null:
			web_query = String(window.location.search)
	return requested_from(arguments, web_query)


static func requested_from(arguments: PackedStringArray, web_query: String = "") -> bool:
	if arguments.has(NATIVE_ARGUMENT):
		return true
	var query: String = web_query.trim_prefix("?")
	for field: String in query.split("&", false):
		var pair: PackedStringArray = field.split("=", true, 1)
		if pair.is_empty() or pair[0] != WEB_QUERY_KEY:
			continue
		if pair.size() == 1:
			return true
		return pair[1].to_lower() in ["1", "true", "yes", "on"]
	return false
