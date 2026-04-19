class_name AttackProfileResource
extends Resource

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")

@export var display_name: String = "Attack"
@export_enum("Blunt", "Slash", "Stab", "Pierce", "Magic", "Impact", "Hack") var attack_type: int = COMBAT_CONFIG.AttackType.SLASH
@export var base_attack: float = 1.0
@export var is_magic: bool = false
@export var range: int = 1
@export var min_range: int = 1
@export_enum("Diamond", "Cross", "Spread Diag") var range_pattern: int = COMBAT_CONFIG.AttackRangePattern.DIAMOND
@export_enum("Default", "Absolute", "Multiplier") var act_cost_mode: int = COMBAT_CONFIG.AttackCostMode.DEFAULT
@export var act_cost_absolute: float = 0.0
@export var act_cost_multiplier: float = 1.0
@export var can_target_flying: bool = true
@export var elevation_modifier: float = 1.0
@export var damage_modifier: float = 1.0
@export var area: AttackAreaResource
@export var notes: String = ""

func get_effective_act_cost(base_attack_cost: float = COMBAT_CONFIG.DEFAULT_ATTACK_ACT_COST) -> float:
	match act_cost_mode:
		COMBAT_CONFIG.AttackCostMode.ABSOLUTE:
			return act_cost_absolute if act_cost_absolute > 0.0 else base_attack_cost
		COMBAT_CONFIG.AttackCostMode.MULTIPLIER:
			return maxf(0.0, base_attack_cost * act_cost_multiplier)
		_:
			return base_attack_cost

func validate() -> Array[String]:
	var errors: Array[String] = []
	if range < 0:
		errors.append("AttackProfileResource.range must be >= 0.")
	if min_range < 0:
		errors.append("AttackProfileResource.min_range must be >= 0.")
	if min_range > range:
		errors.append("AttackProfileResource.min_range cannot be greater than range.")
	if act_cost_mode == COMBAT_CONFIG.AttackCostMode.ABSOLUTE and act_cost_absolute < 0.0:
		errors.append("AttackProfileResource.act_cost_absolute cannot be negative in ABSOLUTE mode.")
	if act_cost_mode == COMBAT_CONFIG.AttackCostMode.MULTIPLIER and act_cost_multiplier < 0.0:
		errors.append("AttackProfileResource.act_cost_multiplier cannot be negative in MULTIPLIER mode.")
	if area == null:
		errors.append("AttackProfileResource.area must be assigned.")
	elif area is AttackAreaResource:
		var area_errors: Array[String] = area.validate()
		for area_error: String in area_errors:
			errors.append("AttackProfileResource.area -> %s" % area_error)
	return errors
