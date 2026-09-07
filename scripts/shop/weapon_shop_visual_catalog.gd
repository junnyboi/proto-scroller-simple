class_name WeaponShopVisualCatalog
extends RefCounted

const BACKPLATES: Dictionary = {
	&"BUSINESS": preload("res://assets/ui/weapon_shop/business_backplate.webp"),
}
const OPERATORS: Dictionary = {
	&"BUSINESS": preload("res://assets/ui/weapon_shop/business_operator.webp"),
}
const PRODUCT_ICONS: Dictionary = {
	&"foreclosure_slugs": preload("res://assets/ui/weapon_shop/foreclosure_slugs.webp"),
	&"hostile_leverage": preload("res://assets/ui/weapon_shop/hostile_leverage.webp"),
	&"collateral_refinance": preload("res://assets/ui/weapon_shop/collateral_refinance.webp"),
}
const CONFIRMATION_FRAME: Texture2D = preload(
	"res://assets/ui/weapon_shop/confirmation_frame.webp"
)
const RAMPAGE_CREDIT: Texture2D = preload("res://assets/ui/weapon_shop/rampage_credit.webp")
const UPGRADE_BURST: Texture2D = preload(
	"res://assets/ui/weapon_shop/upgrade_success_burst.webp"
)
const REPAIR_BURST: Texture2D = preload(
	"res://assets/ui/weapon_shop/repair_success_burst.webp"
)
const NEW_GAME_PLUS: Texture2D = null


static func backplate(district_id: StringName) -> Texture2D:
	return BACKPLATES.get(district_id) as Texture2D


static func operator_portrait(district_id: StringName) -> Texture2D:
	return OPERATORS.get(district_id) as Texture2D


static func product_icon(product_id: StringName) -> Texture2D:
	return PRODUCT_ICONS.get(product_id) as Texture2D


static func operator_name_key(district_id: StringName) -> String:
	return "shop.dialogue.%s.operator" % String(district_id).to_lower()


static func dialogue_key(district_id: StringName) -> String:
	return "shop.dialogue.%s.body" % String(district_id).to_lower()


static func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		if backplate(district.district_id) == null:
			errors.append("missing shop backplate %s" % district.district_id)
		if operator_portrait(district.district_id) == null:
			errors.append("missing shop operator %s" % district.district_id)
		for product: WeaponShopProduct in WeaponShopCatalog.products_for(
			district.district_id
		):
			if product_icon(product.product_id) == null:
				errors.append("missing shop icon %s" % product.product_id)
	return errors
