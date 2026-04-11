class_name ClassCombatResource
extends Resource

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")

@export var class_name_label: String = ""
@export_enum("Armorless", "Tunic", "Light", "Medium", "Heavy") var armor_type: int = COMBAT_CONFIG.ArmorType.ARMORLESS

@export_category("Scaling")
@export var hp_per_vit: float = COMBAT_CONFIG.DEFAULT_HP_PER_VIT
@export var mp_per_wis: float = COMBAT_CONFIG.DEFAULT_MP_PER_WIS
@export var str_scale: float = COMBAT_CONFIG.DEFAULT_STR_SCALE
@export var int_scale: float = COMBAT_CONFIG.DEFAULT_INT_SCALE
@export var vit_scale: float = COMBAT_CONFIG.DEFAULT_VIT_SCALE
@export var wis_scale: float = COMBAT_CONFIG.DEFAULT_WIS_SCALE

@export_category("Defense")
@export var base_pdef: float = 0.0
@export var base_mdef: float = 0.0
@export var pdef_mod: float = 1.0
@export var mdef_mod: float = 1.0

@export_category("Crit")
@export var crit_baseline: float = COMBAT_CONFIG.DEFAULT_CRIT_BASELINE
@export var crit_per_agi: float = COMBAT_CONFIG.DEFAULT_CRIT_PER_AGI
@export var crit_damage_mult: float = COMBAT_CONFIG.DEFAULT_CRIT_DAMAGE_MULT

func validate() -> Array[String]:
	var errors: Array[String] = []
	if hp_per_vit <= 0.0:
		errors.append("ClassCombatResource.hp_per_vit must be > 0.")
	if mp_per_wis < 0.0:
		errors.append("ClassCombatResource.mp_per_wis must be >= 0.")
	if str_scale < 0.0 or int_scale < 0.0 or vit_scale < 0.0 or wis_scale < 0.0:
		errors.append("ClassCombatResource scaling values cannot be negative.")
	if pdef_mod < 0.0 or mdef_mod < 0.0:
		errors.append("ClassCombatResource defense modifiers cannot be negative.")
	if crit_per_agi < 0.0:
		errors.append("ClassCombatResource.crit_per_agi cannot be negative.")
	if crit_damage_mult < 1.0:
		errors.append("ClassCombatResource.crit_damage_mult should be >= 1.0.")
	return errors

