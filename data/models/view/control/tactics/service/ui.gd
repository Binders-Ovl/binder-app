class_name TacticsUIService
extends RefCounted
## Service class for managing UI-related functionalities in the Tactics game.

## Reference to the TacticsControlsResource.
var controls: TacticsControlsResource


## Initializes the TacticsUIService with the necessary controls resource.
func _init(_controls: TacticsControlsResource) -> void:
	controls = _controls


## Updates the controller hints based on the current input device.
func update_controller_hints(ctrl: TacticsControls) -> void:
	if controls.is_joystick:
		ctrl.get_node("%ControllerHints").texture = ctrl.layout_xbox # Set Xbox layout if using joystick
	else:
		ctrl.get_node("%ControllerHints").texture = ctrl.layout_pc # Set PC layout otherwise


## Sets the visibility of the actions menu and updates action button states.
func set_actions_menu_visibility(v: bool, p: TacticsPawn, ctrl: TacticsControls) -> void:
	if not ctrl.get_node("HBox/Actions").visible:
		ctrl.get_node("HBox/Actions/Move").grab_focus() # Focus on Move action if menu wasn't visible
	
	if not p:
		ctrl.get_node("HBox/Actions").visible = false
		return # Exit if no pawn is provided
	
	p.refresh_action_state()
	ctrl.get_node("HBox/Actions").visible = v and p.can_act() # Show menu if pawn can act
	
	# Update action button states based on pawn's capabilities
	ctrl.get_node("HBox/Actions/Move").disabled = not p.res.can_move
	ctrl.get_node("HBox/Actions/Attack").disabled = not p.res.can_attack
	ctrl.get_node("HBox/Actions/Guard").disabled = false
	ctrl.get_node("HBox/Actions/Debug_next_turn").disabled = false
	ctrl.get_node("HBox/Actions/Cancel").disabled = false


## Sets the visibility of attack type menu and updates labels/states.
func set_attack_types_menu_visibility(v: bool, p: TacticsPawn, ctrl: TacticsControls) -> void:
	var node: Control = ctrl.get_node("HBox/AttackTypes")
	if not p:
		node.visible = false
		return
	var a1 = p.stats.get_attack(0)
	var a2 = p.stats.get_attack(1)
	var a3 = p.stats.get_attack(2)
	ctrl.get_node("HBox/AttackTypes/AttackType1").text = str(a1.get("display_name")) if a1 else "Attack 1"
	ctrl.get_node("HBox/AttackTypes/AttackType2").text = str(a2.get("display_name")) if a2 else "Attack 2"
	ctrl.get_node("HBox/AttackTypes/AttackType3").text = str(a3.get("display_name")) if a3 else "Attack 3"
	ctrl.get_node("HBox/AttackTypes/AttackType1").disabled = a1 == null
	ctrl.get_node("HBox/AttackTypes/AttackType2").disabled = a2 == null
	ctrl.get_node("HBox/AttackTypes/AttackType3").disabled = a3 == null
	node.visible = v and p.can_act()
