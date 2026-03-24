class_name TacticsTileRaycast
extends Node3D
## Handles raycasting operations for TacticsTile.
## 
## This class is responsible for detecting neighboring tiles and objects above the tile.
## It is typically instantiated as a child of TacticsTile.

const RAMP_HEIGHT_TOLERANCE: float = 1.2
const SLOPE_NORMAL_Y_THRESHOLD: float = 0.98


#region: --- Methods ---
## Returns all the neighbouring tiles within a given height range.
## [param height] The maximum height difference to consider for neighbors.
## [returns] An array of neighboring Node3D objects (typically TacticsTiles).
func get_all_neighbors(height: float) -> Array[Node3D]:
	var neighbors: Array[Node3D] = []
	var current_tile_y: float = get_parent().global_position.y
	
	for ray: RayCast3D in $Neighbors.get_children() as Array[RayCast3D]:
		if not ray.is_colliding():
			continue
		var obj: Node3D = ray.get_collider() # Get the object hit by the ray
		
		# Check if object exists and is within the specified height range
		var neighbor_surface_y: float = ray.get_collision_point().y
		var center_delta: float = abs(obj.global_position.y - current_tile_y)
		var surface_delta: float = abs(neighbor_surface_y - current_tile_y)
		var slope_bonus: float = RAMP_HEIGHT_TOLERANCE if ray.get_collision_normal().y < SLOPE_NORMAL_Y_THRESHOLD else 0.0
		var allowed_height: float = height + slope_bonus
		if obj is TacticsTile and (center_delta <= allowed_height or surface_delta <= allowed_height):
			neighbors.append(obj) # Add the object to neighbors list
			
	return neighbors


## Returns the object directly above the tile.
## [returns] The object above the tile, or null if none found.
func get_object_above() -> Object:
	return $Above.get_collider() # Return object hit by the upward-facing ray
#endregion
