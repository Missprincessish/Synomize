extends SceneTree

func _initialize() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	var world := packed.instantiate() as VectorVerseSpatialWorld
	root.add_child(world)
	await process_frame
	var failures: Array[String] = []
	world.activate_interaction_id("path_kids")
	await process_frame
	if world.kid_flow.size() != 7 or world.kid_atoms.size() != 7:
		failures.append("The guided path does not contain seven core blocks.")
	for index in 7:
		var expected_id: String = world.kid_flow[index].id
		var visible_choices := world.kid_atoms.filter(func(atom: VectorVerseSpatialAtom) -> bool: return atom.visible and atom.is_available and not atom.is_snapped)
		if visible_choices.size() != 1 or visible_choices[0].atom_id != expected_id:
			failures.append("Step %d did not show exactly one valid next choice." % index)
		world.activate_interaction_id(expected_id)
		await create_timer(0.58).timeout
	if not world.kid_path_complete or world.graph.graph_id != "program3_session_state" or not world.generate_control.visible:
		failures.append("The Star Buddy path did not reach its playable validated state.")
	world.activate_interaction_id("generate")
	await create_timer(0.2).timeout
	if world.star_buddy_preview == null or not world.success_panel.visible:
		failures.append("The Star Buddy game preview did not run.")
	world.activate_interaction_id("collect_star")
	await create_timer(0.1).timeout
	if not world.star_collected or "SCORE  1" not in world.star_buddy_score_text.text:
		failures.append("The playable star collection did not award a point.")
	if failures.is_empty():
		print("SYNOMIZE_STAR_BUDDY_PATH_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
