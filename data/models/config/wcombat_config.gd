class_name WCombatConfig
extends RefCounted

const HIT_BASELINE: float = 72.0
const HIT_MIN: float = 15.0
const HIT_MAX: float = 93.0
const HIT_NEGATIVE_CURVE: float = 80.0
const HIT_POSITIVE_SCALE: float = 24.0
const HIT_NORMALIZER_OFFSET: float = 20.0

const DEFAULT_CRIT_BASELINE: float = 3.0
const DEFAULT_CRIT_PER_AGI: float = 0.15
const DEFAULT_CRIT_DAMAGE_MULT: float = 1.5

const DEFAULT_STR_SCALE: float = 0.8
const DEFAULT_INT_SCALE: float = 0.8
const DEFAULT_VIT_SCALE: float = 1.2
const DEFAULT_WIS_SCALE: float = 1.2
const DEFENSE_K: float = 50.0

const DEFAULT_HP_PER_VIT: float = 8.0
const DEFAULT_MP_PER_WIS: float = 5.0
const DEFAULT_BASE_MOVE: int = 2
const MOVEMENT_STA_DIVISOR: float = 23.0
const JUMP_DIVISOR: float = 2.0

const ACT_BASE_RECOVERY: float = 2.5
const ACT_SPD_MULTIPLIER: float = 1.35

const CDR_CAP_PERCENT: float = 33.0
const CDR_CURVE_CONSTANT: float = 70.0

const DEFAULT_ATTACK_ACT_COST: float = 30.0

enum AttackType { BLUNT, SLASH, STAB, PIERCE, MAGIC, IMPACT, HACK }
enum ArmorType { ARMORLESS, TUNIC, LIGHT, MEDIUM, HEAVY }
enum AttackCostMode { DEFAULT, ABSOLUTE, MULTIPLIER }
enum AreaTargetingMode { TARGET_DATUM, FORWARD_FROM_USER, SELF_CENTERED }
enum AttackRangePattern { DIAMOND, CROSS, SPREAD_DIAG }

const TYPE_MOD_TABLE := {
	AttackType.BLUNT: { ArmorType.ARMORLESS: 0.95, ArmorType.TUNIC: 1.00, ArmorType.LIGHT: 1.00, ArmorType.MEDIUM: 1.10, ArmorType.HEAVY: 1.15 },
	AttackType.SLASH: { ArmorType.ARMORLESS: 1.10, ArmorType.TUNIC: 1.10, ArmorType.LIGHT: 1.05, ArmorType.MEDIUM: 0.95, ArmorType.HEAVY: 0.85 },
	AttackType.STAB: { ArmorType.ARMORLESS: 1.00, ArmorType.TUNIC: 1.00, ArmorType.LIGHT: 1.05, ArmorType.MEDIUM: 1.10, ArmorType.HEAVY: 0.95 },
	AttackType.PIERCE: { ArmorType.ARMORLESS: 1.00, ArmorType.TUNIC: 1.05, ArmorType.LIGHT: 1.10, ArmorType.MEDIUM: 1.05, ArmorType.HEAVY: 0.90 },
	AttackType.MAGIC: { ArmorType.ARMORLESS: 1.00, ArmorType.TUNIC: 1.00, ArmorType.LIGHT: 1.00, ArmorType.MEDIUM: 1.00, ArmorType.HEAVY: 1.00 },
	AttackType.IMPACT: { ArmorType.ARMORLESS: 1.05, ArmorType.TUNIC: 1.05, ArmorType.LIGHT: 1.00, ArmorType.MEDIUM: 1.10, ArmorType.HEAVY: 1.10 },
	AttackType.HACK: { ArmorType.ARMORLESS: 1.55, ArmorType.TUNIC: 1.35, ArmorType.LIGHT: 1.20, ArmorType.MEDIUM: 1.10, ArmorType.HEAVY: 0.80 },
}

static func get_type_mod(attack_type: int, armor_type: int) -> float:
	if not TYPE_MOD_TABLE.has(attack_type):
		return 1.0
	var row: Dictionary = TYPE_MOD_TABLE[attack_type]
	if not row.has(armor_type):
		return 1.0
	return float(row[armor_type])
