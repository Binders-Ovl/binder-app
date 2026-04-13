class_name TacticsPawnSprite
extends Sprite3D
## Handles the visual representation and animation of a pawn in the tactics game

## Animation state machine playback controller
var animator: AnimationNodeStateMachinePlayback = null
## Current frame of the sprite animation
var curr_frame: int = 0
## Current feedback overlay amount applied on top of action tint.
var _feedback_strength: float = 0.0
## Current feedback tint color.
var _feedback_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Base tint used for ready/unavailable action state.
var _base_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
## Home position for miss reactions driven on the feedback pivot.
var _feedback_pivot_home: Vector3 = Vector3.ZERO
## Active feedback tint tween.
var _flash_tween: Tween = null
## Active miss motion tween.
var _miss_tween: Tween = null
## Active guard vibrate tween.
var _guard_tween: Tween = null
## Active overlay flash tween.
var _overlay_tween: Tween = null
## Base overlay scale authored in scene.
var _overlay_base_scale: Vector3 = Vector3.ONE

## Reference to the AnimationTree node
@onready var animation_tree: AnimationTree = $AnimationTree
## Feedback pivot sits above the sprite so miss motion does not fight AnimationTree tracks.
@onready var feedback_pivot: Node3D = get_parent() as Node3D
## Shared overlay sprite used for visible hit flash without shaders.
@onready var flash_overlay: Sprite3D = $FlashOverlay
## Reference to the Label3D node displaying the pawn's name
@onready var character_ui_name_label: Label3D = $CharacterUI/NameLabel

@export_group("Feedback")
@export var action_ready_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var action_spent_tint: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var damage_feedback_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var crit_feedback_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var heal_feedback_color: Color = Color(0.45, 1.0, 0.55, 1.0)
@export var guard_feedback_color: Color = Color(0.929, 0.8, 0.412, 0.157)
@export var damage_feedback_peak: float = 0.92
@export var crit_feedback_peak: float = 0.95
@export var heal_feedback_peak: float = 0.82
@export var guard_feedback_peak: float = 0.9
@export var flash_in_duration: float = 0.05
@export var flash_out_duration: float = 0.2
@export var overlay_flash_alpha_damage: float = 1.0
@export var overlay_flash_alpha_crit: float = 0.95
@export var overlay_flash_alpha_heal: float = 0.85
@export var overlay_flash_alpha_guard: float = 0.92
@export var overlay_flash_in_duration: float = 0.05
@export var overlay_flash_out_duration: float = 0.24
@export var overlay_flash_scale_peak: float = 1.08
@export var guard_vibrate_distance: float = 0.05
@export var guard_vibrate_step_duration: float = 0.04
@export var guard_vibrate_steps: int = 4
@export var miss_distance: float = 0.22
@export var miss_out_duration: float = 0.07
@export var miss_return_duration: float = 0.1


## Sets up the pawn sprite with the given stats and expertise
##
## @param stats: The Stats resource containing pawn data
## @param expertise: The pawn's expertise (class or type)
func setup(stats: Stats, expertise: String) -> void:
	var playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]
	if playback is AnimationNodeStateMachinePlayback:
		animator = playback
	else:
		push_error("Expected AnimationNodeStateMachinePlayback, but got " + str(typeof(playback)))
		return
	
	animator.start("IDLE")
	animation_tree.active = true
	texture = load(stats.sprite) as Texture2D
	character_ui_name_label.text = stats.override_name if stats.override_name else expertise
	_feedback_pivot_home = feedback_pivot.position if feedback_pivot else Vector3.ZERO
	_base_tint = action_ready_tint
	_overlay_base_scale = flash_overlay.scale if flash_overlay else Vector3.ONE
	_sync_flash_overlay()
	_apply_visual_tint()


## Starts the appropriate animation based on the pawn's movement and state
##
## @param move_direction: The direction the pawn is moving in
## @param is_jumping: Whether the pawn is currently jumping
func start_animator(move_direction: Vector3, is_jumping: bool) -> void:
	if move_direction == Vector3.ZERO:
		animator.travel("IDLE")
	elif is_jumping:
		animator.travel("JUMP")


## Rotates the sprite to face the camera and selects the appropriate frame
##
## @param _global_basis: The global basis of the pawn
func rotate_sprite(_global_basis: Basis) -> void:
	# Get forward vector of the camera (looking down the negative Z-axis)
	var _camera_forward: Vector3 = -get_viewport().get_camera_3d().global_basis.z
	# Measure how much the pawn faces towards or away from camera
	var _scalar: float = _global_basis.z.dot(_camera_forward)
	# Determine if the sprite should be flipped horizontally
	flip_h = _global_basis.x.dot(_camera_forward) > 0
	# Select appropriate sprite frame based on pawn orientation relative to camera
	if _scalar < -0.306: # Pawn is facing away from camera, use base "back" frame
		frame = curr_frame
	elif _scalar > 0.306: # Facing towards camera, use "front" view
		frame = curr_frame + 1 * TacticsPawnResource.ANIMATION_FRAMES
	# Note: If -0.306 <= scalar <= 0.306, the frame remains unchanged
	_sync_flash_overlay()


## Adjusts the pawn's position to the center of its current tile
##
## @param pawn: The TacticsPawn to adjust
## @return: Whether the adjustment was successful
func adjust_to_center(pawn: TacticsPawn) -> bool:
	if pawn.get_tile() and not pawn.res.is_moving:
		pawn.global_position = pawn.get_tile().global_position
		return true
	return false


func set_action_available(can_act_now: bool) -> void:
	_base_tint = action_ready_tint if can_act_now else action_spent_tint
	_apply_visual_tint()


func play_feedback(kind: String, source: Node3D = null) -> void:
	match kind:
		"miss":
			_play_miss_reaction(source)
		"crit":
			_play_flash(crit_feedback_color, crit_feedback_peak, overlay_flash_alpha_crit)
		"heal":
			_play_flash(heal_feedback_color, heal_feedback_peak, overlay_flash_alpha_heal)
		"guard", "defense":
			_play_guard_feedback(source)
		_:
			_play_flash(damage_feedback_color, damage_feedback_peak, overlay_flash_alpha_damage)


func _play_flash(color: Color, peak_strength: float, overlay_alpha: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
		_flash_tween = null

	_feedback_color = color
	_set_feedback_strength(0.0)
	_play_overlay_flash(color, overlay_alpha)

	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_feedback_strength, 0.0, clampf(peak_strength, 0.0, 1.0), flash_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(_set_feedback_strength, clampf(peak_strength, 0.0, 1.0), 0.0, flash_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flash_tween.finished.connect(_on_flash_tween_finished, CONNECT_ONE_SHOT)


func _play_miss_reaction(source: Node3D = null) -> void:
	if feedback_pivot == null:
		return

	if _guard_tween:
		_guard_tween.kill()
		_guard_tween = null

	if _miss_tween:
		_miss_tween.kill()
		_miss_tween = null

	feedback_pivot.position = _feedback_pivot_home
	var direction: float = _resolve_miss_direction(source)
	var target_position: Vector3 = _feedback_pivot_home + Vector3(direction * miss_distance, 0.0, 0.0)

	_miss_tween = create_tween()
	_miss_tween.tween_property(feedback_pivot, "position", target_position, miss_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_miss_tween.tween_property(feedback_pivot, "position", _feedback_pivot_home, miss_return_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_miss_tween.finished.connect(_on_miss_tween_finished, CONNECT_ONE_SHOT)


func _play_guard_feedback(source: Node3D = null) -> void:
	_play_flash(guard_feedback_color, guard_feedback_peak, overlay_flash_alpha_guard)
	_play_guard_vibrate(source)


func _play_guard_vibrate(source: Node3D = null) -> void:
	if feedback_pivot == null:
		return

	if _miss_tween:
		_miss_tween.kill()
		_miss_tween = null

	if _guard_tween:
		_guard_tween.kill()
		_guard_tween = null

	feedback_pivot.position = _feedback_pivot_home
	var base_direction: float = _resolve_miss_direction(source)
	var steps: int = maxi(2, guard_vibrate_steps)
	var amplitude: float = maxf(0.0, guard_vibrate_distance)
	var step_duration: float = maxf(0.01, guard_vibrate_step_duration)

	_guard_tween = create_tween()
	for i: int in range(steps):
		var direction: float = base_direction if i % 2 == 0 else -base_direction
		var target_position: Vector3 = _feedback_pivot_home + Vector3(direction * amplitude, 0.0, 0.0)
		_guard_tween.tween_property(feedback_pivot, "position", target_position, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_guard_tween.tween_property(feedback_pivot, "position", _feedback_pivot_home, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_guard_tween.finished.connect(_on_guard_tween_finished, CONNECT_ONE_SHOT)


func _set_feedback_strength(value: float) -> void:
	_feedback_strength = clampf(value, 0.0, 1.0)
	_apply_visual_tint()


func _apply_visual_tint() -> void:
	modulate = _base_tint.lerp(_feedback_color, _feedback_strength)


func _play_overlay_flash(color: Color, target_alpha: float) -> void:
	if flash_overlay == null:
		return

	_sync_flash_overlay()
	if _overlay_tween:
		_overlay_tween.kill()
		_overlay_tween = null

	flash_overlay.visible = true
	flash_overlay.modulate = Color(color.r, color.g, color.b, 0.0)
	flash_overlay.scale = _overlay_base_scale

	_overlay_tween = create_tween()
	_overlay_tween.tween_method(_set_overlay_alpha, 0.0, clampf(target_alpha, 0.0, 1.0), overlay_flash_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_overlay_tween.tween_method(_set_overlay_alpha, clampf(target_alpha, 0.0, 1.0), 0.0, overlay_flash_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_overlay_tween.parallel().tween_property(flash_overlay, "scale", _overlay_base_scale * overlay_flash_scale_peak, overlay_flash_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_overlay_tween.parallel().tween_property(flash_overlay, "scale", _overlay_base_scale, overlay_flash_out_duration).set_delay(overlay_flash_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_overlay_tween.finished.connect(_on_overlay_tween_finished, CONNECT_ONE_SHOT)


func _sync_flash_overlay() -> void:
	if flash_overlay == null:
		return
	flash_overlay.texture = texture
	flash_overlay.hframes = hframes
	flash_overlay.vframes = vframes
	flash_overlay.frame = frame
	flash_overlay.flip_h = flip_h


func _set_overlay_alpha(value: float) -> void:
	if flash_overlay == null:
		return
	var c: Color = flash_overlay.modulate
	c.a = clampf(value, 0.0, 1.0)
	flash_overlay.modulate = c


func _resolve_miss_direction(source: Node3D = null) -> float:
	if source == null or not is_instance_valid(source):
		return 1.0

	var to_target: Vector3 = global_position - source.global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return 1.0

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var right: Vector3 = camera.global_basis.x
		right.y = 0.0
		if right.length_squared() > 0.0001:
			var screen_side: float = to_target.dot(right.normalized())
			if not is_zero_approx(screen_side):
				return signf(screen_side)

	return -1.0 if to_target.x < 0.0 else 1.0


func _on_flash_tween_finished() -> void:
	_flash_tween = null
	_set_feedback_strength(0.0)


func _on_miss_tween_finished() -> void:
	_miss_tween = null
	if feedback_pivot:
		feedback_pivot.position = _feedback_pivot_home


func _on_guard_tween_finished() -> void:
	_guard_tween = null
	if feedback_pivot:
		feedback_pivot.position = _feedback_pivot_home


func _on_overlay_tween_finished() -> void:
	_overlay_tween = null
	if flash_overlay:
		flash_overlay.visible = false
		flash_overlay.modulate.a = 0.0
		flash_overlay.scale = _overlay_base_scale
