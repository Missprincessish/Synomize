extends SceneTree

const SAVE_PATH := "res://evidence/phase4_program1_save.json"

func _initialize() -> void:
	var failures: Array[String] = []
	var empty := VectorVerseVisualGraph.new()
	var empty_filter := VectorVerseCompatibilityFilter.choices_for_graph(empty)
	if empty_filter.visible_choices != ["app_start"]:
		failures.append("Empty graph did not reveal only App Start.")

	var graph := VectorVerseVisualGraph.new()
	if not graph.insert_atom("app_start"):
		failures.append("Could not insert App Start.")
	var after_start := VectorVerseCompatibilityFilter.choices_for_graph(graph)
	if after_start.visible_choices != ["display_message"]:
		failures.append("Morphing filter did not reveal only the supported Log action.")
	if not graph.insert_atom("display_message"):
		failures.append("Could not insert Log action.")
	var complete_filter := VectorVerseCompatibilityFilter.choices_for_graph(graph)
	if not complete_filter.visible_choices.is_empty():
		failures.append("Completed Program 1 still exposed an invalid next choice.")

	var original_ir := VectorVerseTypedIRSerializer.canonical_json(VectorVerseTypedIRSerializer.from_graph(graph))
	var original_backend := VectorVerseGDScriptAdapter.generate_from_ir(VectorVerseTypedIRSerializer.from_graph(graph))
	var save_a := VectorVerseGraphStore.save_graph(SAVE_PATH, graph)
	var save_b := VectorVerseGraphStore.save_graph(SAVE_PATH, graph)
	if not save_a.accepted or not save_b.accepted or save_a.sha256 != save_b.sha256:
		failures.append("Graph save was not deterministic.")
	var loaded := VectorVerseGraphStore.load_graph(SAVE_PATH)
	if not loaded.accepted:
		failures.append("Saved graph failed to load: " + JSON.stringify(loaded.diagnostics))
	else:
		var loaded_graph: VectorVerseVisualGraph = loaded.graph
		var loaded_validation := VectorVerseValidationPipeline.validate_graph(loaded_graph)
		var loaded_ir := VectorVerseTypedIRSerializer.canonical_json(loaded_validation.ir)
		var loaded_backend := VectorVerseGDScriptAdapter.generate_from_ir(loaded_validation.ir)
		if not loaded_validation.accepted_for_backend:
			failures.append("Reloaded Program 1 failed validation.")
		if loaded_ir != original_ir:
			failures.append("Reload changed canonical typed IR.")
		if loaded_backend.source != original_backend.source:
			failures.append("Reload changed generated GDScript.")
		if loaded_backend.source_map != original_backend.source_map:
			failures.append("Reload changed source map.")
		if loaded_backend.manifest != original_backend.manifest:
			failures.append("Reload changed build manifest.")

	var invalid_file := FileAccess.open("res://evidence/phase4_invalid_save.json", FileAccess.WRITE)
	invalid_file.store_string("{not valid json")
	invalid_file.close()
	var invalid_load := VectorVerseGraphStore.load_graph("res://evidence/phase4_invalid_save.json")
	if invalid_load.accepted or not _has_code(invalid_load.diagnostics, "S_LOAD_INVALID_JSON"):
		failures.append("Invalid save did not fail with a stable load diagnostic.")

	if failures.is_empty():
		print("VECTORVERSE_PHASE4_BUILDER_RELIABILITY_PASS")
		print("MORPHING_FILTER_SHARED_AUTHORITY=true")
		print("SAVE_LOAD_DETERMINISTIC=true")
		print("SAVE_SHA256=" + save_a.sha256)
		print("IR_SHA256=" + original_ir.sha256_text())
		print("SOURCE_SHA256=" + original_backend.source.sha256_text())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _has_code(diagnostics: Array, code: String) -> bool:
	return diagnostics.any(func(item): return item.get("code", "") == code)
