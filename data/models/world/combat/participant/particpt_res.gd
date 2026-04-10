class_name TacticsParticipantResource
extends Resource
## Attributes & signals of the tactics participant.
##
## Dependency of: [TacticsParticipant]

## Signal emitted when a turn is skipped
signal called_skip_turn

#region Stage Selection
## Constant for the pawn selection stage
const STAGE_SELECT_PAWN: int = 0
## Constant for the action display stage
const STAGE_SHOW_ACTIONS: int = 1
## Constant for the movement display stage
const STAGE_SHOW_MOVEMENTS: int = 2
## Constant for the location selection stage
const STAGE_SELECT_LOCATION: int = 3
## Constant for the pawn movement stage
const STAGE_MOVE_PAWN: int = 4
## Constant for selecting attack type
const STAGE_SELECT_ATTACK_TYPE: int = 5
## Constant for the target display stage
const STAGE_DISPLAY_TARGETS: int = 6
## Constant for the attack target selection stage
const STAGE_SELECT_ATTACK_TARGET: int = 7
## Constant for the attack execution stage
const STAGE_ATTACK: int = 8
## The current stage of the participant's turn
var stage: int = 0
#endregion

## The currently active pawn
var curr_pawn: TacticsPawn = null:
	set(val):
		curr_pawn = val
		DebugLog.debug_nospam("pawn", val)
## The pawn that can be attacked
var attackable_pawn: TacticsPawn = null
## The selected datum tile for current attack.
var selected_attack_datum: TacticsTile = null
## The node containing the target pawns
var targets: Node = null
## Selected attack slot index.
var selected_attack_slot: int = -1
## Selected attack profile.
var selected_attack: Resource = null

## Flag to control the display of opponent stats
var display_opponent_stats: bool = false
## Flag indicating if the turn has just started
var turn_just_started: bool = true

## Clears selected attack metadata.
func clear_attack_selection() -> void:
	selected_attack_slot = -1
	selected_attack = null
	selected_attack_datum = null


## Emits the skip_turn signal
func skip_turn() -> void:
	called_skip_turn.emit()
