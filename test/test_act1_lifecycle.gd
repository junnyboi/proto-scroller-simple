extends GutTest

const TEMPLATE_MAIN_SCENE: PackedScene = preload("res://scenes/template/template_main.tscn")


func test_lifecycle_freezes_exactly_one_terminal_summary() -> void:
	var lifecycle: CompactRunLifecycle = CompactRunLifecycle.new()
	add_child_autofree(lifecycle)
	var summaries: Array[TemplateRunSummary] = []
	lifecycle.run_finished.connect(
		func(_completed: bool, summary: TemplateRunSummary) -> void:
			summaries.append(summary)
	)
	lifecycle.setup(&"stage_01")
	assert_true(lifecycle.finish_victory(125, 3))
	assert_false(lifecycle.finish_defeat(999, 9))
	assert_eq(summaries.size(), 1)
	assert_true(summaries[0].completed)
	assert_eq(summaries[0].score, 125)
	assert_eq(summaries[0].waves_cleared, 3)


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
	assert_true(victory_stage.lifecycle.finish_victory(100, 3))
	assert_false(victory_stage.lifecycle.finish_defeat(999, 9))
	assert_true(victory_stage.debrief.visible)
	assert_true(victory_stage.lifecycle.frozen_summary.completed)

	victory_stage.debrief.retry_button.pressed.emit()
	await get_tree().process_frame
	assert_not_same(runtime.current_stage, victory_stage)
	assert_eq(_active_stage_count(runtime), 1)

	var defeat_stage: TemplateStage = runtime.current_stage
	assert_true(defeat_stage.lifecycle.finish_defeat(25, 0))
	assert_true(defeat_stage.debrief.visible)
	assert_false(defeat_stage.lifecycle.frozen_summary.completed)
	defeat_stage.debrief.title_button.pressed.emit()
	await get_tree().process_frame
	assert_null(runtime.current_stage)
	assert_not_null(runtime.title_screen)
	assert_eq(_active_stage_count(runtime), 0)
func _active_stage_count(runtime: TemplateMain) -> int:
	var count: int = 0
	for child: Node in runtime.get_children():
		if child is TemplateStage:
			count += 1
	return count
