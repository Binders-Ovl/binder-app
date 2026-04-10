class_name TacticsParticipantCombatService
extends RefCounted

const COMBAT_CONFIG = preload("res://data/models/world/combat/config/combat_config.gd")
const COMBAT_FORMULA = preload("res://data/models/world/combat/formula/combat_formula.gd")
const ATTACK_AREA_SERVICE = preload("res://data/models/world/combat/area/service.gd")

var res: TacticsParticipantResource
var camera: TacticsCameraResource
var controls: TacticsControlsResource
var area_service
var _rng_seeded: bool = false

func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	camera = _camera
	controls = _controls
	area_service = ATTACK_AREA_SERVICE.new()


func attack_pawn(delta: float, is_player: bool) -> void:
	_seed_rng_once()

	var acting_pawn: TacticsPawn = res.curr_pawn
	if not acting_pawn or not is_instance_valid(acting_pawn):
		_reset_to_selection()
		return

	var attack_profile = res.selected_attack
	if attack_profile == null:
		res.stage = res.STAGE_SELECT_ATTACK_TYPE if is_player else res.STAGE_SELECT_PAWN
		return

	var datum_tile: TacticsTile = _resolve_attack_datum_tile(acting_pawn, attack_profile)
	if datum_tile == null:
		res.stage = res.STAGE_SELECT_ATTACK_TARGET if is_player else res.STAGE_SELECT_PAWN
		return

	var visual_target: TacticsPawn = _resolve_visual_target(datum_tile)
	if visual_target and (not is_instance_valid(visual_target) or not visual_target.is_alive()):
		visual_target = null

	if is_zero_approx(acting_pawn.res.wait_delay):
		var attack_cost: float = attack_profile.get_effective_act_cost(float(TacticsConfig.action_cost.attack))
		if not acting_pawn.spend_act(attack_cost):
			res.stage = res.STAGE_SHOW_ACTIONS if is_player else res.STAGE_SELECT_PAWN
			return

	var hit_frame_time: float = TacticsPawnResource.MIN_TIME_FOR_ATTACK / 4.0
	var hit_now: bool = acting_pawn.res.wait_delay <= hit_frame_time and (acting_pawn.res.wait_delay + delta) > hit_frame_time

	if not acting_pawn.attack_target_pawn(visual_target, delta, datum_tile.global_position):
		if hit_now:
			_apply_attack_area_damage(acting_pawn, datum_tile, attack_profile)
		return

	if hit_now:
		_apply_attack_area_damage(acting_pawn, datum_tile, attack_profile)
	else:
		acting_pawn.res.wait_delay = 0.0
		acting_pawn.res.set_attacking(false)
		acting_pawn.refresh_action_state()

	res.attackable_pawn = null
	res.selected_attack_datum = null
	if res.display_opponent_stats:
		res.display_opponent_stats = false

	controls.set_actions_menu_visibility(false, visual_target)
	controls.set_attack_types_menu_visibility(false, visual_target)
	camera.target = acting_pawn

	if not acting_pawn.can_act() or not is_player:
		res.stage = res.STAGE_SELECT_PAWN
	else:
		res.stage = res.STAGE_SHOW_ACTIONS
	res.clear_attack_selection()


func _resolve_visual_target(datum_tile: TacticsTile) -> TacticsPawn:
	if res.attackable_pawn and is_instance_valid(res.attackable_pawn) and res.attackable_pawn.is_alive():
		return res.attackable_pawn
	if datum_tile == null:
		return null
	return datum_tile.get_tile_occupier() as TacticsPawn


func _resolve_attack_datum_tile(attacker: TacticsPawn, attack_profile) -> TacticsTile:
	if attack_profile == null or attack_profile.area == null:
		return null
	if int(attack_profile.area.get("targeting_mode")) == COMBAT_CONFIG.AreaTargetingMode.SELF_CENTERED:
		return attacker.get_tile()
	if res.selected_attack_datum and is_instance_valid(res.selected_attack_datum):
		return res.selected_attack_datum
	if res.attackable_pawn and is_instance_valid(res.attackable_pawn):
		return res.attackable_pawn.get_tile()
	return null


func _apply_attack_area_damage(attacker: TacticsPawn, datum_tile: TacticsTile, attack_profile) -> void:
	var targets: Array[TacticsPawn] = _resolve_affected_targets(attacker, datum_tile, attack_profile)
	if targets.is_empty():
		return
	for target: TacticsPawn in targets:
		var result: Dictionary = _compute_attack_result(attacker, target, attack_profile)
		if not result.get("hit", false):
			continue
		var damage: int = int(result.get("damage", 0))
		if damage <= 0:
			continue
		target.stats.apply_to_curr_health(-damage)


func _resolve_affected_targets(attacker: TacticsPawn, datum_tile: TacticsTile, attack_profile) -> Array[TacticsPawn]:
	var targets: Array[TacticsPawn] = []
	var arena_node: TacticsArena = attacker.get_node_or_null("%TacticsArena")
	if not arena_node:
		return targets

	var affected_tiles: Array[TacticsTile] = area_service.resolve_affected_tiles(attacker, datum_tile, attack_profile, arena_node)
	var visited: Dictionary = {}
	for tile: TacticsTile in affected_tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		var pawn: TacticsPawn = tile.get_tile_occupier() as TacticsPawn
		if pawn == null or not is_instance_valid(pawn) or not pawn.is_alive():
			continue
		if pawn == attacker:
			continue
		if not attack_profile.can_target_flying and pawn.stats.can_fly:
			continue
		var key: int = pawn.get_instance_id()
		if visited.has(key):
			continue
		visited[key] = true
		targets.append(pawn)
	return targets


func _compute_attack_result(attacker: TacticsPawn, target: TacticsPawn, attack_profile) -> Dictionary:
	var attacker_stats: Stats = attacker.stats
	var target_stats: Stats = target.stats
	var attacker_class = attacker_stats.class_combat
	var target_class = target_stats.class_combat

	var hit_roll: int = randi_range(1, 100)
	var did_hit: bool = COMBAT_FORMULA.roll_hit(attacker_stats.agi, target_stats.dex, hit_roll)
	if not did_hit:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
		}

	var armor_type: int = target_stats.get_armor_type()
	var type_mod: float = COMBAT_FORMULA.get_type_mod(attack_profile.attack_type, armor_type)
	var damage: int
	if attack_profile.is_magic:
		damage = COMBAT_FORMULA.calc_magic_damage(
			attack_profile.base_attack,
			float(attacker_stats.intt),
			float(attacker_class.get("int_scale")) if attacker_class else COMBAT_CONFIG.DEFAULT_INT_SCALE,
			type_mod,
			attack_profile.elevation_modifier,
			attack_profile.damage_modifier,
			float(target_class.get("base_mdef")) if target_class else 0.0,
			float(target_stats.wis),
			float(target_class.get("wis_scale")) if target_class else COMBAT_CONFIG.DEFAULT_WIS_SCALE,
			float(target_class.get("mdef_mod")) if target_class else 1.0
		)
	else:
		damage = COMBAT_FORMULA.calc_physical_damage(
			attack_profile.base_attack,
			float(attacker_stats.str),
			float(attacker_class.get("str_scale")) if attacker_class else COMBAT_CONFIG.DEFAULT_STR_SCALE,
			type_mod,
			attack_profile.elevation_modifier,
			attack_profile.damage_modifier,
			float(target_class.get("base_pdef")) if target_class else 0.0,
			float(target_stats.vit),
			float(target_class.get("vit_scale")) if target_class else COMBAT_CONFIG.DEFAULT_VIT_SCALE,
			float(target_class.get("pdef_mod")) if target_class else 1.0
		)

	var crit_chance: float = COMBAT_FORMULA.calc_crit_chance(
		attacker_stats.agi,
		float(attacker_class.get("crit_baseline")) if attacker_class else COMBAT_CONFIG.DEFAULT_CRIT_BASELINE,
		float(attacker_class.get("crit_per_agi")) if attacker_class else COMBAT_CONFIG.DEFAULT_CRIT_PER_AGI
	)
	var crit_roll: float = randf_range(0.0, 100.0)
	var did_crit: bool = crit_roll <= crit_chance
	if did_crit:
		var crit_mult: float = float(attacker_class.get("crit_damage_mult")) if attacker_class else COMBAT_CONFIG.DEFAULT_CRIT_DAMAGE_MULT
		damage = maxi(1, int(round(float(damage) * crit_mult)))

	return {
		"hit": true,
		"crit": did_crit,
		"damage": damage,
	}


func _seed_rng_once() -> void:
	if _rng_seeded:
		return
	randomize()
	_rng_seeded = true


func _reset_to_selection() -> void:
	res.attackable_pawn = null
	res.clear_attack_selection()
	res.stage = res.STAGE_SELECT_PAWN
