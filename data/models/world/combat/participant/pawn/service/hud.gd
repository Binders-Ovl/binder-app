class_name TacticsPawnHudService
extends RefCounted
## Service class for managing the HUD (Heads-Up Display) of a pawn in the tactics game


## Updates the health display of the pawn's character UI
##
## @param pawn: The TacticsPawn whose health display needs to be updated
func update_character_health(pawn: TacticsPawn) -> void:
	var root: SubViewport = pawn.character.get_node_or_null("CharacterUI/HUDRoot") as SubViewport
	if root == null:
		return

	var name_label: Label = root.get_node_or_null("NameLabel") as Label
	var hp_bar: Node = root.get_node_or_null("BarCluster/BarsColumn/HPBar")
	var act_bar: Node = root.get_node_or_null("BarCluster/BarsColumn/ACTBar")
	var guard_icon: Node = root.get_node_or_null("BarCluster/GuardIcon")
	if name_label == null or hp_bar == null or act_bar == null or guard_icon == null:
		return
	if not hp_bar.has_method("set_values") or not act_bar.has_method("set_values") or not guard_icon.has_method("set_guard_state"):
		return

	name_label.text = pawn.stats.override_name if pawn.stats.override_name != "" else pawn.stats.expertise
	hp_bar.call("set_values", pawn.stats.curr_health, pawn.stats.max_health)
	act_bar.call("set_values", int(pawn.stats.curr_act), int(pawn.stats.max_act))
	guard_icon.call("set_guard_state", pawn.is_guarding(), pawn.get_guard_ratio_remaining())


## Applies a tint to the pawn's sprite when it's unable to act
##
## @param pawn: The TacticsPawn to apply the tint to
func tint_when_unable_to_act(pawn: TacticsPawn) -> void:
	pawn.character.set_action_available(pawn.can_act())
