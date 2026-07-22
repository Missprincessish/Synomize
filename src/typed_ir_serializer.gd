class_name VectorVerseTypedIRSerializer
extends RefCounted

const IR_SCHEMA_VERSION := "2.0.0"
const SERIALIZATION_VERSION := 2
const MIGRATION_VERSION := 1

static func from_graph(graph: VectorVerseVisualGraph) -> Dictionary:
	var ir_nodes: Array[Dictionary] = []
	var control_edges: Array[Dictionary] = graph.control_edges.duplicate(true)
	var data_edges: Array[Dictionary] = graph.data_edges.duplicate(true)

	for node in graph.nodes:
		var atom_id: String = node.get("atom_id", "")
		var definition := VectorVerseAtomCatalog.atom(atom_id)
		var node_parameters: Dictionary = node.get("parameters", {}).duplicate(true)
		if node.get("operation_kind", "") == "VALUE_LITERAL" and not node_parameters.has("value_type"):
			for raw_port in definition.get("ports", []):
				if raw_port is Dictionary and raw_port.get("direction", "") == "output" and raw_port.get("category", "") == "data":
					node_parameters["value_type"] = raw_port.get("value_type", "")
					break
		var ir_node := {
			"node_id": node.get("instance_id", ""),
			"source_block_id": node.get("source_block_id", ""),
			"atom_id": atom_id,
			"atom_schema_version": node.get("atom_schema_version", ""),
			"operation_kind": node.get("operation_kind", ""),
			"family": node.get("family", ""),
			"effect_class": node.get("effect_class", ""),
			"capabilities": node.get("capabilities", []).duplicate(),
			"ports": definition.get("ports", []).duplicate(true),
			"parameters": node_parameters,
			"serialization_version": SERIALIZATION_VERSION,
			"migration_version": MIGRATION_VERSION,
			"target_support": definition.get("target_support", {"gdscript": "unsupported"}).duplicate(true)
		}
		ir_nodes.append(ir_node)
		_append_parameter_literals(ir_nodes, data_edges, ir_node, definition)

	return {
		"ir_schema_version": IR_SCHEMA_VERSION,
		"serialization_version": SERIALIZATION_VERSION,
		"migration_version": MIGRATION_VERSION,
		"compiler_contract_version": "1.0.0",
		"target_support": {"gdscript": "proven_subset"},
		"source_graph_schema_version": VectorVerseVisualGraph.SCHEMA_VERSION,
		"graph_id": graph.to_dictionary().get("graph_id", ""),
		"nodes": ir_nodes,
		"control_edges": control_edges,
		"data_edges": data_edges
	}

static func _append_parameter_literals(ir_nodes: Array[Dictionary], data_edges: Array[Dictionary], ir_node: Dictionary, definition: Dictionary) -> void:
	var parameters: Dictionary = ir_node.get("parameters", {})
	for raw_port in definition.get("ports", []):
		if not raw_port is Dictionary:
			continue
		var port: Dictionary = raw_port
		var parameter_name: String = port.get("default_parameter", "")
		if parameter_name.is_empty() or not parameters.has(parameter_name):
			continue
		var literal_id := "%s__%s_literal" % [ir_node.node_id, port.id]
		ir_nodes.append({
			"node_id": literal_id,
			"source_block_id": ir_node.source_block_id,
			"atom_id": "",
			"atom_schema_version": "1.0.0",
			"operation_kind": "VALUE_LITERAL",
			"family": "Variable",
			"effect_class": "PURE",
			"capabilities": [],
			"ports": [{"id": "value", "category": "data", "direction": "output", "value_type": port.value_type, "required": true}],
			"parameters": {"value": parameters[parameter_name], "value_type": port.value_type},
			"serialization_version": SERIALIZATION_VERSION,
			"migration_version": MIGRATION_VERSION,
			"target_support": {"gdscript": "proven"},
			"synthetic": true
		})
		data_edges.append({
			"edge_id": "data_%s_%s" % [ir_node.node_id, port.id],
			"from_node": literal_id,
			"from_port": "value",
			"to_node": ir_node.node_id,
			"to_port": port.id,
			"category": "data",
			"value_type": port.value_type
		})

static func canonical_json(ir: Dictionary) -> String:
	return JSON.stringify(ir, "\t", true) + "\n"

static func migrate_to_current(input_ir: Dictionary) -> Dictionary:
	var ir: Dictionary = input_ir.duplicate(true)
	var source_version: String = ir.get("ir_schema_version", "")
	var source_serialization: int = int(ir.get("serialization_version", 0))
	if source_version == IR_SCHEMA_VERSION and source_serialization == SERIALIZATION_VERSION:
		return ir
	if source_version != "1.0.0" or source_serialization != 1:
		return {}
	ir["ir_schema_version"] = IR_SCHEMA_VERSION
	ir["serialization_version"] = SERIALIZATION_VERSION
	ir["migration_version"] = MIGRATION_VERSION
	ir["compiler_contract_version"] = "1.0.0"
	ir["target_support"] = {"gdscript": "proven_subset"}
	for node in ir.get("nodes", []):
		if not node is Dictionary:
			continue
		node["serialization_version"] = SERIALIZATION_VERSION
		node["migration_version"] = MIGRATION_VERSION
		if not node.has("target_support"):
			var atom_id: String = node.get("atom_id", "")
			var definition := VectorVerseAtomCatalog.atom(atom_id) if not atom_id.is_empty() else {}
			node["target_support"] = definition.get("target_support", {"gdscript": "proven" if node.get("operation_kind", "") in VectorVerseBackendSupportChecker.SUPPORTED_OPERATIONS else "unsupported"}).duplicate(true)
	return ir
