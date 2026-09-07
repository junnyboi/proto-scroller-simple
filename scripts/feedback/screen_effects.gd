class_name ScreenEffects
extends CanvasLayer
## One screen overlay, no screen-texture reads or gameplay state mutations.
const VIGNETTE: Shader = preload("res://shaders/accessibility_vignette.gdshader")
var overlay: ColorRect
var shader_material: ShaderMaterial


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_material = ShaderMaterial.new()
	shader_material.shader = VIGNETTE
	overlay.material = shader_material
	add_child(overlay)
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if overlay == null:
		return
	var strength: float = clampf(float(RuntimeTweakAccess.live_value(&"interface.filter_intensity", 0.18)), 0.0, 1.0)
	overlay.visible = bool(RuntimeTweakAccess.live_value(&"interface.filter_enabled", true)) and strength > 0.0
	shader_material.set_shader_parameter(&"intensity", strength)
