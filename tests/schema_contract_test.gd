extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var catalog_errors := VectorVerseAtomCatalog.load_catalog()
	if not catalog_errors.is_empty():
		failures.append_array(catalog_errors)
	var app_start := VectorVerseAtomCatalog.atom("app_start")
	var log_action := VectorVerseAtomCatalog.atom("display_message")
	if app_start.get("operation_kind", "") != "EVENT_ENTRY":
		failures.append("App Start is not mapped to EVENT_ENTRY.")
	if log_action.get("operation_kind", "") != "ACTION_CALL":
		failures.append("Log is not mapped to ACTION_CALL.")
	if VectorVerseAtomCatalog.port("app_start", "control_out").get("category", "") != "control":
		failures.append("App Start control output is not typed as control.")
	if VectorVerseAtomCatalog.port("display_message", "message").get("value_type", "") != "String":
		failures.append("Log message input is not typed String data.")
	if VectorVerseAtomCatalog.atom("bool_value").get("operation_kind", "") != "VALUE_LITERAL":
		failures.append("Boolean Value is not mapped to VALUE_LITERAL.")
	if VectorVerseAtomCatalog.port("bool_value", "value").get("value_type", "") != "Bool":
		failures.append("Boolean Value output is not typed Bool data.")
	if VectorVerseAtomCatalog.atom("condition").get("operation_kind", "") != "COND_BRANCH":
		failures.append("Condition is not mapped to COND_BRANCH.")
	if VectorVerseAtomCatalog.port("condition", "condition").get("value_type", "") != "Bool":
		failures.append("Condition input is not typed Bool data.")

	var graph := VectorVerseVisualGraph.new()
	graph.insert_atom("app_start")
	graph.insert_atom("display_message")
	if graph.control_edges.size() != 1 or not graph.data_edges.is_empty():
		failures.append("Control and data edges are not stored separately.")
	var saved := graph.to_dictionary()
	if saved.get("schema_version", "") != VectorVerseVisualGraph.SCHEMA_VERSION:
		failures.append("Graph schema version is not frozen.")
	if not saved.has("control_edges") or not saved.has("data_edges") or saved.has("edges"):
		failures.append("Serialized graph does not use separate edge collections.")
	var reloaded := VectorVerseVisualGraph.from_dictionary(saved)
	if not VectorVerseGraphValidator.validate(reloaded).is_empty():
		failures.append("Typed graph did not validate after round trip.")

	var invalid := VectorVerseVisualGraph.from_dictionary(saved)
	invalid.control_edges[0]["to_port"] = "message"
	var invalid_errors := VectorVerseGraphValidator.validate(invalid)
	if not invalid_errors.any(func(error): return "port categories" in error):
		failures.append("Validator did not reject a control edge connected to a data port.")

	if failures.is_empty():
		print("VECTORVERSE_TYPED_SCHEMA_PASS")
		print("GRAPH_SCHEMA_VERSION=" + VectorVerseVisualGraph.SCHEMA_VERSION)
		print("CATALOG_VERSION=" + VectorVerseAtomCatalog.CATALOG_VERSION)
		print("CONTROL_DATA_EDGES_SEPARATE=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
