class_name TacticsCameraService
extends RefCounted
## Service class for TacticsCamera

var res: TacticsCameraResource
var controls: TacticsControlsResource
var move: TacticsCameraMovementService
var zoom: TacticsCameraZoomService
var rotate: TacticsCameraRotationService
var pan: TacticsCameraPanningService

const DELTA_SMOOTHING: int = 10
const MIN_VEL: float = 0.01
const TABLET_MAX_ASPECT: float = 1.45
const TABLET_DEFAULT_FOV: float = 26.0
const WIDE_DEFAULT_FOV: float = 30.0


## Initialize the service and its sub-services
func _init(_res: TacticsCameraResource, _controls: TacticsControlsResource) -> void:
	res = _res
	controls = _controls
	move = TacticsCameraMovementService.new(res, controls)
	zoom = TacticsCameraZoomService.new(res)
	rotate = TacticsCameraRotationService.new(res, controls)
	pan = TacticsCameraPanningService.new(res)


## Set up initial camera properties
func setup(camera: TacticsCamera, cam_node: Camera3D) -> void:
	if not controls:
		push_error("TacticsControls needs a ControlResource from /data/models/view/control/tactics/")
	if not res:
		push_error("TacticsCamera needs a CameraResource (T Cam) from /data/models/view/camera/tactics/")
	else:
		res.viewport_size = camera.get_viewport().size
		apply_resolution_camera_profile(camera, cam_node)


## Main processing function for camera behavior
func process(delta: float, camera: TacticsCamera) -> void:
	var vp_size: Vector2i = camera.get_viewport().size
	if vp_size != res.viewport_size:
		res.viewport_size = vp_size
		apply_resolution_camera_profile(camera, camera.cam_node)

	rotate.check_free_look_activation(delta, camera)
	
	if res.in_free_look:
		rotate.free_look(delta, camera.t_pivot, camera.p_pivot)
	elif not res.is_snapping_to_quad:
		rotate.rotate_camera(delta, camera.t_pivot, camera.p_pivot)
	
	var input_dir: Vector2 = InputCaptureResource.cam_direction
	if input_dir != Vector2.ZERO:
		pan.wasd_pan(delta, camera, input_dir)
	elif pan.is_cursor_near_edge(camera) and not controls.is_joystick:
		pan.edge_pan(delta, camera)
	else:
		res.panning_timer = 0.0
		move.stabilize_camera(delta, camera)
	
	if camera.velocity.length() < MIN_VEL:
		camera.velocity = Vector3.ZERO
	
	move.focus_on_target(camera)
	zoom.apply_zoom_smoothing(camera, delta)


func apply_resolution_camera_profile(camera: TacticsCamera, cam_node: Camera3D) -> void:
	var vp_size: Vector2i = camera.get_viewport().size
	if vp_size.y <= 0:
		return
	var aspect: float = float(vp_size.x) / float(vp_size.y)
	var base_fov: float = TABLET_DEFAULT_FOV if aspect <= TABLET_MAX_ASPECT else WIDE_DEFAULT_FOV
	res.current_fov = clampf(base_fov, res.min_zoom, res.max_zoom)
	res.target_fov = res.current_fov
	cam_node.fov = res.current_fov
	cam_node.keep_aspect = Camera3D.KEEP_HEIGHT
