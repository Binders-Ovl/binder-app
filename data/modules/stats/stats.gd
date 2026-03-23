class_name Stats
extends Node
## Placeholder script that essentially replicates the Pawn Expertise Model into its own self-contained Stats class. 
## 
## This class can be made into a Resource Save utility for instantiated characters, for instance. Alternatively, it could pull the appropriate data from a character save and write back to it as needed.

## Dictionary to store modifiers
var modifiers: Dictionary = {}
## Override name for the character
var override_name: String
## Expertise of the character
var expertise: String
## Current level of the character
var level: int = 1

#region Base Stats
## Movement Points (The radius the pawn can move)
var movement: int
## Jump height
var jump: int
## Maximum health
var max_health: int
## Current health
var curr_health: int
## Maximum mana
var max_mana: int
## Current mana
var curr_mana: int
## Stamina
var sta: int
## Current ACT gauge value
var curr_act: float = 0.0
## ACT gauge cap
var max_act: float = 100.0
## Sprite path
var sprite: String
#endregion

#region Offensive Stats
## Attack power
var attack_power: int
## Attack range
var attack_range: int
## Whether the actor can fly (can move through occupied tiles)
var can_fly: bool
#endregion

## Initialize stats from a StatsResource
func import_stats(stats: StatsResource) -> void:
	override_name = stats.override_name
	expertise = stats.expertise
	level = stats.level
	movement = stats.movement
	stats.set_jump()
	max_health = stats.max_health
	curr_health = max_health
	max_mana = stats.max_mana
	curr_mana = max_mana
	sta = stats.sta
	max_act = float(TacticsConfig.active_timeline.max_act)
	curr_act = 0.0
	sprite = stats.sprite
	attack_power = stats.attack_power
	attack_range = stats.attack_range
	can_fly = stats.can_fly

## Provided a health operation as a parameter (e.g. "-2", "1"), adds the value to current health. As a consequence, this function serves for both damage and healing.
func apply_to_curr_health(new: int) -> void:
	print("Target initial health: ", curr_health, " - Applying damage: ", new)
	curr_health = clamp(curr_health + new, 0, max_health) # Apply health change and clamp to valid range
	print("Target final health: ", curr_health)
