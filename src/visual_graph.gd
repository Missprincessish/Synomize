class_name VectorVerseVisualGraph
extends RefCounted

const SCHEMA_VERSION := "1.1.0"
const LEGACY_SCHEMA_VERSION := "1.0.0"

var graph_id := "vertical_slice_app_start_display_message"
var atom_ids: Array[String] = []
var nodes: Array[Dictionary] = []
var control_edges: Array[Dictionary] = []
var data_edges: Array[Dictionary] = []

func insert_atom(atom_id: String, supplied_parameters: Dictionary = {}) -> bool:
	if not VectorVerseAtomCatalog.has_atom(atom_id):
		return false
	if not VectorVerseAtomCatalog.is_compatible(atom_ids, atom_id):
		return false
	var definition := VectorVerseAtomCatalog.atom(atom_id)
	var parameters: Dictionary = {}
	for parameter_name in definition.get("parameters", {}):
		var specification: Dictionary = definition.parameters[parameter_name]
		parameters[parameter_name] = supplied_parameters.get(parameter_name, specification.get("default"))
	var instance_id := "node_%04d" % (nodes.size() + 1)
	nodes.append(_node(instance_id, atom_id, parameters, nodes.size()))
	if not atom_ids.is_empty():
		var previous: Dictionary = nodes[-2]
		control_edges.append(_control_edge("control_%04d" % control_edges.size(), previous.instance_id, "control_out", instance_id, "control_in"))
	atom_ids.append(atom_id)
	return true

func configure_program2(condition_value: bool) -> void:
	reset()
	graph_id = "program2_condition_%s" % ("true" if condition_value else "false")
	nodes = [
		_node("node_0001", "app_start", {}, 0),
		_node("node_0002", "bool_value", {"value": condition_value}, 1),
		_node("node_0003", "condition", {}, 2),
		_node("node_0004", "display_message", {"message": "Enabled"}, 3),
		_node("node_0005", "display_message", {"message": "Disabled"}, 4)
	]
	atom_ids = ["app_start", "bool_value", "condition", "display_message", "display_message"]
	control_edges = [
		_control_edge("control_0000", "node_0001", "control_out", "node_0003", "control_in"),
		_control_edge("control_0001", "node_0003", "true", "node_0004", "control_in"),
		_control_edge("control_0002", "node_0003", "false", "node_0005", "control_in")
	]
	data_edges = [
		_data_edge("data_0000", "node_0002", "value", "node_0003", "condition", "Bool")
	]

func configure_program3(message: String = "Hello, Synomize!") -> void:
	reset()
	graph_id = "program3_session_state"
	nodes = [
		_node("node_0001", "app_start", {}, 0),
		_node("node_0002", "string_value", {"value": message}, 1),
		_node("node_0003", "state_write", {"state_id": "welcomeMessage", "lifetime": "session"}, 2),
		_node("node_0004", "state_read", {"state_id": "welcomeMessage", "lifetime": "session"}, 3),
		_node("node_0005", "display_message", {"message": ""}, 4)
	]
	atom_ids = ["app_start", "string_value", "state_write", "state_read", "display_message"]
	control_edges = [
		_control_edge("control_0000", "node_0001", "control_out", "node_0003", "control_in"),
		_control_edge("control_0001", "node_0003", "control_out", "node_0004", "control_in"),
		_control_edge("control_0002", "node_0004", "control_out", "node_0005", "control_in")
	]
	data_edges = [
		_data_edge("data_0000", "node_0002", "value", "node_0003", "value", "String"),
		_data_edge("data_0001", "node_0004", "value", "node_0005", "message", "String")
	]

func configure_variable_demo(message: String = "Hello from a Variable") -> void:
	reset()
	graph_id = "demo_variable"
	nodes = [
		_node("node_0001", "app_start", {}, 0),
		_node("node_0002", "string_value", {"value": message}, 1),
		_node("node_0003", "variable_bind", {"symbol": "message", "scope_id": "root"}, 2),
		_node("node_0004", "variable_read", {"symbol": "message", "scope_id": "root"}, 3),
		_node("node_0005", "display_message", {"message": ""}, 4)
	]
	atom_ids = ["app_start", "string_value", "variable_bind", "variable_read", "display_message"]
	control_edges = [
		_control_edge("control_0000", "node_0001", "control_out", "node_0003", "control_in"),
		_control_edge("control_0001", "node_0003", "control_out", "node_0005", "control_in")
	]
	data_edges = [
		_data_edge("data_0000", "node_0002", "value", "node_0003", "value", "String"),
		_data_edge("data_0001", "node_0004", "value", "node_0005", "message", "String")
	]

func configure_loop_demo() -> void:
	reset()
	graph_id = "demo_bounded_loop"
	nodes = [
		_node("node_0001", "app_start", {}, 0),
		_node("node_0002", "bool_value", {"value": true}, 1),
		_node("node_0003", "string_value", {"value": "Build"}, 2),
		_node("node_0004", "loop", {"max_iterations": 3}, 3),
		_node("node_0005", "display_message", {"message": "Building"}, 4),
		_node("node_0006", "display_message", {"message": "Complete"}, 5)
	]
	atom_ids = ["app_start", "bool_value", "string_value", "loop", "display_message", "display_message"]
	control_edges = [
		_control_edge("control_0000", "node_0001", "control_out", "node_0004", "control_in"),
		_control_edge("control_0001", "node_0004", "body", "node_0005", "control_in"),
		_control_edge("control_0002", "node_0004", "done", "node_0006", "control_in")
	]
	data_edges = [_data_edge("data_0000", "node_0002", "value", "node_0004", "condition", "Bool")]

func configure_group_demo(message: String = "Reusable Group") -> void:
	reset()
	graph_id = "demo_reusable_group"
	nodes = [
		_node("node_0001", "app_start", {}, 0),
		_node("node_0002", "module_boundary", {"module_id": "main", "scope_id": "root"}, 1),
		_node("node_0003", "string_value", {"value": message}, 2),
		_node("node_0004", "return", {}, 3),
		_node("node_0005", "display_message", {"message": "Group ready"}, 4)
	]
	atom_ids = ["app_start", "module_boundary", "string_value", "return", "display_message"]
	control_edges = [
		_control_edge("control_0000", "node_0001", "control_out", "node_0005", "control_in"),
		_control_edge("control_0001", "node_0002", "control_out", "node_0004", "control_in")
	]
	data_edges = [_data_edge("data_0000", "node_0003", "value", "node_0004", "value", "String")]

func reset() -> void:
	graph_id = "vertical_slice_app_start_display_message"
	atom_ids.clear()
	nodes.clear()
	control_edges.clear()
	data_edges.clear()

func to_dictionary() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "graph_id": graph_id, "nodes": nodes.duplicate(true), "control_edges": control_edges.duplicate(true), "data_edges": data_edges.duplicate(true)}

static func from_dictionary(data: Dictionary) -> VectorVerseVisualGraph:
	var graph := VectorVerseVisualGraph.new()
	var version: String = data.get("schema_version", "")
	if version not in [SCHEMA_VERSION, LEGACY_SCHEMA_VERSION]:
		return graph
	graph.graph_id = data.get("graph_id", graph.graph_id)
	for raw_node in data.get("nodes", []):
		if raw_node is Dictionary:
			var node: Dictionary = raw_node.duplicate(true)
			graph.nodes.append(node)
			graph.atom_ids.append(node.get("atom_id", ""))
	if version == LEGACY_SCHEMA_VERSION:
		for raw_edge in data.get("edges", []):
			if raw_edge is Dictionary:
				var migrated: Dictionary = raw_edge.duplicate(true)
				migrated.erase("kind")
				migrated["category"] = "control"
				migrated["edge_id"] = "control_%04d" % graph.control_edges.size()
				graph.control_edges.append(migrated)
	else:
		for raw_edge in data.get("control_edges", []):
			if raw_edge is Dictionary: graph.control_edges.append(raw_edge.duplicate(true))
		for raw_edge in data.get("data_edges", []):
			if raw_edge is Dictionary: graph.data_edges.append(raw_edge.duplicate(true))
	return graph

static func _node(instance_id: String, atom_id: String, parameters: Dictionary, position: int) -> Dictionary:
	var definition := VectorVerseAtomCatalog.atom(atom_id)
	return {"instance_id": instance_id, "source_block_id": instance_id, "atom_id": atom_id, "atom_schema_version": definition.get("schema_version", ""), "operation_kind": definition.get("operation_kind", ""), "family": definition.get("family", ""), "effect_class": definition.get("effect_class", "PURE"), "capabilities": definition.get("capabilities", []).duplicate(), "parameters": parameters.duplicate(true), "position": position}

static func _control_edge(edge_id: String, from_node: String, from_port: String, to_node: String, to_port: String) -> Dictionary:
	return {"edge_id": edge_id, "from_node": from_node, "from_port": from_port, "to_node": to_node, "to_port": to_port, "category": "control"}

static func _data_edge(edge_id: String, from_node: String, from_port: String, to_node: String, to_port: String, value_type: String) -> Dictionary:
	return {"edge_id": edge_id, "from_node": from_node, "from_port": from_port, "to_node": to_node, "to_port": to_port, "category": "data", "value_type": value_type}
