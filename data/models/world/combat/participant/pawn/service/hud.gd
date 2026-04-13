class_name TacticsPawnHudService
extends RefCounted
## Service class for managing the HUD (Heads-Up Display) of a pawn in the tactics game


## Updates the health display of the pawn's character UI
##
## @param pawn: The TacticsPawn whose health display needs to be updated
func update_character_health(pawn: TacticsPawn) -> void:
	var _health_label: Label3D = pawn.character.get_node("CharacterUI/HealthLabel")
	var _mana_label: Label3D = pawn.character.get_node("CharacterUI/ManaLabel")
	var _act_label: Label3D = pawn.character.get_node("CharacterUI/ActLabel")
	var _name_label: Label3D = pawn.character.get_node("CharacterUI/NameLabel")
	
	_name_label.text = pawn.stats.override_name if pawn.stats.override_name != "" else pawn.stats.expertise
	_health_label.text = "HP  %s %d/%d" % [_bar(pawn.stats.curr_health, pawn.stats.max_health), pawn.stats.curr_health, pawn.stats.max_health]
	_mana_label.text = "MP  %s %d/%d" % [_bar(pawn.stats.curr_mana, pawn.stats.max_mana), pawn.stats.curr_mana, pawn.stats.max_mana]
	_act_label.text = "ACT %s %d/%d" % [_bar(int(pawn.stats.curr_act), int(pawn.stats.max_act)), int(pawn.stats.curr_act), int(pawn.stats.max_act)]
	_act_label.modulate = Color(1.0, 0.97, 0.5) if pawn.stats.curr_act >= pawn.stats.max_act else Color(1.0, 1.0, 1.0)


## Applies a tint to the pawn's sprite when it's unable to act
##
## @param pawn: The TacticsPawn to apply the tint to
func tint_when_unable_to_act(pawn: TacticsPawn) -> void:
	pawn.character.set_action_available(pawn.can_act())


func _bar(value: int, max_value: int, width: int = 10) -> String:
	if max_value <= 0:
		return "[----------]"
	var ratio: float = clampf(float(value) / float(max_value), 0.0, 1.0)
	var filled: int = int(round(ratio * width))
	return "[%s%s]" % ["#".repeat(filled), "-".repeat(width - filled)]
