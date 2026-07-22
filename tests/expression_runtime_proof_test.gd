extends SceneTree

const CASES := {
	"arithmetic": {"ir": "_arithmetic_ir", "expected": 12},
	"comparison": {"ir": "_comparison_ir", "expected": true},
	"variable_fed": {"ir": "_variable_fed_ir", "expected": 36}
}

func _initialize() -> void:
	var failures: Array[String] = []
	var summaries: Dictionary = {}
	for case_name in CASES:
		var spec: Dictionary = CASES[case_name]
		var ir: Dictionary = call(spec.ir)
		var structural := VectorVerseTypedIRValidator.validate(ir)
		var semantic := VectorVerseCompilerContractValidator.validate(ir)
		var types := VectorVerseTypeValidator.validate(ir)
		var backend := VectorVerseBackendSupportChecker.validate(ir)
		if not structural.is_empty() or not semantic.is_empty() or not types.is_empty() or not backend.is_empty():
			failures.append("%s validation failed: %s" % [case_name, JSON.stringify({"structural":structural,"semantic":semantic,"types":types,"backend":backend})])
			continue
		var first := VectorVerseGDScriptAdapter.generate_from_ir(ir)
		var second := VectorVerseGDScriptAdapter.generate_from_ir(ir)
		if not first.accepted:
			failures.append(case_name + " generation rejected: " + JSON.stringify(first.diagnostics))
			continue
		if first.source != second.source or first.source_map != second.source_map or first.manifest != second.manifest:
			failures.append(case_name + " generation was nondeterministic")
			continue
		var script := GDScript.new()
		script.source_code = first.source
		if script.reload() != OK or not script.can_instantiate():
			failures.append(case_name + " generated source did not parse")
			continue
		var instance = script.new()
		var runtime_output: Variant = instance.execute()
		instance.free()
		if runtime_output != spec.expected:
			failures.append("%s runtime expected %s got %s" % [case_name, str(spec.expected), str(runtime_output)])
			continue
		var folder: String = "res://evidence/expression_runtime_proofs/" + str(case_name)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		_write_text(folder + "/generated.gd", first.source)
		_write_json(folder + "/ir.json", ir)
		_write_json(folder + "/source_map.json", first.source_map)
		_write_json(folder + "/manifest.json", first.manifest)
		_write_text(folder + "/runtime_output.txt", str(runtime_output) + "\n")
		var summary := {
			"case": case_name,
			"runtime_output": runtime_output,
			"expected": spec.expected,
			"ir_sha256": VectorVerseTypedIRSerializer.canonical_json(ir).sha256_text(),
			"source_sha256": first.source.sha256_text(),
			"source_map_sha256": JSON.stringify(first.source_map, "\t", true).sha256_text(),
			"manifest_sha256": JSON.stringify(first.manifest, "\t", true).sha256_text(),
			"parse_success": true,
			"deterministic": true
		}
		_write_json(folder + "/evidence.json", summary)
		summaries[case_name] = summary
		print("EXPRESSION_%s_RUNTIME=%s" % [case_name.to_upper(), str(runtime_output)])
		print("EXPRESSION_%s_SOURCE_SHA256=%s" % [case_name.to_upper(), first.source.sha256_text()])
	_write_json("res://evidence/expression_runtime_proofs/summary.json", {"accepted": failures.is_empty(), "cases": summaries, "errors": failures})
	if failures.is_empty():
		print("VECTORVERSE_EXPRESSION_RUNTIME_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _arithmetic_ir() -> Dictionary:
	return _base([
		_n("event", "EVENT_ENTRY", "Event", [_p("out","control","output","Void")]),
		_literal("left", 7, "Int"), _literal("right", 5, "Int"),
		_expression("expr", "+", "Int")
	], [], [_d("d1","left","value","expr","left","Int"), _d("d2","right","value","expr","right","Int")])

func _comparison_ir() -> Dictionary:
	return _base([
		_n("event", "EVENT_ENTRY", "Event", [_p("out","control","output","Void")]),
		_literal("left", 7, "Int"), _literal("right", 5, "Int"),
		_expression("expr", ">", "Bool")
	], [], [_d("d1","left","value","expr","left","Int"), _d("d2","right","value","expr","right","Int")])

func _variable_fed_ir() -> Dictionary:
	return _base([
		_n("event", "EVENT_ENTRY", "Event", [_p("out","control","output","Void")]),
		_literal("bound_value", 9, "Int"), _literal("right", 4, "Int"),
		_n("bind", "VAR_BIND", "Variable", [_p("in","control","input","Void"),_p("out","control","output","Void"),_p("value","data","input","Int")], {"symbol":"x","scope_id":"root"}, "STATEFUL"),
		_n("read", "VAR_READ", "Variable", [_p("value","data","output","Int")], {"symbol":"x","scope_id":"root"}),
		_expression("expr", "*", "Int")
	], [_c("c1","event","out","bind","in")], [_d("d1","bound_value","value","bind","value","Int"),_d("d2","read","value","expr","left","Int"),_d("d3","right","value","expr","right","Int")])

func _expression(id: String, operator: String, result_type: String) -> Dictionary:
	return _n(id, "EXPRESSION", "Variable", [_p("left","data","input","Int"),_p("right","data","input","Int"),_p("result","data","output",result_type)], {"operator":operator})

func _literal(id: String, value: Variant, value_type: String) -> Dictionary:
	return _n(id, "VALUE_LITERAL", "Variable", [_p("value","data","output",value_type)], {"value":value,"value_type":value_type})

func _p(id:String, category:String, direction:String, value_type:String, required:bool=true) -> Dictionary:
	return {"id":id,"category":category,"direction":direction,"value_type":value_type,"required":required}
func _n(id:String, op:String, family:String, ports:Array, params:Dictionary={}, effect:String="PURE", caps:Array=[]) -> Dictionary:
	return {"node_id":id,"source_block_id":"block_"+id,"atom_id":"fixture_"+id,"atom_schema_version":"1.0.0","operation_kind":op,"family":family,"effect_class":effect,"capabilities":caps,"ports":ports,"parameters":params,"serialization_version":2,"migration_version":1,"target_support":{"gdscript":"proven"}}
func _c(id:String,a:String,ap:String,b:String,bp:String) -> Dictionary:
	return {"edge_id":id,"category":"control","from_node":a,"from_port":ap,"to_node":b,"to_port":bp}
func _d(id:String,a:String,ap:String,b:String,bp:String,t:String) -> Dictionary:
	return {"edge_id":id,"category":"data","from_node":a,"from_port":ap,"to_node":b,"to_port":bp,"value_type":t}
func _base(nodes:Array, controls:Array=[], data:Array=[]) -> Dictionary:
	return {"ir_schema_version":"2.0.0","serialization_version":2,"migration_version":1,"compiler_contract_version":"1.0.0","target_support":{"gdscript":"proven"},"source_graph_schema_version":"1.1.0","graph_id":"expression_proof","nodes":nodes,"control_edges":controls,"data_edges":data}
func _write_text(path:String, content:String) -> void:
	var f=FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()
func _write_json(path:String, value:Variant) -> void:
	_write_text(path, JSON.stringify(value, "\t", true) + "\n")
