class_name TacticsPawnCombatService
extends RefCounted
## Service class for managing combat actions of pawns in the tactics game


## Executes an attack from one pawn to another
##
## @param pawn: The attacking TacticsPawn
## @param target_pawn: The TacticsPawn being attacked
## @param delta: Time elapsed since the last frame
## @return: Whether the attack was completed
func attack_target_pawn(pawn: TacticsPawn, target_pawn: TacticsPawn, delta: float) -> bool:
	if not target_pawn or not is_instance_valid(target_pawn) or not target_pawn.is_alive():
		pawn.res.wait_delay = 0.0
		pawn.res.set_attacking(false)
		return true

	pawn.res.set_attacking(true)
	# Make the attacking pawn face the target
	pawn.serv.movement.look_at_direction(pawn, target_pawn.global_position - pawn.global_position)

	var previous_wait_delay: float = pawn.res.wait_delay
	if pawn.res.wait_delay < TacticsPawnResource.MIN_TIME_FOR_ATTACK:
		pawn.res.wait_delay += delta

	var hit_frame_time: float = TacticsPawnResource.MIN_TIME_FOR_ATTACK / 4.0
	if previous_wait_delay <= hit_frame_time and pawn.res.wait_delay > hit_frame_time:
		target_pawn.stats.apply_to_curr_health(-pawn.stats.attack_power)
		if DebugLog.debug_enabled:
			print_rich("[color=pink]Attacked ", target_pawn, " for ", pawn.stats.attack_power, " damage.[/color]")

	if pawn.res.wait_delay < TacticsPawnResource.MIN_TIME_FOR_ATTACK:
		return false
	
	# Reset the wait delay and return true to indicate the attack is complete
	pawn.res.wait_delay = 0.0
	pawn.res.set_attacking(false)
	return true
