extends SceneTree

const TEMPLATE_MAIN_SCENE: PackedScene = preload("res://scenes/template/template_main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime: TemplateMain = TEMPLATE_MAIN_SCENE.instantiate() as TemplateMain
	root.add_child(runtime)
	await process_frame
	if not runtime.start_stage(&"stage_01"):
		_fail("stage_01 did not start")
		return
	await process_frame
	var stage: TemplateStage = runtime.current_stage
	stage.wave_director.set_physics_process(false)
	var warm_count: int = _node_count(stage)
	var charged_attack_exercised: bool = false
	for step: int in range(256):
		stage.wave_director.simulation_step(0.25)
		var active: Array[CompactEnemy] = stage.wave_director.active_enemies()
		if not charged_attack_exercised and not active.is_empty():
			var target: CompactEnemy = active[0]
			target.set_physics_process(false)
			target.global_position = stage.player.global_position + Vector2(125.0, 0.0)
			if not stage.player.begin_attack_charge():
				_fail("player charge did not begin")
				return
			stage.player.physics_step(0.0, stage.player.full_charge_seconds)
			if not stage.player.release_attack_charge():
				_fail("player charge did not release")
				return
			charged_attack_exercised = true
		for enemy: CompactEnemy in stage.wave_director.active_enemies():
			enemy.set_physics_process(false)
			enemy.receive_damage(9999.0)
		if stage.lifecycle.finalized:
			break
	var passed: bool = (
		charged_attack_exercised
		and stage.lifecycle.finalized
		and stage.lifecycle.frozen_summary.completed
		and stage.lifecycle.frozen_summary.waves_cleared == 3
		and stage.wave_director.pool_exhaustion_count == 0
		and stage.wave_director.pool_node_count() == 8
		and stage.effect_pool.slot_count() == 8
		and _node_count(stage) == warm_count
	)
	root.remove_child(runtime)
	runtime.queue_free()
	await process_frame
	print("[TEMPLATE-PHASE2-DONE] result=%s" % ["PASS" if passed else "FAIL"])
	quit(0 if passed else 1)


func _node_count(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _node_count(child)
	return count


func _fail(message: String) -> void:
	push_error(message)
	print("[TEMPLATE-PHASE2-DONE] result=FAIL reason=%s" % [message])
	quit(1)
