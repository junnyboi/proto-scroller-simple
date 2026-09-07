class_name FinaleEligibilitySnapshot
extends RefCounted

const DOSSIER_REQUIREMENT: int = 20
const EVIDENCE_REQUIREMENT: int = 5
const REQUIRED_EVIDENCE: Array[StringName] = [
	&"LEDGER", &"NURSERY", &"STAGE", &"ARSENAL", &"CROWN",
]

var dossier_count: int
var evidence_count: int
var continuity_generation: int
var evidence_flags: PackedStringArray = PackedStringArray()
var disentangle_eligible: bool


static func from_store(store: CampaignProgressStore) -> FinaleEligibilitySnapshot:
	var snapshot: FinaleEligibilitySnapshot = FinaleEligibilitySnapshot.new()
	if store == null:
		return snapshot
	snapshot.dossier_count = store.dossier_count()
	snapshot.evidence_flags = store.evidence_ids()
	snapshot.evidence_count = snapshot.evidence_flags.size()
	snapshot.continuity_generation = store.continuity_generation()
	snapshot.disentangle_eligible = (
		snapshot.dossier_count >= DOSSIER_REQUIREMENT
		and snapshot.has_all_evidence()
	)
	return snapshot


static func from_dictionary(data: Dictionary) -> FinaleEligibilitySnapshot:
	var snapshot: FinaleEligibilitySnapshot = FinaleEligibilitySnapshot.new()
	snapshot.dossier_count = maxi(int(data.get("dossier_count", 0)), 0)
	snapshot.continuity_generation = maxi(int(data.get("continuity_generation", 0)), 0)
	var raw_flags: Variant = data.get("evidence_flags", PackedStringArray())
	if raw_flags is PackedStringArray:
		snapshot.evidence_flags = (raw_flags as PackedStringArray).duplicate()
	elif raw_flags is Array:
		for evidence_id: Variant in raw_flags as Array:
			snapshot.evidence_flags.append(String(evidence_id))
	snapshot.evidence_flags.sort()
	snapshot.evidence_count = snapshot.evidence_flags.size()
	snapshot.disentangle_eligible = (
		snapshot.dossier_count >= DOSSIER_REQUIREMENT
		and snapshot.has_all_evidence()
	)
	return snapshot


func has_all_evidence() -> bool:
	for evidence_id: StringName in REQUIRED_EVIDENCE:
		if not evidence_flags.has(String(evidence_id)):
			return false
	return true


func as_dictionary() -> Dictionary:
	return {
		"dossier_count": dossier_count,
		"dossier_requirement": DOSSIER_REQUIREMENT,
		"evidence_count": evidence_count,
		"evidence_requirement": EVIDENCE_REQUIREMENT,
		"continuity_generation": continuity_generation,
		"evidence_flags": evidence_flags,
		"disentangle_eligible": disentangle_eligible,
	}
