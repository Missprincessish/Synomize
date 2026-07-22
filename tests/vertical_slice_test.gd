extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var graph := VectorVerseVisualGraph.new()

	var initial_choices := VectorVerseAtomCatalog.compatible_choices(graph.atom_ids)
	if initial_choices != ["app_start"]:
		failures.append("Initial choices were not restricted to app_start.")
	if not graph.insert_atom("app_start"):
		failures.append("Could not insert app_start.")

	var compatible_after_start := VectorVerseAtomCatalog.compatible_choices(graph.atom_ids)
	if compatible_after_start != ["display_message"]:
		failures.append("Only display_message should be compatible after app_start.")
	if not graph.insert_atom("display_message"):
		failures.append("Could not insert display_message.")

	var evidence := VectorVerseVerticalSliceValidator.validate_and_save(graph, compatible_after_start)
	if not evidence.accepted:
		failures.append_array(evidence.errors)
	if not evidence.semantic_validation_success:
		failures.append("Semantic graph validation failed.")
	if evidence.dependency_order != ["node_0001", "node_0002"]:
		failures.append("Dependency order is incorrect.")
	if not evidence.round_trip_generation_match:
		failures.append("Saved graph round-trip changed generated output.")
	if evidence.supported_languages != ["gdscript"]:
		failures.append("Pipeline expanded beyond the approved GDScript adapter.")

	var invalid_graph := VectorVerseVisualGraph.new()
	invalid_graph.nodes = [{
		"instance_id": "node_0001",
		"atom_id": "display_message",
		"family": "Action",
		"parameters": {"message": "Hello, Synomize!"},
		"position": 0
	}]
	invalid_graph.atom_ids = ["display_message"]
	var invalid_errors := VectorVerseGraphValidator.validate(invalid_graph)
	if invalid_errors.is_empty():
		failures.append("Invalid graph was accepted.")

	evidence["invalid_graph_rejected"] = not invalid_errors.is_empty()
	evidence["invalid_graph_errors"] = invalid_errors
	evidence["full_pipeline_test_passed"] = failures.is_empty()
	var evidence_file := FileAccess.open("res://evidence/pipeline_test_evidence.json", FileAccess.WRITE)
	if evidence_file == null:
		failures.append("Could not save complete pipeline evidence.")
	else:
		evidence_file.store_string(JSON.stringify(evidence, "\t") + "\n")
		evidence_file.close()

	if failures.is_empty():
		print("VECTORVERSE_ACCEPTANCE_PASS")
		print("GRAPH_ATOMS=app_start,display_message")
		print("COMPATIBLE_AFTER_APP_START=display_message")
		print("SEMANTIC_VALIDATION=true")
		print("DEPENDENCY_ORDER=node_0001,node_0002")
		print("ROUND_TRIP_MATCH=true")
		print("INVALID_GRAPH_REJECTED=true")
		print("GENERATED_SHA256=" + evidence.generated_source_sha256)
		print("GODOT_PARSE_SUCCESS=true")
		print("RUNTIME_MESSAGE=" + evidence.actual_message)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
