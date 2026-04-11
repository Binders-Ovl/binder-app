class_name TacticsConfig
extends Node3D
## Tactics system configuration.
##
## This class contains static properties and methods for configuring various aspects
## of the tactics system, including colors, materials, pawn properties, and view settings.

const WCOMBAT_CONFIG = preload("res://data/models/config/wcombat_config.gd")

#region: --- Props ---
## Dictionary of color codes used in the tactics system. ff4242BF
static var color: Dictionary = {
	"white": "FFFFFF2A", # Semi-transparent white
	"blue_cola": "008fdbBF", # Semi-transparent blue cola color
	"blue_bolt": "0aa9ffBF", # Semi-transparent blue bolt color
	"rosso_corsa": "d10000BF", # Semi-transparent rosso corsa (racing red) color
	"coral_red": "ff4242BF", # Semi-transparent coral red color
	"soft_yellow": "F6E27ABF", # Soft yellow for attack-area preview
}

## Shared selector overlay tuning
static var tile_overlay_surface_offset: float = 0.065
static var selector_overlay_texture: Texture2D = preload("res://assets/textures/ui/arena_gui/selector_overlay.png")
static var selector_overlay_opacity: float = 0.95

## Optional move-risk overlay tuning
static var enable_purple_move_target_overlay: bool = true
static var move_risk_purple_color: Color = Color("A46BFFB8")

## Backward-compatible aliases
static var overlay_texture: Texture2D = selector_overlay_texture
static var overlay_material: StandardMaterial3D = create_material(
	Color(1.0, 1.0, 1.0, selector_overlay_opacity),
	selector_overlay_texture,
	BaseMaterial3D.SHADING_MODE_PER_PIXEL
)


## Dictionary of materials used for different states in the tactics system.
static var mat_color: Dictionary = {
	"hover": create_material(str(color.white)),
	"reachable": create_material(str(color.blue_cola)),
	"reachable_hover": create_material(str(color.blue_bolt)),
	"reachable_threatened": create_material(move_risk_purple_color),
	"hover_reachable_threatened": create_material(move_risk_purple_color.lightened(0.18)),
	"attackable": create_material(str(color.rosso_corsa)),
	"hover_attackable": create_material(str(color.coral_red)),
	"attack_area_preview": create_material(str(color.soft_yellow)),
	"hover_attack_area_preview": create_material(Color(str(color.soft_yellow)).lightened(0.18)),
}

## Dictionary of pawn-related configuration values.
static var pawn: Dictionary = {
	"base_walk_speed": 4, ## Base speed for pawn movement on the board
	"animation_frames": 1, ## Number of frames for pawn animations
	"min_height_to_jump": 1, ## The tile height from which we use JUMP pawn animation
	"gravity_strength": 6, ## Force of gravity used in jump & fall physics
	"min_time_for_attack": 1, ## Minimum time required for an attack action
}

## Dictionary for the active timeline energy model.
static var active_timeline: Dictionary = {
	"max_act": 100.0, ## ACT gauge cap
	"base_recovery": WCOMBAT_CONFIG.ACT_BASE_RECOVERY, ## Base ACT recovered per second
	"sta_multiplier": WCOMBAT_CONFIG.ACT_SPD_MULTIPLIER, ## STA contribution to ACT recovered per second
}

## Dictionary of ACT costs per action type.
static var action_cost: Dictionary = {
	"move": 70.0,
	"attack": WCOMBAT_CONFIG.DEFAULT_ATTACK_ACT_COST,
	"item": 20.0,
	"skill": 50.0,
}

## Dictionary of view-related configuration values.
static var view: Dictionary = {
	"default_t_cam_zoom": 26, ## The default FOV for tactics camera node
}

## Array of UI element names used to filter out UI elements when parsing the mouse cursor position.
static var ui_elem: Array[String] = [
	"%Actions", "%AttackTypes", "%Hints",
]
#endregion


## Creates a StandardMaterial3D with specified color, texture, and shading mode.
##
## @param color_hex: The color of the material in hexadecimal format.
## @param texture: The albedo texture for the material (optional).
## @param shaded_mode: The shading mode for the material (default: BaseMaterial3D.SHADING_MODE_PER_PIXEL).
## @return: A new StandardMaterial3D instance with the specified properties.
static func create_material(color_hex: Variant, texture: Texture2D = null, shaded_mode: BaseMaterial3D.ShadingMode = BaseMaterial3D.SHADING_MODE_PER_PIXEL) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # Set material to use alpha transparency
	if color_hex is Color:
		material.albedo_color = color_hex # Set the material color
	else:
		material.albedo_color = Color(str(color_hex)) # Set the material color
	material.albedo_texture = texture # Set the albedo texture (if provided)
	material.shading_mode = shaded_mode # Set the shading mode
	return material
