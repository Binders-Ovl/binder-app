class_name CombatFormula
extends RefCounted

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")

static func calc_hit_chance(agi_atk: float, dex_def: float) -> float:
	var denominator: float = agi_atk + dex_def + COMBAT_CONFIG.HIT_NORMALIZER_OFFSET
	if denominator <= 0.0:
		return COMBAT_CONFIG.HIT_BASELINE
	var x: float = (agi_atk - dex_def) / denominator
	var hit: float
	if x < 0.0:
		hit = COMBAT_CONFIG.HIT_BASELINE - COMBAT_CONFIG.HIT_NEGATIVE_CURVE * pow(-x, 2.0)
	else:
		hit = COMBAT_CONFIG.HIT_BASELINE + COMBAT_CONFIG.HIT_POSITIVE_SCALE * x
	return clampf(hit, COMBAT_CONFIG.HIT_MIN, COMBAT_CONFIG.HIT_MAX)

static func calc_hit_chance_int(agi_atk: int, dex_def: int) -> int:
	return int(round(calc_hit_chance(float(agi_atk), float(dex_def))))

static func roll_hit(agi_atk: int, dex_def: int, rng_percent: int) -> bool:
	return rng_percent <= calc_hit_chance_int(agi_atk, dex_def)

static func calc_effective_pdef(vit_def: float, vit_scale: float) -> float:
	var raw_pdef: float = vit_def * vit_scale
	if raw_pdef <= 0.0:
		return 0.0
	return (raw_pdef * COMBAT_CONFIG.DEFENSE_K) / (raw_pdef + COMBAT_CONFIG.DEFENSE_K)

static func calc_effective_mdef(wis_def: float, wis_scale: float) -> float:
	var raw_mdef: float = wis_def * wis_scale
	if raw_mdef <= 0.0:
		return 0.0
	return (raw_mdef * COMBAT_CONFIG.DEFENSE_K) / (raw_mdef + COMBAT_CONFIG.DEFENSE_K)

static func calc_total_pdef(base_pdef: float, vit_def: float, vit_scale: float, pdef_mod: float) -> float:
	return base_pdef + (calc_effective_pdef(vit_def, vit_scale) * pdef_mod)

static func calc_total_mdef(base_mdef: float, wis_def: float, wis_scale: float, mdef_mod: float) -> float:
	return base_mdef + (calc_effective_mdef(wis_def, wis_scale) * mdef_mod)

static func calc_physical_attack_value(base_patk: float, str_atk: float, str_scale: float, type_mod: float, elevation_mod: float, pdmg_mod: float) -> float:
	return (base_patk + (str_atk * str_scale)) * type_mod * elevation_mod * pdmg_mod

static func calc_magic_attack_value(base_matk: float, int_atk: float, int_scale: float, type_mod: float, elevation_mod: float, mdmg_mod: float) -> float:
	return (base_matk + (int_atk * int_scale)) * type_mod * elevation_mod * mdmg_mod

static func calc_physical_damage(base_patk: float, str_atk: float, str_scale: float, type_mod: float, elevation_mod: float, pdmg_mod: float, base_pdef: float, vit_def: float, vit_scale: float, pdef_mod: float) -> int:
	var atk_value: float = calc_physical_attack_value(base_patk, str_atk, str_scale, type_mod, elevation_mod, pdmg_mod)
	var def_value: float = calc_total_pdef(base_pdef, vit_def, vit_scale, pdef_mod)
	return maxi(1, int(round(atk_value - def_value)))

static func calc_magic_damage(base_matk: float, int_atk: float, int_scale: float, type_mod: float, elevation_mod: float, mdmg_mod: float, base_mdef: float, wis_def: float, wis_scale: float, mdef_mod: float) -> int:
	var atk_value: float = calc_magic_attack_value(base_matk, int_atk, int_scale, type_mod, elevation_mod, mdmg_mod)
	var def_value: float = calc_total_mdef(base_mdef, wis_def, wis_scale, mdef_mod)
	return maxi(1, int(round(atk_value - def_value)))

static func calc_max_hp(vit: int, hp_per_vit: float = COMBAT_CONFIG.DEFAULT_HP_PER_VIT) -> int:
	return maxi(1, int(round(float(vit) * hp_per_vit)))

static func calc_max_mp(wis: int, mp_per_wis: float = COMBAT_CONFIG.DEFAULT_MP_PER_WIS) -> int:
	return maxi(0, int(round(float(wis) * mp_per_wis)))

static func calc_movement(sta: int, base_move: int = COMBAT_CONFIG.DEFAULT_BASE_MOVE) -> int:
	return base_move + int(round(float(sta) / COMBAT_CONFIG.MOVEMENT_STA_DIVISOR))

static func calc_jump_from_movement(movement: int) -> int:
	return int(floor(float(movement) / COMBAT_CONFIG.JUMP_DIVISOR))

static func calc_jump_from_sta(sta: int, base_move: int = COMBAT_CONFIG.DEFAULT_BASE_MOVE) -> int:
	return calc_jump_from_movement(calc_movement(sta, base_move))

static func get_type_mod(attack_type: int, armor_type: int) -> float:
	return COMBAT_CONFIG.get_type_mod(attack_type, armor_type)

static func calc_cdr_percent(dex_value: float, cap_percent: float = COMBAT_CONFIG.CDR_CAP_PERCENT, curve_constant: float = COMBAT_CONFIG.CDR_CURVE_CONSTANT) -> float:
	if dex_value <= 0.0:
		return 0.0
	var cdr: float = (dex_value / (dex_value + curve_constant)) * cap_percent
	return clampf(cdr, 0.0, cap_percent)

static func calc_crit_chance(agi_value: int, crit_baseline: float, crit_per_agi: float) -> float:
	return maxf(0.0, crit_baseline + float(agi_value) * crit_per_agi)

static func calc_act_recovery_per_sec(spd_value: int) -> float:
	return COMBAT_CONFIG.ACT_BASE_RECOVERY + float(spd_value) * COMBAT_CONFIG.ACT_SPD_MULTIPLIER

static func apply_guard_to_hit(hit_chance: float, guard_hit_mult: float, is_guarding: bool) -> float:
	if not is_guarding:
		return hit_chance
	return clampf(hit_chance * guard_hit_mult, COMBAT_CONFIG.HIT_MIN, COMBAT_CONFIG.HIT_MAX)

static func apply_guard_to_physical_damage(damage: int, guard_p_dmg_mult: float, is_guarding: bool) -> int:
	if not is_guarding:
		return damage
	return maxi(1, int(round(float(damage) * guard_p_dmg_mult)))

static func apply_guard_to_magic_damage(damage: int, guard_m_dmg_mult: float, is_guarding: bool) -> int:
	if not is_guarding:
		return damage
	return maxi(1, int(round(float(damage) * guard_m_dmg_mult)))
