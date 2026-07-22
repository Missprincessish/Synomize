class_name VectorVerseGraphValidator
extends RefCounted

static func validate(graph: VectorVerseVisualGraph) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(VectorVerseAtomCatalog.load_catalog())
	if graph.nodes.size() != graph.atom_ids.size(): errors.append("Graph node and atom indexes disagree.")
	if graph.nodes.is_empty():
		errors.append("Graph is empty.")
		return errors
	var node_by_id: Dictionary = {}
	var app_start_count := 0
	for index in graph.nodes.size():
		var node: Dictionary = graph.nodes[index]
		var instance_id: String = node.get("instance_id", "")
		var atom_id: String = node.get("atom_id", "")
		if instance_id.is_empty() or node_by_id.has(instance_id):
			errors.append("Graph has a missing or duplicate node instance id.")
			continue
		node_by_id[instance_id] = node
		if not VectorVerseAtomCatalog.has_atom(atom_id):
			errors.append("Graph references unknown atom: " + atom_id)
			continue
		var definition := VectorVerseAtomCatalog.atom(atom_id)
		if atom_id == "app_start": app_start_count += 1
		if node.get("source_block_id", "") != instance_id: errors.append("Node source block id is missing or unstable: " + instance_id)
		if node.get("atom_schema_version", "") != definition.get("schema_version", ""): errors.append("Node atom schema version does not match catalog: " + instance_id)
		if node.get("operation_kind", "") != definition.get("operation_kind", ""): errors.append("Node operation kind does not match catalog: " + instance_id)
		if node.get("family", "") != definition.get("family", ""): errors.append("Node family does not match catalog: " + instance_id)
		if node.get("effect_class", "") != definition.get("effect_class", ""): errors.append("Node effect class does not match catalog: " + instance_id)
		if node.get("capabilities", []) != definition.get("capabilities", []): errors.append("Node capabilities do not match catalog: " + instance_id)
		if node.get("position", -1) != index: errors.append("Node position is not deterministic: " + instance_id)
		errors.append_array(_validate_parameters(node, definition))
	if app_start_count != 1 or graph.nodes[0].get("atom_id", "") != "app_start": errors.append("The graph must contain exactly one leading app_start node.")
	var edge_ids: Dictionary = {}
	for edge in graph.control_edges: errors.append_array(_validate_edge(edge, "control", node_by_id, edge_ids))
	for edge in graph.data_edges: errors.append_array(_validate_edge(edge, "data", node_by_id, edge_ids))
	errors.append_array(_validate_required_inputs(graph, node_by_id))
	if VectorVerseDependencyResolver.resolve(graph).is_empty(): errors.append("Graph contains a control cycle or cannot be dependency ordered.")
	if not _app_start_reaches_effect(graph, node_by_id): errors.append("APP_START must reach at least one effectful action.")
	return errors

static func _validate_parameters(node: Dictionary, definition: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var parameters: Dictionary = node.get("parameters", {})
	for parameter_name in definition.get("parameters", {}):
		var specification: Dictionary = definition.parameters[parameter_name]
		if specification.get("required", false) and not parameters.has(parameter_name):
			errors.append("Required parameter %s missing from %s." % [parameter_name, node.instance_id])
			continue
		if parameters.has(parameter_name):
			var type_name: String = specification.get("type", "")
			var value = parameters[parameter_name]
			if type_name == "String" and not value is String: errors.append("Parameter %s must be a String." % parameter_name)
			if type_name == "Bool" and not value is bool: errors.append("Parameter %s must be a Bool." % parameter_name)
	return errors

static func _validate_edge(edge: Dictionary, category: String, node_by_id: Dictionary, edge_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var edge_id: String = edge.get("edge_id", "")
	if edge_id.is_empty() or edge_ids.has(edge_id): errors.append("Graph has a missing or duplicate edge id.")
	else: edge_ids[edge_id] = true
	if edge.get("category", "") != category: errors.append("Edge category does not match its graph collection: " + edge_id)
	var from_id: String = edge.get("from_node", "")
	var to_id: String = edge.get("to_node", "")
	if not node_by_id.has(from_id) or not node_by_id.has(to_id):
		errors.append("Edge references a missing node: " + edge_id)
		return errors
	var from_port := VectorVerseAtomCatalog.port(node_by_id[from_id].atom_id, edge.get("from_port", ""))
	var to_port := VectorVerseAtomCatalog.port(node_by_id[to_id].atom_id, edge.get("to_port", ""))
	if from_port.is_empty() or to_port.is_empty():
		errors.append("Edge references a missing port: " + edge_id)
		return errors
	if from_port.get("direction", "") != "output" or to_port.get("direction", "") != "input": errors.append("Edge direction is invalid: " + edge_id)
	if from_port.get("category", "") != category or to_port.get("category", "") != category: errors.append("Edge connects incompatible port categories: " + edge_id)
	if category == "data" and from_port.get("value_type", "") != to_port.get("value_type", ""): errors.append("Data edge type mismatch: " + edge_id)
	return errors

static func _validate_required_inputs(graph: VectorVerseVisualGraph, node_by_id: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for node_id in node_by_id:
		var node: Dictionary = node_by_id[node_id]
		var definition := VectorVerseAtomCatalog.atom(node.atom_id)
		for port in definition.get("ports", []):
			if port.get("direction", "") != "input" or not port.get("required", false): continue
			var connected: bool = false
			var edges: Array[Dictionary] = graph.control_edges if port.get("category", "") == "control" else graph.data_edges
			for edge in edges:
				if edge.get("to_node", "") == node_id and edge.get("to_port", "") == port.get("id", ""): connected = true
			var default_parameter: String = port.get("default_parameter", "")
			var has_default: bool = not default_parameter.is_empty() and (node.get("parameters", {}) as Dictionary).has(default_parameter)
			if not connected and not has_default: errors.append("Required input %s is not connected on %s." % [port.get("id", ""), node_id])
	return errors

static func _app_start_reaches_effect(graph: VectorVerseVisualGraph, node_by_id: Dictionary) -> bool:
	var outgoing: Dictionary = {}
	for edge in graph.control_edges: outgoing.get_or_add(edge.from_node, []).append(edge.to_node)
	var queue: Array[String] = [graph.nodes[0].instance_id]
	var seen: Dictionary = {}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if seen.has(current): continue
		seen[current] = true
		if current != graph.nodes[0].instance_id and node_by_id.get(current, {}).get("effect_class", "") == "EFFECTFUL": return true
		for target in outgoing.get(current, []): queue.append(target)
	return false
