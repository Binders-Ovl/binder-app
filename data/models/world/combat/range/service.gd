class_name TacticsAttackRangeService
extends RefCounted
## Runtime resolver for attack target-selection range patterns.

const COMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")

const DIR_NORTH: Vector2i = Vector2i(0, -1)
const DIR_SOUTH: Vector2i = Vector2i(0, 1)
const DIR_EAST: Vector2i = Vector2i(1, 0)
const DIR_WEST: Vector2i = Vector2i(-1, 0)
const CARDINAL_DOT_MIN: float = 0.45
const MAX_STEP_HEIGHT_SCAN: float = 9999.0


func resolve_selectable_tiles(origin_tile: TacticsTile, attack_profile: AttackProfileResource) -> Array[TacticsTile]:
	var tiles: Array[TacticsTile] = []
	if origin_tile == null or not is_instance_valid(origin_tile):
		return tiles
	if attack_profile == null:
		push_error("TacticsAttackRangeService.resolve_selectable_tiles: attack_profile is null.")
		return tiles
	var attack_errors: Array[String] = attack_profile.validate()
	if not attack_errors.is_empty():
		push_error("TacticsAttackRangeService.resolve_selectable_tiles: invalid attack profile: %s" % "; ".join(attack_errors))
		return tiles

	if _is_self_centered_attack(attack_profile):
		tiles.append(origin_tile)
		return tiles

	var max_range: int = get_effective_max_range(attack_profile)
	if max_range < 0:
		return tiles

	var min_range: int = get_effective_min_range(attack_profile, max_range)
	if min_range > max_range:
		return tiles

	var pattern: int = get_range_pattern(attack_profile)
	var offsets: Array[Vector2i] = _build_offsets(pattern, min_range, max_range)
	var visited: Dictionary = {}
	for offset: Vector2i in offsets:
		var tile: TacticsTile = _project_tile_from_offset(origin_tile, offset)
		if tile == null or not is_instance_valid(tile):
			continue
		var key: int = tile.get_instance_id()
		if visited.has(key):
			continue
		visited[key] = true
		tiles.append(tile)
	return tiles


func resolve_selectable_tile_ids(origin_tile: TacticsTile, attack_profile: AttackProfileResource) -> Dictionary:
	var ids: Dictionary = {}
	for tile: TacticsTile in resolve_selectable_tiles(origin_tile, attack_profile):
		ids[tile.get_instance_id()] = true
	return ids


func get_effective_max_range(attack_profile: AttackProfileResource) -> int:
	if attack_profile == null:
		return 0
	var range_value: Variant = attack_profile.get("range")
	if range_value is int or range_value is float:
		return maxi(0, int(range_value))
	return 0


func get_effective_min_range(attack_profile: AttackProfileResource, max_range: int = -1) -> int:
	if attack_profile == null:
		return 1
	var effective_max: int = max_range
	if effective_max < 0:
		effective_max = get_effective_max_range(attack_profile)
	var min_value: Variant = attack_profile.get("min_range")
	var min_range: int = 1
	if min_value is int or min_value is float:
		min_range = int(min_value)
	return clampi(min_range, 0, maxi(0, effective_max))


func get_range_pattern(attack_profile: AttackProfileResource) -> int:
	if attack_profile == null:
		return COMBAT_CONFIG.AttackRangePattern.DIAMOND
	var pattern_value: Variant = attack_profile.get("range_pattern")
	if pattern_value is int or pattern_value is float:
		return int(pattern_value)
	return COMBAT_CONFIG.AttackRangePattern.DIAMOND


func _is_self_centered_attack(attack_profile: AttackProfileResource) -> bool:
	if attack_profile == null:
		return false
	var area: Variant = attack_profile.get("area")
	if area == null:
		return false
	return int(area.get("targeting_mode")) == COMBAT_CONFIG.AreaTargetingMode.SELF_CENTERED


func _build_offsets(pattern: int, min_range: int, max_range: int) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	match pattern:
		COMBAT_CONFIG.AttackRangePattern.CROSS:
			for dist: int in range(min_range, max_range + 1):
				if dist == 0:
					offsets.append(Vector2i.ZERO)
					continue
				offsets.append(Vector2i(dist, 0))
				offsets.append(Vector2i(-dist, 0))
				offsets.append(Vector2i(0, dist))
				offsets.append(Vector2i(0, -dist))
		COMBAT_CONFIG.AttackRangePattern.SPREAD_DIAG:
			for dist: int in range(min_range, max_range + 1):
				if dist == 0:
					offsets.append(Vector2i.ZERO)
					continue
				offsets.append(Vector2i(dist, dist))
				offsets.append(Vector2i(dist, -dist))
				offsets.append(Vector2i(-dist, dist))
				offsets.append(Vector2i(-dist, -dist))
		_:
			for x: int in range(-max_range, max_range + 1):
				for y: int in range(-max_range, max_range + 1):
					var dist: int = absi(x) + absi(y)
					if dist < min_range or dist > max_range:
						continue
					offsets.append(Vector2i(x, y))
	return offsets


func _project_tile_from_offset(origin_tile: TacticsTile, offset: Vector2i) -> TacticsTile:
	if origin_tile == null or not is_instance_valid(origin_tile):
		return null
	var current: TacticsTile = origin_tile

	var x_steps: int = absi(offset.x)
	var x_dir: Vector2i = DIR_EAST if offset.x >= 0 else DIR_WEST
	for _i: int in range(x_steps):
		current = _step_tile_cardinal(current, x_dir)
		if current == null:
			return null

	var y_steps: int = absi(offset.y)
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
