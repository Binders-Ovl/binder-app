extends Sprite3D

@export var target_screen_height_px: float = 56.0
@export var sample_world_units: float = 1.0
@export var min_pixel_size: float = 0.0015
@export var max_pixel_size: float = 0.03
@export var resize_lerp_speed: float = 16.0

var _texture_height_px: float = 64.0


func _ready() -> void:
	if texture:
		_texture_height_px = maxf(1.0, texture.get_size().y)


func _process(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or texture == null:
		return

	var sample_dir: Vector3 = cam.global_basis.y.normalized()
	var origin_screen: Vector2 = cam.unproject_position(global_position)
	var sample_screen: Vector2 = cam.unproject_position(global_position + (sample_dir * sample_world_units))
	var px_per_world: float = origin_screen.distance_to(sample_screen) / maxf(0.001, sample_world_units)
	if px_per_world <= 0.0001:
		return

	var desired_world_height: float = target_screen_height_px / px_per_world
	var target_ps: float = clampf(desired_world_height / _texture_height_px, min_pixel_size, max_pixel_size)
	pixel_size = lerpf(pixel_size, target_ps, clampf(delta * resize_lerp_speed, 0.0, 1.0))
