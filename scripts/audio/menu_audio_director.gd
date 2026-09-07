class_name MenuAudioDirector
extends Node
## Semantic UI aliases reuse the supplied source clips; four voices bound polyphony.
const CUES: Dictionary = {
	&"confirm": AudioCueRegistry.Cue.UPGRADE_CONFIRM,
	&"hover": AudioCueRegistry.Cue.UPGRADE_CONFIRM,
	&"select": AudioCueRegistry.Cue.UPGRADE_CONFIRM,
	&"invalid": AudioCueRegistry.Cue.COMBO_BREAK,
	&"cancel": AudioCueRegistry.Cue.COMBO_BREAK,
	&"pause": AudioCueRegistry.Cue.UPGRADE_CONFIRM,
	&"resume": AudioCueRegistry.Cue.UPGRADE_CONFIRM,
	&"victory": AudioCueRegistry.Cue.SHOP_REPAIR,
	&"defeat": AudioCueRegistry.Cue.COMBO_BREAK,
}
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var last_cue_msec: int = -1000
var play_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index: int in range(4):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = GameAudioBus.UI
		voice.volume_db = -14.0
		add_child(voice)
		voices.append(voice)
	_bind_subtree(get_parent())
	get_tree().node_added.connect(_bind_control)


func play_cue(cue: StringName) -> void:
	if not CUES.has(cue) or voices.is_empty() or Time.get_ticks_msec() - last_cue_msec < 60:
		return
	last_cue_msec = Time.get_ticks_msec()
	play_count += 1
	var voice: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stop()
	voice.volume_db = -25.0 if cue == &"hover" else -14.0
	voice.stream = AudioCueRegistry.PROFILES[CUES[cue]][&"stream"] as AudioStream
	voice.play()


func _bind_subtree(node: Node) -> void:
	_bind_control(node)
	for child: Node in node.get_children():
		_bind_subtree(child)


func _bind_control(node: Node) -> void:
	if not get_parent().is_ancestor_of(node) or node.has_meta(&"menu_audio_bound"):
		return
	if node is BaseButton:
		var button: BaseButton = node as BaseButton
		button.set_meta(&"menu_audio_bound", true)
		button.pressed.connect(_button_activated.bind(button))
		if button is OptionButton:
			(button as OptionButton).item_selected.connect(_selection_changed)
		button.mouse_entered.connect(_hover.bind(button))
		button.focus_entered.connect(_hover.bind(button))
	elif node is Range:
		(node as Range).set_meta(&"menu_audio_bound", true)
		(node as Range).value_changed.connect(_value_changed)
	elif node is LineEdit:
		(node as LineEdit).set_meta(&"menu_audio_bound", true)
		(node as LineEdit).text_submitted.connect(_text_submitted)


func _hover(button: BaseButton) -> void:
	if not button.disabled and button.is_visible_in_tree():
		play_cue(&"hover")


func _value_changed(_value: float) -> void:
	play_cue(&"select")


func _text_submitted(_text: String) -> void:
	play_cue(&"confirm")


func _button_activated(button: BaseButton) -> void:
	var identifier: String = String(button.name).to_lower()
	var back: bool = identifier.contains("close") or identifier.contains("back") or identifier.contains("cancel")
	play_cue(&"cancel" if back else &"confirm")


func _selection_changed(_index: int) -> void:
	play_cue(&"select")
