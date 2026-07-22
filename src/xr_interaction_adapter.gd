class_name VectorVerseXRInteractionAdapter
extends Node

const SELECT_ACTIONS := [&"select", &"grab", &"trigger_click", &"trigger", &"grip_click"]
const MIN_GRAB_DISTANCE := 0.45
const MAX_GRAB_DISTANCE := 4.0
const POINTER_LENGTH := 12.0
const POINTER_GREEN := Color("24ff9a")
const POINTER_CYAN := Color("41dfff")

@onready var world: VectorVerseSpatialWorld = get_parent() as VectorVerseSpatialWorld
@onready var xr_origin: XROrigin3D = $"../XROrigin3D"
@onready var xr_camera: XRCamera3D = $"../XROrigin3D/XRCamera3D"
@onready var desktop_camera: Camera3D = $"../CameraRig/Camera3D"
@onready var left_controller: XRController3D = $"../XROrigin3D/LeftController"
@onready var right_controller: XRController3D = $"../XROrigin3D/RightController"

var xr_runtime_active := false
var adapter_ready := false
var active_controller: XRController3D
var active_grab_distance := 1.0
var xr_interface: XRInterface
var debug_label: Label3D
var startup_diagnostic: Label3D
var startup_background: MeshInstance3D
var pointer_visuals: Dictionary = {}
var last_tracking_summary := ""
var last_diagnostic_summary := ""
var diagnostic_compact := false
var status_elapsed := 0.0
var world_recentered_to_face_player := false
var left_select_held := false
var right_select_held := false
var recenter_gesture_armed := true

func _ready() -> void:
	call_deferred("_configure")

func _configure() -> void:
	for controller in [left_controller, right_controller]:
		controller.button_pressed.connect(_on_button_pressed.bind(controller))
		controller.button_released.connect(_on_button_released.bind(controller))
	_create_pointer_visual(left_controller, POINTER_GREEN)
	_create_pointer_visual(right_controller, POINTER_CYAN)
	world.block_placed.connect(_on_block_placed)
	_create_debug_label()
	_create_startup_diagnostic()
	print("VECTORVERSE_SCENE_STARTUP: Main.tscn loaded; XR origin, XR camera, controllers, and spatial world are present")
	_detect_openxr_runtime()
	adapter_ready = true

func _physics_process(delta: float) -> void:
	if active_controller != null and world.grabbed_atom != null:
		world.update_grab_world_position(_controller_position_on_construction_plane(active_controller))
	_update_pointer_visual(left_controller)
	_update_pointer_visual(right_controller)
	status_elapsed += delta
	if status_elapsed >= 0.2:
		status_elapsed = 0.0
		_update_tracking_status()

func _detect_openxr_runtime() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	xr_runtime_active = xr_interface != null and xr_interface.is_initialized()
	print("VECTORVERSE_XR_INIT: interface_found=%s initialized=%s" % [xr_interface != null, xr_runtime_active])
	if xr_runtime_active:
		XRServer.primary_interface = xr_interface
	get_viewport().use_xr = xr_runtime_active
	xr_camera.current = xr_runtime_active
	desktop_camera.current = not xr_runtime_active
	debug_label.visible = false
	startup_background.visible = false
	startup_diagnostic.visible = false
	if xr_runtime_active:
		_connect_openxr_session_signals()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("VECTORVERSE_XR_VIEWPORT: use_xr=%s xr_camera_current=%s origin=%s" % [
			get_viewport().use_xr,
			xr_camera.current,
			xr_origin.global_position
		])
	else:
		printerr("VECTORVERSE_XR_FAILURE: OpenXR runtime not active; desktop fallback selected")

func _on_button_pressed(action_name: StringName, controller: XRController3D) -> void:
	if action_name not in SELECT_ACTIONS:
		return
	if controller == left_controller:
		left_select_held = true
	elif controller == right_controller:
		right_select_held = true
	_maybe_trigger_manual_recenter()
	var ray := controller.get_node("PointerRay") as RayCast3D
	ray.force_raycast_update()
	route_controller_press(controller, ray.get_collider())

func _on_button_released(action_name: StringName, controller: XRController3D) -> void:
	if action_name not in SELECT_ACTIONS:
		return
	if controller == left_controller:
		left_select_held = false
	elif controller == right_controller:
		right_select_held = false
	if not left_select_held and not right_select_held:
		recenter_gesture_armed = true
	release_controller_grab(controller)

# Hold both triggers/grips together (while not holding an atom) to re-face the
# construction panel toward wherever you are currently looking. Needed because
# the Quest STAGE reference space orientation is set by Guardian, not by which
# way the player is facing when the app starts, so the one-time automatic
# recenter at tracking-ready can guess wrong.
func _maybe_trigger_manual_recenter() -> void:
	if not recenter_gesture_armed:
		return
	if left_select_held and right_select_held and world.grabbed_atom == null:
		recenter_gesture_armed = false
		_perform_recenter()
		world.explanation_text.text = "Centered"
		get_tree().create_timer(1.0).timeout.connect(_restore_instruction)

func _restore_instruction() -> void:
	if world != null and world.explanation_text != null and not world.success_panel.visible:
		world.explanation_text.text = world.instruction_before_grab

func route_controller_press(controller: XRController3D, collider: Object) -> bool:
	if collider is VectorVerseSpatialAtom:
		return begin_controller_grab(controller, collider)
	world.activate_from_pointer(collider)
	return collider != null

func begin_controller_grab(controller: XRController3D, collider: Object) -> bool:
	if active_controller != null or not world.begin_grab(collider):
		return false
	active_controller = controller
	active_grab_distance = clampf(
		controller.global_position.distance_to((collider as Node3D).global_position),
		MIN_GRAB_DISTANCE,
		MAX_GRAB_DISTANCE
	)
	return true

func update_controller_grab_world_position(controller: XRController3D, world_position: Vector3) -> bool:
	if controller != active_controller or world.grabbed_atom == null:
		return false
	world.update_grab_world_position(world_position)
	return true

func release_controller_grab(controller: XRController3D) -> bool:
	if controller != active_controller:
		return false
	active_controller = null
	return world.release_grab()

func _controller_position_on_construction_plane(controller: XRController3D) -> Vector3:
	var origin := controller.global_position
	var direction := -controller.global_basis.z.normalized()
	if absf(direction.z) > 0.0001:
		var plane_distance := (world.DRAG_PLANE_Z - origin.z) / direction.z
		if plane_distance > 0.0 and plane_distance <= POINTER_LENGTH:
			return origin + direction * plane_distance
	return origin + direction * active_grab_distance

func _create_pointer_visual(controller: XRController3D, color: Color) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "VisiblePointerBeam"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, POINTER_LENGTH)
	beam.mesh = mesh
	beam.position = Vector3(0.0, 0.0, -POINTER_LENGTH * 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	beam.material_override = material
	beam.visible = false
	controller.add_child(beam)
	pointer_visuals[controller.get_instance_id()] = beam

func _update_pointer_visual(controller: XRController3D) -> void:
	var beam := pointer_visuals.get(controller.get_instance_id()) as MeshInstance3D
	if beam == null:
		return
	var tracked := xr_runtime_active and controller.get_is_active() and controller.get_has_tracking_data()
	beam.visible = tracked
	if not tracked:
		return
	var ray := controller.get_node("PointerRay") as RayCast3D
	ray.force_raycast_update()
	var length := POINTER_LENGTH
	if ray.is_colliding():
		length = clampf(controller.global_position.distance_to(ray.get_collision_point()), 0.05, POINTER_LENGTH)
		world.preview_interaction(ray.get_collider())
	var box := beam.mesh as BoxMesh
	box.size.z = length
	beam.position.z = -length * 0.5

func _on_block_placed(stage: int) -> void:
	var colors := [Color("24ff9a"), Color("41dfff"), Color("b66cff"), Color("fff36a")]
	var color: Color = colors[stage % colors.size()]
	for beam_value in pointer_visuals.values():
		var beam := beam_value as MeshInstance3D
		if beam == null:
			continue
		var material := beam.material_override as StandardMaterial3D
		var box := beam.mesh as BoxMesh
		if material != null:
			material.albedo_color = color
			material.emission = color
			material.emission_energy_multiplier = 9.0
		if box != null:
			box.size.x = 0.026
			box.size.y = 0.006 if stage % 2 == 0 else 0.026
		var pulse := create_tween().set_parallel(true)
		if material != null:
			pulse.tween_property(material, "emission_energy_multiplier", 4.0, 0.65)
		if box != null:
			pulse.tween_property(box, "size:x", 0.012, 0.65)
			pulse.tween_property(box, "size:y", 0.012, 0.65)

func _create_debug_label() -> void:
	debug_label = Label3D.new()
	debug_label.name = "QuestTrackingDebugStatus"
	debug_label.position = Vector3(0.0, -0.36, -1.25)
	debug_label.font_size = 42
	debug_label.pixel_size = 0.0012
	debug_label.modulate = POINTER_CYAN
	debug_label.outline_size = 12
	debug_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	debug_label.no_depth_test = true
	debug_label.visible = false
	xr_camera.add_child(debug_label)

func _create_startup_diagnostic() -> void:
	startup_background = MeshInstance3D.new()
	startup_background.name = "XRStartupDiagnosticBackground"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.8, 0.88)
	startup_background.mesh = quad
	startup_background.position = Vector3(0.0, 0.12, -1.5)
	var background_material := StandardMaterial3D.new()
	background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	background_material.albedo_color = Color("1455ff")
	background_material.emission_enabled = true
	background_material.emission = Color("1455ff")
	background_material.emission_energy_multiplier = 2.5
	background_material.no_depth_test = true
	startup_background.material_override = background_material
	startup_background.visible = false
	xr_camera.add_child(startup_background)

	startup_diagnostic = Label3D.new()
	startup_diagnostic.name = "XRStartupDiagnosticText"
	startup_diagnostic.position = Vector3(0.0, 0.12, -1.46)
	startup_diagnostic.font_size = 58
	startup_diagnostic.pixel_size = 0.00145
	startup_diagnostic.modulate = Color.WHITE
	startup_diagnostic.outline_size = 14
	startup_diagnostic.outline_modulate = Color("001229")
	startup_diagnostic.no_depth_test = true
	startup_diagnostic.visible = false
	xr_camera.add_child(startup_diagnostic)

func _connect_openxr_session_signals() -> void:
	for signal_name in [
		&"session_begun",
		&"session_synchronized",
		&"session_visible",
		&"session_focussed",
		&"session_stopping",
		&"session_loss_pending",
		&"instance_exiting"
	]:
		if xr_interface.has_signal(signal_name) and not xr_interface.is_connected(signal_name, _on_openxr_session_event):
			xr_interface.connect(signal_name, _on_openxr_session_event.bind(signal_name))

func _on_openxr_session_event(signal_name: StringName) -> void:
	print("VECTORVERSE_XR_SESSION_EVENT: " + String(signal_name))
	_update_tracking_status()

func _update_tracking_status() -> void:
	if not xr_runtime_active or debug_label == null:
		return
	var head_tracked := _head_has_tracking_data()
	if not world_recentered_to_face_player and head_tracked:
		world_recentered_to_face_player = true
		# Give the headset pose a moment to settle after it is worn. The immediate
		# first tracked pose can still reflect the Guardian setup direction.
		get_tree().create_timer(1.15).timeout.connect(_perform_recenter)
	var left_tracked := left_controller.get_is_active() and left_controller.get_has_tracking_data()
	var right_tracked := right_controller.get_is_active() and right_controller.get_has_tracking_data()
	var summary := "HEADSET: %s  |  LEFT: %s  |  RIGHT: %s" % [
		"TRACKED" if head_tracked else "WAITING",
		"TRACKED" if left_tracked else "WAITING",
		"TRACKED" if right_tracked else "WAITING"
	]
	debug_label.text = ""
	debug_label.modulate = POINTER_GREEN if head_tracked and left_tracked and right_tracked else Color("ffd166")
	var session_state := _openxr_session_state_name()
	if not diagnostic_compact and session_state == "FOCUSED" and head_tracked and left_tracked and right_tracked:
		_set_startup_diagnostic_compact()
	var diagnostic_summary := ""
	startup_diagnostic.text = diagnostic_summary
	if summary != last_tracking_summary:
		last_tracking_summary = summary
		print("VECTORVERSE_XR_STATUS: " + summary)
	if diagnostic_summary != last_diagnostic_summary:
		last_diagnostic_summary = diagnostic_summary
		print("VECTORVERSE_XR_DIAGNOSTIC: session=%s headset=%s left=%s right=%s" % [
			session_state,
			head_tracked,
			left_tracked,
			right_tracked
		])

	# Godot's OpenXR STAGE reference space is oriented to the Guardian boundary
	# setup, not to whichever way the player is physically facing when the app
	# starts. Without this, the construction panel and atoms (placed at fixed
	# world coordinates facing -Z) can end up anywhere around the player in an
	# arbitrary physical direction. Set XROrigin3D's yaw (absolute, not
	# additive, so this stays correct no matter how many times it is called)
	# using the player's current facing direction, so the panel is in front.
func _perform_recenter() -> void:
	if not xr_runtime_active or xr_camera == null or world == null or world.panel_root == null:
		return
	# Cancel the tracked local yaw so the headset's current forward becomes the
	# workspace's -Z direction, then counter the room-scale positional offset.
	# This is deterministic and avoids the previous candidate-angle ambiguity
	# that could put the panel ninety degrees to the player's right.
	var local_forward := -xr_camera.basis.z
	local_forward.y = 0.0
	if local_forward.length() < 0.001:
		return
	var local_yaw := atan2(-local_forward.x, -local_forward.z)
	var origin_yaw := -local_yaw
	xr_origin.rotation = Vector3(0.0, origin_yaw, 0.0)
	var local_offset := Vector3(xr_camera.position.x, 0.0, xr_camera.position.z)
	var rotated_offset := Basis(Vector3.UP, origin_yaw) * local_offset
	xr_origin.position.x = -rotated_offset.x
	xr_origin.position.z = 6.0 - rotated_offset.z
	var aligned_forward := -xr_camera.global_basis.z
	aligned_forward.y = 0.0
	var to_panel := world.panel_root.global_position - xr_camera.global_position
	to_panel.y = 0.0
	var score := aligned_forward.normalized().dot(to_panel.normalized()) if aligned_forward.length() > 0.001 and to_panel.length() > 0.001 else 0.0
	print("VECTORVERSE_XR_RECENTER: panel_alignment=%.3f yaw=%.1f" % [score, rad_to_deg(origin_yaw)])

func _set_startup_diagnostic_compact() -> void:
	diagnostic_compact = true
	startup_background.position = Vector3(0.0, 0.55, -1.5)
	startup_background.scale = Vector3(0.68, 0.24, 1.0)
	startup_diagnostic.position = Vector3(0.0, 0.55, -1.46)
	startup_diagnostic.scale = Vector3(0.5, 0.5, 0.5)
	# The larger tracking-status label already did its job (proving tracking
	# works); once the world is confirmed revealed it just sits in front of
	# the construction panel and blocks the real content, so hide it.
	debug_label.visible = false
	# The small compact indicator (including the recenter hint) has also done
	# its job by now; fade it out after a few seconds instead of leaving it
	# permanently in view over the construction panel.
	get_tree().create_timer(6.0).timeout.connect(_hide_startup_diagnostic)
	print("VECTORVERSE_XR_DIAGNOSTIC: compact=true world_revealed=true")

func _hide_startup_diagnostic() -> void:
	startup_background.visible = false
	startup_diagnostic.visible = false

func _openxr_session_state_name() -> String:
	if xr_interface == null or not xr_runtime_active:
		return "NOT INITIALIZED"
	var openxr := xr_interface as OpenXRInterface
	if openxr == null:
		return "INTERFACE ACTIVE"
	match openxr.get_session_state():
		OpenXRInterface.SESSION_STATE_IDLE:
			return "IDLE"
		OpenXRInterface.SESSION_STATE_READY:
			return "READY"
		OpenXRInterface.SESSION_STATE_SYNCHRONIZED:
			return "SYNCHRONIZED"
		OpenXRInterface.SESSION_STATE_VISIBLE:
			return "VISIBLE"
		OpenXRInterface.SESSION_STATE_FOCUSED:
			return "FOCUSED"
		OpenXRInterface.SESSION_STATE_STOPPING:
			return "STOPPING"
		OpenXRInterface.SESSION_STATE_LOSS_PENDING:
			return "LOSS PENDING"
		OpenXRInterface.SESSION_STATE_EXITING:
			return "EXITING"
		_:
			return "UNKNOWN"

func _head_has_tracking_data() -> bool:
	var head_tracker := XRServer.get_tracker("head") as XRPositionalTracker
	if head_tracker == null:
		return false
	var head_pose := head_tracker.get_pose("default")
	return head_pose != null and head_pose.has_tracking_data
