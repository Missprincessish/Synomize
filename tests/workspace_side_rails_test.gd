extends SceneTree

func _initialize() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate() as VectorVerseSpatialWorld
	root.add_child(world)
	await process_frame
	var failures: Array[String] = []
	world.activate_interaction_id("path_adult")
	await process_frame
	if not world.left_rail.visible or not world.right_rail.visible:
		failures.append("Workspace side rails were not shown for an active path.")
	for index in 3:
		world.activate_interaction_id(str(world.kid_flow[index].id))
		await create_timer(0.56).timeout
	if world.kid_step != 3 or world.progress_text.text != "STEP 3 / 7":
		failures.append("Progress rail did not track completed choices.")
	world.activate_interaction_id("back_step")
	await process_frame
	if world.kid_step != 2 or not world.kid_atoms[2].visible or world.kid_atoms[2].is_snapped:
		failures.append("Back One Step did not restore the previous valid choice.")
	world.activate_interaction_id("open_settings")
	if not world.settings_panel.visible or world.left_rail.visible:
		failures.append("Settings did not open from the left rail.")
	world.activate_interaction_id("close_settings")
	world.activate_interaction_id("restart_path")
	await process_frame
	if world.kid_step != 0 or world.progress_text.text != "STEP 0 / 7":
		failures.append("Start Over did not reset only the active path.")
	if failures.is_empty():
		print("SYNOMIZE_WORKSPACE_SIDE_RAILS_PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
