class_name ACTBar
extends Control

const MIN_BAR_SIZE: Vector2 = Vector2(144.0, 10.0)

var _current: int = 0
var _max_value: int = 100


func _ready() -> void:
	custom_minimum_size = MIN_BAR_SIZE


func set_values(current: int, maxv: int) -> void:
	_max_value = maxi(1, maxv)
	_current = clampi(current, 0, _max_value)
	queue_redraw()


func _draw() -> void:
	var bar_size: Vector2 = size
	if bar_size.x <= 0.0 or bar_size.y <= 0.0:
		bar_size = MIN_BAR_SIZE

	var rect := Rect2(Vector2.ZERO, bar_size)
	var fill_ratio: float = clampf(float(_current) / float(_max_value), 0.0, 1.0)
	var fill_rect := Rect2(Vector2.ZERO, Vector2(bar_size.x * fill_ratio, bar_size.y))
	var full: bool = _current >= _max_value

	if full:
		draw_rect(rect.grow(2.0), Color(1.0, 0.74, 0.14, 0.26), true)

	draw_rect(rect, Color(0.035, 0.04, 0.045, 0.92), true)
	draw_rect(fill_rect, _get_fill_color(full), true)
	if fill_rect.size.x > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(fill_rect.size.x, maxf(2.0, bar_size.y * 0.35))), Color(1.0, 1.0, 1.0, 0.28), true)

	_draw_marker(50, bar_size)
	_draw_marker(70, bar_size)
	draw_rect(rect, Color(0.88, 0.76, 0.48, 0.95), false, 1.0)


func _get_fill_color(full: bool) -> Color:
	if full:
		return Color(1.0, 0.79, 0.16, 1.0)
	if _current < 30:
		return Color(0.34, 0.37, 0.4, 1.0)
	if _current < 50:
		return Color(0.14, 0.52, 0.92, 1.0)
	if _current < 70:
		return Color(0.22, 0.84, 0.98, 1.0)
	return Color(0.56, 0.44, 0.93, 1.0)


func _draw_marker(value: int, bar_size: Vector2) -> void:
	if value <= 0 or value >= _max_value:
		return

	var x: float = round((float(value) / float(_max_value)) * bar_size.x)
	draw_line(Vector2(x, 1.0), Vector2(x, bar_size.y - 1.0), Color(0.98, 0.95, 0.78, 0.9), 1.0)
