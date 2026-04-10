class_name AttackProfileResource
extends Resource

const COMBAT_CONFIG = preload("res://data/models/world/combat/config/combat_config.gd")

@export var display_name: String = "Attack"
@export_enum("Blunt", "Slash", "Stab", "Pierce", "Magic", "Impact", "Hack") var attack_type: int = COMBAT_CONFIG.AttackType.SLASH
@export var base_attack: float = 1.0
@export var is_magic: bool = false
@export var range: int = 1
@export_enum("Default", "Absolute", "Multiplier") var act_cost_mode: int = COMBAT_CONFIG.AttackCostMode.DEFAULT
@export var act_cost_absolute: float = 0.0
@export var act_cost_multiplier: float = 1.0
@export var can_target_flying: bool = true
@export var elevation_modifier: float = 1.0
@export var damage_modifier: float = 1.0
@export var area: Resource
@export var notes: String = ""

func get_effective_act_cost(base_attack_cost: float = COMBAT_CONFIG.DEFAULT_ATTACK_ACT_COST) -> float:
	match act_cost_mode:
		COMBAT_CONFIG.AttackCostMode.ABSOLUTE:
			return act_cost_absolute if act_cost_absolute > 0.0 else base_attack_cost
		COMBAT_CONFIG.AttackCostMode.MULTIPLIER:
			return maxf(0.0, base_attack_cost * act_cost_multiplier)
		_:
			return base_attack_cost
