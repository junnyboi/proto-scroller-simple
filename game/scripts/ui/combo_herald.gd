class_name ComboHerald
extends Control

const PRESENTATION_SECONDS: float = 1.15
const LANDSCAPE_INSIGNIA_SIZE: float = 196.0
const PORTRAIT_INSIGNIA_SIZE: float = 150.0

var insignia: TextureRect
var echo: TextureRect
var title_label: Label
var voice_player: AudioStreamPlayer
var last_tier: int = 0
var last_title_key: String = ""
var presentation_count: int = 0
var audio_play_count: int = 0
var supersession_count: int = 0
var _active_tween: Tween
var _active: bool = false
var _insignia_size: float = LANDSCAPE_INSIGNIA_SIZE


func _ready() -> void:
	name = "ComboHerald"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visuals()
	apply_responsive_layout(get_viewport_rect().size)


func present(tier: int) -> bool:
	var profile: Dictionary = ComboHeraldCatalog.profile_for(tier)
	if profile.is_empty():
		return false
	if _active:
		supersession_count += 1
	_stop_active(false)
	last_tier = tier
	last_title_key = String(profile[&"title_key"])
	presentation_count += 1
	_active = true
	insignia.texture = profile[&"texture"] as Texture2D
	echo.texture = insignia.texture
	title_label.text = L10n.t(last_title_key)
	title_label.modulate = profile[&"accent"] as Color
	_reset_visual_state()
	visible = true
	_play_voice(profile[&"voice"] as AudioStream)
	_animate(float(profile[&"intensity"]))
	return true


func dismiss() -> void:
	_stop_active(true)


func apply_responsive_layout(viewport_size: Vector2) -> void:
	var portrait: bool = viewport_size.y > viewport_size.x
	_insignia_size = PORTRAIT_INSIGNIA_SIZE if portrait else LANDSCAPE_INSIGNIA_SIZE
	var center_y: float = viewport_size.y * (0.31 if portrait else 0.46)
	var image_position: Vector2 = Vector2(
		(viewport_size.x - _insignia_size) * 0.5,
		center_y - _insignia_size * 0.5
	)
	for texture_rect: TextureRect in [echo, insignia]:
		if texture_rect == null:
			continue
		texture_rect.position = image_position
		texture_rect.size = Vector2.ONE * _insignia_size
		texture_rect.pivot_offset = texture_rect.size * 0.5
	var label_width: float = minf(viewport_size.x - 48.0, 680.0)
	if title_label != null:
		title_label.position = Vector2(
			(viewport_size.x - label_width) * 0.5,
			image_position.y + _insignia_size - (10.0 if portrait else 4.0)
		)
		title_label.size = Vector2(label_width, 62.0 if portrait else 78.0)
		title_label.pivot_offset = title_label.size * 0.5
		title_label.add_theme_font_size_override(&"font_size", 30 if portrait else 42)
		title_label.add_theme_constant_override(&"outline_size", 8 if portrait else 10)


func is_presenting() -> bool:
	return _active and visible


func _build_visuals() -> void:
	visible = false
	echo = TextureRect.new()
	echo.name = "Echo"
	echo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	echo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(echo)
	insignia = TextureRect.new()
	insignia.name = "Insignia"
	insignia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insignia.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	insignia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(insignia)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_color_override(&"font_outline_color", Color(0.01, 0.02, 0.04, 0.94))
	add_child(title_label)
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "Voice"
	voice_player.bus = GameAudioBus.VOICE
	voice_player.volume_db = -1.0
	voice_player.finished.connect(_on_voice_finished)
	add_child(voice_player)


func _reset_visual_state() -> void:
	insignia.scale = Vector2.ONE * 0.70
	insignia.rotation = deg_to_rad(-9.0)
	insignia.modulate = Color(1.0, 1.0, 1.0, 0.0)
	echo.scale = Vector2.ONE * 0.82
	echo.rotation = deg_to_rad(7.0)
	echo.modulate = Color(0.55, 0.92, 1.0, 0.0)
	title_label.position.y += 8.0
	title_label.modulate.a = 0.0
	title_label.scale = Vector2.ONE * 0.94


func _play_voice(stream: AudioStream) -> void:
	if stream == null:
		return
	voice_player.stop()
	voice_player.stream = stream
	voice_player.play()
	audio_play_count += 1


func _animate(intensity: float) -> void:
	var duration_scale: float = (
		float(RuntimeTweakAccess.live_value(
			&"interface.combo_herald.duration_scale", 1.0
		))
		* float(RuntimeTweakAccess.live_value(&"interface.motion_scale", 1.0))
	)
	if duration_scale <= 0.0:
		_finish_visual()
		return
	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_speed_scale(1.0 / duration_scale)
	_active_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(insignia, "scale", Vector2.ONE * (1.12 * intensity), 0.14)
	_active_tween.tween_property(insignia, "rotation", deg_to_rad(2.0), 0.14)
	_active_tween.tween_property(insignia, "modulate:a", 1.0, 0.08)
	_active_tween.tween_property(echo, "scale", Vector2.ONE * (1.08 * intensity), 0.20)
	_active_tween.tween_property(echo, "modulate:a", 0.62, 0.10)
	_active_tween.tween_property(title_label, "position:y", title_label.position.y - 8.0, 0.20)
	_active_tween.tween_property(title_label, "modulate:a", 1.0, 0.12).set_delay(0.04)
	_active_tween.tween_property(title_label, "scale", Vector2.ONE, 0.18).set_delay(0.02)
	_active_tween.tween_property(insignia, "scale", Vector2.ONE, 0.22).set_delay(0.14)
	_active_tween.tween_property(insignia, "rotation", deg_to_rad(-1.5), 0.64).set_delay(0.14)
	_active_tween.tween_property(echo, "scale", Vector2.ONE * 1.22, 0.64).set_delay(0.14)
	_active_tween.tween_property(echo, "modulate:a", 0.22, 0.64).set_delay(0.14)
	_active_tween.tween_property(insignia, "scale", Vector2.ONE * 1.10, 0.37).set_delay(0.78)
	_active_tween.tween_property(insignia, "modulate:a", 0.0, 0.37).set_delay(0.78)
	_active_tween.tween_property(echo, "scale", Vector2.ONE * 1.55, 0.37).set_delay(0.78)
	_active_tween.tween_property(echo, "modulate:a", 0.0, 0.37).set_delay(0.78)
	_active_tween.tween_property(title_label, "scale", Vector2.ONE * 1.04, 0.37).set_delay(0.78)
	_active_tween.tween_property(title_label, "modulate:a", 0.0, 0.37).set_delay(0.78)
	_active_tween.tween_callback(_finish_visual).set_delay(PRESENTATION_SECONDS)


func _finish_visual() -> void:
	_active_tween = null
	_active = false
	visible = false


func _on_voice_finished() -> void:
	voice_player.stream = null


func _stop_active(stop_voice: bool) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	_active = false
	visible = false
	if stop_voice and voice_player != null:
		voice_player.stop()
		voice_player.stream = null
