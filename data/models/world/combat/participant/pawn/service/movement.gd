class_name TacticsPawnMovementService
extends RefCounted
## Service class for handling pawn movement in the tactics game

const TILE_MATCH_DISTANCE: float = 0.3
const BLOCKED_BUMP_DISTANCE: float = 0.15
const TILE_RECOVERY_DISTANCE: float = 3.0
const BUMP_WINDOW_HALF_EXTENT: float = 1.05


## Rotates the pawn to face the given direction
##
## @param pawn: The TacticsPawn to rotate
## @param dir: The direction vector to face
func look_at_direction(pawn: TacticsPawn, dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	var _fixed_dir: Vector3 = dir * (Vector3(1, 0, 0) if abs(dir.x) > abs(dir.z) else Vector3(0, 0, 1))
	var _angle: float = Vector3.FORWARD.signed_angle_to(_fixed_dir.normalized(), Vector3.UP) + PI
	var _new_rot: Vector3 = Vector3.UP * _angle
	pawn.set_rotation(_new_rot)


## Moves the pawn along its pathfinding stack
##
## @param pawn: The TacticsPawn to move
## @param delta: Time elapsed since the last frame
func move_along_path(pawn: TacticsPawn, delta: float) -> void:
	if pawn.res.pathfinding_tilestack.is_empty():
		return
	
	start_movement(pawn)
	if not _can_advance_to_next_tile(pawn):
		return
	
	if pawn.res.move_direction.length() > 0.5:
		perform_movement(pawn, delta)
		
		var _first_tile_in_stack: Vector3 = pawn.res.pathfinding_tilestack.front()
		if pawn.global_position.distance_to(_first_tile_in_stack) >= 0.02:
			return
	
	pawn.res.pathfinding_tilestack.pop_front()
	reset_movement_state(pawn)
	check_movement_completion(pawn)


## Initiates the pawn's movement
##
## @param pawn: The TacticsPawn to start moving
func start_movement(pawn: TacticsPawn) -> void:
	pawn.res.set_moving(true)
	if pawn.res.move_direction == Vector3.ZERO:
		if not pawn.res.has_move_origin:
			pawn.res.move_origin_position = pawn.global_position
			pawn.res.has_move_origin = true
		pawn.res.move_direction = pawn.res.pathfinding_tilestack.front() - pawn.global_position
		_reserve_next_tile_for_movement(pawn)


## Performs the actual movement of the pawn
##
## @param pawn: The TacticsPawn to move
## @param delta: Time elapsed since the last frame
func perform_movement(pawn: TacticsPawn, delta: float) -> void:
	var target: Vector3 = pawn.res.pathfinding_tilestack.front()
	var move_to_target: Vector3 = target - pawn.global_position
	look_at_direction(pawn, move_to_target)
	var _curr_speed: float = calculate_speed(pawn)
	pawn.global_position = pawn.global_position.move_toward(target, _curr_speed * delta)


## Calculates the current speed of the pawn
##
## @param pawn: The TacticsPawn to calculate speed for
## @return: The calculated speed
func calculate_speed(pawn: TacticsPawn) -> float:
	var _curr_speed: float = pawn.res.walk_speed
	
	if absf(pawn.res.move_direction.y) > float(TacticsPawnResource.MIN_HEIGHT_TO_JUMP):
		_curr_speed = clamp(abs(pawn.res.move_direction.y) * 2.3, 3, INF)
		pawn.res.is_jumping = true
	
	return _curr_speed


## Resets the movement state of the pawn
##
## @param pawn: The TacticsPawn to reset
func reset_movement_state(pawn: TacticsPawn) -> void:
	_release_reserved_move_tile(pawn)
	pawn.res.move_direction = Vector3.ZERO
	pawn.res.is_jumping = false
	pawn.res.gravity = Vector3.ZERO


## Checks if the pawn has completed its movement and adjusts accordingly
##
## @param pawn: The TacticsPawn to check
func check_movement_completion(pawn: TacticsPawn) -> void:
	pawn.res.set_moving(false)
	pawn.character.adjust_to_center(pawn)
	if _resolve_occupied_tile(pawn):
		_finalize_move_transaction(pawn)


func _resolve_occupied_tile(pawn: TacticsPawn) -> bool:
	var curr_tile: TacticsTile = pawn.get_tile()
	if not curr_tile:
		return false

	var tile_pawns: Array[TacticsPawn] = _get_pawns_on_tile(pawn, curr_tile)
	if tile_pawns.is_empty():
		return true

	var primary_owner: TacticsPawn = _get_primary_tile_owner(tile_pawns)
	if not primary_owner or primary_owner == pawn:
		return true

	var arena: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if not arena:
		return false

	arena.res.release_all_bump_tiles_for_pawn(pawn)
	var best: TacticsTile = _find_best_bump_tile(arena, curr_tile, pawn)
	if not best:
		_revert_failed_move_transaction(pawn)
		return false

	if not arena.res.reserve_bump_tile(best, pawn):
		_revert_failed_move_transaction(pawn)
		return false

	var bump_dir: Vector3 = pawn.global_position - primary_owner.global_position
	if bump_dir.length() < 0.01:
		bump_dir = Vector3.BACK
	bump_dir = bump_dir.normalized() * BLOCKED_BUMP_DISTANCE
	var tween: Tween = pawn.create_tween()
	tween.tween_property(pawn, "global_position", pawn.global_position + bump_dir, 0.05)
	tween.tween_property(pawn, "global_position", best.global_position, 0.1)
	tween.tween_callback(func() -> void:
		pawn.character.adjust_to_center(pawn)
		arena.res.release_bump_tile(best, pawn)
	)
	return true


func _find_best_bump_tile(arena: TacticsArena, target_tile: TacticsTile, pawn: TacticsPawn) -> TacticsTile:
	var best: TacticsTile = null
	var best_score: float = INF
	for t: TacticsTile in arena.get_node("Tiles").get_children():
		if t == target_tile:
			continue
		if not _is_tile_in_bump_window(target_tile, t):
			continue
		if _is_bump_tile_claimed(arena, t, pawn):
			continue
		var score: float = t.global_position.distance_to(pawn.global_position)
		if score < best_score:
			best_score = score
			best = t
	return best


func _is_bump_tile_claimed(arena: TacticsArena, tile: TacticsTile, pawn: TacticsPawn) -> bool:
	if tile.is_taken():
		return true
	if arena.res.is_bump_tile_reserved_by_other(tile, pawn):
		return true
	return _has_any_other_pawn_on_tile(pawn, tile)


func _is_tile_in_bump_window(center_tile: TacticsTile, candidate: TacticsTile) -> bool:
	var dx: float = absf(candidate.global_position.x - center_tile.global_position.x)
	var dz: float = absf(candidate.global_position.z - center_tile.global_position.z)
	return dx <= BUMP_WINDOW_HALF_EXTENT and dz <= BUMP_WINDOW_HALF_EXTENT


func _get_pawns_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> Array[TacticsPawn]:
	var result: Array[TacticsPawn] = []
	var scene: Node = pawn.get_tree().current_scene
	if not scene:
		return result
	for node: Node in scene.find_children("*", "TacticsPawn", true, false):
		var other: TacticsPawn = node as TacticsPawn
		if not other or not is_instance_valid(other) or not other.is_alive():
			continue
		var other_tile: TacticsTile = other.get_tile()
		if other_tile == tile or other.global_position.distance_to(tile.global_position) <= TILE_MATCH_DISTANCE:
			result.append(other)
	return result


func _has_any_other_pawn_on_tile(pawn: TacticsPawn, tile: TacticsTile) -> bool:
	for other: TacticsPawn in _get_pawns_on_tile(pawn, tile):
		if other != pawn:
			return true
	return false


func _get_primary_tile_owner(tile_pawns: Array[TacticsPawn]) -> TacticsPawn:
	if tile_pawns.is_empty():
		return null
	var primary: TacticsPawn = tile_pawns[0]
	for other: TacticsPawn in tile_pawns:
		if other.get_instance_id() < primary.get_instance_id():
			primary = other
	return primary


func _can_advance_to_next_tile(pawn: TacticsPawn) -> bool:
	if pawn.res.pathfinding_tilestack.is_empty():
		return false

	var next_tile: TacticsTile = _find_tile_by_position(pawn, pawn.res.pathfinding_tilestack.front())
	if not next_tile:
		_recover_to_nearest_valid_tile(pawn)
		return false
	if _is_next_tile_reserved_by_other(pawn, next_tile):
		_bump_and_stop_when_blocked(pawn, pawn)
		return false
	if not _reserve_specific_tile_for_pawn(pawn, next_tile):
		_bump_and_stop_when_blocked(pawn, pawn)
		return false

	var occupier_obj: Object = next_tile.get_tile_occupier()
	if occupier_obj == null or occupier_obj == pawn:
		return true
	if not (occupier_obj is TacticsPawn):
		_bump_and_stop_when_blocked(pawn, occupier_obj if occupier_obj is Node3D else pawn)
		return false

	var occupier: TacticsPawn = occupier_obj as TacticsPawn
	if not is_instance_valid(occupier) or not occupier.is_alive():
		return true
	if _can_pass_through_occupier(pawn, occupier):
		return true

	_bump_and_stop_when_blocked(pawn, occupier)
	return false


func _can_pass_through_occupier(_mover: TacticsPawn, _occupier: TacticsPawn) -> bool:
	return false


func _find_tile_by_position(pawn: TacticsPawn, position: Vector3) -> TacticsTile:
	var arena: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if not arena:
		return null

	for tile: TacticsTile in arena.get_node("Tiles").get_children():
		if tile.global_position.distance_to(position) <= TILE_MATCH_DISTANCE:
			return tile
	return null


func _find_nearest_tile(arena: TacticsArena, position: Vector3, max_distance: float = TILE_RECOVERY_DISTANCE) -> TacticsTile:
	var best_tile: TacticsTile = null
	var best_dist: float = INF
	for tile: TacticsTile in arena.get_node("Tiles").get_children():
		var dist: float = tile.global_position.distance_to(position)
		if dist <= max_distance and dist < best_dist:
			best_dist = dist
			best_tile = tile
	return best_tile


func _recover_to_nearest_valid_tile(pawn: TacticsPawn) -> void:
	var arena: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if not arena:
		pawn.res.pathfinding_tilestack.clear()
		reset_movement_state(pawn)
		pawn.res.set_moving(false)
		return

	var safe_tile: TacticsTile = _find_nearest_tile(arena, pawn.global_position)
	pawn.res.pathfinding_tilestack.clear()
	reset_movement_state(pawn)
	pawn.res.set_moving(false)
	if safe_tile:
		pawn.global_position = safe_tile.global_position
	pawn.character.adjust_to_center(pawn)


func _revert_failed_move_transaction(pawn: TacticsPawn) -> void:
	var arena: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if arena:
		arena.res.release_all_move_tiles_for_pawn(pawn)
		arena.res.release_all_bump_tiles_for_pawn(pawn)
	pawn.res.pathfinding_tilestack.clear()
	reset_movement_state(pawn)
	pawn.res.set_moving(false)
	if pawn.res.has_move_origin:
		pawn.global_position = pawn.res.move_origin_position
	pawn.character.adjust_to_center(pawn)
	if pawn.res.move_act_spent:
		pawn.stats.curr_act = minf(pawn.stats.max_act, pawn.stats.curr_act + float(TacticsConfig.action_cost.move))
		pawn.refresh_action_state()
	pawn.res.clear_move_transaction()


func _finalize_move_transaction(pawn: TacticsPawn) -> void:
	var arena: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if arena:
		arena.res.release_all_move_tiles_for_pawn(pawn)
		arena.res.release_all_bump_tiles_for_pawn(pawn)
	pawn.res.clear_move_transaction()


func _bump_and_stop_when_blocked(pawn: TacticsPawn, blocker: Node3D) -> void:
	pawn.res.pathfinding_tilestack.clear()
	reset_movement_state(pawn)
	pawn.res.set_moving(false)
	_apply_collision_bump(pawn, blocker)
	pawn.character.adjust_to_center(pawn)


func _apply_collision_bump(pawn: TacticsPawn, blocker: Node3D) -> void:
	var bump_dir: Vector3 = pawn.global_position - blocker.global_position
	if bump_dir.length() < 0.01:
		bump_dir = Vector3.BACK
	bump_dir = bump_dir.normalized() * BLOCKED_BUMP_DISTANCE
	var tween: Tween = pawn.create_tween()
	tween.tween_property(pawn, "global_position", pawn.global_position + bump_dir, 0.05)
	tween.tween_callback(func() -> void: pawn.character.adjust_to_center(pawn))


func _is_same_team(a: TacticsPawn, b: TacticsPawn) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	return a.get_parent() == b.get_parent()


func _reserve_next_tile_for_movement(pawn: TacticsPawn) -> bool:
	if pawn.res.pathfinding_tilestack.is_empty():
		return false
	var next_tile: TacticsTile = _find_tile_by_position(pawn, pawn.res.pathfinding_tilestack.front())
	if not next_tile:
		return false
	return _reserve_specific_tile_for_pawn(pawn, next_tile)


func _reserve_specific_tile_for_pawn(pawn: TacticsPawn, tile: TacticsTile) -> bool:
	if not tile:
		return false
	var arena: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if not arena:
		return false
	if pawn.res.reserved_move_tile == tile:
		return true
	if not arena.res.reserve_move_tile(tile, pawn):
		return false
	_release_reserved_move_tile(pawn)
	pawn.res.reserved_move_tile = tile
	return true


func _release_reserved_move_tile(pawn: TacticsPawn) -> void:
	var reserved_tile: TacticsTile = pawn.res.reserved_move_tile
	if not reserved_tile:
		return
	var arena: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if arena:
		arena.res.release_move_tile(reserved_tile, pawn)
	pawn.res.reserved_move_tile = null


func _is_next_tile_reserved_by_other(pawn: TacticsPawn, tile: TacticsTile) -> bool:
	var arena: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if not arena:
		return false
	return arena.res.is_move_tile_reserved_by_other(tile, pawn)
