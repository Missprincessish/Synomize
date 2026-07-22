extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var graph := VectorVerseVisualGraph.new()
	graph.insert_atom("app_start")
	graph.insert_atom("display_message")
	var validation := VectorVerseValidationPipeline.validate_graph(graph)
	var first := VectorVerseGDScriptAdapter.generate_from_ir(validation.ir)
	var second := VectorVerseGDScriptAdapter.generate_from_ir(validation.ir)

	if not first.accepted or not second.accepted:
		failures.append("Program 1 backend generation was not accepted.")
	if first.source != second.source or first.manifest != second.manifest or first.source_map != second.source_map:
		failures.append("Backend output, manifest, or source map changed across identical generation.")
	if first.source.sha256_text() != "35eac966cc92dfd0b23d762d6194ca7e7a17f83ec2d73e7d683e03e764e888e9":
		failures.append("Program 1 source changed from the approved checkpoint.")
	if first.source_map.size() != 4:
		failures.append("Expected four deterministic source-map spans.")
	if not first.source_map.any(func(span): return span.get("source_block_id", "") == "node_0001"):
		failures.append("App Start block is not represented in the source map.")
	if not first.source_map.any(func(span): return span.get("source_block_id", "") == "node_0002"):
		failures.append("Log block is not represented in the source map.")
	if first.manifest.has("timestamp") or first.manifest.has("generated_at"):
		failures.append("Deterministic build manifest contains runtime time data.")

	var generated_script := GDScript.new()
	generated_script.source_code = first.source
	var parse_ok := generated_script.reload() == OK and generated_script.can_instantiate()
	if not parse_ok:
		failures.append("Generated Program 1 GDScript did not parse.")
	var runtime_message := ""
	if parse_ok:
		var instance = generated_script.new()
		runtime_message = instance.execute()
		instance.free()
	if runtime_message != "Hello, Synomize!":
		failures.append("Generated Program 1 runtime output changed.")

	var unsupported_ir: Dictionary = validation.ir.duplicate(true)
	for node in unsupported_ir.nodes:
		if node.get("operation_kind", "") == "ACTION_CALL":
			node.operation_kind = "MAGIC_UNKNOWN"
	var unsupported_first := VectorVerseGDScriptAdapter.generate_from_ir(unsupported_ir)
	var unsupported_second := VectorVerseGDScriptAdapter.generate_from_ir(unsupported_ir)
	if unsupported_first.accepted or not unsupported_first.source.is_empty():
		failures.append("Unsupported IR generated source instead of failing visibly.")
	if unsupported_first.diagnostics != unsupported_second.diagnostics:
		failures.append("Backend diagnostics are not deterministic.")
	if not unsupported_first.diagnostics.any(func(item): return item.get("code", "") == "B_UNSUPPORTED_IR_OPERATION"):
		failures.append("Unsupported IR did not produce the expected backend diagnostic.")

	if failures.is_empty():
		print("VECTORVERSE_PHASE3_BACKEND_PASS")
		print("BACKEND_VERSION=" + VectorVerseGDScriptAdapter.BACKEND_VERSION)
		print("SOURCE_SHA256=" + first.source.sha256_text())
		print("SOURCE_MAP_SHA256=" + JSON.stringify(first.source_map, "\t", true).sha256_text())
		print("MANIFEST_SHA256=" + JSON.stringify(first.manifest, "\t", true).sha256_text())
		print("RUNTIME_MESSAGE=" + runtime_message)
		print("UNSUPPORTED_IR_FAILS_VISIBLY=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
