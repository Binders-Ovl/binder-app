class_name AttackAreaResource
extends Resource

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")

@export var area_name: String = "Single Target"
@export_enum("Target Datum", "Forward From User", "Self Centered") var targeting_mode: int = COMBAT_CONFIG.AreaTargetingMode.TARGET_DATUM
@export var pattern_size: int = 3
@export var datum_row: int = 2
@export var datum_col: int = 1
@export var affected_offsets: Array[Vector2i] = [Vector2i(0, 0)]
@export var notes: String = ""

func validate() -> Array[String]:
	var errors: Array[String] = []
	if pattern_size < 1:
		errors.append("AttackAreaResource.pattern_size must be >= 1.")
	if datum_row < 0 or datum_row >= pattern_size:
		errors.append("AttackAreaResource.datum_row is out of pattern bounds.")
	if datum_col < 0 or datum_col >= pattern_size:
		errors.append("AttackAreaResource.datum_col is out of pattern bounds.")
	if affected_offsets.is_empty():
		errors.append("AttackAreaResource.affected_offsets should not be empty.")
	return errors
