extends SceneTree

const EVIDENCE_PATH := "res://evidence/quest_smoke_preflight_evidence.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var action_map := load("res://openxr_action_map.tres") as OpenXRActionMap
	var scene := load("res://Main.tscn") as PackedScene
	var world := scene.instantiate() as VectorVerseSpatialWorld
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var adapter: Node = world.get_node("XRInteractionAdapter")
	var origin := world.get_node("XROrigin3D") as XROrigin3D
	var left := world.get_node("XROrigin3D/LeftController") as XRController3D
	var right := world.get_node("XROrigin3D/RightController") as XRController3D
	var xr_settings_valid: bool = (
		ProjectSettings.get_setting("xr/openxr/enabled") == true
		and ProjectSettings.get_setting("xr/openxr/default_action_map") == "res://openxr_action_map.tres"
		and ProjectSettings.get_setting("xr/openxr/form_factor") == 0
		and ProjectSettings.get_setting("xr/openxr/view_configuration") == 1
		and ProjectSettings.get_setting("xr/openxr/reference_space") == 2
		and ProjectSettings.get_setting("xr/shaders/enabled") == true
		and ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc") == true
	)
	if not xr_settings_valid:
		failures.append("OpenXR project settings are incomplete for the Quest smoke test.")

	var action_names: Array[String] = []
	var profile_path := ""
	var binding_paths: Array[String] = []
	if action_map != null and action_map.get_action_set_count() == 1:
		var action_set := action_map.get_action_set(0)
		for action_index in action_set.get_action_count():
			action_names.append(action_set.actions[action_index].resource_name)
	if action_map != null and action_map.get_interaction_profile_count() == 1:
		var profile := action_map.get_interaction_profile(0)
		profile_path = profile.interaction_profile_path
		for binding_index in profile.get_binding_count():
			binding_paths.append(profile.get_binding(binding_index).binding_path)
	var action_map_valid := (
		action_names == ["aim_pose", "grip_pose", "select", "grab"]
		and profile_path == "/interaction_profiles/oculus/touch_controller"
		and binding_paths.size() == 8
		and "/user/hand/left/input/trigger/value" in binding_paths
		and "/user/hand/right/input/squeeze/value" in binding_paths
	)
	if not action_map_valid:
		failures.append("Quest controller action map or bindings are incomplete.")

	var spatial_setup_valid := (
		origin.position.y == 0.0
		and origin.position.z == 6.0
		and left.tracker == &"left_hand"
		and right.tracker == &"right_hand"
		and left.pose == &"aim"
		and right.pose == &"aim"
	)
	if not spatial_setup_valid:
		failures.append("XR origin, floor height, controller trackers, or aim poses are incorrect.")

	var visible_ray_nodes_created := (
		left.get_node_or_null("VisiblePointerBeam") is MeshInstance3D
		and right.get_node_or_null("VisiblePointerBeam") is MeshInstance3D
	)
	var debug_status_created := world.get_node_or_null("XROrigin3D/XRCamera3D/QuestTrackingDebugStatus") is Label3D
	var startup_diagnostic_created := (
		world.get_node_or_null("XROrigin3D/XRCamera3D/XRStartupDiagnosticBackground") is MeshInstance3D
		and world.get_node_or_null("XROrigin3D/XRCamera3D/XRStartupDiagnosticText") is Label3D
	)
	var startup_diagnostic_can_reveal_world := adapter.has_method("_set_startup_diagnostic_compact")
	if not visible_ray_nodes_created or not debug_status_created or not startup_diagnostic_created or not startup_diagnostic_can_reveal_world:
		failures.append("Visible controller rays or headset tracking debug status are missing.")

	var plane_target: Vector3 = adapter._controller_position_on_construction_plane(left)
	var construction_plane_routing: bool = is_equal_approx(plane_target.z, world.DRAG_PLANE_Z) or plane_target.distance_to(left.global_position) <= adapter.MAX_GRAB_DISTANCE
	if not construction_plane_routing:
		failures.append("Controller movement does not route to the construction plane or safe fallback distance.")

	var desktop_fallback_preserved: bool = not adapter.xr_runtime_active and world.camera.current and not root.use_xr
	if not desktop_fallback_preserved:
		failures.append("Desktop fallback did not remain active without an OpenXR runtime.")

	var export_config := FileAccess.get_file_as_string("res://export_presets.cfg")
	var export_preset_valid := (
		"name=\"Meta Quest Smoke Test\"" in export_config
		and "architectures/arm64-v8a=true" in export_config
		and "xr_features/xr_mode=1" in export_config
		and "gradle_build/use_gradle_build=true" in export_config
		and "xr_features/enable_meta_plugin=true" in export_config
		and "package/unique_name=\"org.synhumanity.vectorverse.smoketest\"" in export_config
		and FileAccess.file_exists("res://addons/godotopenxrvendors/plugin.gdextension")
		and FileAccess.file_exists("res://addons/godotopenxrvendors/.bin/android/debug/godotopenxr-meta-debug.aar")
	)
	if not export_preset_valid:
		failures.append("Android Meta Quest export preset is incomplete.")

	var evidence := {
		"accepted": failures.is_empty(),
		"checkpoint_preserved": "/Users/angie/Documents/SYN_HUMANITY_MASTER/VectorVerse-Godot-Checkpoints/VectorVerse-Godot-pre-Quest-smoke-2026-07-17.zip",
		"godot_version": Engine.get_version_info().string,
		"openxr_project_settings_valid": xr_settings_valid,
		"openxr_action_map": "res://openxr_action_map.tres",
		"action_names": action_names,
		"interaction_profile": profile_path,
		"binding_count": binding_paths.size(),
		"xr_origin_at_floor_y_zero": origin.position.y == 0.0,
		"xr_origin_world_position": origin.position,
		"left_and_right_tracking_nodes_valid": spatial_setup_valid,
		"visible_pointer_beams_created": visible_ray_nodes_created,
		"headset_and_controller_debug_status_created": debug_status_created,
		"headset_startup_diagnostic_created": startup_diagnostic_created,
		"startup_diagnostic_can_reveal_world": startup_diagnostic_can_reveal_world,
		"meta_openxr_loader_configured": export_preset_valid,
		"construction_plane_move_routing_valid": construction_plane_routing,
		"desktop_fallback_preserved": desktop_fallback_preserved,
		"android_export_preset_valid": export_preset_valid,
		"headset_launched": false,
		"vr_interaction_proven": false,
		"errors": failures
	}
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t") + "\n")
	file.close()

	if failures.is_empty():
		print("VECTORVERSE_QUEST_PREFLIGHT_PASS")
		print("OPENXR_SETTINGS=true")
		print("QUEST_TOUCH_BINDINGS=true")
		print("TRACKING_DEBUG_VISIBLE=true")
		print("DESKTOP_FALLBACK_PRESERVED=true")
		print("HEADSET_LAUNCHED=false")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
