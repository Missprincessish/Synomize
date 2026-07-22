class_name VectorVerseBackendSupportChecker
extends RefCounted

const BACKEND_ID := "gdscript"
const BACKEND_VERSION := "1.5.0"
const TARGET_GODOT_VERSION := "4.7"
const SUPPORTED_OPERATIONS := ["EVENT_ENTRY", "VALUE_LITERAL", "ACTION_CALL", "COND_BRANCH", "LOOP_CTRL", "VAR_BIND", "VAR_READ", "STATE_WRITE", "STATE_READ", "FUNCTION_OR_MODULE_BOUNDARY", "RETURN", "ERROR_PATH", "EXPRESSION"]
const SUPPORTED_CAPABILITIES := ["LOG"]

static func validate(ir: Dictionary, backend_id: String = BACKEND_ID) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if backend_id != BACKEND_ID:
		return [VectorVerseValidationDiagnostic.make("B_BACKEND_UNKNOWN", "Requested backend is not registered.", "backend")]
	for raw_node in ir.get("nodes", []):
		if not raw_node is Dictionary:
			continue
		var node: Dictionary = raw_node
		var operation: String = node.get("operation_kind", "")
		if operation not in SUPPORTED_OPERATIONS:
			diagnostics.append(VectorVerseValidationDiagnostic.make(
				"B_UNSUPPORTED_IR_OPERATION",
				"Valid IR operation %s is not implemented by the current GDScript backend." % operation,
				"backend",
				"error",
				"node",
				node.get("source_block_id", node.get("node_id", ""))
			))
		for capability in node.get("capabilities", []):
			if capability not in SUPPORTED_CAPABILITIES:
				diagnostics.append(VectorVerseValidationDiagnostic.make(
					"B_UNSUPPORTED_CAPABILITY_BACKEND",
					"The current GDScript backend does not implement capability %s." % capability,
					"backend",
					"error",
					"node",
					node.get("source_block_id", node.get("node_id", ""))
				))
	return VectorVerseValidationDiagnostic.stable_sort(diagnostics)
