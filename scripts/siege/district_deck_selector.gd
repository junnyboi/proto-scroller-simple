class_name DistrictDeckSelector
extends RefCounted


static func select(
	base_district: DistrictDefinition,
	deck: DistrictDeck,
	contracts: Array[RunContract],
	run_seed: int,
	cycle: int
) -> Dictionary:
	var recipe_index: int = posmod(run_seed * 31 + cycle * 17, deck.recipes.size())
	var contract_index: int = posmod(run_seed * 13 + cycle * 7, contracts.size())
	var recipe: DistrictRecipe = deck.recipes[recipe_index]
	var district: DistrictDefinition = base_district.duplicate(true) as DistrictDefinition
	for act_index: int in range(district.acts.size() - 1):
		var act: DistrictAct = district.acts[act_index]
		var beats: Array[DistrictBeat] = act.beats.duplicate()
		if not beats.is_empty():
			var rotation: int = recipe.beat_rotation % beats.size()
			for _step: int in range(rotation):
				beats.append(beats.pop_front())
		if recipe.reverse_alternate_acts and act_index % 2 == 1:
			beats.reverse()
		act.beats = beats
	return {
		"district": district,
		"recipe": recipe,
		"contract": contracts[contract_index],
	}
