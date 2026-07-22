class_name VectorVerseValidationPipeline
extends RefCounted

const CompilerContractValidator = preload("res://src/compiler_contract_validator.gd")

static func validate_graph(
	graph: VectorVerseVisualGraph,
	capability_manifest: Dictionary = {"declared": ["LOG"], "approved_sensitive": []},
	backend_id: String = VectorVerseBackendSupportChecker.BACKEND_ID
) -> Dictionary:
	var human_graph_errors := VectorVerseGraphValidator.validate(graph)
	var graph_diagnostics: Array[Dictionary] = []
	for message in human_graph_errors:
		graph_diagnostics.append(VectorVerseValidationDiagnostic.make("E_HUMAN_GRAPH_INVALID", message, "graph"))

	var ir := VectorVerseTypedIRSerializer.from_graph(graph)
	graph_diagnostics.append_array(VectorVerseTypedIRValidator.validate(ir))
	graph_diagnostics.append_array(CompilerContractValidator.validate(ir))
	var type_diagnostics := VectorVerseTypeValidator.validate(ir)
	var capability_diagnostics := VectorVerseCapabilityValidator.validate(ir, capability_manifest)
	var backend_diagnostics := VectorVerseBackendSupportChecker.validate(ir, backend_id)
	var all: Array[Dictionary] = []
	all.append_array(graph_diagnostics)
	all.append_array(type_diagnostics)
	all.append_array(capability_diagnostics)
	all.append_array(backend_diagnostics)
	all = VectorVerseValidationDiagnostic.stable_sort(all)
	return {
		"validation_contract_version": "1.0.0",
		"ir": ir,
		"graph_diagnostics": VectorVerseValidationDiagnostic.stable_sort(graph_diagnostics),
		"type_diagnostics": type_diagnostics,
		"capability_diagnostics": capability_diagnostics,
		"backend_support_diagnostics": backend_diagnostics,
		"diagnostics": all,
		"graph_valid": graph_diagnostics.is_empty() and type_diagnostics.is_empty() and capability_diagnostics.is_empty(),
		"backend_supported": backend_diagnostics.is_empty(),
		"accepted_for_backend": all.is_empty()
	}
