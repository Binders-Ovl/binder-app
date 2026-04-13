class_name TacticsControlsService
extends RefCounted
## Service class for managing tactics controls and related functionalities.

## Reference to the TacticsControlsResource.
var controls: TacticsControlsResource
## Reference to the TacticsCameraResource.
var t_cam: TacticsCameraResource
## Reference to the TacticsParticipantResource.
var participant: TacticsParticipantResource
## Reference to the TacticsArenaResource.
var arena: TacticsArenaResource
## Node for capturing mouse clicks.
var input_capture: Node
## Service for handling input-related operations.
var input_service: TacticsControlsInputService
## Service for managing UI-related operations.
var ui_service: TacticsUIService
## Service for handling camera-related operations.
var camera_service: TacticsControlsCameraService
## Service for managing pawn selection operations.
var pawn_selection_service: TacticsControlsSelectionService


## Initializes the TacticsControlsService with necessary resources and services.
func _init(_controls: TacticsControlsResource, _t_cam: TacticsCameraResource, _participant: TacticsParticipantResource, _arena: TacticsArenaResource, _inputk_capture: Node) -> void:
	controls = _controls
	t_cam = _t_cam
	participant = _participant
	arena = _arena
	input_capture = _inputk_capture
	input_service = TacticsControlsInputService.new(controls, input_capture)
	ui_service = TacticsUIService.new(controls)
	camera_service = TacticsControlsCameraService.new(t_cam)
	pawn_selection_service = TacticsControlsSelectionService.new(participant, arena, controls, t_cam, input_service)


## Sets up signal connections and performs initial checks.
func setup(ctrl: TacticsControls) -> void:
	if not controls:
		push_error("TacticsControls needs a ControlResource from /data/models/view/controls/tactics/")
	else:
		controls.connect("called_set_actions_menu_visibility", ctrl.set_actions_menu_visibility)
		controls.connect("called_set_attack_types_menu_visibility", ctrl.set_attack_types_menu_visibility)
		controls.connect("called_set_cursor_shape_to_move", ctrl.set_cursor_shape_to_move)
		controls.connect("called_set_cursor_shape_to_arrow", ctrl.set_cursor_shape_to_arrow)
		controls.connect("called_select_pawn", ctrl.select_pawn)
		controls.connect("called_select_pawn_to_attack", ctrl.select_pawn_to_attack)
		controls.connect("called_select_attack_type", ctrl.select_attack_type)
		controls.connect("called_select_new_location", ctrl.select_new_location)
		controls.connect("called_try_reselect_active_pawn", ctrl.try_reselect_active_pawn)
	if not t_cam:
		push_error("TacticsCamera needs a CameraResource (T Cam) from /data/models/view/camera/tactics/")
	if not arena:
		push_error("TacticsControls needs an ArenaResource from /data/models/world/combat/arena/")


## Performs physics processing tasks.
func physics_process(_delta: float, ctrl: TacticsControls) -> void:
	input_service.update_mouse_mode()
	ui_service.update_controller_hints(ctrl)


## Handles input events.
func handle_input(event: InputEvent, _ctrl: TacticsControls) -> void:
	input_service.handle_input(event)
	if event.is_action_pressed("ui_cancel"):
		var key_event: InputEventKey = event as InputEventKey
		if key_event and key_event.echo:
			return
		var can_cancel_from_stage: bool = participant.stage in [
			participant.STAGE_SHOW_ACTIONS,
			participant.STAGE_SHOW_MOVEMENTS,
			participant.STAGE_SELECT_LOCATION,
			participant.STAGE_SELECT_ATTACK_TYPE,
			participant.STAGE_DISPLAY_TARGETS,
			participant.STAGE_SELECT_ATTACK_TARGET,
		]
		if can_cancel_from_stage:
			pawn_selection_service.player_wants_to_cancel()


## Delegates setting actions menu visibility to the UI service.
func set_actions_menu_visibility(v: bool, p: TacticsPawn, ctrl: TacticsControls) -> void:
	ui_service.set_actions_menu_visibility(v, p, ctrl)

## Delegates setting attack-types menu visibility to the UI service.
func set_attack_types_menu_visibility(v: bool, p: TacticsPawn, ctrl: TacticsControls) -> void:
	ui_service.set_attack_types_menu_visibility(v, p, ctrl)


## Delegates pawn selection to the pawn selection service.
func select_pawn(player: TacticsPlayer, ctrl: TacticsControls) -> void:
	pawn_selection_service.select_pawn(player, ctrl)


## Delegates new location selection to the pawn selection service.
func select_new_location(ctrl: TacticsControls) -> void:
	pawn_selection_service.select_new_location(ctrl)

## Attempts active pawn reselection by direct click.
func try_reselect_active_pawn(player: TacticsPlayer, ctrl: TacticsControls, allow_tile_cancel: bool = false) -> void:
	pawn_selection_service.try_reselect_active_pawn(player, ctrl, allow_tile_cancel)


## Delegates pawn attack selection to the pawn selection service.
func select_pawn_to_attack(ctrl: TacticsControls) -> void:
	pawn_selection_service.select_pawn_to_attack(ctrl)

## Delegates attack type selection stage to the pawn selection service.
func select_attack_type(ctrl: TacticsControls) -> void:
	pawn_selection_service.select_attack_type(ctrl)

## Delegates concrete attack type pick.
func choose_attack_type(slot_index: int) -> void:
	pawn_selection_service.choose_attack_type(slot_index)


## Handles player's move action.
func player_wants_to_move() -> void:
	pawn_selection_service.player_wants_to_move()


## Handles player's cancel action.
func player_wants_to_cancel() -> void:
	pawn_selection_service.player_wants_to_cancel()


## Handles player's guard action.
func player_wants_to_guard() -> void:
	pawn_selection_service.player_wants_to_guard()


## Handles player's skip turn action.
func player_wants_to_skip_turn() -> void:
	pawn_selection_service.player_wants_to_skip_turn()


## Handles player's attack action.
func player_wants_to_attack() -> void:
	pawn_selection_service.player_wants_to_attack()


## Delegates camera movement to camera service.
func move_camera(delta: float) -> void:
	camera_service.move_camera(delta, controls.is_joystick)


## Delegates 3D mouse projection to input service.
func get_3d_canvas_mouse_position(collision_mask: int, ctrl: TacticsControls) -> Object:
	return input_service.get_3d_canvas_mouse_position(collision_mask, ctrl)


## Delegates UI hover check to input service.
func is_mouse_hovering_ui_elem(ctrl: TacticsControls) -> bool:
	return input_service.is_mouse_hovering_ui_elem(ctrl)
