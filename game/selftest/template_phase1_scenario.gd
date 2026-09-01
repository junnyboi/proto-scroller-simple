extends SceneTree

const TEMPLATE_MAIN_SCENE: PackedScene = preload("res://scenes/template/template_main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime: TemplateMain = TEMPLATE_MAIN_SCENE.instantiate() as TemplateMain
	if runtime == null:
		_fail("template main did not instantiate")
		return
	root.add_child(runtime)
	await process_frame
	if runtime.title_screen == null or not runtime.start_stage(&"stage_01"):
		_fail("title did not start stage_01")
		return
	await process_frame
	var first_stage: TemplateStage = runtime.current_stage
	if first_stage == null or not first_stage.request_stub_victory():
		_fail("stub victory did not finalize")
		return
	if first_stage.request_stub_defeat() or first_stage.lifecycle.finalization_count != 1:
		_fail("duplicate terminal request was accepted")
		return
	first_stage.debrief.retry_button.pressed.emit()
	await process_frame
	var retry_stage: TemplateStage = runtime.current_stage
	if retry_stage == null or retry_stage == first_stage:
		_fail("retry did not replace the stage")
		return
	if not retry_stage.request_stub_defeat():
		_fail("stub defeat did not finalize")
		return
	retry_stage.debrief.title_button.pressed.emit()
	await process_frame
	var passed: bool = runtime.current_stage == null and runtime.title_screen != null
	root.remove_child(runtime)
	runtime.queue_free()
	await process_frame
	print("[TEMPLATE-PHASE1-DONE] result=%s" % ["PASS" if passed else "FAIL"])
	quit(0 if passed else 1)


func _fail(message: String) -> void:
	push_error(message)
	print("[TEMPLATE-PHASE1-DONE] result=FAIL reason=%s" % [message])
	quit(1)
