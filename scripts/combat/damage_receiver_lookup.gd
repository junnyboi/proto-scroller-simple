class_name DamageReceiverLookup
extends RefCounted

const CACHE_KEY: StringName = &"_damage_receiver_weak"


static func find(start_node: Node) -> Node:
	if start_node == null:
		return null
	if start_node.has_method("receive_damage"):
		return start_node
	if start_node.has_meta(CACHE_KEY):
		var cached_value: Variant = start_node.get_meta(CACHE_KEY)
		if cached_value is WeakRef:
			var cached_receiver: Node = (cached_value as WeakRef).get_ref() as Node
			if (
				cached_receiver != null
				and cached_receiver.has_method("receive_damage")
				and (
					cached_receiver == start_node
					or cached_receiver.is_ancestor_of(start_node)
				)
			):
				return cached_receiver
		start_node.remove_meta(CACHE_KEY)
	var receiver: Node = start_node.get_parent()
	while receiver != null:
		if receiver.has_method("receive_damage"):
			start_node.set_meta(CACHE_KEY, weakref(receiver))
			return receiver
		receiver = receiver.get_parent()
	return null
