class_name VectorVerseValidationDiagnostic
extends RefCounted

static func make(
	code: String,
	message: String,
	stage: String,
	severity: String = "error",
	target_kind: String = "graph",
	target_id: String = "",
	port_id: String = "",
	edge_id: String = "",
	hint: String = ""
) -> Dictionary:
	return {
		"code": code,
		"message": message,
		"hint": hint,
		"stage": stage,
		"severity": severity,
		"target_kind": target_kind,
		"target_id": target_id,
		"port_id": port_id,
		"edge_id": edge_id
	}

static func stable_sort(diagnostics: Array[Dictionary]) -> Array[Dictionary]:
	var result := diagnostics.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var key_a := "%s|%s|%s|%s|%s" % [a.get("stage", ""), a.get("target_id", ""), a.get("port_id", ""), a.get("edge_id", ""), a.get("code", "")]
		var key_b := "%s|%s|%s|%s|%s" % [b.get("stage", ""), b.get("target_id", ""), b.get("port_id", ""), b.get("edge_id", ""), b.get("code", "")]
		return key_a < key_b
	)
	return result
