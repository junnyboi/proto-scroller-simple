class_name WeaponShopCatalog
extends RefCounted

const PRODUCTS_PER_DISTRICT: int = 3

static var _products: Dictionary[StringName, Array] = {}


static func products_for(district_id: StringName) -> Array[WeaponShopProduct]:
	_ensure_catalog()
	var result: Array[WeaponShopProduct] = []
	for product: WeaponShopProduct in _products.get(district_id, []):
		result.append(product)
	return result


static func validation_errors() -> PackedStringArray:
	_ensure_catalog()
	var errors: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		var products: Array = _products.get(district.district_id, [])
		if products.size() != PRODUCTS_PER_DISTRICT:
			errors.append(
				"%s shop product_count=%d expected=%d"
				% [district.district_id, products.size(), PRODUCTS_PER_DISTRICT]
			)
		for product: WeaponShopProduct in products:
			errors.append_array(product.validation_errors())
			if seen.has(product.product_id):
				errors.append("duplicate shop product_id %s" % product.product_id)
			seen[product.product_id] = true
	return errors


static func shop_title_key(district_id: StringName) -> String:
	return "shop.%s.title" % String(district_id).to_lower()


static func shop_tagline_key(district_id: StringName) -> String:
	return "shop.%s.tagline" % String(district_id).to_lower()


static func _ensure_catalog() -> void:
	if not _products.is_empty():
		return
	_products = {
		&"BUSINESS": [
			_product(&"foreclosure_slugs", &"BUSINESS", 25600, &"ballistic_damage", 0.15),
			_product(&"hostile_leverage", &"BUSINESS", 33600, &"weapon_damage", 0.12),
			_product(&"collateral_refinance", &"BUSINESS", 19200, &"repair", 0.0, 0.35),
		],
		&"RESIDENTIAL": [
			_product(&"patchwork_nanoweld", &"RESIDENTIAL", 22400, &"repair", 0.0, 0.50),
			_product(&"scrapheap_magnetics", &"RESIDENTIAL", 38400, &"debris_damage", 0.35),
			_product(&"borrowed_shock_coils", &"RESIDENTIAL", 41600, &"melee_radius", 0.18),
		],
	}


static func _product(
	product_id: StringName,
	district_id: StringName,
	price: int,
	effect_key: StringName,
	effect_value: float = 0.0,
	repair_ratio: float = 0.0
) -> WeaponShopProduct:
	var key: String = String(product_id)
	return WeaponShopProduct.new(
		product_id,
		district_id,
		"shop.product.%s.name" % key,
		"shop.product.%s.description" % key,
		price,
		effect_key,
		effect_value,
		repair_ratio
	)
