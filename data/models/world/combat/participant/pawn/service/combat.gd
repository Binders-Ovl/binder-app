class_name TacticsPawnCombatService
extends RefCounted
## Service class for managing combat actions of pawns in the tactics game


## Executes an attack from one pawn to another
##
## @param pawn: The attacking TacticsPawn
## @param target_pawn: The TacticsPawn being attacked
## @param delta: Time elapsed since the last frame
## @param target_position: Optional explicit aim point when no pawn is targeted
## @return: Whether the attack was completed
func attack_target_pawn(pawn: TacticsPawn, target_pawn: TacticsPawn, delta: float, target_position: Vector3 = Vector3.INF) -> bool:
	var has_target_pawn: bool = target_pawn != null and is_instance_valid(target_pawn) and target_pawn.is_alive()
	var aim_position: Vector3 = target_pawn.global_position if has_target_pawn else target_position
	if aim_position == Vector3.INF:
		pawn.res.wait_delay = 0.0
		pawn.res.set_attacking(false)
		return true

	pawn.res.set_attacking(true)
	# Make the attacking pawn face the target
	pawn.serv.movement.look_at_direction(pawn, aim_position - pawn.global_position)

	if pawn.res.wait_delay < TacticsPawnResource.MIN_TIME_FOR_ATTACK:
		pawn.res.wait_delay += delta

	if pawn.res.wait_delay < TacticsPawnResource.MIN_TIME_FOR_ATTACK:
		return false
	
	# Reset the wait delay and return true to indicate the attack is complete
	pawn.res.wait_delay = 0.0
	pawn.res.set_attacking(false)
	return true
