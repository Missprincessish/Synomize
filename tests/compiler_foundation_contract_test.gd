extends SceneTree

const OPS := ["VALUE_LITERAL", "VAR_BIND", "VAR_READ", "EXPRESSION", "EVENT_ENTRY", "ACTION_CALL", "COND_BRANCH", "LOOP_CTRL", "STATE_READ", "STATE_WRITE", "FUNCTION_OR_MODULE_BOUNDARY", "RETURN", "ERROR_PATH"]
const FAMILIES := ["Variable", "Action", "Condition", "Loop", "Event", "State", "Group"]

func _initialize() -> void:
	var failures: Array[String] = []
	var catalog_errors := VectorVerseAtomCatalog.load_catalog()
	if not catalog_errors.is_empty(): failures.append("Catalog failed: " + JSON.stringify(catalog_errors))
	var catalog_ops: Array = VectorVerseAtomCatalog._catalog.get("canonical_operations", [])
	if catalog_ops != OPS: failures.append("Canonical operation manifest mismatch.")
	var represented := {}
	for atom_id in VectorVerseAtomCatalog._atoms:
		represented[VectorVerseAtomCatalog._atoms[atom_id].get("family", "")] = true
	for family in FAMILIES:
		if not represented.has(family): failures.append("Missing family: " + family)

	var valid := _valid_all_operations_ir()
	var structural := VectorVerseTypedIRValidator.validate(valid)
	var semantic := VectorVerseCompilerContractValidator.validate(valid)
	var types := VectorVerseTypeValidator.validate(valid)
	if not structural.is_empty(): failures.append("All-operations IR structural failure: " + JSON.stringify(structural))
	if not semantic.is_empty(): failures.append("All-operations IR semantic failure: " + JSON.stringify(semantic))
	if not types.is_empty(): failures.append("All-operations IR type failure: " + JSON.stringify(types))
	var seen := {}
	for n in valid.nodes: seen[n.operation_kind] = true
	for op in OPS:
		if not seen.has(op): failures.append("Operation missing from fixture: " + op)
	var backend := VectorVerseBackendSupportChecker.validate(valid)
	if not backend.is_empty():
		failures.append("Canonical operations are not all declared supported: " + JSON.stringify(backend))

	_assert_code(failures, _mutate_missing_input(valid), "E_REQUIRED_INPUT_MISSING")
	_assert_code(failures, _invalid_cycle_ir(), "E_INVALID_CONTROL_CYCLE")
	_assert_code(failures, _unreachable_ir(), "E_EVENT_UNREACHABLE")
	_assert_code(failures, _unbound_variable_ir(), "E_VARIABLE_UNBOUND")
	_assert_code(failures, _invalid_loop_ir(), "E_LOOP_BOUND_INVALID")
	_assert_code(failures, _invalid_state_ir(), "E_STATE_LIFETIME_INVALID")
	_assert_code(failures, _state_read_before_write_ir(), "E_STATE_READ_BEFORE_WRITE")
	_assert_code(failures, _unknown_operation_ir(), "E_OPERATION_UNKNOWN")

	var crossed := valid.duplicate(true)
	crossed.control_edges[0].category = "data"
	if not VectorVerseTypedIRValidator.validate(crossed).any(func(d): return d.get("code", "") == "E_EDGE_CATEGORY"):
		failures.append("Control/data separation was not enforced.")
	var mismatched := valid.duplicate(true)
	mismatched.data_edges[0].value_type = "Bool"
	for n in mismatched.nodes:
		if n.node_id == mismatched.data_edges[0].to_node:
			for p in n.ports:
				if p.id == mismatched.data_edges[0].to_port: p.value_type = "Bool"
	if not VectorVerseTypeValidator.validate(mismatched).any(func(d): return d.get("code", "") == "E_TYPE_MISMATCH"):
		failures.append("Port type mismatch was not rejected.")

	var capability_ir := _single_action_ir(["NETWORK"])
	var cap_errors := VectorVerseCapabilityValidator.validate(capability_ir, {"declared": ["LOG"], "approved_sensitive": []})
	if not cap_errors.any(func(d): return d.get("code", "") == "E_CAPABILITY_NOT_DECLARED"):
		failures.append("Undeclared capability was not rejected.")

	var legacy := _legacy_ir()
	var migrated_a := VectorVerseTypedIRSerializer.migrate_to_current(legacy)
	var migrated_b := VectorVerseTypedIRSerializer.migrate_to_current(legacy)
	if migrated_a.is_empty() or migrated_a != migrated_b: failures.append("Migration was missing or nondeterministic.")
	if migrated_a.get("ir_schema_version", "") != "2.0.0" or migrated_a.get("serialization_version", 0) != 2: failures.append("Migration versions incorrect.")
	var migration_hash := VectorVerseTypedIRSerializer.canonical_json(migrated_a).sha256_text()
	if migration_hash != VectorVerseTypedIRSerializer.canonical_json(migrated_b).sha256_text(): failures.append("Migration hash changed.")

	var p1 := VectorVerseVisualGraph.new(); p1.insert_atom("app_start"); p1.insert_atom("display_message", {"message":"Compiler proof"})
	var ir1 := VectorVerseTypedIRSerializer.from_graph(p1)
	var ir2 := VectorVerseTypedIRSerializer.from_graph(p1)
	if VectorVerseTypedIRSerializer.canonical_json(ir1) != VectorVerseTypedIRSerializer.canonical_json(ir2): failures.append("Serialization was nondeterministic.")
	var generated := VectorVerseGDScriptAdapter.generate_from_ir(ir1)
	if not generated.accepted: failures.append("Proven GDScript subset no longer generates.")
	else:
		var script := GDScript.new(); script.source_code = generated.source
		if script.reload() != OK or not script.can_instantiate(): failures.append("Generated GDScript did not parse.")
		else:
			var instance = script.new(); var output: String = instance.execute(); instance.free()
			if output != "Compiler proof": failures.append("Generated runtime output mismatch.")

	_write_json("res://evidence/compiler_foundation_contract_evidence.json", {
		"accepted": failures.is_empty(), "contract_version": "1.0.0", "ir_schema_version": VectorVerseTypedIRSerializer.IR_SCHEMA_VERSION,
		"serialization_version": VectorVerseTypedIRSerializer.SERIALIZATION_VERSION, "families": FAMILIES, "operations": OPS,
		"all_operations_ir_sha256": VectorVerseTypedIRSerializer.canonical_json(valid).sha256_text(), "migration_sha256": migration_hash,
		"gdscript_proven_subset_runtime": "Compiler proof", "gdscript_only_proven_target": true, "errors": failures
	})
	if failures.is_empty():
		print("VECTORVERSE_COMPILER_FOUNDATION_PASS")
		print("FAMILIES=7")
		print("OPERATIONS=13")
		print("IR_SHA256=" + VectorVerseTypedIRSerializer.canonical_json(valid).sha256_text())
		print("MIGRATION_SHA256=" + migration_hash)
		print("GDSCRIPT_RUNTIME=Compiler proof")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)

func _assert_code(failures: Array[String], ir: Dictionary, code: String) -> void:
	if not VectorVerseCompilerContractValidator.validate(ir).any(func(d): return d.get("code", "") == code): failures.append("Missing diagnostic " + code)

func _p(id:String, category:String, direction:String, value_type:String, required:bool=true) -> Dictionary:
	return {"id":id,"category":category,"direction":direction,"value_type":value_type,"required":required}
func _n(id:String, op:String, family:String, ports:Array, params:Dictionary={}, effect:String="PURE", caps:Array=[]) -> Dictionary:
	return {"node_id":id,"source_block_id":"block_"+id,"atom_id":"fixture_"+id,"atom_schema_version":"1.0.0","operation_kind":op,"family":family,"effect_class":effect,"capabilities":caps,"ports":ports,"parameters":params,"serialization_version":2,"migration_version":1,"target_support":{"gdscript":"unsupported"}}
func _c(id:String,a:String,ap:String,b:String,bp:String) -> Dictionary: return {"edge_id":id,"category":"control","from_node":a,"from_port":ap,"to_node":b,"to_port":bp}
func _d(id:String,a:String,ap:String,b:String,bp:String,t:String) -> Dictionary: return {"edge_id":id,"category":"data","from_node":a,"from_port":ap,"to_node":b,"to_port":bp,"value_type":t}
func _base(nodes:Array, controls:Array=[], data:Array=[]) -> Dictionary:
	return {"ir_schema_version":"2.0.0","serialization_version":2,"migration_version":1,"compiler_contract_version":"1.0.0","target_support":{"gdscript":"proven_subset"},"source_graph_schema_version":"1.1.0","graph_id":"compiler_contract","nodes":nodes,"control_edges":controls,"data_edges":data}

func _valid_all_operations_ir() -> Dictionary:
	var nodes=[
		_n("event","EVENT_ENTRY","Event",[_p("out","control","output","Void")]),
		_n("text","VALUE_LITERAL","Variable",[_p("value","data","output","String")],{"value":"ok","value_type":"String"}),
		_n("int1","VALUE_LITERAL","Variable",[_p("value","data","output","Int")],{"value":1,"value_type":"Int"}),
		_n("int2","VALUE_LITERAL","Variable",[_p("value","data","output","Int")],{"value":2,"value_type":"Int"}),
		_n("bool","VALUE_LITERAL","Variable",[_p("value","data","output","Bool")],{"value":true,"value_type":"Bool"}),
		_n("bind","VAR_BIND","Variable",[_p("in","control","input","Void"),_p("out","control","output","Void"),_p("value","data","input","String")],{"symbol":"x","scope_id":"root"},"STATEFUL"),
		_n("read","VAR_READ","Variable",[_p("value","data","output","String")],{"symbol":"x","scope_id":"root"}),
		_n("expr","EXPRESSION","Variable",[_p("left","data","input","Int"),_p("right","data","input","Int"),_p("result","data","output","Int")],{"operator":"+"}),
		_n("write","STATE_WRITE","State",[_p("in","control","input","Void"),_p("out","control","output","Void"),_p("value","data","input","String")],{"state_id":"s","lifetime":"session"},"STATEFUL"),
		_n("state_read","STATE_READ","State",[_p("in","control","input","Void"),_p("out","control","output","Void"),_p("value","data","output","String")],{"state_id":"s","lifetime":"session"},"STATEFUL"),
		_n("condition","COND_BRANCH","Condition",[_p("in","control","input","Void"),_p("true","control","output","Void"),_p("false","control","output","Void",false),_p("condition","data","input","Bool")]),
		_n("loop","LOOP_CTRL","Loop",[_p("in","control","input","Void"),_p("body","control","output","Void"),_p("done","control","output","Void",false),_p("condition","data","input","Bool")],{"max_iterations":3}),
		_n("module","FUNCTION_OR_MODULE_BOUNDARY","Group",[_p("in","control","input","Void"),_p("out","control","output","Void")],{"module_id":"main","scope_id":"root"}),
		_n("action","ACTION_CALL","Action",[_p("in","control","input","Void"),_p("out","control","output","Void"),_p("message","data","input","String")],{},"EFFECTFUL",["LOG"]),
		_n("return","RETURN","Action",[_p("in","control","input","Void"),_p("out","control","output","Void",false),_p("value","data","input","String",false)]),
		_n("error","ERROR_PATH","Action",[_p("in","control","input","Void"),_p("error","data","input","String")],{},"EFFECTFUL",["LOG"])
	]
	var controls=[_c("c1","event","out","bind","in"),_c("c2","bind","out","write","in"),_c("c3","write","out","state_read","in"),_c("c4","state_read","out","condition","in"),_c("c5","condition","true","loop","in"),_c("c6","loop","body","module","in"),_c("c7","module","out","action","in"),_c("c8","action","out","return","in"),_c("c9","return","out","error","in")]
	var data=[_d("d1","text","value","bind","value","String"),_d("d2","int1","value","expr","left","Int"),_d("d3","int2","value","expr","right","Int"),_d("d4","read","value","write","value","String"),_d("d5","bool","value","condition","condition","Bool"),_d("d6","bool","value","loop","condition","Bool"),_d("d7","state_read","value","action","message","String"),_d("d8","text","value","error","error","String")]
	return _base(nodes,controls,data)

func _mutate_missing_input(ir:Dictionary)->Dictionary:
	var x=ir.duplicate(true); x.data_edges=x.data_edges.filter(func(e): return e.edge_id!="d8"); return x
func _invalid_cycle_ir()->Dictionary:
	var e=_n("event","EVENT_ENTRY","Event",[_p("out","control","output","Void")]); var a=_n("a","ACTION_CALL","Action",[_p("in","control","input","Void"),_p("out","control","output","Void")],{},"EFFECTFUL"); var b=_n("b","ACTION_CALL","Action",[_p("in","control","input","Void"),_p("out","control","output","Void")],{},"EFFECTFUL"); return _base([e,a,b],[_c("c1","event","out","a","in"),_c("c2","a","out","b","in"),_c("c3","b","out","a","in")])
func _unreachable_ir()->Dictionary: return _base([_n("event","EVENT_ENTRY","Event",[_p("out","control","output","Void")]),_n("a","ACTION_CALL","Action",[_p("in","control","input","Void",false)],{},"EFFECTFUL")])
func _unbound_variable_ir()->Dictionary: return _base([_n("read","VAR_READ","Variable",[_p("value","data","output","String")],{"symbol":"missing","scope_id":"root"})])
func _invalid_loop_ir()->Dictionary: return _base([_n("loop","LOOP_CTRL","Loop",[],{"max_iterations":0})])
func _invalid_state_ir()->Dictionary: return _base([_n("write","STATE_WRITE","State",[],{"state_id":"s","lifetime":"forever"})])
func _state_read_before_write_ir()->Dictionary: return _base([_n("read","STATE_READ","State",[],{"state_id":"s","lifetime":"session"})])
func _unknown_operation_ir()->Dictionary: return _base([_n("x","MAGIC_UNKNOWN","Group",[])])
func _single_action_ir(caps:Array)->Dictionary: return _base([_n("a","ACTION_CALL","Action",[],{},"EFFECTFUL",caps)])
func _legacy_ir()->Dictionary:
	var x = _base([_n("event", "EVENT_ENTRY", "Event", [_p("out", "control", "output", "Void")])])
	x.ir_schema_version = "1.0.0"
	x.serialization_version = 1
	x.erase("migration_version")
	x.erase("compiler_contract_version")
	x.erase("target_support")
	for n in x.nodes:
		n.serialization_version = 1
		n.erase("migration_version")
		n.erase("target_support")
	return x
func _write_json(path:String,value:Variant)->void:
	var f=FileAccess.open(path,FileAccess.WRITE); if f!=null: f.store_string(JSON.stringify(value,"\t",true)+"\n"); f.close()
