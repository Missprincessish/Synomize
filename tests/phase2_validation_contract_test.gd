extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var graph := VectorVerseVisualGraph.new()
	graph.insert_atom("app_start")
	graph.insert_atom("display_message")
	var result := VectorVerseValidationPipeline.validate_graph(graph)

	if not result.graph_valid or not result.backend_supported or not result.accepted_for_backend:
		failures.append("Program 1 did not pass the complete Phase 2 validation pipeline: " + JSON.stringify(result.diagnostics))
	if result.ir.get("ir_schema_version", "") != VectorVerseTypedIRSerializer.IR_SCHEMA_VERSION:
		failures.append("Typed IR schema version missing or incorrect.")
	if result.ir.get("nodes", []).size() != 3:
		failures.append("Program 1 IR must contain Event, synthetic Value literal, and Log Action.")
	if result.ir.get("control_edges", []).size() != 1 or result.ir.get("data_edges", []).size() != 1:
		failures.append("Program 1 IR must separate one control edge and one data edge.")
	var json_a := VectorVerseTypedIRSerializer.canonical_json(result.ir)
	var json_b := VectorVerseTypedIRSerializer.canonical_json(VectorVerseTypedIRSerializer.from_graph(graph))
	if json_a != json_b or json_a.sha256_text() != json_b.sha256_text():
		failures.append("Typed IR serialization is not deterministic.")

	var missing_capability := VectorVerseValidationPipeline.validate_graph(graph, {"declared": [], "approved_sensitive": []})
	if not _has_code(missing_capability.capability_diagnostics, "E_CAPABILITY_NOT_DECLARED"):
		failures.append("Capability validator did not reject undeclared LOG.")

	var sensitive_ir: Dictionary = result.ir.duplicate(true)
	for node in sensitive_ir.nodes:
		if node.get("operation_kind", "") == "ACTION_CALL":
			node.capabilities = ["NETWORK"]
	var sensitive_errors := VectorVerseCapabilityValidator.validate(sensitive_ir, {"declared": ["NETWORK"], "approved_sensitive": []})
	if not _has_code(sensitive_errors, "E_PERMISSION_REQUIRED"):
		failures.append("Sensitive capability did not require explicit approval.")

	var type_bad: Dictionary = result.ir.duplicate(true)
	for node in type_bad.nodes:
		if node.get("operation_kind", "") == "VALUE_LITERAL":
			node.parameters.value_type = "Bool"
			node.ports[0].value_type = "Bool"
	var type_errors := VectorVerseTypeValidator.validate(type_bad)
	if not _has_code(type_errors, "E_LITERAL_TYPE_MISMATCH") or not _has_code(type_errors, "E_TYPE_MISMATCH"):
		failures.append("Type validator did not reject mismatched literal and connection types.")

	var dangling: Dictionary = result.ir.duplicate(true)
	dangling.data_edges[0].to_node = "missing_node"
	var dangling_errors := VectorVerseTypedIRValidator.validate(dangling)
	if not _has_code(dangling_errors, "E_DANGLING_EDGE"):
		failures.append("IR validator did not reject a dangling edge.")

	var program2 := _program2_ir()
	var p2_graph_errors := VectorVerseTypedIRValidator.validate(program2)
	var p2_type_errors := VectorVerseTypeValidator.validate(program2)
	var p2_backend_errors := VectorVerseBackendSupportChecker.validate(program2)
	if not p2_graph_errors.is_empty() or not p2_type_errors.is_empty():
		failures.append("Program 2 IR fixture is not structurally/type valid.")
	if not p2_backend_errors.is_empty():
		failures.append("Program 2 Condition operations should now be supported by the Phase 5 backend.")

	var program3 := _program3_ir()
	var p3_graph_errors := VectorVerseTypedIRValidator.validate(program3)
	var p3_type_errors := VectorVerseTypeValidator.validate(program3)
	var p3_backend_errors := VectorVerseBackendSupportChecker.validate(program3)
	if not p3_graph_errors.is_empty() or not p3_type_errors.is_empty():
		failures.append("Program 3 IR fixture is not structurally/type valid.")
	if not p3_backend_errors.is_empty():
		failures.append("Program 3 State operations should now be supported by the Phase 6 backend.")

	var first_codes := _codes(VectorVerseValidationDiagnostic.stable_sort(p2_backend_errors))
	var second_codes := _codes(VectorVerseValidationDiagnostic.stable_sort(p2_backend_errors))
	if first_codes != second_codes:
		failures.append("Diagnostic ordering is not stable.")

	if failures.is_empty():
		print("VECTORVERSE_PHASE2_VALIDATION_PASS")
		print("IR_SCHEMA_VERSION=" + VectorVerseTypedIRSerializer.IR_SCHEMA_VERSION)
		print("PROGRAM1_ACCEPTED_FOR_GDSCRIPT=true")
		print("PROGRAM2_VALID_IR_BACKEND_SUPPORTED=true")
		print("PROGRAM3_VALID_IR_BACKEND_SUPPORTED=true")
		print("DIAGNOSTICS_STABLE=true")
		print("IR_SHA256=" + json_a.sha256_text())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _has_code(diagnostics: Array, code: String) -> bool:
	return diagnostics.any(func(item): return item.get("code", "") == code)

func _codes(diagnostics: Array) -> Array[String]:
	var codes: Array[String] = []
	for diagnostic in diagnostics:
		codes.append(diagnostic.get("code", ""))
	return codes

func _node(node_id: String, source_id: String, operation: String, ports: Array, parameters: Dictionary = {}, capabilities: Array = [], effect: String = "PURE") -> Dictionary:
	return {
		"node_id": node_id,
		"source_block_id": source_id,
		"atom_id": "fixture_" + operation.to_lower(),
		"atom_schema_version": "1.0.0",
		"operation_kind": operation,
		"family": "Fixture",
		"effect_class": effect,
		"capabilities": capabilities,
		"ports": ports,
		"parameters": parameters,
		"serialization_version": 1
	}

func _control_out(id: String = "control_out") -> Dictionary:
	return {"id": id, "category": "control", "direction": "output", "value_type": "Void", "required": true}

func _control_in(id: String = "control_in") -> Dictionary:
	return {"id": id, "category": "control", "direction": "input", "value_type": "Void", "required": true}

func _data_out(id: String, type_name: String) -> Dictionary:
	return {"id": id, "category": "data", "direction": "output", "value_type": type_name, "required": true}

func _data_in(id: String, type_name: String) -> Dictionary:
	return {"id": id, "category": "data", "direction": "input", "value_type": type_name, "required": true}

func _edge(id: String, category: String, from_node: String, from_port: String, to_node: String, to_port: String, type_name: String = "") -> Dictionary:
	var edge := {"edge_id": id, "category": category, "from_node": from_node, "from_port": from_port, "to_node": to_node, "to_port": to_port}
	if category == "data":
		edge["value_type"] = type_name
	return edge

func _program2_ir() -> Dictionary:
	return {
		"ir_schema_version": "1.0.0", "serialization_version": 1, "source_graph_schema_version": "1.1.0", "graph_id": "program2_condition",
		"nodes": [
			_node("n1", "vr_event", "EVENT_ENTRY", [_control_out()]),
			_node("n2", "vr_bool", "VALUE_LITERAL", [_data_out("value", "Bool")], {"value": true, "value_type": "Bool"}),
			_node("n3", "vr_condition", "COND_BRANCH", [_control_in(), _data_in("condition", "Bool"), _control_out("true"), _control_out("false")]),
			_node("n4", "vr_true", "ACTION_CALL", [_control_in(), _data_in("message", "String")], {}, ["LOG"], "EFFECTFUL"),
			_node("n5", "vr_false", "ACTION_CALL", [_control_in(), _data_in("message", "String")], {}, ["LOG"], "EFFECTFUL"),
			_node("n6", "vr_true_text", "VALUE_LITERAL", [_data_out("value", "String")], {"value": "Enabled", "value_type": "String"}),
			_node("n7", "vr_false_text", "VALUE_LITERAL", [_data_out("value", "String")], {"value": "Disabled", "value_type": "String"})
		],
		"control_edges": [_edge("c1", "control", "n1", "control_out", "n3", "control_in"), _edge("c2", "control", "n3", "true", "n4", "control_in"), _edge("c3", "control", "n3", "false", "n5", "control_in")],
		"data_edges": [_edge("d1", "data", "n2", "value", "n3", "condition", "Bool"), _edge("d2", "data", "n6", "value", "n4", "message", "String"), _edge("d3", "data", "n7", "value", "n5", "message", "String")]
	}

func _program3_ir() -> Dictionary:
	return {
		"ir_schema_version": "1.0.0", "serialization_version": 1, "source_graph_schema_version": "1.1.0", "graph_id": "program3_state",
		"nodes": [
			_node("n1", "vr_event", "EVENT_ENTRY", [_control_out()]),
			_node("n2", "vr_text", "VALUE_LITERAL", [_data_out("value", "String")], {"value": "Hello World", "value_type": "String"}),
			_node("n3", "vr_state_write", "STATE_WRITE", [_control_in(), _control_out(), _data_in("value", "String")], {"state_id": "welcomeMessage", "lifetime": "session"}, [], "STATEFUL"),
			_node("n4", "vr_state_read", "STATE_READ", [_control_in(), _control_out(), _data_out("value", "String")], {"state_id": "welcomeMessage", "lifetime": "session"}, [], "STATEFUL"),
			_node("n5", "vr_log", "ACTION_CALL", [_control_in(), _data_in("message", "String")], {}, ["LOG"], "EFFECTFUL")
		],
		"control_edges": [_edge("c1", "control", "n1", "control_out", "n3", "control_in"), _edge("c2", "control", "n3", "control_out", "n4", "control_in"), _edge("c3", "control", "n4", "control_out", "n5", "control_in")],
		"data_edges": [_edge("d1", "data", "n2", "value", "n3", "value", "String"), _edge("d2", "data", "n4", "value", "n5", "message", "String")]
	}
