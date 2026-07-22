class_name VectorVerseTypedIRValidator
extends RefCounted

static func validate(ir: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if not (ir.get("ir_schema_version", "") in ["1.0.0", VectorVerseTypedIRSerializer.IR_SCHEMA_VERSION]):
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_SCHEMA_VERSION", "Unsupported typed IR schema version.", "graph", "error", "graph", "", "", "", "Use a supported schema or explicit migration."))
	if not (ir.get("serialization_version", -1) in [1, VectorVerseTypedIRSerializer.SERIALIZATION_VERSION]):
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_SERIALIZATION_VERSION", "Unsupported typed IR serialization version.", "graph"))

	var node_by_id: Dictionary = {}
	for raw_node in ir.get("nodes", []):
		if not raw_node is Dictionary:
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_NODE_NOT_OBJECT", "IR node is not an object.", "graph"))
			continue
		var node: Dictionary = raw_node
		var node_id: String = node.get("node_id", "")
		if node_id.is_empty() or node_by_id.has(node_id):
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_DUPLICATE_NODE_ID", "IR node ID is missing or duplicated.", "graph", "error", "node", node_id))
			continue
		node_by_id[node_id] = node
		if node.get("source_block_id", "").is_empty():
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_SOURCE_BLOCK_MISSING", "IR node cannot map back to a VR block.", "graph", "error", "node", node_id))
		if node.get("operation_kind", "").is_empty():
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_OPERATION_KIND_MISSING", "IR node has no operation kind.", "graph", "error", "node", node_id))
		diagnostics.append_array(_validate_ports(node))

	var edge_ids: Dictionary = {}
	for raw_edge in ir.get("control_edges", []):
		if raw_edge is Dictionary:
			diagnostics.append_array(_validate_edge(raw_edge, "control", node_by_id, edge_ids))
		else:
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_EDGE_NOT_OBJECT", "Control edge is not an object.", "graph"))
	for raw_edge in ir.get("data_edges", []):
		if raw_edge is Dictionary:
			diagnostics.append_array(_validate_edge(raw_edge, "data", node_by_id, edge_ids))
		else:
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_EDGE_NOT_OBJECT", "Data edge is not an object.", "graph"))
	return VectorVerseValidationDiagnostic.stable_sort(diagnostics)

static func _validate_ports(node: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var ids: Dictionary = {}
	for raw_port in node.get("ports", []):
		if not raw_port is Dictionary:
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_PORT_NOT_OBJECT", "IR port is not an object.", "graph", "error", "node", node.node_id))
			continue
		var port: Dictionary = raw_port
		var port_id: String = port.get("id", "")
		if port_id.is_empty() or ids.has(port_id):
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_DUPLICATE_PORT_ID", "Port ID is missing or duplicated.", "graph", "error", "port", node.node_id, port_id))
		else:
			ids[port_id] = true
		if port.get("category", "") not in VectorVerseAtomCatalog.PORT_CATEGORIES:
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_PORT_CATEGORY", "Port category must be control or data.", "graph", "error", "port", node.node_id, port_id))
		if port.get("direction", "") not in VectorVerseAtomCatalog.PORT_DIRECTIONS:
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_PORT_DIRECTION", "Port direction must be input or output.", "graph", "error", "port", node.node_id, port_id))
		if port.get("value_type", "") not in VectorVerseAtomCatalog.VALUE_TYPES:
			diagnostics.append(VectorVerseValidationDiagnostic.make("E_UNSUPPORTED_TYPE", "Port uses an unsupported value type.", "type", "error", "port", node.node_id, port_id))
	return diagnostics

static func _validate_edge(edge: Dictionary, expected_category: String, node_by_id: Dictionary, edge_ids: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var edge_id: String = edge.get("edge_id", "")
	if edge_id.is_empty() or edge_ids.has(edge_id):
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_DUPLICATE_EDGE_ID", "Edge ID is missing or duplicated.", "graph", "error", "edge", "", "", edge_id))
	else:
		edge_ids[edge_id] = true
	if edge.get("category", "") != expected_category:
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_EDGE_CATEGORY", "Edge is stored in the wrong category collection.", "graph", "error", "edge", "", "", edge_id))
	var from_id: String = edge.get("from_node", "")
	var to_id: String = edge.get("to_node", "")
	if not node_by_id.has(from_id) or not node_by_id.has(to_id):
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_DANGLING_EDGE", "Edge references a missing node.", "graph", "error", "edge", "", "", edge_id))
		return diagnostics
	var from_port := _find_port(node_by_id[from_id], edge.get("from_port", ""))
	var to_port := _find_port(node_by_id[to_id], edge.get("to_port", ""))
	if from_port.is_empty() or to_port.is_empty():
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_MISSING_PORT", "Edge references a missing port.", "graph", "error", "edge", "", "", edge_id))
		return diagnostics
	if from_port.get("direction", "") != "output" or to_port.get("direction", "") != "input":
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_INVALID_EDGE_DIRECTION", "Connections must run from output to input.", "graph", "error", "edge", "", "", edge_id))
	if from_port.get("category", "") != expected_category or to_port.get("category", "") != expected_category:
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_PORT_CATEGORY_MISMATCH", "Control and data ports cannot be crossed.", "graph", "error", "edge", "", "", edge_id))
	if expected_category == "data" and from_port.get("value_type", "") != to_port.get("value_type", ""):
		diagnostics.append(VectorVerseValidationDiagnostic.make("E_TYPE_MISMATCH", "Connected data ports have different types.", "type", "error", "edge", to_id, edge.get("to_port", ""), edge_id, "Add an explicit conversion block."))
	return diagnostics

static func _find_port(node: Dictionary, port_id: String) -> Dictionary:
	for raw_port in node.get("ports", []):
		if raw_port is Dictionary and raw_port.get("id", "") == port_id:
			return raw_port
	return {}
