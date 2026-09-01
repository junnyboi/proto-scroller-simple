extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func before_each() -> void:
	L10n.set_locale("en")


func after_each() -> void:
	L10n.set_locale("en")


func test_catalog_has_three_unique_shop_only_products_per_district() -> void:
	assert_eq(WeaponShopCatalog.validation_errors(), PackedStringArray())
	assert_eq(WeaponShopVisualCatalog.validation_errors(), PackedStringArray())
	var expected_prices: Dictionary[StringName, int] = {
		&"foreclosure_slugs": 25600,
		&"hostile_leverage": 33600,
		&"collateral_refinance": 19200,
		&"patchwork_nanoweld": 22400,
		&"scrapheap_magnetics": 38400,
		&"borrowed_shock_coils": 41600,
	}
	var level_ids: Dictionary[StringName, bool] = {}
	var level_catalog: UpgradeCatalog = load(
		"res://resources/upgrades/upgrade_catalog.tres"
	) as UpgradeCatalog
	for profile: UpgradeProfile in level_catalog.profiles:
		level_ids[profile.upgrade_id] = true
	var product_ids: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		var products: Array[WeaponShopProduct] = WeaponShopCatalog.products_for(
			district.district_id
		)
		assert_eq(products.size(), 3)
		for product: WeaponShopProduct in products:
			assert_false(product_ids.has(product.product_id))
			assert_false(level_ids.has(product.product_id))
			assert_eq(product.price, expected_prices[product.product_id])
			product_ids[product.product_id] = true
	assert_eq(product_ids.size(), CityDistrictCatalog.DISTRICT_COUNT * 3)


func test_simplified_chinese_shop_localizes_every_visible_surface() -> void:
	L10n.set_locale("zh-CN")
	var city: CitySlice = await _spawn_city()
	city.rampage_session.run_score.safe_score = 60_000
	city.robot.current_health = city.robot.max_health * 0.5
	_open_act_shop(city, 0)
	var overlay: WeaponShopOverlay = city.weapon_shop_assembler.overlay
	assert_eq(overlay.title_label.text, "黑账本交易所")
	assert_eq(overlay.tagline_label.text, "账本脊柱 // 无证军备清算")
	assert_eq(overlay.score_caption.text, "破坏积分")
	assert_eq(overlay.warning_label.text, "消费将降低你的最终破坏得分。")
	assert_eq(overlay.continue_button.text, "继续")
	assert_eq(overlay.dialogue_panel.operator_label.text, "审计官维尔 // 黑账本")
	assert_string_contains(overlay.dialogue_panel.body_label.text, "破坏得分")
	assert_eq(overlay.dialogue_panel.continue_button.text, "打开账本")
	assert_eq(overlay.cards[0].title_label.text, "止赎弹头")
	assert_eq(overlay.cards[0].description_label.text, "机枪伤害 +15%。")
	assert_string_contains(overlay.cards[0].price_label.text, "价格")
	assert_eq(overlay.cards[0].state_label.text, "购买")
	assert_true(overlay.title_label.get_theme_font(&"font").has_char("黑".unicode_at(0)))
	overlay.dialogue_panel._dismiss()
	overlay.cards[2]._request_preview()
	assert_eq(overlay.preview_panel.heading_label.text, "预计装备变化")
	assert_eq(overlay.preview_panel.product_label.text, "抵押物再融资")
	assert_string_contains(overlay.preview_panel.rows_label.text, "底盘完整度")
	overlay.cards[2]._on_pressed()
	assert_true(overlay.confirmation_panel.active)
	assert_eq(overlay.confirmation_panel.prompt_label.text, "授权扣除破坏得分？")
	assert_eq(overlay.confirmation_panel.confirm_button.text, "确认 / 19200")
	assert_eq(overlay.confirmation_panel.cancel_button.text, "取消")


func test_boss_salvage_opens_matching_shop_banks_score_and_keeps_handoff_held() -> void:
	var city: CitySlice = await _spawn_city()
	var score: RunScore = city.rampage_session.run_score
	score.safe_score = 6000
	score.pending_bank.value = 1000
	city._on_score_changed(score.score, 0)
	var banner_count: int = city.district_transition_banner.presentation_count
	_open_act_shop(city, 0)
	var session: WeaponShopSession = city.weapon_shop_assembler.session
	assert_true(session.active)
	assert_eq(session.active_district.district_id, &"BUSINESS")
	assert_true(city.weapon_shop_assembler.overlay.visible)
	assert_true(city.weapon_shop_assembler.overlay.dialogue_panel.active)
	assert_true(city.urban_siege.pause_coordinator.is_paused())
	assert_false(city.urban_siege.director._act_advance_blocked)
	assert_eq(score.pending_bank.value, 0)
	assert_eq(score.safe_score, 7000)
	assert_eq(city.district_transition_banner.presentation_count, banner_count)
	assert_true(city.upgrade_assembler.session.presentation_blocked)
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	var shop_x: float = city.robot.global_position.x
	city.robot.physics_step(1.0, 0.2)
	assert_gt(city.robot.global_position.x, shop_x)
	assert_true(session.close_shop())
	assert_false(city.weapon_shop_assembler.overlay.visible)
	assert_false(city.urban_siege.pause_coordinator.is_paused())
	assert_false(city.urban_siege.director._act_advance_blocked)
	assert_eq(city.district_transition_banner.presentation_count, banner_count)
	assert_false(city.upgrade_assembler.session.presentation_blocked)
	assert_false(session.queue_act_completion(0, city.urban_siege.cycle_count))


func test_every_boss_shop_waits_for_shared_defeat_celebration() -> void:
	var city: CitySlice = await _spawn_city()
	var assembler: WeaponShopAssembler = city.weapon_shop_assembler
	var spectacle: BossDefeatSpectacle2D = (
		city.urban_siege.boss_session.utility_pool.defeat_spectacle
	)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		var act_index: int = 0
		for district: CityDistrictProfile in CityDistrictCatalog.districts():
			if district.district_id == definition.district_id:
				act_index = district.district_index
				break
		assembler.session.visited_acts[StringName(
			"%d:%d:%s" % [
				city.urban_siege.cycle_count,
				act_index,
				definition.district_id,
			]
		)] = true
		spectacle.activate(Vector2.ZERO)
		assert_true(
			city.urban_siege.boss_session.defeat_celebration_active(),
			String(definition.boss_id)
		)
		assert_false(
			assembler.queue_boss_salvage(definition),
			String(definition.boss_id)
		)
		assert_false(assembler.session.active, String(definition.boss_id))
		assert_null(assembler.session.pending_district, String(definition.boss_id))
		spectacle.deactivate()
		assert_true(
			assembler.queue_boss_salvage(definition),
			String(definition.boss_id)
		)
		assert_true(assembler.session.active, String(definition.boss_id))
		assert_true(assembler.overlay.visible, String(definition.boss_id))
		assert_eq(
			assembler.session.active_district.district_id,
			definition.district_id,
			String(definition.boss_id)
		)
		assert_true(assembler.session.close_shop(), String(definition.boss_id))


func test_purchase_deducts_score_repairs_once_and_updates_hud() -> void:
	var city: CitySlice = await _spawn_city()
	var score: RunScore = city.rampage_session.run_score
	score.safe_score = 30_000
	city._on_score_changed(score.score, 0)
	city.robot.current_health = 30.0
	city.robot.health_changed.emit(city.robot.current_health, city.robot.max_health)
	var expected_health: float = minf(
		city.robot.max_health,
		30.0 + city.robot.max_health * 0.50
	)
	_open_act_shop(city, 1)
	var session: WeaponShopSession = city.weapon_shop_assembler.session
	assert_true(session.purchase(&"patchwork_nanoweld"))
	assert_eq(score.score, 7600)
	assert_almost_eq(city.robot.current_health, expected_health, 0.01)
	assert_eq(city.gameplay_hud.score_label.text, "00007600")
	assert_eq(session.product_status(session.active_products[0]), &"sold")
	assert_false(session.purchase(&"patchwork_nanoweld"))
	assert_eq(score.score, 7600)


func test_insufficient_score_and_full_health_reject_without_spending() -> void:
	var city: CitySlice = await _spawn_city()
	var score: RunScore = city.rampage_session.run_score
	score.safe_score = 1000
	_open_act_shop(city, 1)
	var session: WeaponShopSession = city.weapon_shop_assembler.session
	var overlay: WeaponShopOverlay = city.weapon_shop_assembler.overlay
	assert_eq(session.product_status(session.active_products[0]), &"healthy")
	assert_eq(session.product_status(session.active_products[1]), &"funds")
	assert_false(session.purchase(&"patchwork_nanoweld"))
	assert_false(session.purchase(&"scrapheap_magnetics"))
	assert_eq(score.score, 1000)
	overlay.dialogue_panel._dismiss()
	overlay.cards[1]._on_pressed()
	assert_eq(overlay.insufficient_warning_count, 1)
	assert_eq(overlay.last_insufficient_product_id, &"scrapheap_magnetics")
	assert_true(overlay.insufficient_flash.visible)
	assert_false(overlay.confirmation_panel.active)
	assert_eq(score.score, 1000)
	await get_tree().process_frame
	assert_gt(overlay.insufficient_flash.modulate.a, 0.0)


func test_hover_preview_confirmation_and_upgrade_feedback_are_transactional() -> void:
	var city: CitySlice = await _spawn_city()
	var score: RunScore = city.rampage_session.run_score
	score.safe_score = 60_000
	_open_act_shop(city, 0)
	var overlay: WeaponShopOverlay = city.weapon_shop_assembler.overlay
	overlay.dialogue_panel._dismiss()
	var card: WeaponShopCard = overlay.cards[0]
	card._request_preview()
	assert_true(overlay.preview_panel.visible)
	assert_eq(overlay.preview_panel.active_product_id, card.product.product_id)
	assert_string_contains(overlay.preview_panel.rows_label.text, "100%")
	assert_eq(
		overlay.preview_panel.rows_label.get_theme_font_size(&"font_size"),
		WeaponShopStatPreviewPanel.PROJECTED_STAT_FONT_SIZE
	)
	assert_eq(WeaponShopStatPreviewPanel.PROJECTED_STAT_FONT_SIZE, 22)
	assert_not_null(overlay.preview_panel.get_node_or_null("StatPreviewContainer"))
	assert_eq(overlay.preview_panel.get_child_count(), 4)
	for child: Node in overlay.preview_panel.get_children():
		if child is Label:
			assert_false((child as Label).text.contains("AVAILABLE"))
			assert_false((child as Label).text.contains("CONFIRM TO PURCHASE"))
	assert_null(overlay.get_node_or_null("TransactionFeedback"))
	var score_before: int = score.score
	card._on_pressed()
	assert_true(overlay.confirmation_panel.active)
	assert_eq(score.score, score_before)
	assert_string_contains(overlay.confirmation_panel.score_label.text, ">>")
	overlay.confirmation_panel._cancel()
	assert_eq(score.score, score_before)
	card._on_pressed()
	overlay.confirmation_panel._confirm()
	assert_eq(score.score, score_before - card.product.price)
	assert_eq(
		city.impact_feedback_pool.last_cue,
		AudioCueRegistry.Cue.SHOP_PURCHASE
	)
	assert_eq(overlay.transaction_burst_count, 1)
	assert_true(overlay.upgrade_particles.emitting)


func test_repair_confirmation_uses_distinct_audio_and_repair_particles() -> void:
	var city: CitySlice = await _spawn_city()
	city.rampage_session.run_score.safe_score = 60_000
	city.robot.current_health = 40.0
	_open_act_shop(city, 1)
	var overlay: WeaponShopOverlay = city.weapon_shop_assembler.overlay
	overlay.dialogue_panel._dismiss()
	var repair_card: WeaponShopCard = overlay.cards[0]
	repair_card._request_preview()
	var preview_lines: PackedStringArray = overlay.preview_panel.rows_label.text.split("\n")
	assert_eq(preview_lines.size(), 2)
	assert_eq(preview_lines[0], "CHASSIS INTEGRITY")
	assert_string_contains(preview_lines[1], ">>")
	repair_card._on_pressed()
	overlay.confirmation_panel._confirm()
	assert_eq(city.impact_feedback_pool.last_cue, AudioCueRegistry.Cue.SHOP_REPAIR)
	assert_true(overlay.repair_particles.emitting)
	assert_gt(city.robot.current_health, 40.0)


func test_retained_shop_effects_scale_weapons_structure_debris_and_melee_area() -> void:
	var robot: GiantRobotController = GiantRobotController.new()
	add_child_autofree(robot)
	await get_tree().process_frame
	var effects: WeaponShopUpgradeRuntime = WeaponShopUpgradeRuntime.new()
	add_child_autofree(effects)
	effects.setup(robot)
	for district_id: StringName in [&"BUSINESS", &"RESIDENTIAL"]:
		for product: WeaponShopProduct in WeaponShopCatalog.products_for(district_id):
			if not product.is_repair():
				assert_true(effects.apply_product(product))
	var base: AttackSpec = AttackSpec.new(
		AttackSpec.Mode.GROUND_SMASH,
		51,
		1,
		0.0,
		0.0,
		0.0,
		0.0,
		100.0,
		120.0,
		900.0,
		Vector2(200.0, 200.0),
		Vector2.ZERO
	)
	var decorated: AttackSpec = effects.decorate_attack(base)
	assert_almost_eq(decorated.actor_damage, 100.0, 0.01)
	assert_almost_eq(decorated.hit_size.x, 141.6, 0.01)
	assert_gt(decorated.kinetic_debris_bonus, 0.0)
	assert_almost_eq(
		effects.scale_weapon_damage(100.0, &"machine_gun", robot, 99),
		128.8,
		0.01
	)
	var leverage: WeaponShopProduct = WeaponShopCatalog.products_for(&"BUSINESS")[1]
	var leverage_preview: Array[Dictionary] = effects.preview_for(leverage)
	assert_eq(leverage_preview.size(), 1)
	assert_almost_eq(float(leverage_preview[0].before), 1.12, 0.001)
	assert_almost_eq(float(leverage_preview[0].after), 1.2544, 0.001)


func test_portrait_overlay_keeps_dialogue_cards_and_continue_inside_viewport() -> void:
	var city: CitySlice = await _spawn_city()
	city.rampage_session.run_score.safe_score = 20_000
	_open_act_shop(city, 1)
	get_window().content_scale_size = Vector2i(720, 1280)
	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame
	var overlay: WeaponShopOverlay = city.weapon_shop_assembler.overlay
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(get_tree().root.size))
	assert_true(viewport_rect.encloses(overlay.dialogue_panel.continue_button.get_global_rect()))
	overlay.dialogue_panel._dismiss()
	assert_eq(overlay.cards.size(), 3)
	for card: WeaponShopCard in overlay.cards:
		assert_true(viewport_rect.encloses(card.get_global_rect()))
	assert_false(overlay.cards[0].get_global_rect().intersects(
		overlay.cards[1].get_global_rect()
	))
	assert_false(overlay.cards[1].get_global_rect().intersects(
		overlay.cards[2].get_global_rect()
	))
	assert_true(viewport_rect.encloses(overlay.continue_button.get_global_rect()))
	get_window().content_scale_size = Vector2i(1280, 720)
	get_tree().root.size = Vector2i(1280, 720)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	return city


func _open_act_shop(city: CitySlice, act_index: int) -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[act_index]
	city.weapon_shop_assembler.queue_boss_salvage(definition)
	await get_tree().process_frame


func _product(product_id: StringName, district_id: StringName) -> WeaponShopProduct:
	for product: WeaponShopProduct in WeaponShopCatalog.products_for(district_id):
		if product.product_id == product_id:
			return product
	return null
