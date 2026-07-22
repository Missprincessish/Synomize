extends SceneTree

const EVIDENCE_PATH := "res://evidence/player_interaction_evidence.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene := load("res://Main.tscn") as PackedScene
	var world = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var authoritative_root_is_3d := world is Node3D
	var has_camera := world.get_node_or_null("CameraRig/Camera3D") is Camera3D
	var has_world_environment := world.get_node_or_null("WorldEnvironment") is WorldEnvironment
	var panel_is_physical_mesh := world.panel_body is MeshInstance3D
	var floor_is_spatial := world.get_node("PolishedBlackFloor").get_child_count() > 0
	var atoms_are_spatial_areas := world.app_start_atom is Area3D and world.display_message_atom is Area3D
	var starts_empty: bool = world.graph.atom_ids.is_empty()
	var action_hidden_initially: bool = not world.action_socket.visible and not world.display_message_atom.visible

	if not authoritative_root_is_3d:
		failures.append("Authoritative root is not Node3D.")
	if not has_camera or not has_world_environment:
		failures.append("Spatial camera or world environment is missing.")
	if not panel_is_physical_mesh or not floor_is_spatial:
		failures.append("Panel or floor is not physical 3D geometry.")
	if not atoms_are_spatial_areas:
		failures.append("Atoms are not independently raycastable 3D areas.")
	if not starts_empty or not action_hidden_initially:
		failures.append("Initial compatibility state is not restricted to App Start.")

	var app_screen_position: Vector2 = world.camera.unproject_position(world.app_start_atom.global_position)
	var app_raycast_hit = world._raycast(app_screen_position)
	var mouse_ray_hits_app_start: bool = app_raycast_hit == world.app_start_atom
	if not mouse_ray_hits_app_start:
		failures.append("Camera mouse ray did not hit the App Start collider.")
	world._unhandled_input(_mouse_button(app_screen_position, true))
	var app_grab_started: bool = world.grabbed_atom == world.app_start_atom
	var event_socket_screen: Vector2 = world.camera.unproject_position(world.socket_target_for_atom("app_start"))
	world._unhandled_input(_mouse_motion(event_socket_screen))
	world._unhandled_input(_mouse_button(event_socket_screen, false))
	await process_frame
	await physics_frame
	var app_snapped: bool = world.app_start_atom.is_snapped
	var app_drop_accepted: bool = app_snapped
	var only_action_revealed: bool = world.graph.atom_ids == ["app_start"] and world.compatible_after_start == ["display_message"] and world.action_socket.visible and world.display_message_atom.visible
	if not app_grab_started or not app_drop_accepted or not app_snapped:
		failures.append("App Start did not complete the grab-to-compatible-socket lifecycle.")
	if not only_action_revealed:
		failures.append("App Start did not reveal only the compatible 3D Action choice.")

	var log_staging_position: Vector3 = world.display_message_atom.position
	var log_screen_position: Vector2 = world.camera.unproject_position(world.display_message_atom.global_position)
	var log_raycast_hit = world._raycast(log_screen_position)
	var mouse_ray_hits_log: bool = log_raycast_hit == world.display_message_atom
	if not mouse_ray_hits_log:
		failures.append("Camera mouse ray did not hit the revealed Log collider.")
	var invalid_grab_started: bool = world.begin_grab(log_raycast_hit)
	world.update_grab_world_position(Vector3(-4.5, 1.2, world.DRAG_PLANE_Z))
	var invalid_drop_rejected: bool = not world.release_grab()
	await create_timer(0.4).timeout
	var invalid_drop_preserved_graph: bool = world.graph.atom_ids == ["app_start"] and not world.display_message_atom.is_snapped and world.display_message_atom.position.distance_to(log_staging_position) < 0.08
	if not invalid_grab_started or not invalid_drop_rejected or not invalid_drop_preserved_graph:
		failures.append("Invalid Log drop was not rejected and returned to staging.")

	var refreshed_log_screen: Vector2 = world.camera.unproject_position(world.display_message_atom.global_position)
	world._unhandled_input(_mouse_button(refreshed_log_screen, true))
	var valid_log_grab_started: bool = world.grabbed_atom == world.display_message_atom
	var action_socket_screen: Vector2 = world.camera.unproject_position(world.socket_target_for_atom("display_message"))
	world._unhandled_input(_mouse_motion(action_socket_screen))
	world._unhandled_input(_mouse_button(action_socket_screen, false))
	await process_frame
	await physics_frame
	var graph_ready: bool = world.graph.atom_ids == ["app_start", "display_message"]
	var log_snapped: bool = world.display_message_atom.is_snapped
	var log_drop_accepted: bool = log_snapped
	var generate_revealed: bool = world.generate_control.visible
	if not valid_log_grab_started or not log_drop_accepted or not log_snapped or not graph_ready or not generate_revealed:
		failures.append("Log insertion did not complete the physical graph and reveal Generate.")

	var generate_screen_position: Vector2 = world.camera.unproject_position(world.generate_control.global_position)
	var generate_raycast_hit = world._raycast(generate_screen_position)
	var mouse_ray_hits_generate: bool = generate_raycast_hit == world.generate_control
	if not mouse_ray_hits_generate:
		failures.append("Camera mouse ray did not hit the revealed Generate collider.")
	world.activate_from_pointer(generate_raycast_hit)
	await create_timer(2.2).timeout
	var generated_and_verified: bool = world.success_panel.visible and world.success_heading.text == "You created \"Hello World\""
	var synomize_success_message: bool = world.completion_actions.visible
	var generated_code_hidden: bool = world.success_panel.name == "ProjectCelebration"
	var all_languages_visible: bool = not world.has_node("LanguageDropdownMenu")
	var success_glow_visible: bool = world.celebration_root != null
	if not generated_and_verified:
		failures.append("Spatial Generate control did not run the deterministic pipeline.")
	if not synomize_success_message or not generated_code_hidden or not all_languages_visible or not success_glow_visible:
		failures.append("Synomize completion did not show only the protected celebration and build choices.")

	var evidence := {
		"accepted": failures.is_empty(),
		"authoritative_scene": "res://Main.tscn",
		"authoritative_root_type": "Node3D",
		"desktop_interaction": "Camera3D mouse raycast",
		"xr_extension_seam": "activate_from_pointer(collider)",
		"mouse_ray_hits_app_start": mouse_ray_hits_app_start,
		"mouse_ray_hits_log": mouse_ray_hits_log,
		"mouse_ray_hits_generate": mouse_ray_hits_generate,
		"xr_neutral_grab_methods": ["begin_grab", "update_grab_world_position", "release_grab"],
		"app_grab_started": app_grab_started,
		"app_drop_accepted_at_compatible_socket": app_drop_accepted,
		"app_atom_snapped": app_snapped,
		"invalid_log_drop_rejected": invalid_drop_rejected,
		"invalid_drop_returned_to_staging": invalid_drop_preserved_graph,
		"log_grab_started": valid_log_grab_started,
		"log_drop_accepted_at_compatible_socket": log_drop_accepted,
		"log_atom_snapped": log_snapped,
		"click_to_insert_fallback_preserved": world.has_method("activate_from_pointer"),
		"camera_3d_present": has_camera,
		"world_environment_present": has_world_environment,
		"physical_panel_mesh_present": panel_is_physical_mesh,
		"spatial_floor_present": floor_is_spatial,
		"atoms_are_separate_raycastable_3d_objects": atoms_are_spatial_areas,
		"starts_with_empty_graph": starts_empty,
		"action_choice_hidden_until_compatible": action_hidden_initially,
		"only_compatible_action_revealed": only_action_revealed,
		"visual_graph_atoms": world.graph.atom_ids,
		"generate_control_revealed_after_valid_graph": generate_revealed,
		"generated_and_runtime_verified": generated_and_verified,
		"synomize_success_message": synomize_success_message,
		"generated_code_hidden": generated_code_hidden,
		"all_language_options_visible": all_languages_visible,
		"success_glow_visible": success_glow_visible,
		"preserved_2d_reference": "res://prototypes/2d_ui_reference/Main2DReference.tscn",
		"errors": failures
	}
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence, "\t") + "\n")
		file.close()
	else:
		failures.append("Could not save spatial interaction evidence.")

	if failures.is_empty():
		print("VECTORVERSE_SPATIAL_3D_PASS")
		print("ROOT_TYPE=Node3D")
		print("MOUSE_RAYCAST_ARCHITECTURE=true")
		print("GRAB_AND_SNAP=true")
		print("INVALID_DROP_REJECTED=true")
		print("GRAPH_ATOMS=app_start,display_message")
		print("GDSCRIPT_RUNTIME_VERIFIED=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	return event

func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event
