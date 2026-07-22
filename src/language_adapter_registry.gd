class_name VectorVerseLanguageAdapterRegistry
extends RefCounted

const ADAPTER_CONTRACT_VERSION := "1.0.0"
const SUPPORTED_LANGUAGE := "gdscript"

static func adapter_descriptors() -> Array[Dictionary]:
	return [{"backend_id": "gdscript", "adapter_contract_version": ADAPTER_CONTRACT_VERSION, "backend_version": VectorVerseGDScriptAdapter.BACKEND_VERSION, "status": "proven_subset", "target_runtime": "Godot 4.7"}]

static func supported_languages() -> Array[String]:
	return [SUPPORTED_LANGUAGE]

static func generate(language: String, graph: VectorVerseVisualGraph, ordered_nodes: Array[String]) -> String:
	if language != SUPPORTED_LANGUAGE:
		return ""
	return VectorVerseGDScriptAdapter.generate(graph, ordered_nodes)


static func generate_result(language: String, ir: Dictionary) -> Dictionary:
	if language != SUPPORTED_LANGUAGE:
		return {
			"accepted": false,
			"source": "",
			"source_map": [],
			"diagnostics": [VectorVerseValidationDiagnostic.make("B_BACKEND_UNKNOWN", "Requested backend is not registered.", "backend")],
			"manifest": {}
		}
	return VectorVerseGDScriptAdapter.generate_from_ir(ir)
