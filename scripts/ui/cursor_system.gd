class_name CursorSystem
extends Node

const ROLE_METADATA: StringName = &"cursor_role"

const NAVIGATE_TEXTURE: Texture2D = preload(
	"res://art/template/cursors/cursor_navigate.png"
)
const COMMAND_TEXTURE: Texture2D = preload(
	"res://art/template/cursors/cursor_command.png"
)
const INSPECT_TEXTURE: Texture2D = preload(
	"res://art/template/cursors/cursor_inspect.png"
)
const BLOCKED_TEXTURE: Texture2D = preload(
	"res://art/template/cursors/cursor_blocked.png"
)

const NAVIGATE_HOTSPOT: Vector2 = Vector2(1.0, 1.0)
const COMMAND_HOTSPOT: Vector2 = Vector2(5.0, 5.0)
const CENTER_HOTSPOT: Vector2 = Vector2(32.0, 32.0)

var _custom_cursors_active: bool = false
var _mouse_inside_window: bool = true


func _ready() -> void:
	_install_custom_cursors()
	get_tree().node_added.connect(_apply_declared_role)
	_apply_roles_in_subtree(get_tree().root)


func _exit_tree() -> void:
	_release_custom_cursors()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_ENTER:
			_mouse_inside_window = true
			_install_custom_cursors()
		NOTIFICATION_WM_MOUSE_EXIT:
			_mouse_inside_window = false
			_release_custom_cursors()
		NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _mouse_inside_window:
				_install_custom_cursors()
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_release_custom_cursors()


func _release_custom_cursors() -> void:
	_custom_cursors_active = false
	if DisplayServer.get_name() == "headless":
		return
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_HELP)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_FORBIDDEN)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


static func shape_for_role(role: StringName) -> Control.CursorShape:
	match role:
		&"command":
			return Control.CURSOR_POINTING_HAND
		&"inspect":
			return Control.CURSOR_HELP
		&"blocked":
			return Control.CURSOR_FORBIDDEN
		_:
			return Control.CURSOR_ARROW


static func apply_role(control: Control, role: StringName) -> void:
	control.mouse_default_cursor_shape = shape_for_role(role)


func _install_custom_cursors() -> void:
	_custom_cursors_active = false
	if DisplayServer.get_name() == "headless":
		return
	Input.set_custom_mouse_cursor(
		NAVIGATE_TEXTURE,
		Input.CURSOR_ARROW,
		NAVIGATE_HOTSPOT
	)
	Input.set_custom_mouse_cursor(
		COMMAND_TEXTURE,
		Input.CURSOR_POINTING_HAND,
		COMMAND_HOTSPOT
	)
	Input.set_custom_mouse_cursor(
		INSPECT_TEXTURE,
		Input.CURSOR_HELP,
		CENTER_HOTSPOT
	)
	Input.set_custom_mouse_cursor(
		BLOCKED_TEXTURE,
		Input.CURSOR_FORBIDDEN,
		CENTER_HOTSPOT
	)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_custom_cursors_active = true


func _apply_roles_in_subtree(node: Node) -> void:
	_apply_declared_role(node)
	for child: Node in node.get_children():
		_apply_roles_in_subtree(child)


func _apply_declared_role(node: Node) -> void:
	if node is not Control or not node.has_meta(ROLE_METADATA):
		return
	var control: Control = node as Control
	apply_role(control, StringName(control.get_meta(ROLE_METADATA, &"navigate")))
