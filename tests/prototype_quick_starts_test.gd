extends SceneTree

func _initialize() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	var world := packed.instantiate() as VectorVerseSpatialWorld
	root.add_child(world)
	await process_frame
	var failures: Array[String] = []
	if not world.path_menu.visible:
		failures.append("Quick Start menu was not shown first.")
	for path_id in ["scratch", "adult", "kids"]:
		world.activate_interaction_id("path_" + path_id)
		await process_frame
		if world.active_path != path_id:
			failures.append(path_id + " did not remain isolated as the active path.")
		for index in world.kid_flow.size():
			var active_choices := world.kid_atoms.filter(func(atom: VectorVerseSpatialAtom) -> bool: return atom.visible and not atom.is_snapped)
			if active_choices.size() != 1:
				failures.append(path_id + " showed more than one next choice.")
			world.activate_interaction_id(str(world.kid_flow[index].id))
			await create_timer(0.56).timeout
		world.activate_interaction_id("generate")
		await create_timer(0.18).timeout
		if not world.inventory_types.has(path_id):
			failures.append(path_id + " was not stored once in permanent inventory.")
		world.activate_interaction_id("create_new")
		await process_frame
	if world.inventory_types.size() != 3:
		failures.append("Inventory counted duplicates instead of unique creation types.")
	world.activate_interaction_id("path_adult")
	for index in world.kid_flow.size():
		world.activate_interaction_id(str(world.kid_flow[index].id))
		await create_timer(0.56).timeout
	world.activate_interaction_id("generate")
	await create_timer(0.18).timeout
	if world.adult_task_labels.size() != 3:
		failures.append("Daily Checklist did not run as a usable app.")
	world.activate_interaction_id("open_export")
	if not world.export_panel.visible:
		failures.append("Export-only delivery choices were not shown.")
	if failures.is_empty():
		print("SYNOMIZE_QUICK_STARTS_PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
