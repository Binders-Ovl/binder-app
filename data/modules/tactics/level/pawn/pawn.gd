class_name TacticsPawn
extends CharacterBody3D
## Represents a pawn in the tactics game, handling movement, combat, and state management

## Resource containing control-related data and configurations
@export var controls: TacticsControlsResource = load("res://data/models/view/control/tactics/control.tres")

## Resource containing pawn-specific data and configurations
var res: TacticsPawnResource
## Service handling pawn-related logic and operations
var serv: TacticsPawnService

## Reference to the Stats node, handling pawn statistics
@onready var stats: Stats = $Expertise/Stats
## The expertise (class or type) of the pawn
@onready var expertise: String = $Expertise/Stats.expertise
## Reference to the TacticsPawnSprite node, handling visual representation
@onready var feedback_pivot: Node3D = $FeedbackPivot
@onready var character: TacticsPawnSprite = $FeedbackPivot/Character
## Preferred world-space anchor for combat feedback text
@onready var damage_anchor: Marker3D = $FeedbackPivot/Character/DamageAnchor


## Initializes the TacticsPawn node
func _ready() -> void:
	res = TacticsPawnResource.new()
	serv = TacticsPawnService.new()
	serv.setup(self)
	controls.set_actions_menu_visibility(false, self)
	show_pawn_stats(false)


## Processes pawn logic every physics frame
##
## @param delta: Time elapsed since the last frame
func _physics_process(delta: float) -> void:
	serv.process(self, delta)


## Centers the pawn on its current tile
##
## @return: Whether the centering operation was successful
func center() -> bool:
	return character.adjust_to_center(self)


## Shows or hides the pawn's stats UI
##
## @param v: Whether to show (true) or hide (false) the stats
func show_pawn_stats(v: bool) -> void:
	character.get_node("CharacterUI").visible = v


## Returns the preferred combat text anchor node
func get_damage_anchor() -> Node3D:
	if damage_anchor and is_instance_valid(damage_anchor):
		return damage_anchor
	return character


## Returns world-space position for combat text popups
func get_damage_anchor_position() -> Vector3:
	var anchor: Node3D = get_damage_anchor()
	if anchor and is_instance_valid(anchor):
		return anchor.global_position
	return global_position + Vector3(0.0, 1.8, 0.0)


## Plays a scene-authored combat feedback effect on the pawn.
func play_feedback(kind: String, source: Node3D = null) -> void:
	if character and is_instance_valid(character):
		character.play_feedback(kind, source)


## Gets the tile the pawn is currently on
##
## @return: The TacticsTile the pawn is on
func get_tile() -> TacticsTile:
	var tile: Object = $Tile.get_collider()
	return tile if tile is TacticsTile and is_instance_valid(tile) else null


## Checks if the pawn is alive
##
## @return: Whether the pawn's current health is above 0
func is_alive() -> bool:
	return stats.curr_health > 0


## Checks if the pawn can move
##
## @return: Whether the pawn can move and is alive
func can_pawn_move() -> bool:
	return res.can_move and is_alive()


## Checks if the pawn can attack
##
## @return: Whether the pawn can attack and is alive
func can_pawn_attack() -> bool:
	return res.can_attack and is_alive()


## Checks if the pawn can perform any action
##
## @return: Whether the pawn can move or attack, and is alive
func can_act() -> bool:
	return (res.can_move or res.can_attack) and is_alive() and not res.is_moving and not res.is_attacking


func is_guarding() -> bool:
	return res.is_guarding


func get_guard_ratio_remaining() -> float:
	if not res.is_guarding:
		return 0.0
	var class_combat: ClassCombatResource = stats.class_combat
	if class_combat == null or class_combat.guard_time <= 0.0:
		return 0.0
	return clampf(res.guard_remaining_time / class_combat.guard_time, 0.0, 1.0)


func set_guarding(value: bool) -> void:
	res.set_guarding(value)


func can_activate_guard() -> bool:
	if not is_alive() or res.is_moving or res.is_attacking or res.is_guarding:
		return false
	if stats.curr_act < float(TacticsConfig.action_cost.guard):
		return false
	var class_combat: ClassCombatResource = stats.class_combat
	if class_combat == null:
		return false
	return class_combat.guard_time > 0.0 and res.guard_cooldown_remaining <= 0.0


func activate_guard() -> bool:
	if not can_activate_guard():
		return false
	var tile: TacticsTile = get_tile()
	var class_combat: ClassCombatResource = stats.class_combat
	if tile == null or class_combat == null:
		return false
	res.activate_guard(class_combat.guard_time, class_combat.guard_cooldown, tile.get_instance_id())
	return true


func break_guard() -> void:
	res.deactivate_guard()


func tick_guard(delta: float) -> void:
	if res.guard_cooldown_remaining > 0.0:
		res.guard_cooldown_remaining = maxf(0.0, res.guard_cooldown_remaining - delta)
	if not res.is_guarding:
		return
	var curr_tile: TacticsTile = get_tile()
	if curr_tile == null or curr_tile.get_instance_id() != res.guard_anchor_tile_id:
		break_guard()
		return
	res.guard_remaining_time = maxf(0.0, res.guard_remaining_time - delta)
	if res.guard_remaining_time <= 0.0:
		break_guard()


## Resets the pawn's turn state
func reset_turn() -> void:
	res.reset_turn()


## Ends the pawn's turn
func end_pawn_turn() -> void:
	res.end_pawn_turn()


## Initiates an attack on a target pawn
##
## @param target_pawn: The TacticsPawn to attack
## @param delta: Time elapsed since the last frame
## @param target_position: Optional explicit aim point when no pawn is targeted
## @return: Whether the attack was successful
func attack_target_pawn(target_pawn: TacticsPawn, delta: float, target_position: Vector3 = Vector3.INF) -> bool:
	return serv.attack_target_pawn(self, target_pawn, delta, target_position)


## Moves the pawn along its designated path
##
## @param delta: Time elapsed since the last frame
func move_along_path(delta: float) -> void:
	serv.movement.move_along_path(self, delta)


## Updates ACT gauge over time using STA and active timeline config.
func tick_act(delta: float) -> void:
	if not is_alive() or res.is_attacking:
		return
	var gain_per_sec: float = stats.get_act_recovery_per_sec()
	stats.curr_act = clampf(stats.curr_act + (gain_per_sec * delta), 0.0, stats.max_act)


## Recomputes move/attack availability based on current ACT and pawn state.
func refresh_action_state() -> void:
	var alive: bool = is_alive()
	var min_attack_cost: float = _get_min_attack_cost()
	res.can_move = alive and not res.is_moving and stats.curr_act >= float(TacticsConfig.action_cost.move)
	res.can_attack = alive and not res.is_moving and not res.is_attacking and stats.curr_act >= min_attack_cost


## Attempts to spend ACT from the pawn gauge.
func spend_act(cost: float) -> bool:
	if stats.curr_act < cost:
		return false
	stats.curr_act = maxf(0.0, stats.curr_act - cost)
	refresh_action_state()
	return true


func _get_min_attack_cost() -> float:
	var default_cost: float = float(TacticsConfig.action_cost.attack)
	var costs: Array[float] = []
	for idx: int in [0, 1, 2]:
		var attack = stats.get_attack(idx)
		if attack and attack.has_method("get_effective_act_cost"):
			costs.append(float(attack.call("get_effective_act_cost", default_cost)))
	if costs.is_empty():
		return default_cost
	costs.sort()
	return maxf(0.0, costs[0])
