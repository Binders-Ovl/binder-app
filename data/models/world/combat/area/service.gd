class_name TacticsAttackAreaService
extends RefCounted
## Runtime resolver for authored attack-area patterns.

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")

const DIR_NORTH: Vector2i = Vector2i(0, -1)
const DIR_SOUTH: Vector2i = Vector2i(0, 1)
const DIR_EAST: Vector2i = Vector2i(1, 0)
const DIR_WEST: Vector2i = Vector2i(-1, 0)
const CARDINAL_DOT_MIN: float = 0.45
const MAX_STEP_HEIGHT_SCAN: float = 9999.0

func resolve_affected_tiles(attacker: TacticsPawn, datum_tile: TacticsTile, attack_profile: Resource, arena: TacticsArena) -> Array[TacticsTile]:
	var tiles: Array[TacticsTile] = []
	if not attacker or not is_instance_valid(attacker):
		return tiles
	if not attack_profile:
		push_error("TacticsAttackAreaService.resolve_affected_tiles: attack_profile is null.")
		return tiles
	if not arena or not is_instance_valid(arena):
		return tiles

	if not (attack_profile is AttackProfileResource):
		push_error("TacticsAttackAreaService.resolve_affected_tiles: attack_profile must be AttackProfileResource.")
		return tiles
	var attack: AttackProfileResource = attack_profile as AttackProfileResource
	var attack_errors: Array[String] = attack.validate()
	if not attack_errors.is_empty():
		push_error("Invalid AttackProfileResource: %s" % "; ".join(attack_errors))
		return tiles
	if attack.area == null:
		return tiles

	var area: AttackAreaResource = attack.area
	var effective_datum: TacticsTile = _resolve_effective_datum(attacker, datum_tile, area)
	if effective_datum == null:
		return tiles

	var forward: Vector2i = resolve_forward_direction(attacker, effective_datum, area)
	var offsets: Array = area.get("affected_offsets") if area != null else []
	var visited: Dictionary = {}
	for offset_value: Variant in offsets:
		if not (offset_value is Vector2i):
			continue
		var local_offset: Vector2i = offset_value
		var rotated: Vector2i = rotate_offset(local_offset, forward)
		var tile: TacticsTile = _project_tile_from_offset(effective_datum, rotated)
		if tile == null:
			continue
		var key: int = tile.get_instance_id()
		if visited.has(key):
			continue
		visited[key] = true
		tiles.append(tile)
	return tiles

func resolve_forward_direction(attacker: TacticsPawn, datum_tile: TacticsTile, area: AttackAreaResource) -> Vector2i:
	if area == null:
		return DIR_NORTH
	var targeting_mode: int = int(area.get("targeting_mode"))
	match targeting_mode:
		COMBAT_CONFIG.AreaTargetingMode.SELF_CENTERED:
			return _resolve_from_pawn_facing(attacker)
		COMBAT_CONFIG.AreaTargetingMode.FORWARD_FROM_USER, COMBAT_CONFIG.AreaTargetingMode.TARGET_DATUM:
			return _resolve_from_attacker_to_datum(attacker, datum_tile)
		_:
			return _resolve_from_attacker_to_datum(attacker, datum_tile)

func rotate_offset(local_offset: Vector2i, forward: Vector2i) -> Vector2i:
	match forward:
		DIR_NORTH:
			return local_offset
		DIR_EAST:
			return Vector2i(-local_offset.y, local_offset.x)
		DIR_SOUTH:
			return Vector2i(-local_offset.x, -local_offset.y)
		DIR_WEST:
			return Vector2i(local_offset.y, -local_offset.x)
		_:
			return local_offset

func _resolve_effective_datum(attacker: TacticsPawn, datum_tile: TacticsTile, area: AttackAreaResource) -> TacticsTile:
	if attacker == null or not is_instance_valid(attacker):
		return null
	if area != null and int(area.get("targeting_mode")) == COMBAT_CONFIG.AreaTargetingMode.SELF_CENTERED:
		return attacker.get_tile()
	return datum_tile

func _resolve_from_attacker_to_datum(attacker: TacticsPawn, datum_tile: TacticsTile) -> Vector2i:
	if attacker == null or not is_instance_valid(attacker) or datum_tile == null:
		return _resolve_from_pawn_facing(attacker)
	var attacker_tile: TacticsTile = attacker.get_tile()
	if attacker_tile == null:
		return _resolve_from_pawn_facing(attacker)
	var delta: Vector3 = datum_tile.global_position - attacker_tile.global_position
	var flat: Vector2 = Vector2(delta.x, delta.z)
	if flat.length() < 0.01:
		return _resolve_from_pawn_facing(attacker)
	if absf(flat.x) > absf(flat.y):
		return DIR_EAST if flat.x > 0.0 else DIR_WEST
	return DIR_SOUTH if flat.y > 0.0 else DIR_NORTH

func _resolve_from_pawn_facing(attacker: TacticsPawn) -> Vector2i:
	if attacker == null or not is_instance_valid(attacker):
		return DIR_NORTH
	var forward3: Vector3 = -attacker.global_transform.basis.z
	var flat: Vector2 = Vector2(forward3.x, forward3.z)
	if flat.length() < 0.01:
		return DIR_NORTH
	if absf(flat.x) > absf(flat.y):
		return DIR_EAST if flat.x > 0.0 else DIR_WEST
	return DIR_SOUTH if flat.y > 0.0 else DIR_NORTH

func _project_tile_from_offset(origin_tile: TacticsTile, offset: Vector2i) -> TacticsTile:
	if origin_tile == null or not is_instance_valid(origin_tile):
		return null
	var current: TacticsTile = origin_tile
	var x_steps: int = abs(offset.x)
	var x_dir: Vector2i = DIR_EAST if offset.x >= 0 else DIR_WEST
	for _i: int in range(x_steps):
		current = _step_tile_cardinal(current, x_dir)
		if current == null:
			return null

	var y_steps: int = abs(offset.y)
	var y_dir: Vector2i = DIR_SOUTH if offset.y >= 0 else DIR_NORTH
	for _j: int in range(y_steps):
		current = _step_tile_cardinal(current, y_dir)
		if current == null:
			return null
	return current


func _step_tile_cardinal(from_tile: TacticsTile, cardinal: Vector2i) -> TacticsTile:
	if from_tile == null or not is_instance_valid(from_tile):
		return null
	var dir2: Vector2 = Vector2(float(cardinal.x), float(cardinal.y)).normalized()
	var best_tile: TacticsTile = null
	var best_dot: float = -INF
	for candidate_value: Variant in from_tile.get_neighbors(MAX_STEP_HEIGHT_SCAN):
		if not (candidate_value is TacticsTile):
			continue
		var candidate: TacticsTile = candidate_value as TacticsTile
		if candidate == null or not is_instance_valid(candidate):
			continue
		var delta: Vector3 = candidate.global_position - from_tile.global_position
		var flat: Vector2 = Vector2(delta.x, delta.z)
		if flat.length() < 0.001:
			continue
		var dot_value: float = flat.normalized().dot(dir2)
		if dot_value > best_dot:
			best_dot = dot_value
			best_tile = candidate
	if best_dot < CARDINAL_DOT_MIN:
		return null
	return best_tile
