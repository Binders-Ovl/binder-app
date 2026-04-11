class_name TacticsArenaService
extends RefCounted
## Service class for TacticsArena

## The service we inject into every tile
const TILE_SERVICE = preload("res://data/models/world/combat/arena/tile_service/service.gd")
const ATTACK_AREA_SERVICE = preload("res://data/models/world/combat/area/service.gd")
const ATTACK_RANGE_SERVICE = preload("res://data/models/world/combat/range/service.gd")
const SELECTOR_OVERLAY_ROOT_NAME: StringName = &"SelectorOverlay"
const SELECTOR_OVERLAY_MESH_NAME: StringName = &"SelectorOverlayMesh"
const SELECTOR_OVERLAY_ROOT_PATH: NodePath = ^"SelectorOverlay"
const SELECTOR_OVERLAY_MESH_PATH: NodePath = ^"SelectorOverlayMesh"
const ACTIVE_TILE_OVERLAYS_ROOT_NAME: StringName = &"ActiveTileOverlays"
const ACTIVE_TILE_OVERLAYS_ROOT_PATH: NodePath = ^"ActiveTileOverlays"
const ACTIVE_TILE_OVERLAY_NAME_PREFIX: String = "ActiveTileOverlay"
const TILE_NEIGHBOR_SCAN_HEIGHT: float = 9999.0

var res: TacticsArenaResource
var _active_overlay_material_cache: Dictionary = {}
var _attack_area_service
var _attack_range_service


## Initialize the service with a TacticsArenaResource
## [param _res] The TacticsArenaResource to use
func _init(_res: TacticsArenaResource) -> void:
	res = _res
	_attack_area_service = ATTACK_AREA_SERVICE.new()
	_attack_range_service = ATTACK_RANGE_SERVICE.new()


## Set up the arena by connecting signals
## [param arena] The TacticsArena to set up
func setup(arena: TacticsArena) -> void:
	if not res:
		push_error("TacticsArena needs an ArenaResource from /data/models/world/combat/arena/")
	else:
		res.connect("called_reset_all_tile_markers", arena.reset_all_tile_markers)
		res.connect("called_get_pathfinding_tilestack", arena.get_pathfinding_tilestack)
		res.connect("called_mark_hover_tile", arena.mark_hover_tile)


## Captures mutable tile/pathfinding state so temporary computations can be restored.
func capture_navigation_state(arena: TacticsArena) -> Dictionary:
	var state: Dictionary = {
		"tiles": {},
		"path_tiles_stack": []
	}
	if not arena or not is_instance_valid(arena):
		return state

	var tiles_state: Dictionary = {}
	for tile: TacticsTile in arena.get_node("Tiles").get_children():
		tiles_state[tile.get_instance_id()] = {
			"tile": tile,
			"hover": tile.hover,
			"reachable": tile.reachable,
			"threatened_move": tile.threatened_move,
			"attackable": tile.attackable,
			"attack_area_preview": tile.attack_area_preview,
			"pf_root": tile.pf_root,
			"pf_distance": tile.pf_distance
		}
	state["tiles"] = tiles_state
	if res:
		state["path_tiles_stack"] = res.path_tiles_stack.duplicate()
	return state


## Restores tile/pathfinding state previously captured by capture_navigation_state().
func restore_navigation_state(arena: TacticsArena, state: Dictionary) -> void:
	var tiles_state: Dictionary = state.get("tiles", {})
	for key: int in tiles_state.keys():
		var tile_state: Dictionary = tiles_state[key]
		var tile: TacticsTile = tile_state.get("tile", null)
		if not tile or not is_instance_valid(tile):
			continue
		tile.hover = tile_state.get("hover", false)
		tile.reachable = tile_state.get("reachable", false)
		tile.threatened_move = tile_state.get("threatened_move", false)
		tile.attackable = tile_state.get("attackable", false)
		tile.attack_area_preview = tile_state.get("attack_area_preview", false)
		tile.pf_root = tile_state.get("pf_root", null)
		tile.pf_distance = tile_state.get("pf_distance", 0.0)

	if res:
		res.path_tiles_stack = state.get("path_tiles_stack", []).duplicate()
	_refresh_active_tile_overlays(arena)


## Reset markers for all tiles in the arena
## [param arena] The TacticsArena containing the tiles
func reset_all_tile_markers(arena: TacticsArena) -> void:
	for _t: TacticsTile in arena.get_node("Tiles").get_children():
		_t.reset_markers()
	_set_selector_overlay_visible(arena, false)
	_set_active_tile_overlays_visible(arena, false)


## Configure tiles in the arena
## [param arena] The TacticsArena to configure
func configure_tiles(arena: TacticsArena) -> void:
	arena.get_node("Tiles").visible = true
	var _tiles: Node3D = arena.get_node("Tiles")
	TILE_SERVICE.tiles_into_staticbodies(_tiles)
	_ensure_selector_overlay(arena)
	_ensure_active_tile_overlays_root(arena)


## Process tiles surrounding a root tile
## [param root_tile] The starting tile
## [param height] The height to consider for neighbors
## [param allies_on_map] Array of allied pawns on the map
func process_surrounding_tiles(root_tile: TacticsTile, max_distance: float, max_step_height: float, allies_on_map: Array = [], allow_pass_through: bool = false, ignore_occupancy: bool = false) -> void:
	if not root_tile or not is_instance_valid(root_tile):
		return
	var margin: float = maxf(0.0, res.step_height_margin if res else 0.0)
	var allowed_step_height: float = maxf(0.0, max_step_height) + margin
	var _tiles_process_q: Array = [root_tile]
	
	while not _tiles_process_q.is_empty():
		var _curr_tile: TacticsTile = _tiles_process_q.pop_front()
		
		var _add_to_tiles_list: Callable = func _add(_neighbor: TacticsTile) -> void:
			_neighbor.pf_root = _curr_tile
			_neighbor.pf_distance = _curr_tile.pf_distance + 1
			_tiles_process_q.push_back(_neighbor)
		
		if _curr_tile.pf_distance >= max_distance:
			continue

		for _neighbor: TacticsTile in _curr_tile.get_neighbors(allowed_step_height):
			if not _neighbor.pf_root and _neighbor != root_tile:
				if _can_step_on_or_pass_through(_neighbor, allies_on_map, allow_pass_through, ignore_occupancy):
					_add_to_tiles_list.call(_neighbor)


func _can_step_on_or_pass_through(tile: TacticsTile, _allies_on_map: Array, _mover_can_fly: bool, ignore_occupancy: bool = false) -> bool:
	if ignore_occupancy:
		return true
	if res and res.is_move_tile_reserved(tile):
		return false
	if not tile.is_taken():
		return true

	return false


## Get the pathfinding tilestack to a target tile
## [param to] The target tile
## [returns] Array of global positions forming the path
func get_pathfinding_tilestack(to: TacticsTile) -> Array:
	var _path_tiles_stack: Array = []
	
	while to:
		to.hover = true
		_path_tiles_stack.push_front(to.global_position)
		to = to.pf_root
		
	res.path_tiles_stack = _path_tiles_stack
	return _path_tiles_stack


## Get the nearest tile adjacent to a target pawn
## [param pawn] The pawn seeking a target
## [param target_pawns] Array of potential target pawns
## [returns] The nearest adjacent tile or the pawn's current tile if no target found
func get_nearest_target_adjacent_tile(pawn: TacticsPawn, target_pawns: Array) -> TacticsTile:
	var _nearest_target: Node3D = null
	var pawn_tile: TacticsTile = pawn.get_tile()
	if not pawn_tile:
		return null
	
	for _p: TacticsPawn in target_pawns:
		if not is_instance_valid(_p) or _p.stats.curr_health <= 0:
			continue
		var target_tile: TacticsTile = _p.get_tile()
		if not target_tile:
			continue
		for _n: TacticsTile in target_tile.get_neighbors(pawn.stats.jump):
			if not _nearest_target or _n.pf_distance < _nearest_target.pf_distance:
				if _n.pf_distance > 0 and not _n.is_taken():
					_nearest_target = _n
	
	while _nearest_target and not _nearest_target.reachable: 
		_nearest_target = _nearest_target.pf_root
	
	if _nearest_target:
		return _nearest_target 
	else:
		DebugLog.debug_nospam("nearest_target", pawn)
		return pawn_tile


## Get the weakest attackable pawn from an array of pawns
## [param pawn_arr] Array of pawns to evaluate
## [returns] The weakest attackable pawn or null if none found
func get_weakest_attackable_pawn(pawn_arr: Array) -> TacticsPawn:
	var _weakest: TacticsPawn = null
	
	for _p: TacticsPawn in pawn_arr:
		if not is_instance_valid(_p):
			continue
		var tile: TacticsTile = _p.get_tile()
		if not tile:
			continue
		if not _weakest or _p.stats.curr_health < _weakest.stats.curr_health:
			if _p.stats.curr_health > 0 and tile.attackable:
				_weakest = _p
	
	return _weakest


## Mark a tile as hovered and unmark others
## [param arena] The TacticsArena containing the tiles
## [param tile] The tile to mark as hovered
func mark_hover_tile(arena: TacticsArena, tile: TacticsTile) -> void:
	for _t: TacticsTile in arena.get_node("Tiles").get_children():
		_t.hover = false
	
	if tile:
		tile.hover = true
	_update_selector_overlay(arena, tile)


## Mark reachable tiles within a certain distance from a root tile
## [param arena] The TacticsArena containing the tiles
## [param root] The starting tile
## [param distance] The maximum distance to consider
func mark_reachable_tiles(arena: TacticsArena, root: TacticsTile, distance: float) -> void:
	for _t: TacticsTile in arena.get_node("Tiles").get_children():
		var _has_dist: bool = _t.pf_distance > 0
		var _reachable: bool = _t.pf_distance <= distance
		var _not_taken: bool = not _t.is_taken()
		var _is_root: bool = _t == root
		
		_t.reachable = (_has_dist and _reachable and _not_taken) or _is_root
	_update_move_risk_tiles(arena, root)
	_refresh_active_tile_overlays(arena)


## Mark attackable tiles from either scalar radius or attack profile range pattern.
## [param arena] The TacticsArena containing the tiles
## [param root] The starting tile
## [param distance] The maximum attack distance used by legacy scalar flow
## [param attack_profile] Optional attack profile with range pattern and min range rules
func mark_attackable_tiles(arena: TacticsArena, root: TacticsTile, distance: float, attack_profile: AttackProfileResource = null) -> void:
	if attack_profile != null:
		_mark_attackable_tiles_by_profile(arena, root, attack_profile)
		return

	for _t: TacticsTile in arena.get_node("Tiles").get_children():
		var _has_dist: bool = _t.pf_distance > 0
		var _reachable: bool = _t.pf_distance <= distance
		var _is_root: bool = _t == root

		_t.attackable = _has_dist and _reachable or _is_root
		_t.threatened_move = false
	_refresh_active_tile_overlays(arena)


## Preview resolved attack area footprint for currently hovered datum.
func mark_attack_area_preview(arena: TacticsArena, attacker: TacticsPawn, datum_tile: TacticsTile, attack_profile: AttackProfileResource) -> void:
	for tile_node: Node in arena.get_node("Tiles").get_children():
		if tile_node is TacticsTile:
			(tile_node as TacticsTile).attack_area_preview = false

	if not attacker or not is_instance_valid(attacker):
		_refresh_active_tile_overlays(arena)
		return
	if not attack_profile:
		_refresh_active_tile_overlays(arena)
		return
	var attack_errors: Array[String] = attack_profile.validate()
	if not attack_errors.is_empty():
		push_error("TacticsArenaService.mark_attack_area_preview: invalid attack profile: %s" % "; ".join(attack_errors))
		_refresh_active_tile_overlays(arena)
		return
	if attack_profile.area == null:
		_refresh_active_tile_overlays(arena)
		return

	var resolved_tiles: Array[TacticsTile] = _attack_area_service.resolve_affected_tiles(attacker, datum_tile, attack_profile, arena)
	for tile: TacticsTile in resolved_tiles:
		if tile and is_instance_valid(tile):
			tile.attack_area_preview = true
	_refresh_active_tile_overlays(arena)


## Build tile-based attack footprint for one pawn.
## [returns] Dictionary keyed by tile instance id.
func build_attack_footprint(pawn: TacticsPawn) -> Dictionary:
	return _build_attack_footprint_for_pawn(pawn)


func _ensure_selector_overlay(arena: TacticsArena) -> void:
	var root: Node3D = _get_selector_overlay_root(arena)
	if not root:
		root = Node3D.new()
		root.name = SELECTOR_OVERLAY_ROOT_NAME
		arena.add_child(root)

	var mesh_instance: MeshInstance3D = root.get_node_or_null(SELECTOR_OVERLAY_MESH_PATH) as MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = SELECTOR_OVERLAY_MESH_NAME
		root.add_child(mesh_instance)

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE
	mesh_instance.mesh = plane
	mesh_instance.material_override = _build_selector_overlay_material()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.visible = false


func _build_selector_overlay_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, clampf(TacticsConfig.selector_overlay_opacity, 0.0, 1.0))
	material.albedo_texture = TacticsConfig.selector_overlay_texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = -10
	return material


func _update_selector_overlay(arena: TacticsArena, tile: TacticsTile) -> void:
	var root: Node3D = _get_selector_overlay_root(arena)
	if not root:
		return
	if not tile or not is_instance_valid(tile):
		root.visible = false
		return

	var anchor: Dictionary = tile.get_overlay_anchor()
	if anchor.is_empty():
		root.visible = false
		return

	var normal: Vector3 = anchor.get("normal", Vector3.UP)
	if normal == Vector3.ZERO:
		normal = Vector3.UP
	normal = normal.normalized()

	var position: Vector3 = anchor.get(
		"position",
		tile.global_position + normal * maxf(0.0, TacticsConfig.tile_overlay_surface_offset)
	)
	root.global_transform = Transform3D(_basis_from_surface_normal(normal), position)
	root.visible = true


func _basis_from_surface_normal(normal: Vector3) -> Basis:
	var from_up: Vector3 = Vector3.UP
	var dot: float = clampf(from_up.dot(normal), -1.0, 1.0)
	if dot >= 0.9999:
		return Basis.IDENTITY
	if dot <= -0.9999:
		return Basis(Vector3.RIGHT, PI)
	var axis: Vector3 = from_up.cross(normal).normalized()
	var angle: float = acos(dot)
	return Basis(axis, angle)


func _set_selector_overlay_visible(arena: TacticsArena, visible: bool) -> void:
	var root: Node3D = _get_selector_overlay_root(arena)
	if root:
		root.visible = visible


func _get_selector_overlay_root(arena: TacticsArena) -> Node3D:
	if not arena or not is_instance_valid(arena):
		return null
	return arena.get_node_or_null(SELECTOR_OVERLAY_ROOT_PATH) as Node3D


func _ensure_active_tile_overlays_root(arena: TacticsArena) -> void:
	var root: Node3D = _get_active_tile_overlays_root(arena)
	if root:
		return
	root = Node3D.new()
	root.name = ACTIVE_TILE_OVERLAYS_ROOT_NAME
	root.visible = false
	arena.add_child(root)


func _get_active_tile_overlays_root(arena: TacticsArena) -> Node3D:
	if not arena or not is_instance_valid(arena):
		return null
	return arena.get_node_or_null(ACTIVE_TILE_OVERLAYS_ROOT_PATH) as Node3D


func _set_active_tile_overlays_visible(arena: TacticsArena, visible: bool) -> void:
	var root: Node3D = _get_active_tile_overlays_root(arena)
	if not root:
		return
	root.visible = visible
	if not visible:
		for child: Node in root.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false


func _refresh_active_tile_overlays(arena: TacticsArena) -> void:
	var root: Node3D = _get_active_tile_overlays_root(arena)
	if not root:
		_ensure_active_tile_overlays_root(arena)
		root = _get_active_tile_overlays_root(arena)
	if not root:
		return

	var tiles_node: Node = arena.get_node("Tiles")
	var overlay_index: int = 0
	for tile_node: Node in tiles_node.get_children():
		if not (tile_node is TacticsTile):
			continue
		var tile: TacticsTile = tile_node as TacticsTile
		if not tile.reachable and not tile.attackable and not tile.attack_area_preview and not tile.threatened_move:
			continue

		var anchor: Dictionary = tile.get_overlay_anchor()
		if anchor.is_empty():
			continue
		var normal: Vector3 = anchor.get("normal", Vector3.UP)
		if normal == Vector3.ZERO:
			normal = Vector3.UP
		normal = normal.normalized()
		var position: Vector3 = anchor.get(
			"position",
			tile.global_position + normal * maxf(0.0, TacticsConfig.tile_overlay_surface_offset)
		)

		var overlay_mesh: MeshInstance3D = _get_or_create_active_tile_overlay(root, overlay_index)
		overlay_mesh.global_transform = Transform3D(_basis_from_surface_normal(normal), position)
		overlay_mesh.material_override = _get_active_tile_overlay_material(tile)
		overlay_mesh.visible = true
		overlay_index += 1

	for idx: int in range(overlay_index, root.get_child_count()):
		var extra: Node = root.get_child(idx)
		if extra is MeshInstance3D:
			(extra as MeshInstance3D).visible = false

	root.visible = overlay_index > 0


func _get_or_create_active_tile_overlay(root: Node3D, index: int) -> MeshInstance3D:
	if index < root.get_child_count():
		var existing: Node = root.get_child(index)
		if existing is MeshInstance3D:
			return existing as MeshInstance3D

	var overlay: MeshInstance3D = MeshInstance3D.new()
	overlay.name = "%s%d" % [ACTIVE_TILE_OVERLAY_NAME_PREFIX, index]
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE
	overlay.mesh = plane
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(overlay)
	return overlay


func _get_active_tile_overlay_material(tile: TacticsTile) -> StandardMaterial3D:
	var color: Color = Color(1.0, 1.0, 1.0, clampf(TacticsConfig.selector_overlay_opacity, 0.0, 1.0))
	var key: String = "mask_%s" % color.to_html(true)
	if _active_overlay_material_cache.has(key):
		return _active_overlay_material_cache[key] as StandardMaterial3D

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.albedo_texture = TacticsConfig.selector_overlay_texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = -10
	_active_overlay_material_cache[key] = material
	return material


func _update_move_risk_tiles(arena: TacticsArena, root: TacticsTile) -> void:
	var tiles_node: Node = arena.get_node("Tiles")
	var tiles: Array = tiles_node.get_children()
	for tile: TacticsTile in tiles:
		tile.threatened_move = false

	if not TacticsConfig.enable_purple_move_target_overlay:
		return
	if not root or not is_instance_valid(root):
		return

	var mover: TacticsPawn = root.get_tile_occupier() as TacticsPawn
	if not mover or not is_instance_valid(mover) or not mover.is_alive():
		return
	if not _is_player_controlled_pawn(mover):
		return

	var threat_map: Dictionary = _build_opponent_threat_map(mover)
	if threat_map.is_empty():
		return

	for tile: TacticsTile in tiles:
		if tile.reachable and threat_map.has(tile.get_instance_id()):
			tile.threatened_move = true


func _build_opponent_threat_map(mover: TacticsPawn) -> Dictionary:
	var threat_map: Dictionary = {}
	var opponents: Array[TacticsPawn] = _get_opponent_pawns(mover)
	for opponent: TacticsPawn in opponents:
		var footprint: Dictionary = _build_attack_footprint_for_pawn(opponent)
		for tile_id: int in footprint.keys():
			threat_map[tile_id] = true

	return threat_map


func _build_attack_footprint_for_pawn(attacker: TacticsPawn) -> Dictionary:
	var footprint: Dictionary = {}
	if not attacker or not is_instance_valid(attacker) or not attacker.is_alive():
		return footprint

	var origin_tile: TacticsTile = attacker.get_tile()
	if not origin_tile or not is_instance_valid(origin_tile):
		return footprint

	var primary_attack: AttackProfileResource = attacker.stats.get_primary_attack()
	if primary_attack != null:
		return _attack_range_service.resolve_selectable_tile_ids(origin_tile, primary_attack)

	# Legacy fallback for units without attack profile data.
	var attack_range: int = attacker.stats.get_primary_attack_range()
	var visited: Dictionary = {origin_tile.get_instance_id(): 0}
	var queue: Array[TacticsTile] = [origin_tile]
	while not queue.is_empty():
		var popped: Variant = queue.pop_front()
		if not (popped is TacticsTile):
			continue
		var tile: TacticsTile = popped as TacticsTile
		if not is_instance_valid(tile):
			continue

		var tile_id: int = tile.get_instance_id()
		var dist: int = int(visited.get(tile_id, 0))
		footprint[tile_id] = true
		if dist >= attack_range:
			continue

		for neighbor_variant: Variant in tile.get_neighbors(TILE_NEIGHBOR_SCAN_HEIGHT):
			if not (neighbor_variant is TacticsTile):
				continue
			var neighbor: TacticsTile = neighbor_variant as TacticsTile
			if not is_instance_valid(neighbor):
				continue
			var key: int = neighbor.get_instance_id()
			if visited.has(key):
				continue
			visited[key] = dist + 1
			queue.push_back(neighbor)

	return footprint


func _mark_attackable_tiles_by_profile(arena: TacticsArena, root: TacticsTile, attack_profile: AttackProfileResource) -> void:
	var selectable_tile_ids: Dictionary = {}
	var attack_errors: Array[String] = attack_profile.validate()
	if not attack_errors.is_empty():
		push_error("TacticsArenaService._mark_attackable_tiles_by_profile: invalid attack profile: %s" % "; ".join(attack_errors))
		for tile_node: Node in arena.get_node("Tiles").get_children():
			if tile_node is TacticsTile:
				var tile_clear: TacticsTile = tile_node as TacticsTile
				tile_clear.attackable = false
				tile_clear.threatened_move = false
		_refresh_active_tile_overlays(arena)
		return
	if root and is_instance_valid(root):
		selectable_tile_ids = _attack_range_service.resolve_selectable_tile_ids(root, attack_profile)

	for tile_node: Node in arena.get_node("Tiles").get_children():
		if not (tile_node is TacticsTile):
			continue
		var tile: TacticsTile = tile_node as TacticsTile
		tile.attackable = selectable_tile_ids.has(tile.get_instance_id())
		tile.threatened_move = false
	_refresh_active_tile_overlays(arena)


func _get_opponent_pawns(mover: TacticsPawn) -> Array[TacticsPawn]:
	var opponent_pawns: Array[TacticsPawn] = []
	if not mover or not is_instance_valid(mover):
		return opponent_pawns

	var mover_team: Node = mover.get_parent()
	if not mover_team or not is_instance_valid(mover_team):
		return opponent_pawns

	var roster_root: Node = mover_team.get_parent()
	if not roster_root or not is_instance_valid(roster_root):
		return opponent_pawns

	for team: Node in roster_root.get_children():
		if team == mover_team:
			continue
		for child: Node in team.get_children():
			if child is TacticsPawn:
				var pawn: TacticsPawn = child as TacticsPawn
				if pawn and is_instance_valid(pawn) and pawn.is_alive():
					opponent_pawns.append(pawn)

	return opponent_pawns


func _is_player_controlled_pawn(pawn: TacticsPawn) -> bool:
	if not pawn or not is_instance_valid(pawn):
		return false
	var team: Node = pawn.get_parent()
	return team != null and is_instance_valid(team) and String(team.name) == "TacticsPlayer"
