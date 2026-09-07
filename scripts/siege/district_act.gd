class_name DistrictAct
extends Resource

@export var act_id: StringName = &"CONTACT"
@export var display_name: String = "encounter.contact"
@export_range(15.0, 120.0, 1.0) var target_duration: float = 75.0
@export var beats: Array[DistrictBeat] = []
@export var milestone_after: StringName = &""
@export var elite_allowed: bool = false
@export var chaos_enabled: bool = false
@export_range(0.0, 0.5, 0.01) var spawn_stagger_seconds: float = 0.0
@export_range(0.0, 0.5, 0.01) var spawn_jitter_seconds: float = 0.0
@export_range(0.0, 1.0, 0.05) var mirrored_flank_chance: float = 0.0
@export_range(1, 3, 1) var elite_units_per_beat: int = 1
@export_range(0, 10, 1) var hazard_pressure_budget: int = 0
@export_range(0, 3, 1) var hazard_events_per_beat: int = 0
