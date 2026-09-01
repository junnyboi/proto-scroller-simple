class_name WeaponShopSession
extends Node

signal shop_opened(
	district: CityDistrictProfile,
	products: Array[WeaponShopProduct],
	score: int
)
signal purchase_completed(product: WeaponShopProduct, remaining_score: int)
signal purchase_rejected(product: WeaponShopProduct, reason: StringName)
signal shop_closed(district: CityDistrictProfile, act_index: int, terminal: bool)

const ACT_SHOP_DISTRICTS: Dictionary = {
	0: &"BUSINESS",
	1: &"RESIDENTIAL",
}

var pause: RunPauseCoordinator
var run_score: RunScore
var effects: WeaponShopUpgradeRuntime
var robot: GiantRobotController
var telegraphs: TelegraphPresenter2D
var active_district: CityDistrictProfile
var active_products: Array[WeaponShopProduct] = []
var active_act_index: int = -1
var active_cycle: int = 1
var active_terminal: bool = false
var pause_token: int = 0
var purchased: Dictionary[StringName, bool] = {}
var visited_acts: Dictionary[StringName, bool] = {}
var pending_district: CityDistrictProfile
var pending_act_index: int = -1
var pending_cycle: int = 1
var pending_terminal: bool = false
var active: bool = false


func setup(
	p_pause: RunPauseCoordinator,
	p_run_score: RunScore,
	p_effects: WeaponShopUpgradeRuntime,
	p_robot: GiantRobotController,
	p_telegraphs: TelegraphPresenter2D
) -> PackedStringArray:
	pause = p_pause
	run_score = p_run_score
	effects = p_effects
	robot = p_robot
	telegraphs = p_telegraphs
	var errors: PackedStringArray = WeaponShopCatalog.validation_errors()
	errors.append_array(WeaponShopVisualCatalog.validation_errors())
	return errors


func _process(_delta: float) -> void:
	if pending_district != null and not active and pause != null and not pause.is_paused():
		_open_pending()


func queue_act_completion(act_index: int, cycle: int) -> bool:
	if not ACT_SHOP_DISTRICTS.has(act_index):
		return false
	return _queue_shop(
		ACT_SHOP_DISTRICTS[act_index] as StringName,
		act_index,
		cycle,
		false
	)


func ensure_act_completion(act_index: int, cycle: int) -> bool:
	if not ACT_SHOP_DISTRICTS.has(act_index):
		return false
	return _ensure_shop(
		ACT_SHOP_DISTRICTS[act_index] as StringName,
		act_index,
		cycle,
		false
	)


func purchase(product_id: StringName) -> bool:
	if not active or run_score == null or effects == null:
		return false
	var product: WeaponShopProduct = _active_product(product_id)
	if product == null:
		return false
	var status: StringName = product_status(product)
	if status != &"available":
		purchase_rejected.emit(product, status)
		return false
	var deducted: int = run_score.deduct(product.price)
	if deducted != product.price or not effects.apply_product(product):
		return false
	purchased[product_id] = true
	purchase_completed.emit(product, run_score.score)
	return true


func close_shop() -> bool:
	if not active or active_district == null:
		return false
	var closed_district: CityDistrictProfile = active_district
	var closed_act_index: int = active_act_index
	var closed_terminal: bool = active_terminal
	active = false
	active_products.clear()
	active_district = null
	active_act_index = -1
	active_terminal = false
	if pause != null and pause_token != 0:
		pause.release(pause_token)
	pause_token = 0
	shop_closed.emit(closed_district, closed_act_index, closed_terminal)
	return true


func product_status(product: WeaponShopProduct) -> StringName:
	if product == null:
		return &"missing"
	if purchased.has(product.product_id):
		return &"sold"
	if product.is_repair() and robot != null and robot.current_health >= robot.max_health:
		return &"healthy"
	if run_score == null or run_score.score < product.price:
		return &"funds"
	return &"available"


func reset_run() -> void:
	if active:
		close_shop()
	purchased.clear()
	visited_acts.clear()
	_clear_pending()


func _queue_shop(
	district_id: StringName,
	act_index: int,
	cycle: int,
	terminal: bool
) -> bool:
	var key: StringName = StringName("%d:%d:%s" % [cycle, act_index, district_id])
	if active or pending_district != null or visited_acts.has(key):
		return false
	var district: CityDistrictProfile = _district(district_id)
	if district == null:
		return false
	visited_acts[key] = true
	pending_district = district
	pending_act_index = act_index
	pending_cycle = maxi(cycle, 1)
	pending_terminal = terminal
	_open_pending()
	return true


func _ensure_shop(
	district_id: StringName,
	act_index: int,
	cycle: int,
	terminal: bool
) -> bool:
	var normalized_cycle: int = maxi(cycle, 1)
	if active:
		return (
			active_district != null
			and active_district.district_id == district_id
			and active_act_index == act_index
			and active_cycle == normalized_cycle
			and active_terminal == terminal
		)
	if pending_district != null:
		var matches_pending: bool = (
			pending_district.district_id == district_id
			and pending_act_index == act_index
			and pending_cycle == normalized_cycle
			and pending_terminal == terminal
		)
		if matches_pending:
			_open_pending()
		return matches_pending
	var key: StringName = StringName(
		"%d:%d:%s" % [normalized_cycle, act_index, district_id]
	)
	visited_acts.erase(key)
	return _queue_shop(district_id, act_index, normalized_cycle, terminal)


func _open_pending() -> void:
	if pending_district == null or active or pause == null or pause.is_paused():
		return
	if telegraphs != null and telegraphs.active_count() > 0:
		return
	active_district = pending_district
	active_act_index = pending_act_index
	active_cycle = pending_cycle
	active_terminal = pending_terminal
	_clear_pending()
	active_products = _priced_products_for(active_district.district_id)
	if run_score != null:
		run_score.bank_all()
	pause_token = pause.acquire(&"weapon_shop")
	active = true
	shop_opened.emit(active_district, active_products, run_score.score)


func _clear_pending() -> void:
	pending_district = null
	pending_act_index = -1
	pending_cycle = 1
	pending_terminal = false


func _active_product(product_id: StringName) -> WeaponShopProduct:
	for product: WeaponShopProduct in active_products:
		if product.product_id == product_id:
			return product
	return null


func _priced_products_for(district_id: StringName) -> Array[WeaponShopProduct]:
	var price_multiplier: float = float(RuntimeTweakAccess.run_value(
		&"progression.shop.price_multiplier", 1.0
	))
	var products: Array[WeaponShopProduct] = []
	for source: WeaponShopProduct in WeaponShopCatalog.products_for(district_id):
		products.append(WeaponShopProduct.new(
			source.product_id,
			source.district_id,
			source.name_key,
			source.description_key,
			maxi(roundi(float(source.price) * price_multiplier), 1),
			source.effect_key,
			source.effect_value,
			source.repair_ratio
		))
	return products


func _district(district_id: StringName) -> CityDistrictProfile:
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		if district.district_id == district_id:
			return district
	return null
