class_name TacticsControlsSelectionService
extends RefCounted

var participant: TacticsParticipantResource
var arena: TacticsArenaResource
var controls: TacticsControlsResource
var t_cam: TacticsCameraResource
var input_service: TacticsControlsInputService

func _init(_participant: TacticsParticipantResource, _arena: TacticsArenaResource, _controls: TacticsControlsResource, _t_cam: TacticsCameraResource, _input_service: TacticsControlsInputService) -> void:
	participant = _participant
	arena = _arena
	controls = _controls
	t_cam = _t_cam
	input_service = _input_service

func select_pawn(player: TacticsPlayer, ctrl: TacticsControls) -> void:
	arena.reset_all_tile_markers()
	if ctrl.curr_pawn:
		controls.set_actions_menu_visibility(false, participant.curr_pawn)
		controls.set_attack_types_menu_visibility(false, participant.curr_pawn)
		ctrl.curr_pawn.show_pawn_stats(false)

	ctrl.curr_pawn = _select_hovered_pawn(ctrl)
	if not ctrl.curr_pawn:
		return
	ctrl.curr_pawn.show_pawn_stats(true)

	if Input.is_action_just_pressed("ui_accept") and ctrl.curr_pawn.can_act():
		if ctrl.curr_pawn in player.get_children():
			_activate_player_pawn(ctrl, ctrl.curr_pawn)


func try_reselect_active_pawn(player: TacticsPlayer, ctrl: TacticsControls, allow_tile_cancel: bool = false) -> void:
	if not participant.curr_pawn or not is_instance_valid(participant.curr_pawn) or not participant.curr_pawn.is_alive():
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return

	var hovered_pawn: TacticsPawn = input_service.get_3d_canvas_mouse_position(2, ctrl) as TacticsPawn
	var hovered_tile: TacticsTile = input_service.get_3d_canvas_mouse_position(1, ctrl) if hovered_pawn == null else hovered_pawn.get_tile()
	arena.mark_hover_tile(hovered_tile)

	if hovered_pawn and hovered_pawn in player.get_children() and hovered_pawn.can_act():
		_activate_player_pawn(ctrl, hovered_pawn)
		return

	if allow_tile_cancel and hovered_tile and hovered_pawn == null:
		_cancel_active_selection(ctrl)

func select_attack_type(ctrl: TacticsControls) -> void:
	if not participant.curr_pawn or not is_instance_valid(participant.curr_pawn):
		participant.clear_attack_selection()
		participant.stage = participant.STAGE_SELECT_PAWN
		return
	# Keep actions visible so Cancel can back out to the action menu.
	controls.set_actions_menu_visibility(true, participant.curr_pawn)
	controls.set_attack_types_menu_visibility(true, participant.curr_pawn)
	ctrl.get_node("HBox/Actions/Move").disabled = true
	ctrl.get_node("HBox/Actions/Attack").disabled = true
	ctrl.get_node("HBox/Actions/Guard").disabled = true
	ctrl.get_node("HBox/Actions/Debug_next_turn").disabled = true
	ctrl.get_node("HBox/Actions/Cancel").disabled = false

func choose_attack_type(slot_index: int) -> void:
	if not participant.curr_pawn or not is_instance_valid(participant.curr_pawn):
		participant.clear_attack_selection()
		participant.stage = participant.STAGE_SELECT_PAWN
		return
	var attack = participant.curr_pawn.stats.get_attack(slot_index)
	if attack == null:
		return
	var attack_errors: Array[String] = attack.validate()
	if not attack_errors.is_empty():
		push_error("TacticsControlsSelectionService.choose_attack_type: invalid attack profile: %s" % "; ".join(attack_errors))
		return
	participant.selected_attack_slot = slot_index
	participant.selected_attack = attack
	participant.selected_attack_datum = null
	participant.attackable_pawn = null
	participant.stage = participant.STAGE_DISPLAY_TARGETS

func select_pawn_to_attack(ctrl: TacticsControls) -> void:
	if not participant.curr_pawn or not is_instance_valid(participant.curr_pawn):
		participant.attackable_pawn = null
		participant.clear_attack_selection()
		participant.stage = participant.STAGE_SELECT_PAWN
		return
	if participant.selected_attack == null:
		push_error("TacticsControlsSelectionService.select_pawn_to_attack: selected_attack is null.")
		participant.stage = participant.STAGE_SELECT_ATTACK_TYPE
		return
	if not _is_attack_profile_valid(participant.selected_attack):
		participant.stage = participant.STAGE_SELECT_ATTACK_TYPE
		return

	_refresh_live_attack_context(participant.selected_attack)
	controls.set_actions_menu_visibility(true, participant.curr_pawn)
	controls.set_attack_types_menu_visibility(false, participant.curr_pawn)
	if participant.attackable_pawn:
		controls.set_actions_menu_visibility(false, participant.attackable_pawn)
		participant.attackable_pawn.show_pawn_stats(false)

	var tile: TacticsTile = _select_hovered_tile(ctrl)
	var arena_node: TacticsArena = participant.curr_pawn.get_node_or_null("%TacticsArena")
	if arena_node:
		arena_node.mark_attack_area_preview(participant.curr_pawn, tile, participant.selected_attack)
	var occupier: Object = tile.get_tile_occupier() if tile else null
	var hovered_target: TacticsPawn = occupier as TacticsPawn
	participant.attackable_pawn = hovered_target if tile and tile.attackable and _is_valid_attack_target(participant.curr_pawn, hovered_target) else null
	if participant.attackable_pawn:
		controls.set_actions_menu_visibility(true, participant.attackable_pawn)
		participant.attackable_pawn.show_pawn_stats(true)
	if Input.is_action_just_pressed("ui_accept") and tile and tile.attackable:
		participant.selected_attack_datum = tile
		t_cam.target = participant.attackable_pawn if participant.attackable_pawn else tile
		participant.stage = participant.STAGE_ATTACK


func _is_valid_attack_target(attacker: TacticsPawn, target: TacticsPawn) -> bool:
	if not attacker or not is_instance_valid(attacker):
		return false
	if not target or not is_instance_valid(target) or not target.is_alive():
		return false
	return true

func player_wants_to_move() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	_clear_attack_preview()
	participant.clear_attack_selection()
	if not participant.curr_pawn or not participant.curr_pawn.can_pawn_move():
		return
	participant.stage = participant.STAGE_SHOW_MOVEMENTS

func player_wants_to_cancel() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false

	if participant.stage == participant.STAGE_SELECT_ATTACK_TARGET or participant.stage == participant.STAGE_DISPLAY_TARGETS:
		_clear_attack_preview()
		participant.attackable_pawn = null
		participant.selected_attack_datum = null
		participant.stage = participant.STAGE_SELECT_ATTACK_TYPE
		return
	if participant.stage == participant.STAGE_SELECT_ATTACK_TYPE:
		_clear_attack_preview()
		participant.clear_attack_selection()
		participant.stage = participant.STAGE_SHOW_ACTIONS
		return
	if participant.stage == participant.STAGE_SHOW_ACTIONS:
		_clear_attack_preview()
		participant.clear_attack_selection()
		participant.stage = participant.STAGE_SELECT_PAWN
		return
	participant.stage = participant.STAGE_SHOW_ACTIONS if participant.stage > participant.STAGE_SHOW_ACTIONS else participant.STAGE_SELECT_PAWN

func player_wants_to_guard() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	_clear_attack_preview()
	participant.clear_attack_selection()
	if not participant.curr_pawn or not is_instance_valid(participant.curr_pawn):
		return
	if not participant.curr_pawn.can_activate_guard():
		return
	if not participant.curr_pawn.spend_act(float(TacticsConfig.action_cost.guard)):
		return
	if not participant.curr_pawn.activate_guard():
		participant.curr_pawn.stats.curr_act = minf(participant.curr_pawn.stats.max_act, participant.curr_pawn.stats.curr_act + float(TacticsConfig.action_cost.guard))
		participant.curr_pawn.refresh_action_state()
		return
	participant.curr_pawn.refresh_action_state()
	participant.stage = participant.STAGE_SHOW_ACTIONS

func player_wants_to_skip_turn() -> void:
	if participant.display_opponent_stats:
		participant.display_opponent_stats = false
	_clear_attack_preview()
	participant.clear_attack_selection()
	participant.skip_turn()

func player_wants_to_attack() -> void:
	if not participant.curr_pawn or not participant.curr_pawn.can_pawn_attack():
		return
	_clear_attack_preview()
	participant.attackable_pawn = null
	participant.clear_attack_selection()
	participant.stage = participant.STAGE_SELECT_ATTACK_TYPE

func select_new_location(ctrl: TacticsControls) -> void:
	_refresh_live_move_context(ctrl)
	var acting_pawn: TacticsPawn = participant.curr_pawn if participant.curr_pawn and is_instance_valid(participant.curr_pawn) else ctrl.curr_pawn
	if not acting_pawn or not acting_pawn.is_alive():
		participant.stage = participant.STAGE_SELECT_PAWN
		return
	var tile: TacticsTile = input_service.get_3d_canvas_mouse_position(1, ctrl)
	arena.mark_hover_tile(tile)
	if Input.is_action_just_pressed("ui_accept") and tile and tile.reachable:
		_refresh_live_move_context(ctrl)
		var path: Array = arena.get_pathfinding_tilestack(tile)
		if path.is_empty():
			return
		if not _path_has_movement(path, acting_pawn.global_position):
			return
		if not acting_pawn.spend_act(float(TacticsConfig.action_cost.move)):
			return
		acting_pawn.break_guard()
		acting_pawn.res.mark_move_transaction(acting_pawn.global_position)
		acting_pawn.res.pathfinding_tilestack = path
		ctrl.curr_pawn = acting_pawn
		t_cam.target = tile
		participant.stage = participant.STAGE_MOVE_PAWN


func _select_hovered_pawn(ctrl: TacticsControls) -> PhysicsBody3D:
	var pawn: TacticsPawn = input_service.get_3d_canvas_mouse_position(2, ctrl)
	var tile: TacticsTile = input_service.get_3d_canvas_mouse_position(1, ctrl) if not pawn else pawn.get_tile()
	arena.mark_hover_tile(tile)
	return pawn if pawn else tile.get_tile_occupier() if tile else null


func _select_hovered_tile(ctrl: TacticsControls) -> TacticsTile:
	var pawn: TacticsPawn = input_service.get_3d_canvas_mouse_position(2, ctrl)
	var tile: TacticsTile = input_service.get_3d_canvas_mouse_position(1, ctrl) if not pawn else pawn.get_tile()
	arena.mark_hover_tile(tile)
	return tile

func _refresh_live_move_context(ctrl: TacticsControls) -> void:
	var pawn: TacticsPawn = participant.curr_pawn if participant.curr_pawn and is_instance_valid(participant.curr_pawn) else ctrl.curr_pawn
	if not pawn or not is_instance_valid(pawn) or not pawn.is_alive():
		return
	var curr_tile: TacticsTile = pawn.get_tile()
	if not curr_tile:
		return
	var arena_node: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if not arena_node:
		return

	arena_node.reset_all_tile_markers()
	arena_node.process_surrounding_tiles(curr_tile, float(pawn.stats.movement), float(pawn.stats.jump), pawn.get_parent().get_children(), pawn.stats.can_fly)
	arena_node.mark_reachable_tiles(curr_tile, pawn.stats.movement)


func _refresh_live_attack_context(attack: AttackProfileResource) -> void:
	var pawn: TacticsPawn = participant.curr_pawn
	if not pawn or not is_instance_valid(pawn) or not pawn.is_alive():
		return
	var curr_tile: TacticsTile = pawn.get_tile()
	if not curr_tile:
		return
	var arena_node: TacticsArena = pawn.get_node_or_null("%TacticsArena")
	if not arena_node:
		return

	arena_node.reset_all_tile_markers()
	arena_node.mark_attackable_tiles(curr_tile, float(attack.range), attack)


func _is_attack_profile_valid(attack: AttackProfileResource) -> bool:
	if attack == null:
		push_error("TacticsControlsSelectionService: attack profile is null.")
		return false
	var attack_errors: Array[String] = attack.validate()
	if attack_errors.is_empty():
		return true
	push_error("TacticsControlsSelectionService: invalid attack profile: %s" % "; ".join(attack_errors))
	return false


func _path_has_movement(path: Array, from_position: Vector3) -> bool:
	for step: Variant in path:
		if step is Vector3 and from_position.distance_to(step) > 0.02:
			return true
	return false


func _clear_attack_preview() -> void:
	if not participant.curr_pawn or not is_instance_valid(participant.curr_pawn):
		return
	var arena_node: TacticsArena = participant.curr_pawn.get_node_or_null("%TacticsArena")
	if arena_node:
		arena_node.mark_attack_area_preview(participant.curr_pawn, null, null)


func _activate_player_pawn(ctrl: TacticsControls, pawn: TacticsPawn) -> void:
	if not pawn or not is_instance_valid(pawn):
		return

	if participant.curr_pawn and is_instance_valid(participant.curr_pawn) and participant.curr_pawn != pawn:
		controls.set_actions_menu_visibility(false, participant.curr_pawn)
		controls.set_attack_types_menu_visibility(false, participant.curr_pawn)
		participant.curr_pawn.show_pawn_stats(false)

	_clear_attack_preview()
	participant.attackable_pawn = null
	participant.clear_attack_selection()
	participant.curr_pawn = pawn
	ctrl.curr_pawn = pawn
	pawn.show_pawn_stats(true)
	t_cam.target = pawn
	controls.set_attack_types_menu_visibility(false, pawn)
	controls.set_actions_menu_visibility(true, pawn)
	participant.stage = participant.STAGE_SHOW_ACTIONS


func _cancel_active_selection(ctrl: TacticsControls) -> void:
	_clear_attack_preview()
	participant.attackable_pawn = null
	participant.clear_attack_selection()

	if participant.curr_pawn and is_instance_valid(participant.curr_pawn):
		controls.set_actions_menu_visibility(false, participant.curr_pawn)
		controls.set_attack_types_menu_visibility(false, participant.curr_pawn)
		participant.curr_pawn.show_pawn_stats(false)

	participant.curr_pawn = null
	ctrl.curr_pawn = null
	participant.stage = participant.STAGE_SELECT_PAWN
