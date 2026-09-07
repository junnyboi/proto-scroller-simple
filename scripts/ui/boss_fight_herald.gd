class_name BossFightHerald
extends Control

const PRESENTATION_SECONDS: float = 1.2
const SPLASH: Texture2D = preload(
	"res://assets/ui/boss_fight/boss-fight-splash.webp"
)
const VOICE: AudioStream = preload("res://assets/audio/voice/boss_fight.wav")
const SPLASH_ASPECT: float = 1344.0 / 576.0

var splash: TextureRect
var voice_player: AudioStreamPlayer
var presentation_count: int = 0
var audio_play_count: int = 0
var _active_tween: Tween


func _ready() -> void:
	name = "BossFightHerald"
	z_index = 40
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visuals()
	apply_responsive_layout(get_viewport_rect().size)


func present() -> void:
	dismiss()
	presentation_count += 1
	visible = true
	splash.modulate = Color(1.0, 1.0, 1.0, 0.0)
	splash.scale = Vector2.ONE * 1.12
	voice_player.stop()
	voice_player.play()
	audio_play_count += 1
	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(splash, "modulate:a", 1.0, 0.08)
	_active_tween.tween_property(splash, "scale", Vector2.ONE, 0.18)
	_active_tween.tween_property(
		splash,
		"modulate:a",
		0.0,
		0.22
	).set_delay(PRESENTATION_SECONDS - 0.22)
	_active_tween.tween_property(
		splash,
		"scale",
		Vector2.ONE * 1.05,
		0.22
	).set_delay(PRESENTATION_SECONDS - 0.22)
	_active_tween.tween_callback(_finish).set_delay(PRESENTATION_SECONDS)


func dismiss() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	visible = false
	if voice_player != null:
		voice_player.stop()


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if splash == null:
		return
	var target_width: float = minf(viewport_size.x * 0.94, 1344.0)
	var target_height: float = target_width / SPLASH_ASPECT
	var maximum_height: float = viewport_size.y * 0.52
	if target_height > maximum_height:
		target_height = maximum_height
		target_width = target_height * SPLASH_ASPECT
	splash.size = Vector2(target_width, target_height)
	splash.position = Vector2(
		(viewport_size.x - target_width) * 0.5,
		(viewport_size.y - target_height) * 0.46
	)
	splash.pivot_offset = splash.size * 0.5


func _build_visuals() -> void:
	visible = false
	splash = TextureRect.new()
	splash.name = "Splash"
	splash.texture = SPLASH
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(splash)
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "Voice"
	voice_player.stream = VOICE
	voice_player.bus = GameAudioBus.VOICE
	voice_player.volume_db = -1.0
	add_child(voice_player)


func _finish() -> void:
	_active_tween = null
	visible = false
