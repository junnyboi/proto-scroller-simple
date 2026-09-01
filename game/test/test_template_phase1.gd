extends GutTest

const TEMPLATE_MAIN_SCENE: PackedScene = preload("res://scenes/template/template_main.tscn")


func test_runtime_selector_accepts_only_explicit_native_or_web_opt_in() -> void:
	assert_true(TemplateRuntimeSelector.requested_from(
		PackedStringArray(["--template-runtime"])
	))
	assert_true(TemplateRuntimeSelector.requested_from(
		PackedStringArray(),
		"?templateRuntime=1"
	))
	assert_true(TemplateRuntimeSelector.requested_from(
		PackedStringArray(),
		"?other=1&templateRuntime=true"
	))
	assert_false(TemplateRuntimeSelector.requested_from(PackedStringArray()))
	assert_false(TemplateRuntimeSelector.requested_from(
		PackedStringArray(),
		"?templateRuntime=0"
	))


func test_stage_factory_is_allowlisted_and_rejects_unknown_ids() -> void:
	var factory: StageFactory = StageFactory.new()
	assert_eq(factory.known_stage_ids(), PackedStringArray(["stage_01"]))
	assert_not_null(factory.definition(&"stage_01"))
	assert_null(factory.definition(&"missing"))
	assert_null(factory.create(&"missing"))
	var stage: TemplateStage = factory.create(&"stage_01", 41)
	assert_not_null(stage)
	assert_eq(stage.definition.stage_id, &"stage_01")
	assert_eq(stage.run_seed, 41)
	stage.free()


func test_lifecycle_freezes_exactly_one_terminal_summary() -> void:
	var lifecycle: CompactRunLifecycle = CompactRunLifecycle.new()
	add_child_autofree(lifecycle)
	var summaries: Array[TemplateRunSummary] = []
	lifecycle.run_finished.connect(
		func(_completed: bool, summary: TemplateRunSummary) -> void:
			summaries.append(summary)
	)
	lifecycle.setup(&"stage_01", 73)
	assert_true(lifecycle.finish_victory(125, 3))
	assert_false(lifecycle.finish_defeat(999, 9))
	assert_eq(lifecycle.finalization_count, 1)
	assert_eq(summaries.size(), 1)
	assert_true(summaries[0].completed)
	assert_eq(summaries[0].score, 125)
	assert_eq(summaries[0].waves_cleared, 3)
	assert_eq(summaries[0].run_seed, 73)


func test_template_shell_supports_victory_retry_defeat_and_title() -> void:
	var runtime: TemplateMain = TEMPLATE_MAIN_SCENE.instantiate() as TemplateMain
	add_child_autofree(runtime)
	await get_tree().process_frame
	assert_not_null(runtime.title_screen)
	assert_null(runtime.current_stage)

	var original_title: BasicTitle = runtime.title_screen
	original_title.request_start()
	await get_tree().process_frame
	assert_null(runtime.title_screen)
	assert_not_null(runtime.current_stage)
	assert_eq(_active_stage_count(runtime), 1)

	var victory_stage: TemplateStage = runtime.current_stage
	assert_true(victory_stage.request_stub_victory())
	assert_false(victory_stage.request_stub_defeat())
	assert_true(victory_stage.debrief.visible)
	assert_eq(victory_stage.lifecycle.finalization_count, 1)
	assert_not_null(runtime.last_summary)
	assert_true(runtime.last_summary.completed)

	victory_stage.debrief.retry_button.pressed.emit()
	await get_tree().process_frame
	assert_not_same(runtime.current_stage, victory_stage)
	assert_eq(_active_stage_count(runtime), 1)

	var defeat_stage: TemplateStage = runtime.current_stage
	assert_true(defeat_stage.request_stub_defeat())
	assert_true(defeat_stage.debrief.visible)
	assert_false(runtime.last_summary.completed)
	defeat_stage.debrief.title_button.pressed.emit()
	await get_tree().process_frame
	assert_null(runtime.current_stage)
	assert_not_null(runtime.title_screen)
	assert_eq(_active_stage_count(runtime), 0)


func test_invalid_stage_does_not_replace_title() -> void:
	var runtime: TemplateMain = TEMPLATE_MAIN_SCENE.instantiate() as TemplateMain
	add_child_autofree(runtime)
	await get_tree().process_frame
	var original_title: BasicTitle = runtime.title_screen
	assert_false(runtime.start_stage(&"unknown_stage"))
	assert_same(runtime.title_screen, original_title)
	assert_null(runtime.current_stage)


func _active_stage_count(runtime: TemplateMain) -> int:
	var count: int = 0
	for child: Node in runtime.get_children():
		if child is TemplateStage:
			count += 1
	return count
