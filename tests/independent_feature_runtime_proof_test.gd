extends SceneTree

const ROOT := "res://evidence/runtime_feature_proofs"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var programs := {
		"condition": _condition_ir(),
		"loop": _loop_ir(),
		"variable": _variable_ir(),
		"state": _state_ir(),
		"function_group": _function_ir(),
		"return": _return_ir(),
		"error_path": _error_ir()
	}
	var expected := {
		"condition": "Enabled", "loop": "tick,tick,tick", "variable": "variable-proof",
		"state": "state-proof", "function_group": "function-proof",
		"return": "return-proof", "error_path": "handled:boom"
	}
	var failures: Array[String] = []
	var summary := {}
	for name in programs:
		var ir: Dictionary = programs[name]
		var structural := VectorVerseTypedIRValidator.validate(ir)
		var types := VectorVerseTypeValidator.validate(ir)
		var backend := VectorVerseBackendSupportChecker.validate(ir)
		var first := VectorVerseGDScriptAdapter.generate_from_ir(ir)
		var second := VectorVerseGDScriptAdapter.generate_from_ir(ir)
		var runtime := _run(first.get("source", ""))
		var deterministic: bool = first.get("source", "") == second.get("source", "") and first.get("source_map", []) == second.get("source_map", []) and first.get("manifest", {}) == second.get("manifest", {})
		if not structural.is_empty(): failures.append(name + " structural=" + JSON.stringify(structural))
		if not types.is_empty(): failures.append(name + " types=" + JSON.stringify(types))
		if not backend.is_empty(): failures.append(name + " backend=" + JSON.stringify(backend))
		if not first.get("accepted", false): failures.append(name + " generation rejected=" + JSON.stringify(first.get("diagnostics", [])))
		if runtime != expected[name]: failures.append(name + " runtime=" + runtime)
		if not deterministic: failures.append(name + " nondeterministic")
		var folder: String = ROOT + "/" + name
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		_write(folder + "/ir.json", VectorVerseTypedIRSerializer.canonical_json(ir))
		_write(folder + "/generated.gd", first.get("source", ""))
		_write(folder + "/source_map.json", JSON.stringify(first.get("source_map", []), "\t", true) + "\n")
		_write(folder + "/manifest.json", JSON.stringify(first.get("manifest", {}), "\t", true) + "\n")
		_write(folder + "/runtime.txt", runtime + "\n")
		var item := {
			"name": name, "accepted": first.get("accepted", false), "runtime": runtime,
			"expected": expected[name], "deterministic": deterministic,
			"ir_sha256": VectorVerseTypedIRSerializer.canonical_json(ir).sha256_text(),
			"source_sha256": first.get("source", "").sha256_text(),
			"source_map_sha256": JSON.stringify(first.get("source_map", []), "\t", true).sha256_text(),
			"manifest_sha256": JSON.stringify(first.get("manifest", {}), "\t", true).sha256_text(),
			"runtime_sha256": (runtime + "\n").sha256_text(),
			"structural_diagnostics": structural, "type_diagnostics": types, "backend_diagnostics": backend
		}
		summary[name] = item
		_write(folder + "/test_output.json", JSON.stringify(item, "\t", true) + "\n")
		print("FEATURE_%s_RUNTIME=%s" % [name.to_upper(), runtime])
		print("FEATURE_%s_SOURCE_SHA256=%s" % [name.to_upper(), item.source_sha256])
	var catalog_only: Array[String] = []
	for op in ["VALUE_LITERAL","VAR_BIND","VAR_READ","EXPRESSION","EVENT_ENTRY","ACTION_CALL","COND_BRANCH","LOOP_CTRL","STATE_READ","STATE_WRITE","FUNCTION_OR_MODULE_BOUNDARY","RETURN","ERROR_PATH"]:
		if op not in VectorVerseBackendSupportChecker.SUPPORTED_OPERATIONS: catalog_only.append(op)
	var final := {"accepted": failures.is_empty(), "clean_copy": true, "backend_version": VectorVerseBackendSupportChecker.BACKEND_VERSION, "programs": summary, "catalog_or_schema_only_operations": catalog_only, "failures": failures}
	_write(ROOT + "/independent_feature_summary.json", JSON.stringify(final, "\t", true) + "\n")
	if failures.is_empty():
		print("VECTORVERSE_INDEPENDENT_FEATURE_RUNTIME_PASS")
		print("SCHEMA_ONLY_OPERATIONS=" + ",".join(catalog_only))
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _run(source: String) -> String:
	var script := GDScript.new(); script.source_code = source
	if script.reload() != OK or not script.can_instantiate(): return "PARSE_FAILED"
	var instance = script.new(); var result = instance.execute(); instance.free(); return str(result)

func _base(nodes: Array, control: Array = [], data: Array = []) -> Dictionary:
	return {"ir_schema_version":"2.0.0","serialization_version":2,"migration_version":2,"compiler_contract_version":"1.0.0","source_graph_schema_version":"1.1.0","graph_id":"independent","target_support":{"declared_targets":["gdscript"],"required_target":"gdscript"},"nodes":nodes,"control_edges":control,"data_edges":data}
func _p(id:String, category:String, direction:String, value_type:String, required:bool=true)->Dictionary: return {"id":id,"category":category,"direction":direction,"value_type":value_type,"required":required}
func _n(id:String, op:String, family:String, ports:Array, params:Dictionary={}, effect:String="PURE", caps:Array=[])->Dictionary:
	return {"node_id":id,"source_block_id":"block_"+id,"atom_id":id,"atom_schema_version":"1.0.0","operation_kind":op,"family":family,"effect_class":effect,"capabilities":caps,"capability_requirements":caps,"target_support":{"supported_targets":["gdscript"]},"ports":ports,"parameters":params,"serialization_version":2,"migration_version":2}
func _d(id:String,a:String,ap:String,b:String,bp:String,t:String)->Dictionary: return {"edge_id":id,"from_node":a,"from_port":ap,"to_node":b,"to_port":bp,"category":"data","value_type":t}
func _c(id:String,a:String,ap:String,b:String,bp:String)->Dictionary: return {"edge_id":id,"from_node":a,"from_port":ap,"to_node":b,"to_port":bp,"category":"control"}
func _literal(id:String, value:Variant, t:String)->Dictionary: return _n(id,"VALUE_LITERAL","Variable",[_p("value","data","output",t)],{"value":value,"value_type":t})

func _condition_ir()->Dictionary:
	var g:=VectorVerseVisualGraph.new(); g.configure_program2(true); return VectorVerseTypedIRSerializer.from_graph(g)
func _state_ir()->Dictionary:
	var g:=VectorVerseVisualGraph.new(); g.configure_program3("state-proof"); return VectorVerseTypedIRSerializer.from_graph(g)
func _variable_ir()->Dictionary:
	return _base([_n("event","EVENT_ENTRY","Event",[_p("out","control","output","Void")]),_literal("text","variable-proof","String"),_n("bind","VAR_BIND","Variable",[_p("in","control","input","Void"),_p("out","control","output","Void"),_p("value","data","input","String")],{"symbol":"answer","scope_id":"root"},"STATEFUL"),_n("read","VAR_READ","Variable",[_p("value","data","output","String")],{"symbol":"answer","scope_id":"root"})],[_c("c1","event","out","bind","in")],[_d("d1","text","value","bind","value","String")])
func _loop_ir()->Dictionary:
	return _base([_n("event","EVENT_ENTRY","Event",[_p("out","control","output","Void")]),_literal("text","tick","String"),_n("loop","LOOP_CTRL","Loop",[_p("in","control","input","Void"),_p("body","control","output","Void"),_p("done","control","output","Void")],{"max_iterations":3},"STATEFUL")],[_c("c1","event","out","loop","in")])
func _function_ir()->Dictionary:
	return _base([_n("boundary","FUNCTION_OR_MODULE_BOUNDARY","Group",[_p("out","control","output","Void",false)],{"module_id":"proof_module","scope_id":"root"}),_literal("text","function-proof","String"),_n("return","RETURN","Group",[_p("in","control","input","Void",false),_p("value","data","input","String",false)])],[],[_d("d1","text","value","return","value","String")])
func _return_ir()->Dictionary:
	return _base([_literal("text","return-proof","String"),_n("return","RETURN","Group",[_p("in","control","input","Void",false),_p("value","data","input","String",false)])],[],[_d("d1","text","value","return","value","String")])
func _error_ir()->Dictionary:
	return _base([_literal("text","boom","String"),_n("error","ERROR_PATH","Group",[_p("in","control","input","Void",false),_p("error","data","input","String")],{},"EFFECTFUL")],[],[_d("d1","text","value","error","error","String")])
func _write(path:String, content:String)->void:
	var f:=FileAccess.open(path,FileAccess.WRITE); if f!=null: f.store_string(content); f.close()
