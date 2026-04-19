class_name GuardIcon
extends Control

const ICON_TEXTURE: Texture2D = preload("res://assets/textures/ui/arena_gui/tate_pl.png")
const ACTIVE_COLOR: Color = Color(1.0, 0.93, 0.55, 1.0)
const INACTIVE_COLOR: Color = Color(0.72, 0.78, 0.8, 0.46)
const MIN_ICON_SIZE: Vector2 = Vector2(48.0, 48.0)

var _active: bool = false
var _remaining_ratio: float = 0.0


func _ready() -> void:
	custom_minimum_size = MIN_ICON_SIZE


func set_guard_state(active: bool, remaining_ratio: float) -> void:
	_active = active
	_remaining_ratio = clampf(remaining_ratio, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var icon_size: Vector2 = size
	if icon_size.x <= 0.0 or icon_size.y <= 0.0:
		icon_size = MIN_ICON_SIZE

	var rect := Rect2(Vector2.ZERO, icon_size)
	if _active:
		_draw_active_guard(rect)
	else:
		draw_texture_rect(ICON_TEXTURE, rect, false, INACTIVE_COLOR)


func _draw_active_guard(rect: Rect2) -> void:
	draw_texture_rect(ICON_TEXTURE, rect, false, INACTIVE_COLOR)

	var remaining_height: float = rect.size.y * _remaining_ratio
	if remaining_height <= 0.0:
		return

	var remaining_rect := Rect2(
		Vector2(rect.position.x, rect.end.y - remaining_height),
		Vector2(rect.size.x, remaining_height)
	)
	var texture_size: Vector2 = ICON_TEXTURE.get_size()
	var source_rect := Rect2(
		Vector2(0.0, texture_size.y * (1.0 - _remaining_ratio)),
		Vector2(texture_size.x, texture_size.y * _remaining_ratio)
	)
	draw_texture_rect_region(ICON_TEXTURE, remaining_rect, source_rect, ACTIVE_COLOR)
