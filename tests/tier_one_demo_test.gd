extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	for family in ["variable", "condition", "loop", "state", "group"]:
		var graph := VectorVerseVisualGraph.new()
		match family:
			"variable": graph.configure_variable_demo()
			"condition": graph.configure_program2(true)
			"loop": graph.configure_loop_demo()
			"state": graph.configure_program3("Memory")
			"group": graph.configure_group_demo()
		var validation := VectorVerseValidationPipeline.validate_graph(graph)
		var generation := VectorVerseGDScriptAdapter.generate_from_ir(validation.ir)
		if not validation.accepted_for_backend or not generation.accepted:
			failures.append(family)
	if failures.is_empty():
		print("SYNOMIZE_SEVEN_TIER_ONE_BLOCKS_PASS")
		quit(0)
	else:
		push_error("Tier-one demos failed: " + ",".join(failures))
		quit(1)
