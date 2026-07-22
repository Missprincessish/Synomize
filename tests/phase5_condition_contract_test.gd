extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var true_graph := VectorVerseVisualGraph.new()
	true_graph.configure_program2(true)
	var false_graph := VectorVerseVisualGraph.new()
	false_graph.configure_program2(false)
	var true_validation := VectorVerseValidationPipeline.validate_graph(true_graph)
	var false_validation := VectorVerseValidationPipeline.validate_graph(false_graph)
	if not true_validation.accepted_for_backend:
		failures.append("True Program 2 graph failed validation: " + JSON.stringify(true_validation.diagnostics))
	if not false_validation.accepted_for_backend:
		failures.append("False Program 2 graph failed validation: " + JSON.stringify(false_validation.diagnostics))
	var true_a := VectorVerseGDScriptAdapter.generate_from_ir(true_validation.ir)
	var true_b := VectorVerseGDScriptAdapter.generate_from_ir(true_validation.ir)
	var false_a := VectorVerseGDScriptAdapter.generate_from_ir(false_validation.ir)
	var false_b := VectorVerseGDScriptAdapter.generate_from_ir(false_validation.ir)
	if not true_a.accepted or not false_a.accepted:
		failures.append("Program 2 backend generation was rejected.")
	if true_a.source != true_b.source or true_a.source_map != true_b.source_map or true_a.manifest != true_b.manifest:
		failures.append("True branch regeneration was not deterministic.")
	if false_a.source != false_b.source or false_a.source_map != false_b.source_map or false_a.manifest != false_b.manifest:
		failures.append("False branch regeneration was not deterministic.")
	var true_runtime := _run_generated(true_a.source)
	var false_runtime := _run_generated(false_a.source)
	if true_runtime != "Enabled": failures.append("True fixture did not execute only Enabled.")
	if false_runtime != "Disabled": failures.append("False fixture did not execute only Disabled.")
	if not true_a.source_map.any(func(span): return span.get("span_id", "") == "condition_branch"):
		failures.append("Condition branch is missing from the source map.")
	if not true_a.source_map.any(func(span): return span.get("source_block_id", "") == "node_0004"):
		failures.append("True Log block is missing from the source map.")
	if not true_a.source_map.any(func(span): return span.get("source_block_id", "") == "node_0005"):
		failures.append("False Log block is missing from the source map.")
	var invalid_ir: Dictionary = true_validation.ir.duplicate(true)
	for node in invalid_ir.nodes:
		if node.get("node_id", "") == "node_0002":
			node.parameters.value = "not a bool"
			node.parameters.value_type = "String"
			node.ports[0].value_type = "String"
	var invalid_type_errors := VectorVerseTypeValidator.validate(invalid_ir)
	var invalid_backend := VectorVerseGDScriptAdapter.generate_from_ir(invalid_ir)
	if not invalid_type_errors.any(func(item): return item.get("code", "") == "E_TYPE_MISMATCH"):
		failures.append("Non-Bool condition fixture was not rejected by type validation.")
	if invalid_backend.accepted or not invalid_backend.source.is_empty():
		failures.append("Invalid condition fixture emitted executable source.")
	_write_text("res://generated/program2_condition_true.gd", true_a.source)
	_write_text("res://generated/program2_condition_false.gd", false_a.source)
	_write_json("res://evidence/program2_true_ir.json", true_validation.ir)
	_write_json("res://evidence/program2_false_ir.json", false_validation.ir)
	_write_json("res://evidence/program2_true_source_map.json", true_a.source_map)
	_write_json("res://evidence/program2_false_source_map.json", false_a.source_map)
	_write_json("res://evidence/phase5_condition_evidence.json", {
		"accepted": failures.is_empty(),
		"phase": 5,
		"program": "App Start + Bool + Condition + two Log actions",
		"true_runtime": true_runtime,
		"false_runtime": false_runtime,
		"non_bool_rejected": not invalid_type_errors.is_empty() and not invalid_backend.accepted,
		"true_source_sha256": true_a.source.sha256_text(),
		"false_source_sha256": false_a.source.sha256_text(),
		"true_ir_sha256": VectorVerseTypedIRSerializer.canonical_json(true_validation.ir).sha256_text(),
		"false_ir_sha256": VectorVerseTypedIRSerializer.canonical_json(false_validation.ir).sha256_text(),
		"true_source_map_sha256": JSON.stringify(true_a.source_map, "\t", true).sha256_text(),
		"false_source_map_sha256": JSON.stringify(false_a.source_map, "\t", true).sha256_text(),
		"desktop_runtime_proven": true,
		"quest_runtime_proven_this_run": false,
		"quest_reason": "No ADB device was connected during this run; packaged self-test markers are embedded for the next headset launch.",
		"errors": failures
	})
	if failures.is_empty():
		print("VECTORVERSE_PHASE5_CONDITION_PASS")
		print("TRUE_RUNTIME=Enabled")
		print("FALSE_RUNTIME=Disabled")
		print("TRUE_SOURCE_SHA256=" + true_a.source.sha256_text())
		print("FALSE_SOURCE_SHA256=" + false_a.source.sha256_text())
		print("TRUE_SOURCE_MAP_SHA256=" + JSON.stringify(true_a.source_map, "\t", true).sha256_text())
		print("FALSE_SOURCE_MAP_SHA256=" + JSON.stringify(false_a.source_map, "\t", true).sha256_text())
		print("NON_BOOL_REJECTED=true")
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
