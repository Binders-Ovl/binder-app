class_name StatsResource
extends Resource

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")
const COMBAT_FORMULA = preload("res://data/models/world/combat/formula/combat_formula.gd")

@export var override_name: String = ""
@export var expertise: String = ""

@export_category("Init")
@export_enum("Tank", "Flank", "Physical", "Distance", "Support") var strategy: int = 0
@export var level: int = 1
@export_file("*.png") var sprite: String = "res://assets/textures/actor/"

@export_category("Core Stats")
@export var str: int = 10
@export var intt: int = 10
@export var agi: int = 10
@export var dex: int = 10
@export var vit: int = 10
@export var wis: int = 10
@export var spd: int = 10
@export var sta: int = 10

@export_category("Class")
@export var class_combat: ClassCombatResource
@export var base_move: int = COMBAT_CONFIG.DEFAULT_BASE_MOVE
@export var can_fly: bool = false

@export_category("Attacks")
@export var attack_1: AttackProfileResource
@export var attack_2: AttackProfileResource
@export var attack_3: AttackProfileResource

@export_category("Skills")
@export var skill_library: SkillLibraryResource

func get_movement() -> int:
	return COMBAT_FORMULA.calc_movement(sta, base_move)

func get_jump() -> int:
	return COMBAT_FORMULA.calc_jump_from_movement(get_movement())

func get_max_health() -> int:
	if class_combat == null:
		return COMBAT_FORMULA.calc_max_hp(vit)
	var hp_per_vit: float = COMBAT_CONFIG.DEFAULT_HP_PER_VIT
	var value: Variant = class_combat.get("hp_per_vit")
	if value is int or value is float:
		hp_per_vit = float(value)
	return COMBAT_FORMULA.calc_max_hp(vit, hp_per_vit)

func get_max_mana() -> int:
	if class_combat == null:
		return COMBAT_FORMULA.calc_max_mp(wis)
	var mp_per_wis: float = COMBAT_CONFIG.DEFAULT_MP_PER_WIS
	var value: Variant = class_combat.get("mp_per_wis")
	if value is int or value is float:
		mp_per_wis = float(value)
	return COMBAT_FORMULA.calc_max_mp(wis, mp_per_wis)

func validate() -> Array[String]:
	var errors: Array[String] = []
	if base_move < 0:
		errors.append("StatsResource.base_move cannot be negative.")
	if level < 1:
		errors.append("StatsResource.level should be >= 1.")
	if class_combat == null:
		errors.append("StatsResource.class_combat must be assigned.")
	else:
		var class_errors: Array[String] = class_combat.validate()
		for class_error: String in class_errors:
			errors.append("StatsResource.class_combat -> %s" % class_error)

	for idx: int in range(3):
		var attack: AttackProfileResource = [attack_1, attack_2, attack_3][idx]
		if attack == null:
			continue
		var attack_errors: Array[String] = attack.validate()
		for attack_error: String in attack_errors:
			errors.append("StatsResource.attack_%d -> %s" % [idx + 1, attack_error])

	if skill_library != null:
		var skill_errors: Array[String] = skill_library.validate()
		for skill_error: String in skill_errors:
			errors.append("StatsResource.skill_library -> %s" % skill_error)

	return errors
