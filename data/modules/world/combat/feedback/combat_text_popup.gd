class_name CombatTextPopup
extends Node2D

signal finished(popup: Node2D)

@export var pop_duration: float = 0.9
@export var rise_duration: float = 0.25
@export var settle_duration: float = 0.35
@export var fade_duration: float = 0.7
@export var rise_height_px: float = 58.0
@export var settle_drop_px: float = 18.0
@export var damage_scale: float = 1.0
@export var crit_scale: float = 1.2
@export var miss_scale: float = 0.96
@export var start_scale_factor: float = 0.84
@export var damage_color: Color = Color(1.0, 0.96, 0.84, 1.0)
@export var crit_color: Color = Color(1.0, 0.88, 0.35, 1.0)
@export var miss_color: Color = Color(0.88, 0.94, 1.0, 1.0)
@export var heal_color: Color = Color(0.38, 1.0, 0.5, 1.0)
@export var damage_font_size: int = 32
@export var crit_font_size: int = 40
@export var miss_font_size: int = 28
@export var outline_size: int = 6
@export var outline_color: Color = Color(0.02, 0.02, 0.04, 0.95)
@export var popup_font: Font

@onready var label: Label = $Label

var _camera: Camera3D = null
var _world_position: Vector3 = Vector3.ZERO
var _screen_offset: Vector2 = Vector2.ZERO
var _active_tween: Tween = null


func show_result(payload: Dictionary, camera: Camera3D) -> void:
	_kill_tween()

	_camera = camera
	_world_position = payload.get("world_position", Vector3.ZERO)
	_screen_offset = Vector2.ZERO
	visible = true
	scale = Vector2.ONE * clampf(start_scale_factor, 0.2, 1.0)
	set_process(true)

	var kind: String = String(payload.get("kind", "damage"))
	var did_crit: bool = bool(payload.get("crit", false))
	var damage: int = int(payload.get("damage", 0))
	var text: String = String(payload.get("text", ""))

	_apply_text_style(kind, text, damage, did_crit)
	_update_screen_position()
	_play_tween(kind, did_crit)


func _process(_delta: float) -> void:
	_update_screen_position()


func _update_screen_position() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
		if _camera == null:
			visible = false
			return

	if _camera.is_position_behind(_world_position):
		visible = false
		return

	visible = true
	position = _camera.unproject_position(_world_position) + _screen_offset


func _apply_text_style(kind: String, explicit_text: String, damage: int, did_crit: bool) -> void:
	if popup_font != null:
		label.add_theme_font_override("font", popup_font)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	label.modulate.a = 1.0

	match kind:
		"miss":
			label.text = explicit_text if not explicit_text.is_empty() else "MISS"
			label.modulate = miss_color
			label.add_theme_font_size_override("font_size", miss_font_size)
		"heal":
			label.text = explicit_text if not explicit_text.is_empty() else "+%d" % damage
			label.modulate = heal_color
			label.add_theme_font_size_override("font_size", damage_font_size)
		_:
			label.text = explicit_text if not explicit_text.is_empty() else str(damage)
			label.modulate = crit_color if did_crit else damage_color
			label.add_theme_font_size_override("font_size", crit_font_size if did_crit else damage_font_size)


func _play_tween(kind: String, did_crit: bool) -> void:
	var target_scale: float = damage_scale
	if kind == "miss":
		target_scale = miss_scale
	elif did_crit:
		target_scale = crit_scale

	var rise_to: float = -absf(rise_height_px)
	var settle_to: float = rise_to + absf(settle_drop_px)

	_active_tween = create_tween()
	_active_tween.tween_property(self, "scale", Vector2.ONE * target_scale, pop_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_method(_set_screen_offset_y, 0.0, rise_to, rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_method(_set_screen_offset_y, rise_to, settle_to, settle_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.parallel().tween_property(label, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.finished.connect(_on_tween_finished, CONNECT_ONE_SHOT)


func _set_screen_offset_y(v: float) -> void:
	_screen_offset.y = v
	_update_screen_position()


func _on_tween_finished() -> void:
	_active_tween = null
	set_process(false)
	emit_signal("finished", self)


func _kill_tween() -> void:
	if _active_tween:
		_active_tween.kill()
		_active_tween = null
