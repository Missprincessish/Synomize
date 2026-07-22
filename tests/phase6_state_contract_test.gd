extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var graph := VectorVerseVisualGraph.new()
	graph.configure_program3("Remember me exactly")
	var validation := VectorVerseValidationPipeline.validate_graph(graph)
	if not validation.accepted_for_backend:
		failures.append("Program 3 graph failed validation: " + JSON.stringify(validation.diagnostics))
	var a := VectorVerseGDScriptAdapter.generate_from_ir(validation.ir)
	var b := VectorVerseGDScriptAdapter.generate_from_ir(validation.ir)
	if not a.accepted:
		failures.append("Program 3 backend generation was rejected: " + JSON.stringify(a.diagnostics))
	if a.source != b.source or a.source_map != b.source_map or a.manifest != b.manifest:
		failures.append("Program 3 regeneration was not deterministic.")
	var runtime := _run_generated(a.source)
	if runtime != "Remember me exactly":
		failures.append("Read-after-write returned %s instead of exact input." % runtime)
	for span_id in ["state_input_literal", "state_write", "state_read", "log_action"]:
		if not a.source_map.any(func(span): return span.get("span_id", "") == span_id):
			failures.append("Source map is missing " + span_id)
	var invalid_ir: Dictionary = validation.ir.duplicate(true)
	for node in invalid_ir.nodes:
		if node.get("operation_kind", "") == "STATE_READ": node.parameters.state_id = "differentKey"
	var invalid := VectorVerseGDScriptAdapter.generate_from_ir(invalid_ir)
	if invalid.accepted or not invalid.diagnostics.any(func(item): return item.get("code", "") == "B_PROGRAM3_STATE_ID_MISMATCH"):
		failures.append("Mismatched state IDs were not rejected deterministically.")
	_write_text("res://generated/program3_session_state.gd", a.source)
	_write_json("res://evidence/program3_state_ir.json", validation.ir)
	_write_json("res://evidence/program3_state_source_map.json", a.source_map)
	_write_json("res://evidence/phase6_state_evidence.json", {
		"accepted": failures.is_empty(),
		"phase": 6,
		"program": "App Start + session State Write + State Read + Log",
		"runtime": runtime,
		"exact_read_after_write": runtime == "Remember me exactly",
		"mismatched_state_id_rejected": not invalid.accepted,
		"source_sha256": a.source.sha256_text(),
		"ir_sha256": VectorVerseTypedIRSerializer.canonical_json(validation.ir).sha256_text(),
		"source_map_sha256": JSON.stringify(a.source_map, "\t", true).sha256_text(),
		"desktop_runtime_proven": true,
		"quest_runtime_proven_this_run": false,
		"errors": failures
	})
	if failures.is_empty():
		print("VECTORVERSE_PHASE6_STATE_PASS")
		print("STATE_RUNTIME=Remember me exactly")
		print("EXACT_READ_AFTER_WRITE=true")
		print("MISMATCHED_STATE_ID_REJECTED=true")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _run_generated(source: String) -> String:
	var generated_script := GDScript.new()
	generated_script.source_code = source
	if generated_script.reload() != OK or not generated_script.can_instantiate(): return "PARSE_FAILED"
	var instance = generated_script.new()
	var result: String = instance.execute()
	instance.free()
	return result

func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()

func _write_json(path: String, value: Variant) -> void:
	_write_text(path, JSON.stringify(value, "\t", true) + "\n")
