class_name Stats
extends Node

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")
const COMBAT_FORMULA = preload("res://data/models/world/combat/formula/combat_formula.gd")

var modifiers: Dictionary = {}
var override_name: String
var expertise: String
var level: int = 1
var sprite: String
var class_combat: ClassCombatResource

# Core stats
var str: int = 0
var intt: int = 0
var agi: int = 0
var dex: int = 0
var vit: int = 0
var wis: int = 0
var spd: int = 0
var sta: int = 0
var can_fly: bool = false

# Dynamic combat state
var movement: int = 0
var jump: int = 0
var max_health: int = 0
var curr_health: int = 0
var max_mana: int = 0
var curr_mana: int = 0
var curr_act: float = 0.0
var max_act: float = 100.0

var attack_1: AttackProfileResource
var attack_2: AttackProfileResource
var attack_3: AttackProfileResource

func import_stats(resource: StatsResource) -> void:
	if resource == null:
		push_error("Stats.import_stats: resource is null.")
		return
	var validation_errors: Array[String] = resource.validate()
	if not validation_errors.is_empty():
		push_error("Stats.import_stats: invalid StatsResource: %s" % "; ".join(validation_errors))

	override_name = resource.override_name
	expertise = resource.expertise
	level = resource.level
	sprite = resource.sprite
	class_combat = resource.class_combat
	str = resource.str
	intt = resource.intt
	agi = resource.agi
	dex = resource.dex
	vit = resource.vit
	wis = resource.wis
	spd = resource.spd
	sta = resource.sta
	can_fly = resource.can_fly
	movement = resource.get_movement()
	jump = resource.get_jump()
	max_health = resource.get_max_health()
	curr_health = max_health
	max_mana = resource.get_max_mana()
	curr_mana = max_mana
	max_act = float(TacticsConfig.active_timeline.max_act)
	curr_act = 0.0
	attack_1 = resource.attack_1
	attack_2 = resource.attack_2
	attack_3 = resource.attack_3

func get_attack(slot_index: int) -> AttackProfileResource:
	match slot_index:
		0:
			return attack_1
		1:
			return attack_2
		2:
			return attack_3
		_:
			return null

func get_primary_attack() -> AttackProfileResource:
	for attack: AttackProfileResource in [attack_1, attack_2, attack_3]:
		if attack != null:
			return attack
	return null

func get_primary_attack_range() -> int:
	var primary_attack = get_primary_attack()
	if primary_attack == null:
		return 1
	var attack_range_value: Variant = primary_attack.get("range")
	if attack_range_value is int or attack_range_value is float:
		return maxi(0, int(attack_range_value))
	return 1

func get_armor_type() -> int:
	if class_combat == null:
		return COMBAT_CONFIG.ArmorType.ARMORLESS
	var armor_type: Variant = class_combat.get("armor_type")
	if armor_type is int:
		return int(armor_type)
	return COMBAT_CONFIG.ArmorType.ARMORLESS

func apply_to_curr_health(new_value: int) -> void:
	curr_health = clampi(curr_health + new_value, 0, max_health)

func get_act_recovery_per_sec() -> float:
	return COMBAT_FORMULA.calc_act_recovery_per_sec(spd)
