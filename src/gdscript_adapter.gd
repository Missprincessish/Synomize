class_name VectorVerseGDScriptAdapter
extends RefCounted

const BACKEND_ID := "gdscript"
const BACKEND_VERSION := "1.5.0"
const TARGET_GODOT_VERSION := "4.7"
const TEMPLATE_PATH := "res://templates/gdscript/app_start_display_message.gd.tpl"
const TEMPLATE_SOURCE := "extends Node\n\nconst MESSAGE := {{MESSAGE_LITERAL}}\n\nfunc execute() -> String:\n\tprint(MESSAGE)\n\treturn MESSAGE\n\nfunc _ready() -> void:\n\texecute()\n\n"
const STATE_TEMPLATE := "extends Node\n\nconst INPUT_VALUE := {{VALUE_LITERAL}}\nvar session_state: Dictionary = {}\n\nfunc execute() -> String:\n\tsession_state[{{STATE_ID_LITERAL}}] = INPUT_VALUE\n\tvar result: String = session_state.get({{STATE_ID_LITERAL}}, \"\")\n\tprint(result)\n\treturn result\n\nfunc _ready() -> void:\n\texecute()\n\n"
const CONDITION_TEMPLATE := "extends Node\n\nconst CONDITION := {{CONDITION_LITERAL}}\nconst TRUE_MESSAGE := {{TRUE_LITERAL}}\nconst FALSE_MESSAGE := {{FALSE_LITERAL}}\n\nfunc execute() -> String:\n\tvar result := TRUE_MESSAGE if CONDITION else FALSE_MESSAGE\n\tprint(result)\n\treturn result\n\nfunc _ready() -> void:\n\texecute()\n\n"

static func generate(graph: VectorVerseVisualGraph, ordered_nodes: Array[String] = []) -> String:
	var result := generate_from_ir(VectorVerseTypedIRSerializer.from_graph(graph))
	return result.get("source", "") if result.get("accepted", false) else ""

static func generate_from_ir(ir: Dictionary) -> Dictionary:
	var diagnostics := VectorVerseBackendSupportChecker.validate(ir, BACKEND_ID)
	if not diagnostics.is_empty(): return _result("", [], diagnostics, ir)
	var operations: Array[String] = []
	for raw_node in ir.get("nodes", []):
		if raw_node is Dictionary: operations.append(raw_node.get("operation_kind", ""))
	if "EXPRESSION" in operations: return _generate_expression_program(ir)
	if "LOOP_CTRL" in operations: return _generate_loop_program(ir)
	if "VAR_BIND" in operations or "VAR_READ" in operations: return _generate_variable_program(ir)
	if "FUNCTION_OR_MODULE_BOUNDARY" in operations: return _generate_function_program(ir)
	if "ERROR_PATH" in operations: return _generate_error_program(ir)
	if "RETURN" in operations: return _generate_return_program(ir)
	if "STATE_WRITE" in operations or "STATE_READ" in operations: return _generate_program3(ir)
	if "COND_BRANCH" in operations: return _generate_program2(ir)
	return _generate_program1(ir)

static func _generate_program1(ir: Dictionary) -> Dictionary:
	var event_node: Dictionary = {}
	var literal_node: Dictionary = {}
	var action_node: Dictionary = {}
	for raw_node in ir.get("nodes", []):
		if not raw_node is Dictionary: continue
		match raw_node.get("operation_kind", ""):
			"EVENT_ENTRY": event_node = raw_node
			"VALUE_LITERAL": literal_node = raw_node
			"ACTION_CALL": action_node = raw_node
	var shape_errors: Array[Dictionary] = []
	if event_node.is_empty() or literal_node.is_empty() or action_node.is_empty(): shape_errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM1_SHAPE", "Program 1 backend requires one Event Entry, one String literal, and one Log action.", "backend"))
	if literal_node.get("parameters", {}).get("value_type", "") != "String": shape_errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM1_LITERAL_TYPE", "Program 1 message literal must be String.", "backend", "error", "node", literal_node.get("source_block_id", "")))
	if "LOG" not in action_node.get("capabilities", []): shape_errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM1_ACTION", "Program 1 action must declare LOG capability.", "backend", "error", "node", action_node.get("source_block_id", "")))
	if not shape_errors.is_empty(): return _result("", [], VectorVerseValidationDiagnostic.stable_sort(shape_errors), ir)
	var source := TEMPLATE_SOURCE.replace("{{MESSAGE_LITERAL}}", JSON.stringify(literal_node.get("parameters", {}).get("value", "")))
	var source_map: Array[Dictionary] = [_span("synthetic_scaffold_header", "synthetic", "", 1, 3), _span("message_literal", "node", literal_node.get("source_block_id", literal_node.get("node_id", "")), 3, 3), _span("execute_action", "node", action_node.get("source_block_id", action_node.get("node_id", "")), 5, 8), _span("app_start_entry", "node", event_node.get("source_block_id", event_node.get("node_id", "")), 10, 11)]
	return _result(source, source_map, [], ir)

static func _generate_program2(ir: Dictionary) -> Dictionary:
	var nodes := _node_index(ir)
	var condition_node: Dictionary = {}
	var event_node: Dictionary = {}
	for node in nodes.values():
		if node.get("operation_kind", "") == "COND_BRANCH": condition_node = node
		if node.get("operation_kind", "") == "EVENT_ENTRY": event_node = node
	var errors: Array[Dictionary] = []
	if condition_node.is_empty() or event_node.is_empty(): errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM2_SHAPE", "Program 2 requires App Start and one Condition.", "backend"))
	if not errors.is_empty(): return _result("", [], errors, ir)
	var condition_source := _incoming_data_node(ir, condition_node.node_id, "condition", nodes)
	var true_action := _control_target(ir, condition_node.node_id, "true", nodes)
	var false_action := _control_target(ir, condition_node.node_id, "false", nodes)
	var true_literal := _incoming_data_node(ir, true_action.get("node_id", ""), "message", nodes)
	var false_literal := _incoming_data_node(ir, false_action.get("node_id", ""), "message", nodes)
	if condition_source.get("parameters", {}).get("value_type", "") != "Bool": errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM2_BOOL_REQUIRED", "Condition input must be Bool.", "backend", "error", "node", condition_node.get("source_block_id", ""), "condition"))
	for pair in [[true_action, true_literal, "true"], [false_action, false_literal, "false"]]:
		if pair[0].is_empty() or pair[1].get("parameters", {}).get("value_type", "") != "String" or "LOG" not in pair[0].get("capabilities", []): errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM2_BRANCH_SHAPE", "Each Condition branch requires one String-fed Log action.", "backend", "error", "node", condition_node.get("source_block_id", ""), str(pair[2])))
	if not errors.is_empty(): return _result("", [], VectorVerseValidationDiagnostic.stable_sort(errors), ir)
	var source := CONDITION_TEMPLATE.replace("{{CONDITION_LITERAL}}", "true" if condition_source.parameters.value else "false").replace("{{TRUE_LITERAL}}", JSON.stringify(true_literal.parameters.value)).replace("{{FALSE_LITERAL}}", JSON.stringify(false_literal.parameters.value))
	var source_map: Array[Dictionary] = [
		_span("program2_scaffold", "synthetic", "", 1, 2),
		_span("condition_literal", "node", condition_source.get("source_block_id", ""), 3, 3),
		_span("true_message_literal", "node", true_literal.get("source_block_id", ""), 4, 4),
		_span("false_message_literal", "node", false_literal.get("source_block_id", ""), 5, 5),
		_span("condition_branch", "node", condition_node.get("source_block_id", ""), 7, 10),
		_span("true_log_action", "node", true_action.get("source_block_id", ""), 8, 10),
		_span("false_log_action", "node", false_action.get("source_block_id", ""), 8, 10),
		_span("app_start_entry", "node", event_node.get("source_block_id", ""), 12, 13)
	]
	return _result(source, source_map, [], ir)

static func _generate_program3(ir: Dictionary) -> Dictionary:
	var nodes := _node_index(ir)
	var event_node: Dictionary = {}
	var write_node: Dictionary = {}
	var read_node: Dictionary = {}
	var log_node: Dictionary = {}
	for node in nodes.values():
		match node.get("operation_kind", ""):
			"EVENT_ENTRY": event_node = node
			"STATE_WRITE": write_node = node
			"STATE_READ": read_node = node
			"ACTION_CALL":
				if "LOG" in node.get("capabilities", []): log_node = node
	var errors: Array[Dictionary] = []
	if event_node.is_empty() or write_node.is_empty() or read_node.is_empty() or log_node.is_empty():
		errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM3_SHAPE", "Program 3 requires App Start, State Write, State Read, and Log.", "backend"))
	var value_node := _incoming_data_node(ir, write_node.get("node_id", ""), "value", nodes)
	var state_id: String = write_node.get("parameters", {}).get("state_id", "")
	if value_node.get("parameters", {}).get("value_type", "") != "String":
		errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM3_STRING_REQUIRED", "State Write input must be String.", "backend", "error", "node", write_node.get("source_block_id", ""), "value"))
	if state_id.is_empty() or read_node.get("parameters", {}).get("state_id", "") != state_id:
		errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM3_STATE_ID_MISMATCH", "State Write and State Read must use the same non-empty state_id.", "backend"))
	if write_node.get("parameters", {}).get("lifetime", "") != "session" or read_node.get("parameters", {}).get("lifetime", "") != "session":
		errors.append(VectorVerseValidationDiagnostic.make("B_PROGRAM3_LIFETIME", "Phase 6 supports session state only.", "backend"))
	if not errors.is_empty(): return _result("", [], VectorVerseValidationDiagnostic.stable_sort(errors), ir)
	var source := STATE_TEMPLATE.replace("{{VALUE_LITERAL}}", JSON.stringify(value_node.parameters.value)).replace("{{STATE_ID_LITERAL}}", JSON.stringify(state_id))
	var source_map: Array[Dictionary] = [
		_span("program3_scaffold", "synthetic", "", 1, 4),
		_span("state_input_literal", "node", value_node.get("source_block_id", ""), 3, 3),
		_span("state_write", "node", write_node.get("source_block_id", ""), 7, 7),
		_span("state_read", "node", read_node.get("source_block_id", ""), 8, 8),
		_span("log_action", "node", log_node.get("source_block_id", ""), 9, 10),
		_span("app_start_entry", "node", event_node.get("source_block_id", ""), 12, 13)
	]
	return _result(source, source_map, [], ir)


static func _generate_expression_program(ir: Dictionary) -> Dictionary:
	var nodes := _node_index(ir)
	var expression: Dictionary = {}
	for node in nodes.values():
		if node.get("operation_kind", "") == "EXPRESSION":
			expression = node
	var errors: Array[Dictionary] = []
	if expression.is_empty():
		errors.append(VectorVerseValidationDiagnostic.make("B_EXPRESSION_SHAPE", "Expression program requires one Expression node.", "backend"))
		return _result("", [], errors, ir)
	var left_node := _incoming_data_node(ir, expression.get("node_id", ""), "left", nodes)
	var right_node := _incoming_data_node(ir, expression.get("node_id", ""), "right", nodes)
	var left_value := _resolve_expression_operand(ir, left_node, nodes)
	var right_value := _resolve_expression_operand(ir, right_node, nodes)
	if not left_value.get("resolved", false):
		errors.append(VectorVerseValidationDiagnostic.make("B_EXPRESSION_LEFT", "Expression left operand could not be resolved.", "backend", "error", "node", expression.get("source_block_id", ""), "left"))
	if not right_value.get("resolved", false):
		errors.append(VectorVerseValidationDiagnostic.make("B_EXPRESSION_RIGHT", "Expression right operand could not be resolved.", "backend", "error", "node", expression.get("source_block_id", ""), "right"))
	var operator: String = expression.get("parameters", {}).get("operator", "")
	if operator not in ["+", "-", "*", "/", "%", "==", "!=", "<", "<=", ">", ">="]:
		errors.append(VectorVerseValidationDiagnostic.make("B_EXPRESSION_OPERATOR", "Expression operator is not supported by GDScript backend.", "backend", "error", "node", expression.get("source_block_id", "")))
	if not errors.is_empty():
		return _result("", [], VectorVerseValidationDiagnostic.stable_sort(errors), ir)
	var source := "extends Node\n\nfunc execute() -> Variant:\n\tvar left: Variant = %s\n\tvar right: Variant = %s\n\tvar result: Variant = left %s right\n\tprint(result)\n\treturn result\n" % [JSON.stringify(left_value.value), JSON.stringify(right_value.value), operator]
	var source_map: Array[Dictionary] = [
		_span("expression_left", "node", left_node.get("source_block_id", ""), 4, 4),
		_span("expression_right", "node", right_node.get("source_block_id", ""), 5, 5),
		_span("expression_operation", "node", expression.get("source_block_id", ""), 6, 8)
	]
	return _result(source, source_map, [], ir)

static func _resolve_expression_operand(ir: Dictionary, node: Dictionary, nodes: Dictionary) -> Dictionary:
	if node.is_empty():
		return {"resolved": false}
	match node.get("operation_kind", ""):
		"VALUE_LITERAL":
			return {"resolved": true, "value": node.get("parameters", {}).get("value")}
		"VAR_READ":
			var symbol: String = node.get("parameters", {}).get("symbol", "")
			var scope_id: String = node.get("parameters", {}).get("scope_id", "root")
			for candidate in nodes.values():
				if candidate.get("operation_kind", "") == "VAR_BIND" and candidate.get("parameters", {}).get("symbol", "") == symbol and candidate.get("parameters", {}).get("scope_id", "root") == scope_id:
					var bound_source := _incoming_data_node(ir, candidate.get("node_id", ""), "value", nodes)
					return _resolve_expression_operand(ir, bound_source, nodes)
	return {"resolved": false}

static func _generate_variable_program(ir: Dictionary) -> Dictionary:
	var nodes := _node_index(ir)
	var bind: Dictionary = {}; var read: Dictionary = {}
	for node in nodes.values():
		if node.get("operation_kind", "") == "VAR_BIND": bind = node
		if node.get("operation_kind", "") == "VAR_READ": read = node
	var value := _incoming_data_node(ir, bind.get("node_id", ""), "value", nodes)
	var errors: Array[Dictionary] = []
	if bind.is_empty() or read.is_empty() or value.is_empty(): errors.append(VectorVerseValidationDiagnostic.make("B_VARIABLE_SHAPE", "Variable program requires bind, read, and input literal.", "backend"))
	if bind.get("parameters", {}).get("symbol", "") != read.get("parameters", {}).get("symbol", ""): errors.append(VectorVerseValidationDiagnostic.make("B_VARIABLE_SYMBOL", "Variable read must use the bound symbol.", "backend", "error", "node", read.get("source_block_id", "")))
	if not errors.is_empty(): return _result("", [], errors, ir)
	var literal := JSON.stringify(value.get("parameters", {}).get("value", ""))
	var source := "extends Node\n\nfunc execute() -> String:\n\tvar bound_value: String = %s\n\tvar result: String = bound_value\n\tprint(result)\n\treturn result\n" % literal
	return _result(source, [_span("variable_bind", "node", bind.get("source_block_id", ""), 4, 4), _span("variable_read", "node", read.get("source_block_id", ""), 5, 7)], [], ir)

static func _generate_loop_program(ir: Dictionary) -> Dictionary:
	var nodes := _node_index(ir); var loop: Dictionary = {}; var message: Dictionary = {}
	for node in nodes.values():
		if node.get("operation_kind", "") == "LOOP_CTRL": loop = node
		if node.get("operation_kind", "") == "VALUE_LITERAL" and node.get("parameters", {}).get("value_type", "") == "String": message = node
	var count: int = int(loop.get("parameters", {}).get("max_iterations", 0))
	var errors: Array[Dictionary] = []
	if loop.is_empty() or message.is_empty() or count < 1: errors.append(VectorVerseValidationDiagnostic.make("B_LOOP_SHAPE", "Loop program requires a positive bounded count and String body value.", "backend"))
	if not errors.is_empty(): return _result("", [], errors, ir)
	var source := "extends Node\n\nfunc execute() -> String:\n\tvar values: Array[String] = []\n\tfor index in range(%d):\n\t\tvalues.append(%s)\n\tvar result := \",\".join(values)\n\tprint(result)\n\treturn result\n" % [count, JSON.stringify(message.parameters.value)]
	return _result(source, [_span("bounded_loop", "node", loop.get("source_block_id", ""), 5, 6)], [], ir)

static func _generate_function_program(ir: Dictionary) -> Dictionary:
	var nodes := _node_index(ir); var boundary: Dictionary = {}; var ret: Dictionary = {}
	for node in nodes.values():
		if node.get("operation_kind", "") == "FUNCTION_OR_MODULE_BOUNDARY": boundary = node
		if node.get("operation_kind", "") == "RETURN": ret = node
	var value := _incoming_data_node(ir, ret.get("node_id", ""), "value", nodes)
	var errors: Array[Dictionary] = []
	if boundary.is_empty() or ret.is_empty() or value.is_empty(): errors.append(VectorVerseValidationDiagnostic.make("B_FUNCTION_SHAPE", "Function program requires boundary, return, and return value.", "backend"))
	if not errors.is_empty(): return _result("", [], errors, ir)
	var source := "extends Node\n\nfunc module_main() -> String:\n\treturn %s\n\nfunc execute() -> String:\n\tvar result := module_main()\n\tprint(result)\n\treturn result\n" % JSON.stringify(value.parameters.value)
	return _result(source, [_span("module_boundary", "node", boundary.get("source_block_id", ""), 3, 4), _span("return", "node", ret.get("source_block_id", ""), 4, 4)], [], ir)

static func _generate_return_program(ir: Dictionary) -> Dictionary:
	var nodes := _node_index(ir); var ret: Dictionary = {}
	for node in nodes.values():
		if node.get("operation_kind", "") == "RETURN": ret = node
	var value := _incoming_data_node(ir, ret.get("node_id", ""), "value", nodes)
	if ret.is_empty() or value.is_empty(): return _result("", [], [VectorVerseValidationDiagnostic.make("B_RETURN_SHAPE", "Return program requires a value.", "backend")], ir)
	var source := "extends Node\n\nfunc execute() -> String:\n\treturn %s\n" % JSON.stringify(value.parameters.value)
	return _result(source, [_span("return", "node", ret.get("source_block_id", ""), 4, 4)], [], ir)

static func _generate_error_program(ir: Dictionary) -> Dictionary:
	var nodes := _node_index(ir); var error_node: Dictionary = {}
	for node in nodes.values():
		if node.get("operation_kind", "") == "ERROR_PATH": error_node = node
	var value := _incoming_data_node(ir, error_node.get("node_id", ""), "error", nodes)
	if error_node.is_empty() or value.is_empty(): return _result("", [], [VectorVerseValidationDiagnostic.make("B_ERROR_SHAPE", "Error Path requires an error String.", "backend")], ir)
	var source := "extends Node\n\nfunc execute() -> String:\n\tvar error_message: String = %s\n\tvar result := \"handled:\" + error_message\n\tprint(result)\n\treturn result\n" % JSON.stringify(value.parameters.value)
	return _result(source, [_span("error_path", "node", error_node.get("source_block_id", ""), 4, 7)], [], ir)

static func _node_index(ir: Dictionary) -> Dictionary:
	var result := {}
	for node in ir.get("nodes", []):
		if node is Dictionary: result[node.get("node_id", "")] = node
	return result

static func _incoming_data_node(ir: Dictionary, to_node: String, to_port: String, nodes: Dictionary) -> Dictionary:
	for edge in ir.get("data_edges", []):
		if edge.get("to_node", "") == to_node and edge.get("to_port", "") == to_port: return nodes.get(edge.get("from_node", ""), {})
	return {}

static func _control_target(ir: Dictionary, from_node: String, from_port: String, nodes: Dictionary) -> Dictionary:
	for edge in ir.get("control_edges", []):
		if edge.get("from_node", "") == from_node and edge.get("from_port", "") == from_port: return nodes.get(edge.get("to_node", ""), {})
	return {}

static func _result(source: String, source_map: Array[Dictionary], diagnostics: Array, ir: Dictionary) -> Dictionary:
	var typed_diagnostics: Array[Dictionary] = []
	for diagnostic in diagnostics:
		if diagnostic is Dictionary: typed_diagnostics.append(diagnostic)
	var sorted_diagnostics := VectorVerseValidationDiagnostic.stable_sort(typed_diagnostics)
	var manifest := {"manifest_version": "1.0.0", "backend_id": BACKEND_ID, "backend_version": BACKEND_VERSION, "target_godot_version": TARGET_GODOT_VERSION, "ir_schema_version": ir.get("ir_schema_version", ""), "ir_sha256": VectorVerseTypedIRSerializer.canonical_json(ir).sha256_text(), "source_sha256": source.sha256_text(), "source_map_sha256": JSON.stringify(source_map, "\t", true).sha256_text(), "diagnostics_sha256": JSON.stringify(sorted_diagnostics, "\t", true).sha256_text()}
	return {"accepted": sorted_diagnostics.is_empty() and not source.is_empty(), "source": source, "source_map": source_map, "diagnostics": sorted_diagnostics, "manifest": manifest}

static func _span(span_id: String, target_kind: String, source_block_id: String, start_line: int, end_line: int) -> Dictionary:
	return {"span_id": span_id, "target_kind": target_kind, "source_block_id": source_block_id, "generated_start_line": start_line, "generated_end_line": end_line}
