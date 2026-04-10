class_name AttackAreaResource
extends Resource

const COMBAT_CONFIG = preload("res://data/models/world/combat/config/combat_config.gd")

@export var area_name: String = "Single Target"
@export_enum("Target Datum", "Forward From User", "Self Centered") var targeting_mode: int = COMBAT_CONFIG.AreaTargetingMode.TARGET_DATUM
@export var pattern_size: int = 3
@export var datum_row: int = 2
@export var datum_col: int = 1
@export var affected_offsets: Array[Vector2i] = [Vector2i(0, 0)]
@export var notes: String = ""
