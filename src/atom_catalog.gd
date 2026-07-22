class_name VectorVerseAtomCatalog
extends RefCounted

const CATALOG_PATH := "res://data/atom_catalog.json"
const CATALOG_VERSION := "2.0.0"
const ATOM_SCHEMA_VERSION := "1.0.0"
const REQUIRED_FAMILIES := ["Variable", "Action", "Condition", "Loop", "Event", "State", "Group"]
const PORT_CATEGORIES := ["control", "data"]
const PORT_DIRECTIONS := ["input", "output"]
const VALUE_TYPES := ["Void", "String", "Int", "Float", "Bool"]
const EFFECT_CLASSES := ["PURE", "STATEFUL", "EFFECTFUL"]

static var _catalog: Dictionary = {}
static var _atoms: Dictionary = {}

static func load_catalog() -> Array[String]:
	var errors: Array[String] = []
	_catalog.clear()
	_atoms.clear()
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return ["Could not read atom catalog: " + CATALOG_PATH]
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return ["Atom catalog is not a JSON object."]
	_catalog = parsed
	if _catalog.get("catalog_version", "") != CATALOG_VERSION:
		errors.append("Unsupported atom catalog version.")
	if _catalog.get("atom_schema_version", "") != ATOM_SCHEMA_VERSION:
		errors.append("Unsupported atom schema version.")
	if _catalog.get("families", []) != REQUIRED_FAMILIES:
		errors.append("Atom catalog must declare the seven authority families in canonical order.")
	if _catalog.get("entry_atoms", []) != ["app_start"]:
		errors.append("The approved vertical slice must declare app_start as its only entry atom.")

	for raw_atom in _catalog.get("atoms", []):
		if not raw_atom is Dictionary:
			errors.append("Atom definition is not an object.")
			continue
		var atom_definition: Dictionary = raw_atom
		var atom_id: String = atom_definition.get("id", "")
		if atom_id.is_empty() or _atoms.has(atom_id):
			errors.append("Atom definition has a missing or duplicate id: " + atom_id)
			continue
		for required_key in ["schema_version", "family", "display_name", "shape", "explanation", "operation_kind", "effect_class", "capabilities", "ports", "compatible_next", "parameters", "codegen_operation"]:
			if not atom_definition.has(required_key):
				errors.append("Atom %s is missing %s." % [atom_id, required_key])
		if atom_definition.get("schema_version", "") != ATOM_SCHEMA_VERSION:
			errors.append("Atom %s has an unsupported schema version." % atom_id)
		if atom_definition.get("family", "") not in REQUIRED_FAMILIES:
			errors.append("Unknown family for atom: " + atom_id)
		if atom_definition.get("effect_class", "") not in EFFECT_CLASSES:
			errors.append("Unknown effect class for atom: " + atom_id)
		errors.append_array(_validate_ports(atom_id, atom_definition.get("ports", [])))
		_atoms[atom_id] = atom_definition.duplicate(true)

	for atom_id in _atoms:
		for next_id in _atoms[atom_id].get("compatible_next", []):
			if not _atoms.has(next_id):
				errors.append("Atom %s references missing compatible atom %s." % [atom_id, next_id])
	return errors

static func _validate_ports(atom_id: String, raw_ports: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not raw_ports is Array:
		return ["Atom %s ports must be an array." % atom_id]
	var port_ids: Dictionary = {}
	for raw_port in raw_ports:
		if not raw_port is Dictionary:
			errors.append("Atom %s has a non-object port." % atom_id)
			continue
		var port: Dictionary = raw_port
		var port_id: String = port.get("id", "")
		if port_id.is_empty() or port_ids.has(port_id):
			errors.append("Atom %s has a missing or duplicate port id." % atom_id)
			continue
		port_ids[port_id] = true
		if port.get("category", "") not in PORT_CATEGORIES:
			errors.append("Atom %s port %s has an invalid category." % [atom_id, port_id])
		if port.get("direction", "") not in PORT_DIRECTIONS:
			errors.append("Atom %s port %s has an invalid direction." % [atom_id, port_id])
		if port.get("value_type", "") not in VALUE_TYPES:
			errors.append("Atom %s port %s has an unsupported type." % [atom_id, port_id])
	return errors

static func ensure_loaded() -> bool:
	if _catalog.is_empty():
		return load_catalog().is_empty()
	return true

static func families() -> Array:
	ensure_loaded()
	return _catalog.get("families", []).duplicate()

static func has_atom(atom_id: String) -> bool:
	ensure_loaded()
	return _atoms.has(atom_id)

static func compatible_choices(atom_ids: Array[String]) -> Array[String]:
	ensure_loaded()
	if atom_ids.is_empty():
		var entries: Array[String] = []
		for atom_id in _catalog.get("entry_atoms", []):
			entries.append(atom_id)
		return entries
	var result: Array[String] = []
	for next_id in _atoms.get(atom_ids[-1], {}).get("compatible_next", []):
		result.append(next_id)
	return result

static func is_compatible(atom_ids: Array[String], candidate_id: String) -> bool:
	return candidate_id in compatible_choices(atom_ids)

static func atom(atom_id: String) -> Dictionary:
	ensure_loaded()
	return _atoms.get(atom_id, {}).duplicate(true)

static func port(atom_id: String, port_id: String) -> Dictionary:
	for raw_port in atom(atom_id).get("ports", []):
		if raw_port is Dictionary and raw_port.get("id", "") == port_id:
			return raw_port.duplicate(true)
	return {}
