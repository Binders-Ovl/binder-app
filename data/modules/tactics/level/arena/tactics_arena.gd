class_name TacticsArena
extends Node3D
## Tile config & sorting, neighbours, hover & reach UI overlay, pathfinding and targeting utilities.
## 
## Resource Interface: [TacticsArenaResource] -- Service: [TacticsArenaService]
## Dependency: [TacticsTile] -- Service: [TacticsTileService]

## Resource containing arena-related data and configurations
@export var res: TacticsArenaResource = load("res://data/models/world/combat/arena/arena.tres")
## Service handling arena-related operations
var serv: TacticsArenaService


func _ready() -> void:
	serv = TacticsArenaService.new(res) # Initialize the arena service
	serv.setup(self) # Set up the arena


## Resets all tile markers in the arena
func reset_all_tile_markers() -> void:
	serv.reset_all_tile_markers(self)


## Configures all tiles in the arena
func configure_tiles() -> void:
	serv.configure_tiles(self)


## Processes tiles surrounding a given root tile
## [param root_tile] The central tile to process around
## [param height] The height to consider for processing
## [param allies_on_map] Array of allied pawns on the map (optional)
func process_surrounding_tiles(root_tile: TacticsTile, max_distance: float, max_step_height: float, allies_on_map: Array = [], allow_pass_through: bool = false, ignore_occupancy: bool = false) -> void:
	serv.process_surrounding_tiles(root_tile, max_distance, max_step_height, allies_on_map, allow_pass_through, ignore_occupancy)


## Returns an array of tiles representing the pathfinding stack to a given tile
## [param to] The destination tile
## [returns] Array of tiles forming the path
func get_pathfinding_tilestack(to: TacticsTile) -> Array:
	return serv.get_pathfinding_tilestack(to)


## Finds the nearest tile adjacent to any target pawn
## [param pawn] The pawn seeking a target
## [param target_pawns] Array of potential target pawns
## [returns] The nearest adjacent tile to a target
func get_nearest_target_adjacent_tile(pawn: TacticsPawn, target_pawns: Array) -> TacticsTile:
	return serv.get_nearest_target_adjacent_tile(pawn, target_pawns)


## Identifies the weakest attackable pawn from an array of pawns
## [param pawn_arr] Array of pawns to evaluate
## [returns] The weakest attackable pawn
func get_weakest_attackable_pawn(pawn_arr: Array) -> TacticsPawn:
	return serv.get_weakest_attackable_pawn(pawn_arr)


## Marks a tile as hovered
## [param tile] The tile to mark as hovered
func mark_hover_tile(tile: TacticsTile) -> void:
	serv.mark_hover_tile(self, tile)


## Marks tiles reachable within a certain distance from a root tile
## [param root] The starting tile
## [param distance] The maximum distance to consider
func mark_reachable_tiles(root: TacticsTile, distance: float) -> void:
	serv.mark_reachable_tiles(self, root, distance)


## Marks tiles attackable within a certain distance from a root tile
## [param root] The starting tile
## [param distance] The maximum attack distance
func mark_attackable_tiles(root: TacticsTile, distance: float) -> void:
	serv.mark_attackable_tiles(self, root, distance)


## Captures mutable navigation/overlay state for temporary planning operations.
func capture_navigation_state() -> Dictionary:
	return serv.capture_navigation_state(self)


## Restores mutable navigation/overlay state from a previous capture.
func restore_navigation_state(state: Dictionary) -> void:
	serv.restore_navigation_state(self, state)
