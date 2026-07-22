class_name VectorVerseCompatibilityFilter
extends RefCounted

static func choices_for_graph(
	graph: VectorVerseVisualGraph,
	capability_manifest: Dictionary = {"declared": ["LOG"], "approved_sensitive": []},
	backend_id: String = VectorVerseBackendSupportChecker.BACKEND_ID
) -> Dictionary:
	var visible: Array[String] = []
	var rejected: Array[Dictionary] = []
	var candidates := _candidate_ids(graph)
	if graph.nodes.is_empty():
		return {
			"schema_version": "1.0.0",
			"graph_schema_version": VectorVerseVisualGraph.SCHEMA_VERSION,
			"catalog_version": VectorVerseAtomCatalog.CATALOG_VERSION,
			"backend_id": backend_id,
			"visible_choices": candidates,
			"rejected_choices": []
		}
	for candidate_id in candidates:
		var probe := VectorVerseVisualGraph.from_dictionary(graph.to_dictionary())
		if not probe.insert_atom(candidate_id):
			rejected.append({"atom_id": candidate_id, "reason": "catalog_incompatible"})
			continue
		var result := VectorVerseValidationPipeline.validate_graph(probe, capability_manifest, backend_id)
		if result.accepted_for_backend:
			visible.append(candidate_id)
		else:
			rejected.append({
				"atom_id": candidate_id,
				"reason": "validation_or_backend_rejected",
				"diagnostics": result.diagnostics
			})
	return {
		"schema_version": "1.0.0",
		"graph_schema_version": VectorVerseVisualGraph.SCHEMA_VERSION,
		"catalog_version": VectorVerseAtomCatalog.CATALOG_VERSION,
		"backend_id": backend_id,
		"visible_choices": visible,
		"rejected_choices": rejected
	}

static func _candidate_ids(graph: VectorVerseVisualGraph) -> Array[String]:
	return VectorVerseAtomCatalog.compatible_choices(graph.atom_ids)
