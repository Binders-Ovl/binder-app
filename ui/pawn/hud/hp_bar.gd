class_name HPBar
extends Control

const MIN_BAR_SIZE: Vector2 = Vector2(144.0, 14.0)

var _current: int = 0
var _max_value: int = 1


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

	draw_rect(rect, Color(0.03, 0.06, 0.03, 0.92), true)
	draw_rect(fill_rect, Color(0.14, 0.74, 0.22, 1.0), true)
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(fill_rect.size.x, maxf(2.0, bar_size.y * 0.35))), Color(0.78, 1.0, 0.8, 0.3), true)

	_draw_separators(bar_size)
	draw_rect(rect, Color(0.93, 0.79, 0.52, 1.0), false, 1.0)
	draw_rect(rect.grow(-1.0), Color(0.04, 0.08, 0.03, 0.85), false, 1.0)


func _draw_separators(bar_size: Vector2) -> void:
	if _max_value <= 100:
		return

	var draw_small: bool = _max_value < 3000
	if draw_small:
		for value: int in range(100, _max_value, 100):
			if value % 1000 == 0:
				continue
			_draw_separator(value, bar_size, false)

	for value: int in range(1000, _max_value, 1000):
		_draw_separator(value, bar_size, true)


func _draw_separator(value: int, bar_size: Vector2, big: bool) -> void:
	var x: float = round((float(value) / float(_max_value)) * bar_size.x)
	if x <= 0.0 or x >= bar_size.x:
		return

	if big:
		draw_line(Vector2(x, 1.0), Vector2(x, bar_size.y - 1.0), Color(0.02, 0.02, 0.02, 0.92), 1.0)
		return

	var half_top: float = floor(bar_size.y * 0.5)
	draw_line(Vector2(x, half_top), Vector2(x, bar_size.y - 1.0), Color(0.9, 0.9, 0.92, 0.78), 1.0)
