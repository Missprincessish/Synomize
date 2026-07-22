class_name VectorVerseGraphStore
extends RefCounted

const STORE_VERSION := 1

static func save_graph(path: String, graph: VectorVerseVisualGraph) -> Dictionary:
	var payload := {
		"store_version": STORE_VERSION,
		"graph": graph.to_dictionary()
	}
	var canonical := JSON.stringify(payload, "\t", true) + "\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("S_SAVE_OPEN_FAILED", "Could not open graph save path.", path)
	file.store_string(canonical)
	file.close()
	return {
		"accepted": true,
		"path": path,
		"sha256": canonical.sha256_text(),
		"bytes": canonical.to_utf8_buffer().size(),
		"diagnostics": []
	}

static func load_graph(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("S_LOAD_OPEN_FAILED", "Could not open graph save file.", path)
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _failure("S_LOAD_INVALID_JSON", "Graph save is not valid JSON.", path)
	var parsed = parser.data
	if not parsed is Dictionary:
		return _failure("S_LOAD_INVALID_JSON", "Graph save is not a JSON object.", path)
	if parsed.get("store_version", -1) != STORE_VERSION:
		return _failure("S_STORE_VERSION_UNSUPPORTED", "Unsupported graph store version.", path)
	if not parsed.get("graph") is Dictionary:
		return _failure("S_GRAPH_MISSING", "Graph save contains no graph object.", path)
	var graph := VectorVerseVisualGraph.from_dictionary(parsed.graph)
	var validation := VectorVerseValidationPipeline.validate_graph(graph)
	if not validation.graph_valid:
		return {
			"accepted": false,
			"path": path,
			"graph": graph,
			"diagnostics": validation.graph_diagnostics
		}
	return {
		"accepted": true,
		"path": path,
		"graph": graph,
		"sha256": (JSON.stringify(parsed, "\t", true) + "\n").sha256_text(),
		"diagnostics": []
	}

static func _failure(code: String, message: String, path: String) -> Dictionary:
	return {
		"accepted": false,
		"path": path,
		"diagnostics": [VectorVerseValidationDiagnostic.make(code, message, "save_load", "error", "graph")]
	}
