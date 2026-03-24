class_name TacticsParticipantCombatService
extends RefCounted
## Service class for handling combat-related actions
## 
## Parent: [TacticsParticipantService]

## Resource containing participant data and configurations
var res: TacticsParticipantResource
## Resource for camera-related data and configurations
var camera: TacticsCameraResource
## Resource for control-related data and configurations
var controls: TacticsControlsResource


## Initializes the TacticsParticipantCombatService
##
## @param _res: The TacticsParticipantResource to use
## @param _camera: The TacticsCameraResource to use
## @param _controls: The TacticsControlsResource to use
func _init(_res: TacticsParticipantResource, _camera: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	camera = _camera
	controls = _controls


## Handles the attack action of a pawn
##
## @param delta: Time elapsed since the last frame
## @param is_player: Whether the attacking pawn belongs to the player
func attack_pawn(delta: float, is_player: bool) -> void:
	var acting_pawn: TacticsPawn = res.curr_pawn
	if not acting_pawn or not is_instance_valid(acting_pawn):
		res.attackable_pawn = null
		res.stage = res.STAGE_SELECT_PAWN
		return

	var target_pawn: TacticsPawn = res.attackable_pawn
	if target_pawn and (not is_instance_valid(target_pawn) or not target_pawn.is_alive()):
		target_pawn = null
		res.attackable_pawn = null

	# Handle case when no attackable pawn is available
	if not target_pawn:
		acting_pawn.res.wait_delay = 0.0
		acting_pawn.res.set_attacking(false)
		acting_pawn.refresh_action_state()
	else:
		# Spend ACT once at the beginning of the attack action.
		if is_zero_approx(acting_pawn.res.wait_delay):
			if not acting_pawn.spend_act(float(TacticsConfig.action_cost.attack)):
				res.stage = res.STAGE_SELECT_PAWN if not is_player else res.STAGE_SHOW_ACTIONS
				return
		# Attempt to attack the target pawn
		if not acting_pawn.attack_target_pawn(target_pawn, delta):
			return
		# Hide actions menu and focus camera on attacking pawn
		controls.set_actions_menu_visibility(false, target_pawn)
		camera.target = acting_pawn
	
	# Reset attackable pawn
	res.attackable_pawn = null
	# Reset opponent stats display
	if res.display_opponent_stats:
		res.display_opponent_stats = false
	
	# Determine next stage based on current pawn's ability to act and whether it's a player pawn
	if not acting_pawn.can_act() or not is_player:
		res.stage = res.STAGE_SELECT_PAWN
	elif acting_pawn.can_act() and is_player:
		res.stage = res.STAGE_SHOW_ACTIONS
