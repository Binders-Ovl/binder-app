class_name CombatFeedbackLayer
extends Node3D

@export var popup_scene: PackedScene = preload("res://data/modules/world/combat/feedback/combat_text_popup.tscn")
@export var stack_reset_seconds: float = 0.45
@export var stack_step_y: float = 0.2
@export var stack_jitter_x: float = 0.16
@export var stack_jitter_z: float = 0.07
@export var max_stack_steps: int = 4
@export var max_pool_size: int = 18
@export var stale_cleanup_interval: float = 1.0

var _stack_state_by_target: Dictionary = {}
var _inactive_popups: Array[Node2D] = []
var _next_stale_cleanup_at: float = 0.0
var _canvas_layer: CanvasLayer = null


func _ready() -> void:
	_ensure_canvas_layer()


func show_result(result: Dictionary) -> void:
	var target: TacticsPawn = result.get("target", null) as TacticsPawn
	if target == null or not is_instance_valid(target):
		return
	_ensure_canvas_layer()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var now: float = _now_seconds()
	if now >= _next_stale_cleanup_at:
		_prune_stale_stack_state(now)
		_next_stale_cleanup_at = now + stale_cleanup_interval

	var base_position: Vector3 = _resolve_anchor_position(target, result)
	var spawn_position: Vector3 = _apply_stack_offset(target, base_position, now)
	var popup: Node2D = _acquire_popup()
	if popup == null:
		return

	var render_payload: Dictionary = result.duplicate()
	render_payload["world_position"] = spawn_position
	popup.call("show_result", render_payload, camera)


func _acquire_popup() -> Node2D:
	if not _inactive_popups.is_empty():
		var pooled_popup: Node2D = _inactive_popups.pop_back()
		if pooled_popup and is_instance_valid(pooled_popup):
			pooled_popup.visible = true
			return pooled_popup

	if popup_scene == null:
		return null

	var popup: Node2D = popup_scene.instantiate() as Node2D
	if popup == null:
		push_error("CombatFeedbackLayer: popup scene did not instantiate a Node2D popup.")
		return null
	_canvas_layer.add_child(popup)
	popup.connect("finished", Callable(self, "_on_popup_finished"))
	return popup


func _on_popup_finished(popup: Node2D) -> void:
	if popup == null or not is_instance_valid(popup):
		return

	if _inactive_popups.size() >= max_pool_size:
		popup.queue_free()
		return

	popup.visible = false
	popup.scale = Vector2.ONE
	_inactive_popups.append(popup)


func _resolve_anchor_position(target: TacticsPawn, result: Dictionary) -> Vector3:
	if target.has_method("get_damage_anchor_position"):
		return target.get_damage_anchor_position()
	if result.has("world_position"):
		return result.get("world_position", target.global_position)
	return target.global_position + Vector3(0.0, 1.8, 0.0)


func _apply_stack_offset(target: TacticsPawn, base_position: Vector3, now: float) -> Vector3:
	var target_id: int = target.get_instance_id()
	var entry: Dictionary = _stack_state_by_target.get(target_id, {})
	var stack_count: int = int(entry.get("count", 0))
	var last_time: float = float(entry.get("last_time", -INF))

	if now - last_time > stack_reset_seconds:
		stack_count = 0

	var stack_index: int = mini(stack_count, max_stack_steps)
	entry["count"] = stack_count + 1
	entry["last_time"] = now
	_stack_state_by_target[target_id] = entry

	var camera: Camera3D = get_viewport().get_camera_3d()
	var right: Vector3 = Vector3.RIGHT
	var forward: Vector3 = Vector3.FORWARD
	if camera != null:
		right = camera.global_basis.x
		right.y = 0.0
		forward = -camera.global_basis.z
		forward.y = 0.0
	if right.length_squared() > 0.0001:
		right = right.normalized()
	else:
		right = Vector3.RIGHT
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	else:
		forward = Vector3.FORWARD

	var horizontal_offset: Vector3 = right * randf_range(-stack_jitter_x, stack_jitter_x)
	var depth_offset: Vector3 = forward * randf_range(-stack_jitter_z, stack_jitter_z)
	var vertical_offset: Vector3 = Vector3.UP * (float(stack_index) * stack_step_y)
	return base_position + horizontal_offset + depth_offset + vertical_offset


func _prune_stale_stack_state(now: float) -> void:
	var expiry: float = stack_reset_seconds * 2.0
	var stale_ids: Array[int] = []
	for target_id in _stack_state_by_target.keys():
		var entry: Dictionary = _stack_state_by_target[target_id]
		var last_time: float = float(entry.get("last_time", -INF))
		if now - last_time > expiry:
			stale_ids.append(int(target_id))
	for target_id: int in stale_ids:
		_stack_state_by_target.erase(target_id)


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _ensure_canvas_layer() -> void:
	if _canvas_layer != null and is_instance_valid(_canvas_layer):
		return
	var existing: Node = get_node_or_null("CombatFeedbackCanvas")
	if existing and existing is CanvasLayer:
		_canvas_layer = existing as CanvasLayer
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CombatFeedbackCanvas"
	layer.layer = 5
	add_child(layer)
	_canvas_layer = layer
