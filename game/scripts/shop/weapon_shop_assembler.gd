class_name WeaponShopAssembler
extends Node

var session: WeaponShopSession
var effects: WeaponShopUpgradeRuntime
var overlay: WeaponShopOverlay
var music_duck: MusicDuckController
var upgrade_session: UpgradeSession
var siege: UrbanSiegeRuntime
var impact_feedback_pool: ImpactFeedbackPool


func setup(city: Node) -> PackedStringArray:
	name = "WeaponShopAssembler"
	var robot: GiantRobotController = city.get("robot") as GiantRobotController
	siege = city.get("urban_siege") as UrbanSiegeRuntime
	var rampage: RampageSession = city.get("rampage_session") as RampageSession
	var upgrades: PlayerUpgradeAssembler = city.get("upgrade_assembler") as PlayerUpgradeAssembler
	music_duck = city.get("music_duck_controller") as MusicDuckController
	impact_feedback_pool = city.get("impact_feedback_pool") as ImpactFeedbackPool
	upgrade_session = upgrades.session
	effects = WeaponShopUpgradeRuntime.new()
	effects.name = "WeaponShopUpgradeRuntime"
	effects.setup(robot)
	add_child(effects)
	upgrades.shop_effects = effects
	upgrades.arsenal.shop_effects = effects
	city.get("contextual_attacks").call(&"set_shop_upgrade_runtime", effects)
	overlay = WeaponShopOverlay.new()
	var hud: GameplayHud = city.get("gameplay_hud") as GameplayHud
	hud.add_child(overlay)
	L10n.apply_locale_font(overlay)
	session = WeaponShopSession.new()
	session.name = "WeaponShopSession"
	add_child(session)
	var errors: PackedStringArray = session.setup(
		siege.pause_coordinator,
		rampage.run_score,
		effects,
		robot,
		city.get("telegraph_presenter") as TelegraphPresenter2D
	)
	session.shop_opened.connect(_on_shop_opened)
	session.purchase_completed.connect(_on_purchase_completed)
	session.purchase_rejected.connect(_on_purchase_rejected)
	session.shop_closed.connect(_on_shop_closed)
	overlay.purchase_requested.connect(session.purchase)
	overlay.preview_requested.connect(_on_preview_requested)
	overlay.continue_requested.connect(session.close_shop)
	siege.pause_coordinator.pause_changed.connect(_on_pause_changed)
	return errors


func queue_boss_salvage(definition: BossEncounterDefinition) -> bool:
	if (
		definition == null
		or session == null
		or (
			siege != null
			and siege.boss_session != null
			and siege.boss_session.defeat_celebration_active()
		)
	):
		return false
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		if district.district_id == definition.district_id:
			return session.ensure_act_completion(
				district.district_index,
				siege.cycle_count
			)
	return false


func _on_shop_opened(
	district: CityDistrictProfile,
	products: Array[WeaponShopProduct],
	score: int
) -> void:
	upgrade_session.set_presentation_blocked(true)
	music_duck.set_ducked(true)
	var statuses: Dictionary[StringName, StringName] = {}
	for product: WeaponShopProduct in products:
		statuses[product.product_id] = session.product_status(product)
	overlay.show_shop(district, products, score, statuses)


func _on_purchase_completed(product: WeaponShopProduct, remaining_score: int) -> void:
	overlay.set_score(remaining_score)
	overlay.update_status(product.product_id, &"sold")
	overlay.play_transaction_success(product)
	impact_feedback_pool.play_cue(
		AudioCueRegistry.Cue.SHOP_REPAIR
		if product.is_repair()
		else AudioCueRegistry.Cue.SHOP_PURCHASE,
		Vector2.ZERO
	)
	_refresh_statuses()


func _on_purchase_rejected(product: WeaponShopProduct, reason: StringName) -> void:
	overlay.update_status(product.product_id, reason)


func _on_shop_closed(
	district: CityDistrictProfile,
	_act_index: int,
	_terminal: bool
) -> void:
	overlay.hide_shop()
	music_duck.set_ducked(false)
	upgrade_session.set_presentation_blocked(false)
	if siege.boss_campaign != null:
		siege.boss_campaign.complete_shop_handoff(district.district_id)


func _on_pause_changed(paused: bool) -> void:
	effects.set_process(not paused)


func _refresh_statuses() -> void:
	for card: WeaponShopCard in overlay.cards:
		if card.product != null:
				overlay.update_status(
					card.product.product_id,
					session.product_status(card.product)
				)


func _on_preview_requested(product_id: StringName) -> void:
	for product: WeaponShopProduct in session.active_products:
		if product.product_id == product_id:
			overlay.set_preview(
				product,
				effects.preview_for(product)
			)
			return
