class_name VectorVerseDependencyResolver
extends RefCounted

static func resolve(graph: VectorVerseVisualGraph) -> Array[String]:
	if graph.nodes.is_empty():
		return []
	var indegree: Dictionary = {}
	var outgoing: Dictionary = {}
	var remaining: Array[String] = []
	for node in graph.nodes:
		var instance_id: String = node.get("instance_id", "")
		if instance_id.is_empty() or indegree.has(instance_id):
			return []
		indegree[instance_id] = 0
		outgoing[instance_id] = []
		remaining.append(instance_id)
	for edge in graph.control_edges:
		var from_id: String = edge.get("from_node", "")
		var to_id: String = edge.get("to_node", "")
		if not indegree.has(from_id) or not indegree.has(to_id):
			return []
		indegree[to_id] += 1
		outgoing[from_id].append(to_id)

	var ordered: Array[String] = []
	while not remaining.is_empty():
		var next_id := ""
		for candidate in remaining:
			if indegree[candidate] == 0:
				next_id = candidate
				break
		if next_id.is_empty():
			return []
		remaining.erase(next_id)
		ordered.append(next_id)
		for target in outgoing[next_id]:
			indegree[target] -= 1
	return ordered
