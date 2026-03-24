class_name TacticsArenaResource
extends Resource
## Attributes, controller & signals of the tactics arena.

## Emitted when all tile markers need to be reset
signal called_reset_all_tile_markers
## Emitted when pathfinding tilestack is requested
## [param tile] The target tile for pathfinding
signal called_get_pathfinding_tilestack(tile: TacticsTile)
## Emitted when a tile needs to be marked as hovered
## [param tile] The tile to be marked as hovered
signal called_mark_hover_tile(tile: TacticsTile)

## Stores the current pathfinding tiles stack
var path_tiles_stack: Array = []
## Extra vertical margin applied when checking neighbor step height.
## Keeps movement primarily controlled by `stats.jump` while tolerating mesh imprecision.
@export var step_height_margin: float = 0.75
## Tracks temporary bump destination reservations to avoid multiple pawns claiming the same fallback tile.
var bump_tile_reservations: Dictionary = {}


## Triggers the reset of all tile markers
func reset_all_tile_markers() -> void:
	called_reset_all_tile_markers.emit()


## Requests the pathfinding tilestack for a given tile
## [param tile] The target tile for pathfinding
## [returns] The array of tiles in the pathfinding stack
func get_pathfinding_tilestack(tile: TacticsTile) -> Array:
	called_get_pathfinding_tilestack.emit(tile)
	return path_tiles_stack


## Marks a tile as hovered
## [param tile] The tile to be marked as hovered
func mark_hover_tile(tile: TacticsTile) -> void:
	called_mark_hover_tile.emit(tile)


func reserve_bump_tile(tile: TacticsTile, pawn: TacticsPawn) -> bool:
	if not tile or not pawn:
		return false
	_prune_invalid_bump_reservations()
	var key: int = tile.get_instance_id()
	if bump_tile_reservations.has(key):
		return bump_tile_reservations[key] == pawn.get_instance_id()
	bump_tile_reservations[key] = pawn.get_instance_id()
	return true


func release_bump_tile(tile: TacticsTile, pawn: TacticsPawn) -> void:
	if not tile or not pawn:
		return
	var key: int = tile.get_instance_id()
	if bump_tile_reservations.get(key, -1) == pawn.get_instance_id():
		bump_tile_reservations.erase(key)


func release_all_bump_tiles_for_pawn(pawn: TacticsPawn) -> void:
	if not pawn:
		return
	var owner_id: int = pawn.get_instance_id()
	var keys_to_erase: Array[int] = []
	for key: int in bump_tile_reservations.keys():
		if bump_tile_reservations[key] == owner_id:
			keys_to_erase.append(key)
	for key: int in keys_to_erase:
		bump_tile_reservations.erase(key)


func is_bump_tile_reserved_by_other(tile: TacticsTile, pawn: TacticsPawn) -> bool:
	if not tile or not pawn:
		return false
	_prune_invalid_bump_reservations()
	var key: int = tile.get_instance_id()
	return bump_tile_reservations.has(key) and bump_tile_reservations[key] != pawn.get_instance_id()


func _prune_invalid_bump_reservations() -> void:
	var keys_to_erase: Array[int] = []
	for key: int in bump_tile_reservations.keys():
		var owner_id: int = bump_tile_reservations[key]
		if owner_id == 0:
			keys_to_erase.append(key)
	for key: int in keys_to_erase:
		bump_tile_reservations.erase(key)
