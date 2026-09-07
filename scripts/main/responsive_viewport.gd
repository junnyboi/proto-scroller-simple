class_name ResponsiveViewport
extends Node

signal orientation_changed(portrait: bool, design_size: Vector2i)

const LANDSCAPE_SIZE: Vector2i = Vector2i(1280, 720)
const PORTRAIT_SIZE: Vector2i = Vector2i(720, 1280)

var portrait_mode: bool = false
var design_size: Vector2i = LANDSCAPE_SIZE
var _applying: bool = false
var _web_window: Variant
var _web_resize_callback: Variant


func setup() -> void:
	var window: Window = get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if not window.size_changed.is_connected(_on_window_size_changed):
		window.size_changed.connect(_on_window_size_changed)
	if OS.has_feature("web"):
		_web_window = JavaScriptBridge.get_interface("window")
		_web_resize_callback = JavaScriptBridge.create_callback(_on_web_resize)
		_web_window.addEventListener("resize", _web_resize_callback)
	apply_window_size(_physical_window_size())


func _exit_tree() -> void:
	if _web_window != null and _web_resize_callback != null:
		_web_window.removeEventListener("resize", _web_resize_callback)


func apply_window_size(window_size: Vector2i) -> void:
	if _applying or window_size.x <= 0 or window_size.y <= 0:
		return
	var next_portrait: bool = window_size.y > window_size.x
	var next_size: Vector2i = PORTRAIT_SIZE if next_portrait else LANDSCAPE_SIZE
	if design_size == next_size and get_window().content_scale_size == next_size:
		return
	_applying = true
	portrait_mode = next_portrait
	design_size = next_size
	get_window().content_scale_size = next_size
	_applying = false
	orientation_changed.emit(portrait_mode, design_size)


func _on_window_size_changed() -> void:
	call_deferred("apply_window_size", _physical_window_size())


func _on_web_resize(_arguments: Array) -> void:
	call_deferred("apply_window_size", _physical_window_size())


func _physical_window_size() -> Vector2i:
	if OS.has_feature("web"):
		var browser_dimensions: Variant = JavaScriptBridge.eval(
			"window.innerWidth + ',' + window.innerHeight"
		)
		var components: PackedStringArray = String(browser_dimensions).split(",")
		if components.size() == 2:
			return Vector2i(int(components[0]), int(components[1]))
	return DisplayServer.window_get_size()
