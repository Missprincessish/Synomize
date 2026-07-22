class_name VectorVerseTypeValidator
extends RefCounted

static func validate(ir: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var node_by_id: Dictionary = {}
	for raw_node in ir.get("nodes", []):
		if raw_node is Dictionary:
			node_by_id[raw_node.get("node_id", "")] = raw_node
			diagnostics.append_array(_validate_literal(raw_node))

	for raw_edge in ir.get("data_edges", []):
		if not raw_edge is Dictionary:
			continue
		var edge: Dictionary = raw_edge
		var from_node: Dictionary = node_by_id.get(edge.get("from_node", ""), {})
		var to_node: Dictionary = node_by_id.get(edge.get("to_node", ""), {})
		if from_node.is_empty() or to_node.is_empty():
			continue
		var source := _find_port(from_node, edge.get("from_port", ""))
		var target := _find_port(to_node, edge.get("to_port", ""))
		if source.is_empty() or target.is_empty():
			continue
		var source_type: String = source.get("value_type", "")
		var target_type: String = target.get("value_type", "")
		if source_type != target_type:
			diagnostics.append(VectorVerseValidationDiagnostic.make(
				"E_TYPE_MISMATCH",
				"%s cannot connect directly to %s." % [source_type, target_type],
				"type",
				"error",
				"edge",
				to_node.get("source_block_id", to_node.get("node_id", "")),
				edge.get("to_port", ""),
				edge.get("edge_id", ""),
				"Use an explicit conversion block."
			))
	return VectorVerseValidationDiagnostic.stable_sort(diagnostics)

static func _validate_literal(node: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if node.get("operation_kind", "") != "VALUE_LITERAL":
		return diagnostics
	var parameters: Dictionary = node.get("parameters", {})
	var declared_type: String = parameters.get("value_type", "")
	var value = parameters.get("value")
	var actual_type := _variant_type_name(value)
	if declared_type != actual_type:
		diagnostics.append(VectorVerseValidationDiagnostic.make(
			"E_LITERAL_TYPE_MISMATCH",
			"Literal declares %s but contains %s." % [declared_type, actual_type],
			"type",
			"error",
			"node",
			node.get("source_block_id", node.get("node_id", "")),
			"value"
		))
	return diagnostics

static func _variant_type_name(value: Variant) -> String:
	if value is String:
		return "String"
	if value is bool:
		return "Bool"
	if value is int:
		return "Int"
	if value is float:
		return "Float"
	return "Unsupported"

static func _find_port(node: Dictionary, port_id: String) -> Dictionary:
	for raw_port in node.get("ports", []):
		if raw_port is Dictionary and raw_port.get("id", "") == port_id:
			return raw_port
	return {}
