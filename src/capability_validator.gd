class_name VectorVerseCapabilityValidator
extends RefCounted

const SENSITIVE_CAPABILITIES := ["MIC", "CAMERA", "FILE_IO", "NETWORK", "EXTERNAL_STORAGE"]

static func validate(ir: Dictionary, manifest: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var declared: Array = manifest.get("declared", [])
	var approved: Array = manifest.get("approved_sensitive", [])
	for raw_node in ir.get("nodes", []):
		if not raw_node is Dictionary:
			continue
		var node: Dictionary = raw_node
		for capability in node.get("capabilities", []):
			if capability not in declared:
				diagnostics.append(VectorVerseValidationDiagnostic.make(
					"E_CAPABILITY_NOT_DECLARED",
					"Action requires undeclared capability %s." % capability,
					"capability",
					"error",
					"node",
					node.get("source_block_id", node.get("node_id", "")),
					"",
					"",
					"Declare the capability in the project manifest."
				))
			elif capability in SENSITIVE_CAPABILITIES and capability not in approved:
				diagnostics.append(VectorVerseValidationDiagnostic.make(
					"E_PERMISSION_REQUIRED",
					"Sensitive capability %s is declared but not approved." % capability,
					"capability",
					"error",
					"node",
					node.get("source_block_id", node.get("node_id", "")),
					"",
					"",
					"Request explicit user approval before export."
				))
	return VectorVerseValidationDiagnostic.stable_sort(diagnostics)
