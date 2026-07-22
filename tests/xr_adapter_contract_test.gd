extends SceneTree

const EVIDENCE_PATH := "res://evidence/xr_adapter_evidence.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene := load("res://Main.tscn") as PackedScene
	var world := scene.instantiate() as VectorVerseSpatialWorld
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var origin := world.get_node_or_null("XROrigin3D") as XROrigin3D
	var xr_camera := world.get_node_or_null("XROrigin3D/XRCamera3D") as XRCamera3D
	var left := world.get_node_or_null("XROrigin3D/LeftController") as XRController3D
	var right := world.get_node_or_null("XROrigin3D/RightController") as XRController3D
	var left_ray := world.get_node_or_null("XROrigin3D/LeftController/PointerRay") as RayCast3D
	var right_ray := world.get_node_or_null("XROrigin3D/RightController/PointerRay") as RayCast3D
	var adapter: Node = world.get_node_or_null("XRInteractionAdapter")
	var structure_valid := origin != null and xr_camera != null and left != null and right != null and left_ray != null and right_ray != null and adapter != null
	if not structure_valid:
		failures.append("XR origin, camera, controllers, rays, or adapter is missing.")

	var desktop_fallback_preserved: bool = not adapter.xr_runtime_active and world.camera.current and not xr_camera.current and not root.use_xr
	if not desktop_fallback_preserved:
		failures.append("Desktop Camera3D fallback was not preserved without an initialized OpenXR runtime.")

	var app_grabbed: bool = adapter.begin_controller_grab(left, world.app_start_atom)
	var app_positioned: bool = adapter.update_controller_grab_world_position(left, world.socket_target_for_atom("app_start"))
	var app_accepted: bool = adapter.release_controller_grab(left)
	await process_frame
	var compatible_action_only := world.graph.atom_ids == ["app_start"] and world.compatible_after_start == ["display_message"] and world.display_message_atom.visible
	if not app_grabbed or not app_positioned or not app_accepted or not compatible_action_only:
		failures.append("Left controller did not route App Start through the shared compatible insertion lifecycle.")

	var log_grabbed: bool = adapter.begin_controller_grab(right, world.display_message_atom)
	var log_positioned: bool = adapter.update_controller_grab_world_position(right, world.socket_target_for_atom("display_message"))
	var log_accepted: bool = adapter.release_controller_grab(right)
	await process_frame
	var graph_complete := world.graph.atom_ids == ["app_start", "display_message"] and world.generate_control.visible
	if not log_grabbed or not log_positioned or not log_accepted or not graph_complete:
		failures.append("Right controller did not route Log through the shared compatible insertion lifecycle.")

	var generate_routed: bool = adapter.route_controller_press(right, world.generate_control)
	await create_timer(1.45).timeout
	var deterministic_pipeline_verified: bool = generate_routed and world.success_panel.visible and world.success_heading.text == "You created \"Hello World\""
	if not deterministic_pipeline_verified:
		failures.append("XR pointer activation did not reach the deterministic generation pipeline.")

	var evidence := {
		"accepted": failures.is_empty(),
		"authoritative_scene": "res://Main.tscn",
		"adapter": "res://src/xr_interaction_adapter.gd",
		"xr_origin_present": origin != null,
		"xr_camera_present": xr_camera != null,
		"left_and_right_controller_present": left != null and right != null,
		"controller_rays_present": left_ray != null and right_ray != null,
		"adapter_contract_verified": structure_valid and app_accepted and log_accepted and deterministic_pipeline_verified,
		"shared_lifecycle": ["begin_grab", "update_grab_world_position", "release_grab", "activate_from_pointer"],
		"desktop_fallback_preserved": desktop_fallback_preserved,
		"only_compatible_action_revealed": compatible_action_only,
		"visual_graph_atoms": world.graph.atom_ids,
		"deterministic_gdscript_pipeline_verified": deterministic_pipeline_verified,
		"openxr_runtime_active_during_test": adapter.xr_runtime_active,
		"headset_deployment_tested": false,
		"limitations": "Contract tested headlessly; a real Meta Quest/OpenXR runtime remains required for headset acceptance.",
		"errors": failures
	}
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence, "\t") + "\n")
		file.close()
	else:
		failures.append("Could not save XR adapter evidence.")

	if failures.is_empty():
		print("VECTORVERSE_XR_ADAPTER_PASS")
		print("XR_SCENE_CONTRACT=true")
		print("CONTROLLER_SHARED_LIFECYCLE=true")
		print("DESKTOP_FALLBACK_PRESERVED=true")
		print("HEADSET_DEPLOYMENT_TESTED=false")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
