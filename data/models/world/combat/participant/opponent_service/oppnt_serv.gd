class_name TacticsOpponentService
extends RefCounted
## Service class for TacticsOpponent

## Resource containing participant data and configurations
var res: TacticsParticipantResource
## Resource for camera-related data and configurations
var camera: TacticsCameraResource
## Resource for control-related data and configurations
var controls: TacticsControlsResource
## Reference to the TacticsArena node
var arena: TacticsArena


## Initializes the TacticsOpponentService
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


## Checks if all opponent pawns are properly configured
##
## @param opponent: The TacticsOpponent node to check
## @return: Whether all pawns are configured
func is_pawn_configured(opponent: TacticsOpponent) -> bool:
	for pawn: TacticsPawn in opponent.get_children():
		if not pawn.center():
			return false
	return true


## Selects a pawn for the opponent to control
##
## @param opponent: The TacticsOpponent node
func choose_pawn(opponent: TacticsOpponent) -> void:
	arena.reset_all_tile_markers()
	for p: TacticsPawn in opponent.get_children():
		if p.can_act() and p.is_alive():
			res.curr_pawn = p
			res.stage = res.STAGE_SHOW_ACTIONS
			return


## Initiates the opponent's pawn to chase the nearest enemy
##
## @param opponent: The TacticsOpponent node
## @param player_node: The player's node
func chase_nearest_enemy(opponent: TacticsOpponent, player_node: Node) -> void:
	if not res.curr_pawn or not is_instance_valid(res.curr_pawn):
		res.stage = res.STAGE_SELECT_PAWN
		return
	if res.curr_pawn.res.can_move:
		var curr_tile: TacticsTile = res.curr_pawn.get_tile()
		if not curr_tile:
			res.stage = res.STAGE_SELECT_PAWN
			return
		arena.reset_all_tile_markers()
		arena.process_surrounding_tiles(curr_tile, float(res.curr_pawn.stats.movement), float(res.curr_pawn.stats.jump), opponent.get_children(), res.curr_pawn.stats.can_fly)
		arena.mark_reachable_tiles(curr_tile, res.curr_pawn.stats.movement)
		
		var to: TacticsTile = arena.get_nearest_target_adjacent_tile(res.curr_pawn, player_node.get_children())
		if not to:
			res.stage = res.STAGE_SELECT_PAWN
			return
		res.curr_pawn.res.pathfinding_tilestack = arena.get_pathfinding_tilestack(to)
		camera.target = to
		if DebugLog.debug_enabled:
			print_rich("[color=orange]", res.curr_pawn, " moving to [i]", to, "[/i][/color]")
			print_rich("[color=orange]Through: [i]", res.curr_pawn.res.pathfinding_tilestack, "[/i][/color]")
			print_rich("[color=cyan]Camera target updated to destination tile.[/color]")
		res.stage = res.STAGE_SHOW_MOVEMENTS
	else:
		res.stage = res.STAGE_SELECT_PAWN
		push_error("Tried to make a pawn that cannot move chase nearest enemy: ", res.curr_pawn)


## Checks if the opponent's pawn has finished moving
func is_pawn_done_moving() -> void:
	if not res.curr_pawn or not is_instance_valid(res.curr_pawn):
		res.stage = res.STAGE_SELECT_PAWN
		return
	if res.curr_pawn.res.pathfinding_tilestack.is_empty():
		if DebugLog.debug_enabled:
			print_rich("[color=orange]Pawn is done moving.[/color]")
		res.stage = res.STAGE_SELECT_LOCATION


## Selects a pawn for the opponent to attack
func choose_pawn_to_attack() -> void:
	if not res.curr_pawn or not is_instance_valid(res.curr_pawn):
		res.stage = res.STAGE_SELECT_PAWN
		return
	var attack_profile: AttackProfileResource = res.curr_pawn.stats.get_primary_attack()
	if attack_profile == null:
		push_error("TacticsOpponentService.choose_pawn_to_attack: primary attack is null.")
		res.stage = res.STAGE_SELECT_PAWN
		return
	var attack_errors: Array[String] = attack_profile.validate()
	if not attack_errors.is_empty():
		push_error("TacticsOpponentService.choose_pawn_to_attack: invalid attack profile: %s" % "; ".join(attack_errors))
		res.stage = res.STAGE_SELECT_PAWN
		return
	res.selected_attack_slot = 0
	res.selected_attack = attack_profile
	var curr_tile: TacticsTile = res.curr_pawn.get_tile()
	if not curr_tile:
		res.stage = res.STAGE_SELECT_PAWN
		return
	arena.reset_all_tile_markers()
	arena.mark_attackable_tiles(curr_tile, float(attack_profile.range), attack_profile)
	
	res.attackable_pawn = arena.get_weakest_attackable_pawn(res.targets.get_children())
	if res.attackable_pawn:
		res.selected_attack_datum = res.attackable_pawn.get_tile()
		if DebugLog.debug_enabled:
			print_rich("[color=orange]Weakest target detected:", res.attackable_pawn, "[/color]")
		controls.set_actions_menu_visibility(true, res.attackable_pawn)
		camera.target = res.attackable_pawn
	else:
		if DebugLog.debug_enabled:
			print_rich("[color=orange]No target detected.[/color]")
		
	res.stage = res.STAGE_MOVE_PAWN
