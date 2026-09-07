class_name RuntimeTweakAccess
extends RefCounted

static var _service: RuntimeTweakService


static func bind_service(service: RuntimeTweakService) -> void:
	_service = service


static func unbind_service(service: RuntimeTweakService = null) -> void:
	if service == null or _service == service:
		_service = null


static func service() -> RuntimeTweakService:
	return _service if is_instance_valid(_service) else null


static func requested_value(identifier: StringName, fallback: Variant) -> Variant:
	var authority: RuntimeTweakService = service()
	return authority.requested_value(identifier, fallback) if authority != null else fallback


static func live_value(identifier: StringName, fallback: Variant) -> Variant:
	var authority: RuntimeTweakService = service()
	return authority.live_value(identifier, fallback) if authority != null else fallback


static func live_color(identifier: StringName, fallback: Color = Color.WHITE) -> Color:
	var candidate: Variant = live_value(identifier, "#%s" % fallback.to_html(false))
	if candidate is Color:
		return candidate
	if candidate is String and Color.html_is_valid(String(candidate)):
		return Color.from_string(String(candidate), fallback)
	return fallback


static func run_value(identifier: StringName, fallback: Variant) -> Variant:
	var authority: RuntimeTweakService = service()
	return authority.run_value(identifier, fallback) if authority != null else fallback


static func district_value(identifier: StringName, fallback: Variant) -> Variant:
	var authority: RuntimeTweakService = service()
	return authority.district_value(identifier, fallback) if authority != null else fallback


static func next_attack_value(identifier: StringName, fallback: Variant) -> Variant:
	var authority: RuntimeTweakService = service()
	return authority.next_attack_value(identifier, fallback) if authority != null else fallback


static func next_spawn_value(identifier: StringName, fallback: Variant) -> Variant:
	var authority: RuntimeTweakService = service()
	return authority.next_spawn_value(identifier, fallback) if authority != null else fallback
