class_name TacticsTile
extends StaticBody3D
## Handles tiles, hover colors, tile state, pathfinding.
## 
## This is ultimately a module, as it is programatically appended onto every tile by way of the TacticsTileService.
## Dependencies: [TacticsTileService] [br]
## Used by: [TacticsArena]

#region: --- Props ---
## Resource for tile raycasting
var tile_raycast: Resource = load("res://data/modules/tactics/level/arena/tile/raycast/tile_raycasting.tscn")

## Whether the tile is reachable
var reachable: bool = false
## Whether the tile is attackable
var attackable: bool = false
## Whether the tile is inside currently previewed attack area footprint.
var attack_area_preview: bool = false
## Whether the tile is being hovered over
var hover: bool = false
## Whether moving here would place the active unit in opponent attack range
var threatened_move: bool = false

## Pathfinding starting point.[br]Used by [TacticsArena]
var pf_root: TacticsTile
## The distance to cover.[br]Used by [TacticsArena]
var pf_distance: float

## Material for hover state
var hover_mat: StandardMaterial3D = TacticsConfig.mat_color.hover
## Material for reachable state
var reachable_mat: StandardMaterial3D = TacticsConfig.mat_color.reachable
## Material for hover and reachable state
var hover_reachable_mat: StandardMaterial3D = TacticsConfig.mat_color.reachable_hover
## Material for reachable move-risk state
var reachable_threatened_mat: StandardMaterial3D = TacticsConfig.mat_color.reachable_threatened
## Material for hover + reachable move-risk state
var hover_reachable_threatened_mat: StandardMaterial3D = TacticsConfig.mat_color.hover_reachable_threatened
## Material for attackable state
var attackable_mat: StandardMaterial3D = TacticsConfig.mat_color.attackable
## Material for hover and attackable state
var hover_attackable_mat: StandardMaterial3D = TacticsConfig.mat_color.hover_attackable
## Material for attack-area preview state
var attack_area_preview_mat: StandardMaterial3D = TacticsConfig.mat_color.attack_area_preview
## Material for hover + attack-area preview state
var hover_attack_area_preview_mat: StandardMaterial3D = TacticsConfig.mat_color.hover_attack_area_preview
#endregion

#region: --- Processing ---
func _process(_delta: float) -> void:
	# Get child node named "Tile" and cast it to a MeshInstance3D.
	# If the node doesn't exist, it will be null.
	var tile: MeshInstance3D = get_node_or_null("Tile") as MeshInstance3D
	if not tile:
		return # If the "Tile" node wasn't found, the function exits early to avoid errors.
	
	# Set visibility based on current tactical states.
	tile.visible = attackable or attack_area_preview or reachable or hover or threatened_move
	
	match hover:
		true: # If hover is true, decide which material to use based on the tile's state
			if reachable and threatened_move:
				tile.material_override = hover_reachable_threatened_mat
			elif attack_area_preview:
				tile.material_override = hover_attack_area_preview_mat
			elif reachable:
				tile.material_override = hover_reachable_mat
			elif attackable:
				tile.material_override = hover_attackable_mat
			else:
				tile.material_override = hover_mat
		false: # If hover is false, this block decides between two materials
			if reachable and threatened_move:
				tile.material_override = reachable_threatened_mat
			elif attack_area_preview:
				tile.material_override = attack_area_preview_mat
			elif reachable:
				tile.material_override = reachable_mat
			elif attackable:
				tile.material_override = attackable_mat
			else:
				tile.material_override = null
#endregion

#region: --- Methods ---
# Getters
## Returns all 4 directly adjacent tiles
func get_neighbors(height: float) -> Array:
	return $RayCasting.get_all_neighbors(height)


## Returns any collider directly (<=1m) above
func get_tile_occupier() -> Object:
	var occupier: Object = $RayCasting.get_object_above()
	if occupier == null or not is_instance_valid(occupier):
		return null
	return occupier


## Returns world-space overlay anchor data (position, normal, tile) for shared selector placement.
func get_overlay_anchor(offset: float = TacticsConfig.tile_overlay_surface_offset) -> Dictionary:
	var raycasting: TacticsTileRaycast = $RayCasting as TacticsTileRaycast
	if not raycasting:
		return {}
	return raycasting.get_overlay_anchor(offset)


## Return whether target tile is occupied
func is_taken() -> bool:
	return get_tile_occupier() != null


# Setters
## Resets the tile's markers (pf_root, pf_distance, reachable, attackable)
func reset_markers() -> void:
	pf_root = null
	pf_distance = 0
	reachable = false
	attackable = false
	attack_area_preview = false
	threatened_move = false


## Initializes tile (disable hover, instantiate raycast & reset state)
func configure_tile() -> void:
	hover = false
	var instance: Node = tile_raycast.instantiate() # Instantiate raycast
	add_child(instance) # Add raycast as child
	reset_markers() # Reset tile markers
#endregion
