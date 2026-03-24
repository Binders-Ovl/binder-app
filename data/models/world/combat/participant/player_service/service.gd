class_name TacticsPlayerService
extends RefCounted
## Service class for TacticsPlayer

## Resource containing participant data and configurations
var res: TacticsParticipantResource
## Resource for camera-related data and configurations
var camera: TacticsCameraResource
## Resource for control-related data and configurations
var controls: TacticsControlsResource
## Reference to the TacticsArena node
var arena: TacticsArena


## Initializes the TacticsPlayerService
##
## @param _res: The TacticsParticipantResource to use
## @param _camera: The TacticsCameraResource to use
## @param _controls: The TacticsControlsResource to use
## @param _arena: The TacticsArena node to use
func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource, _arena: TacticsArena) -> void:
	res = _res
	camera = _camera
	controls = _controls
	arena = _arena


func _get_active_pawn() -> TacticsPawn:
	var p: TacticsPawn = res.curr_pawn
	if not p or not is_instance_valid(p) or not p.is_alive():
		return null
	return p


func _fallback_to_pawn_selection() -> void:
	res.curr_pawn = null
	res.attackable_pawn = null
	res.display_opponent_stats = false
	controls.set_actions_menu_visibility(false, null)
	res.stage = res.STAGE_SELECT_PAWN


## Toggles the display of enemy pawn stats
##
## @param opponent_node: The opponent's node containing enemy pawns
func toggle_enemy_stats(opponent_node: Node) -> void:
	var enemy_pawns: Array = opponent_node.get_children()
	
	if res.display_opponent_stats:
		for p: TacticsPawn in enemy_pawns:
			p.res.pawn_hud_enabled = true
			p.show_pawn_stats(true)
	else:
		for p: TacticsPawn in enemy_pawns:
			if p.res.pawn_hud_enabled == true:
				p.show_pawn_stats(false)
				p.res.pawn_hud_enabled = false


## Checks if all player pawns are properly configured
##
## @param player: The TacticsPlayer node to check
## @return: Whether all pawns are configured
func is_pawn_configured(player: TacticsPlayer) -> bool:
	for pawn: TacticsPawn in player.get_children():
		if pawn is TacticsPawn:
			if not pawn.center():
				return false
	return true


## Displays available actions for the current pawn
func show_available_pawn_actions() -> void:
	var p: TacticsPawn = _get_active_pawn()
	if not p:
		_fallback_to_pawn_selection()
		return

	controls.set_actions_menu_visibility(true, p)
	arena.reset_all_tile_markers()
	var tile: TacticsTile = p.get_tile()
	if not tile:
		_fallback_to_pawn_selection()
		return
	arena.mark_hover_tile(tile)


## Displays available movement options for the current pawn
func show_available_movements() -> void:
	arena.reset_all_tile_markers()
	
	var p: TacticsPawn = _get_active_pawn()
	if not p:
		_fallback_to_pawn_selection()
		return

	var curr_tile: TacticsTile = p.get_tile()
	if not curr_tile:
		_fallback_to_pawn_selection()
		return

	camera.target = p
	arena.process_surrounding_tiles(curr_tile, float(p.stats.movement), float(p.stats.jump), p.get_parent().get_children(), p.stats.can_fly)
	arena.mark_reachable_tiles(curr_tile, p.stats.movement)
	res.stage = res.STAGE_SELECT_LOCATION


## Displays attackable targets for the current pawn
func display_attackable_targets() -> void:
	arena.reset_all_tile_markers()
	var p: TacticsPawn = _get_active_pawn()
	if not p:
		_fallback_to_pawn_selection()
		return

	var curr_tile: TacticsTile = p.get_tile()
	if not curr_tile:
		_fallback_to_pawn_selection()
		return
	
	res.display_opponent_stats = true
	
	camera.target = p
	arena.process_surrounding_tiles(curr_tile, float(p.stats.attack_range), 9999.0, [], false, true)
	arena.mark_attackable_tiles(curr_tile, float(p.stats.attack_range))
	res.stage = res.STAGE_SELECT_ATTACK_TARGET


## Initiates the movement of the current pawn
func move_pawn() -> void:
	var p: TacticsPawn = _get_active_pawn()
	if not p:
		_fallback_to_pawn_selection()
		return

	controls.set_actions_menu_visibility(false, p)
	if p.res.pathfinding_tilestack.is_empty():
		res.stage = res.STAGE_SELECT_PAWN if not p.can_act() else res.STAGE_SHOW_ACTIONS
