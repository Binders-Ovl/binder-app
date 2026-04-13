class_name TacticsParticipantCombatService
extends RefCounted

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")
const COMBAT_FORMULA = preload("res://data/models/world/combat/formula/combat_formula.gd")
const ATTACK_AREA_SERVICE = preload("res://data/models/world/combat/area/service.gd")

var res: TacticsParticipantResource
var camera: TacticsCameraResource
var controls: TacticsControlsResource
var area_service
var _rng_seeded: bool = false
var _pending_attack_target_ids: Array[int] = []
var _feedback_layer: Node = null

const TILE_OCCUPANCY_TOLERANCE: float = 0.6

func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	camera = _camera
	controls = _controls
	area_service = ATTACK_AREA_SERVICE.new()


func attack_pawn(delta: float, is_player: bool) -> void:
	_seed_rng_once()

	var acting_pawn: TacticsPawn = res.curr_pawn
	if not acting_pawn or not is_instance_valid(acting_pawn):
		_clear_pending_attack_targets()
		_reset_to_selection()
		return

	var attack_profile: AttackProfileResource = res.selected_attack
	if attack_profile == null:
		_clear_pending_attack_targets()
		push_error("TacticsParticipantCombatService.attack_pawn: selected_attack is null.")
		res.stage = res.STAGE_SELECT_ATTACK_TYPE if is_player else res.STAGE_SELECT_PAWN
		return
	var attack_errors: Array[String] = attack_profile.validate()
	if not attack_errors.is_empty():
		_clear_pending_attack_targets()
		push_error("TacticsParticipantCombatService.attack_pawn: invalid selected attack profile: %s" % "; ".join(attack_errors))
		res.stage = res.STAGE_SELECT_ATTACK_TYPE if is_player else res.STAGE_SELECT_PAWN
		return

	var datum_tile: TacticsTile = _resolve_attack_datum_tile(acting_pawn, attack_profile)
	if datum_tile == null:
		_clear_pending_attack_targets()
		res.stage = res.STAGE_SELECT_ATTACK_TARGET if is_player else res.STAGE_SELECT_PAWN
		return

	var visual_target: TacticsPawn = _resolve_visual_target(datum_tile)
	if visual_target and (not is_instance_valid(visual_target) or not visual_target.is_alive()):
		visual_target = null

	if is_zero_approx(acting_pawn.res.wait_delay):
		var attack_cost: float = attack_profile.get_effective_act_cost(float(TacticsConfig.action_cost.attack))
		if not acting_pawn.spend_act(attack_cost):
			_clear_pending_attack_targets()
			res.stage = res.STAGE_SHOW_ACTIONS if is_player else res.STAGE_SELECT_PAWN
			return
		acting_pawn.break_guard()
		_pending_attack_target_ids = _snapshot_affected_target_ids(acting_pawn, datum_tile, attack_profile)

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
	_clear_pending_attack_targets()

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


func _resolve_attack_datum_tile(attacker: TacticsPawn, attack_profile: AttackProfileResource) -> TacticsTile:
	if attack_profile == null or attack_profile.area == null:
		return null
	if int(attack_profile.area.get("targeting_mode")) == COMBAT_CONFIG.AreaTargetingMode.SELF_CENTERED:
		return attacker.get_tile()
	if res.selected_attack_datum and is_instance_valid(res.selected_attack_datum):
		return res.selected_attack_datum
	if res.attackable_pawn and is_instance_valid(res.attackable_pawn):
		return res.attackable_pawn.get_tile()
	return null


func _apply_attack_area_damage(attacker: TacticsPawn, datum_tile: TacticsTile, attack_profile: AttackProfileResource) -> void:
	var targets: Array[TacticsPawn] = _resolve_pending_targets(attacker)
	if targets.is_empty():
		targets = _resolve_affected_targets(attacker, datum_tile, attack_profile)
	if targets.is_empty():
		return
	var feedback_layer: Node = _resolve_feedback_layer(attacker)
	for target: TacticsPawn in targets:
		var result: Dictionary = resolve_attack_result(attacker, target, attack_profile)
		apply_attack_outcome(attacker, target, result, feedback_layer)


func _resolve_affected_targets(attacker: TacticsPawn, datum_tile: TacticsTile, attack_profile: AttackProfileResource) -> Array[TacticsPawn]:
	var targets: Array[TacticsPawn] = []
	var arena_node: TacticsArena = attacker.get_node_or_null("%TacticsArena")
	if not arena_node:
		return targets

	var affected_tiles: Array[TacticsTile] = area_service.resolve_affected_tiles(attacker, datum_tile, attack_profile, arena_node)
	var visited: Dictionary = {}
	for tile: TacticsTile in affected_tiles:
		if tile == null or not is_instance_valid(tile):
			continue
		for pawn: TacticsPawn in _get_attack_targets_for_tile(attacker, tile, arena_node):
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


func _snapshot_affected_target_ids(attacker: TacticsPawn, datum_tile: TacticsTile, attack_profile: AttackProfileResource) -> Array[int]:
	var ids: Array[int] = []
	for target: TacticsPawn in _resolve_affected_targets(attacker, datum_tile, attack_profile):
		if target and is_instance_valid(target) and target.is_alive():
			ids.append(target.get_instance_id())
	return ids


func _resolve_pending_targets(attacker: TacticsPawn) -> Array[TacticsPawn]:
	var targets: Array[TacticsPawn] = []
	if _pending_attack_target_ids.is_empty():
		return targets
	var visited: Dictionary = {}
	for id_value: int in _pending_attack_target_ids:
		var pawn: TacticsPawn = _find_pawn_by_instance_id(attacker, id_value)
		if pawn == null or not is_instance_valid(pawn) or not pawn.is_alive():
			continue
		var key: int = pawn.get_instance_id()
		if visited.has(key):
			continue
		visited[key] = true
		targets.append(pawn)
	return targets


func _get_attack_targets_for_tile(attacker: TacticsPawn, tile: TacticsTile, arena_node: TacticsArena) -> Array[TacticsPawn]:
	var targets: Array[TacticsPawn] = []
	var visited: Dictionary = {}

	var occupier: TacticsPawn = tile.get_tile_occupier() as TacticsPawn
	if occupier and is_instance_valid(occupier) and occupier.is_alive():
		targets.append(occupier)
		visited[occupier.get_instance_id()] = true

	if arena_node and arena_node.res:
		var owner_id: int = int(arena_node.res.move_tile_reservations.get(tile.get_instance_id(), 0))
		if owner_id != 0:
			var reserved_owner: TacticsPawn = _find_pawn_by_instance_id(attacker, owner_id)
			if reserved_owner and is_instance_valid(reserved_owner) and reserved_owner.is_alive():
				var reserved_key: int = reserved_owner.get_instance_id()
				if not visited.has(reserved_key):
					targets.append(reserved_owner)
					visited[reserved_key] = true

	for pawn: TacticsPawn in _get_all_living_pawns(attacker):
		if pawn == null or not is_instance_valid(pawn) or not pawn.is_alive():
			continue
		var key: int = pawn.get_instance_id()
		if visited.has(key):
			continue
		var pawn_tile: TacticsTile = pawn.get_tile()
		if pawn_tile == tile or pawn.global_position.distance_to(tile.global_position) <= TILE_OCCUPANCY_TOLERANCE:
			targets.append(pawn)
			visited[key] = true

	return targets


func _get_all_living_pawns(attacker: TacticsPawn) -> Array[TacticsPawn]:
	var pawns: Array[TacticsPawn] = []
	if attacker == null or not is_instance_valid(attacker):
		return pawns
	var scene: Node = attacker.get_tree().current_scene
	if scene == null:
		return pawns
	for node: Node in scene.find_children("*", "TacticsPawn", true, false):
		var pawn: TacticsPawn = node as TacticsPawn
		if pawn and is_instance_valid(pawn) and pawn.is_alive():
			pawns.append(pawn)
	return pawns


func _find_pawn_by_instance_id(attacker: TacticsPawn, pawn_id: int) -> TacticsPawn:
	if pawn_id == 0:
		return null
	for pawn: TacticsPawn in _get_all_living_pawns(attacker):
		if pawn.get_instance_id() == pawn_id:
			return pawn
	return null


func _compute_attack_result(attacker: TacticsPawn, target: TacticsPawn, attack_profile: AttackProfileResource) -> Dictionary:
	var attacker_stats: Stats = attacker.stats
	var target_stats: Stats = target.stats
	var attacker_class = attacker_stats.class_combat
	var target_class = target_stats.class_combat

	var hit_chance: float = COMBAT_FORMULA.calc_hit_chance(float(attacker_stats.agi), float(target_stats.dex))
	hit_chance = COMBAT_FORMULA.apply_guard_to_hit(
		hit_chance,
		float(target_class.guard_hit_mult) if target_class else 1.0,
		_is_target_guarding(target)
	)
	var hit_roll: int = randi_range(1, 100)
	var did_hit: bool = hit_roll <= int(round(hit_chance))
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

	var guarded_hit: bool = damage > 0 and _is_target_guarding(target)
	if guarded_hit:
		if attack_profile.is_magic:
			damage = COMBAT_FORMULA.apply_guard_to_magic_damage(
				damage,
				float(target_class.guard_m_dmg_mult) if target_class else 1.0,
				true
			)
		else:
			damage = COMBAT_FORMULA.apply_guard_to_physical_damage(
				damage,
				float(target_class.guard_p_dmg_mult) if target_class else 1.0,
				true
			)

	return {
		"hit": true,
		"crit": did_crit,
		"damage": damage,
		"guarded": guarded_hit,
	}


func resolve_attack_result(attacker: TacticsPawn, target: TacticsPawn, attack_profile: AttackProfileResource) -> Dictionary:
	return _compute_attack_result(attacker, target, attack_profile)


func apply_attack_outcome(attacker: TacticsPawn, target: TacticsPawn, result: Dictionary, feedback_layer: Node = null) -> void:
	var layer: Node = feedback_layer if feedback_layer else _resolve_feedback_layer(attacker)
	var resolved_result: Dictionary = result.duplicate()
	var did_hit: bool = bool(resolved_result.get("hit", false))
	var guarded_hit: bool = did_hit and bool(resolved_result.get("guarded", false))

	var payload: Dictionary = _build_feedback_payload(attacker, target, resolved_result)
	if layer and layer.has_method("show_result"):
		layer.call("show_result", payload)

	if did_hit:
		var damage: int = int(resolved_result.get("damage", 0))
		if damage > 0:
			target.stats.apply_to_curr_health(-damage)


func _build_feedback_payload(attacker: TacticsPawn, target: TacticsPawn, result: Dictionary) -> Dictionary:
	# README-INFO: Payload `kind`/`text` is the extension seam for future feedback placeholders
	# (for example mana heal/damage variants) while keeping combat authority centralized here.
	var did_hit: bool = bool(result.get("hit", false))
	var did_crit: bool = did_hit and bool(result.get("crit", false))
	var guarded_hit: bool = did_hit and bool(result.get("guarded", false))
	var damage: int = int(result.get("damage", 0))
	var kind: String = "miss"
	if did_hit:
		kind = "guard" if guarded_hit else "damage"
	var visual_kind: String = kind
	if did_crit and not guarded_hit:
		visual_kind = "crit"
	var popup_text: String = str(maxi(0, damage)) if did_hit else "MISS"
	var anchor_position: Vector3 = target.get_damage_anchor_position()

	return {
		"target": target,
		"attacker": attacker,
		"hit": did_hit,
		"crit": did_crit,
		"damage": damage,
		"world_position": anchor_position,
		"kind": kind,
		"visual_kind": visual_kind,
		"guarded": guarded_hit,
		"text": popup_text,
	}


func _is_target_guarding(target: TacticsPawn) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return target.is_guarding()


func _resolve_feedback_layer(attacker: TacticsPawn) -> Node:
	if _feedback_layer and is_instance_valid(_feedback_layer):
		return _feedback_layer
	if attacker == null or not is_instance_valid(attacker):
		return null

	var arena_node: TacticsArena = attacker.get_node_or_null("%TacticsArena")
	if arena_node and is_instance_valid(arena_node):
		var level_root: Node = arena_node.get_parent()
		if level_root:
			var node: Node = level_root.get_node_or_null("CombatFeedbackLayer")
			if node and node.has_method("show_result"):
				_feedback_layer = node
				return _feedback_layer

	var scene: Node = attacker.get_tree().current_scene
	if scene:
		var found: Node = scene.find_child("CombatFeedbackLayer", true, false)
		if found and found.has_method("show_result"):
			_feedback_layer = found
			return _feedback_layer
	return null


func _seed_rng_once() -> void:
	if _rng_seeded:
		return
	randomize()
	_rng_seeded = true


func _reset_to_selection() -> void:
	_clear_pending_attack_targets()
	res.attackable_pawn = null
	res.clear_attack_selection()
	res.stage = res.STAGE_SELECT_PAWN


func _clear_pending_attack_targets() -> void:
	_pending_attack_target_ids.clear()
