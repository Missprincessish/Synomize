class_name VectorVersePipelineCompiler
extends RefCounted

const LANGUAGE := "gdscript"
const GENERATED_PATH := "res://generated/app_start_display_message.gd"
const GRAPH_PATH := "res://evidence/visual_graph.json"
const EVIDENCE_PATH := "res://evidence/validation_evidence.json"
const TYPED_IR_PATH := "res://evidence/typed_ir.json"
const VALIDATION_REPORT_PATH := "res://evidence/phase2_validation_report.json"
const SOURCE_MAP_PATH := "res://evidence/program1_source_map.json"
const BUILD_MANIFEST_PATH := "res://evidence/program1_build_manifest.json"
const BACKEND_DIAGNOSTICS_PATH := "res://evidence/program1_backend_diagnostics.json"
const PACKAGED_OUTPUT_DIR := "user://vectorverse_smoke"
const EXPECTED_MESSAGE := "Hello, Synomize!"

static func compile_validate_save(graph: VectorVerseVisualGraph, compatible_after_start: Array[String]) -> Dictionary:
	var validation_result := VectorVerseValidationPipeline.validate_graph(graph)
	var validation_errors: Array[String] = []
	for diagnostic in validation_result.diagnostics:
		validation_errors.append("[%s] %s" % [diagnostic.get("code", "E_UNKNOWN"), diagnostic.get("message", "Validation failed.")])
	var ordered_nodes := VectorVerseDependencyResolver.resolve(graph)
	var backend_result_a := VectorVerseLanguageAdapterRegistry.generate_result(LANGUAGE, validation_result.ir)
	var backend_result_b := VectorVerseLanguageAdapterRegistry.generate_result(LANGUAGE, validation_result.ir)
	var source_a: String = backend_result_a.get("source", "")
	var source_b: String = backend_result_b.get("source", "")
	var graph_data := graph.to_dictionary()
	var generated_path := _runtime_output_path(GENERATED_PATH)
	var graph_path := _runtime_output_path(GRAPH_PATH)
	var evidence_path := _runtime_output_path(EVIDENCE_PATH)
	var typed_ir_path := _runtime_output_path(TYPED_IR_PATH)
	var validation_report_path := _runtime_output_path(VALIDATION_REPORT_PATH)
	var source_map_path := _runtime_output_path(SOURCE_MAP_PATH)
	var build_manifest_path := _runtime_output_path(BUILD_MANIFEST_PATH)
	var backend_diagnostics_path := _runtime_output_path(BACKEND_DIAGNOSTICS_PATH)

	var evidence := {
		"milestone": "Data-driven GDScript coding pipeline",
		"interaction_mode": "manual_player_selection",
		"language_adapter": LANGUAGE,
		"supported_languages": VectorVerseLanguageAdapterRegistry.supported_languages(),
		"catalog_path": VectorVerseAtomCatalog.CATALOG_PATH,
		"template_path": VectorVerseGDScriptAdapter.TEMPLATE_PATH,
		"graph_has_two_atoms": graph.nodes.size() == 2,
		"graph_has_valid_edge": graph.control_edges.size() == 1 and graph.data_edges.is_empty(),
		"compatible_choices_after_app_start": compatible_after_start,
		"only_compatible_choices_shown": compatible_after_start == ["display_message"],
		"semantic_validation_success": validation_result.graph_valid,
		"typed_ir_schema_version": validation_result.ir.get("ir_schema_version", ""),
		"typed_ir_file": typed_ir_path,
		"validation_contract_version": validation_result.validation_contract_version,
		"graph_diagnostics": validation_result.graph_diagnostics,
		"type_diagnostics": validation_result.type_diagnostics,
		"capability_diagnostics": validation_result.capability_diagnostics,
		"backend_support_diagnostics": validation_result.backend_support_diagnostics,
		"backend_support_success": validation_result.backend_supported,
		"backend_generation_success": backend_result_a.get("accepted", false),
		"source_map_file": source_map_path,
		"build_manifest_file": build_manifest_path,
		"backend_diagnostics_file": backend_diagnostics_path,
		"source_map_sha256": JSON.stringify(backend_result_a.get("source_map", []), "\t", true).sha256_text(),
		"build_manifest_sha256": JSON.stringify(backend_result_a.get("manifest", {}), "\t", true).sha256_text(),
		"backend_diagnostics_sha256": JSON.stringify(backend_result_a.get("diagnostics", []), "\t", true).sha256_text(),
		"dependency_order": ordered_nodes,
		"dependency_resolution_success": ordered_nodes == ["node_0001", "node_0002"],
		"generated_file": generated_path,
		"generated_source_sha256": source_a.sha256_text(),
		"deterministic_generation": not source_a.is_empty() and source_a == source_b and backend_result_a.get("source_map", []) == backend_result_b.get("source_map", []) and backend_result_a.get("manifest", {}) == backend_result_b.get("manifest", {}) and backend_result_a.get("diagnostics", []) == backend_result_b.get("diagnostics", []),
		"round_trip_generation_match": false,
		"godot_parse_success": false,
		"runtime_success": false,
		"expected_message": EXPECTED_MESSAGE,
		"actual_message": "",
		"errors": validation_errors.duplicate()
	}

	if not evidence.only_compatible_choices_shown:
		evidence.errors.append("Compatible-choice filter returned an unexpected atom.")
	if not evidence.dependency_resolution_success:
		evidence.errors.append("Dependency ordering was not deterministic.")
	if not evidence.deterministic_generation:
		evidence.errors.append("GDScript adapter output was not deterministic.")

	_prepare_runtime_output_directory()
	_write_text(graph_path, JSON.stringify(graph_data, "\t", true) + "\n")
	_write_text(typed_ir_path, VectorVerseTypedIRSerializer.canonical_json(validation_result.ir))
	_write_text(validation_report_path, JSON.stringify(validation_result, "\t", true) + "\n")
	_write_text(source_map_path, JSON.stringify(backend_result_a.get("source_map", []), "\t", true) + "\n")
	_write_text(build_manifest_path, JSON.stringify(backend_result_a.get("manifest", {}), "\t", true) + "\n")
	_write_text(backend_diagnostics_path, JSON.stringify(backend_result_a.get("diagnostics", []), "\t", true) + "\n")
	_write_text(generated_path, source_a)

	var saved_file := FileAccess.open(graph_path, FileAccess.READ)
	if saved_file != null:
		var saved_data = JSON.parse_string(saved_file.get_as_text())
		saved_file.close()
		if saved_data is Dictionary:
			var reloaded_graph := VectorVerseVisualGraph.from_dictionary(saved_data)
			var reloaded_validation := VectorVerseValidationPipeline.validate_graph(reloaded_graph)
			var reloaded_order := VectorVerseDependencyResolver.resolve(reloaded_graph)
			var reloaded_backend := VectorVerseLanguageAdapterRegistry.generate_result(LANGUAGE, reloaded_validation.ir)
			var reloaded_source: String = reloaded_backend.get("source", "")
			evidence.round_trip_generation_match = reloaded_validation.accepted_for_backend and reloaded_backend.get("accepted", false) and reloaded_source == source_a and reloaded_backend.get("source_map", []) == backend_result_a.get("source_map", []) and reloaded_backend.get("manifest", {}) == backend_result_a.get("manifest", {}) and VectorVerseTypedIRSerializer.canonical_json(reloaded_validation.ir) == VectorVerseTypedIRSerializer.canonical_json(validation_result.ir)
	if not evidence.round_trip_generation_match:
		evidence.errors.append("Saved graph did not round-trip to identical GDScript.")

	if evidence.errors.is_empty():
		var generated_script := GDScript.new()
		generated_script.source_code = source_a
		evidence.godot_parse_success = generated_script.reload() == OK and generated_script.can_instantiate()
		if evidence.godot_parse_success:
			var instance = generated_script.new()
			if instance != null and instance.has_method("execute"):
				evidence.actual_message = instance.execute()
				evidence.runtime_success = evidence.actual_message == EXPECTED_MESSAGE
			instance.free()
		else:
			evidence.errors.append("Godot could not parse or instantiate generated GDScript.")
	if not evidence.runtime_success:
		evidence.errors.append("Generated program did not produce the expected message.")

	evidence["accepted"] = evidence.errors.is_empty()
	_write_text(evidence_path, JSON.stringify(evidence, "\t") + "\n")
	return evidence

static func _runtime_output_path(editor_path: String) -> String:
	if OS.has_feature("editor"):
		return editor_path
	return PACKAGED_OUTPUT_DIR + "/" + editor_path.get_file()

static func _prepare_runtime_output_directory() -> void:
	if OS.has_feature("editor"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PACKAGED_OUTPUT_DIR))

static func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write: " + path)
		return
	file.store_string(content)
	file.close()
