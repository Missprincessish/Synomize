class_name VectorVerseCompilerContractValidator
extends RefCounted

const CONTRACT_VERSION := "1.0.0"
const OPERATIONS := ["VALUE_LITERAL", "VAR_BIND", "VAR_READ", "EXPRESSION", "EVENT_ENTRY", "ACTION_CALL", "COND_BRANCH", "LOOP_CTRL", "STATE_READ", "STATE_WRITE", "FUNCTION_OR_MODULE_BOUNDARY", "RETURN", "ERROR_PATH"]

static func validate(ir: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var nodes := _index(ir.get("nodes", []))
	out.append_array(_operations(nodes, ir.get("compiler_contract_version", "") == CONTRACT_VERSION))
	out.append_array(_required_inputs(ir, nodes))
	out.append_array(_control_cycles(ir, nodes))
	out.append_array(_event_reachability(ir, nodes))
	out.append_array(_variables(ir, nodes))
	out.append_array(_loops(ir, nodes))
	out.append_array(_states(ir, nodes))
	return VectorVerseValidationDiagnostic.stable_sort(out)

static func _index(raw: Array) -> Dictionary:
	var result := {}
	for node in raw:
		if node is Dictionary: result[node.get("node_id", "")] = node
	return result

static func _operations(nodes: Dictionary, strict: bool) -> Array[Dictionary]:
	var d: Array[Dictionary] = []
	for n in nodes.values():
		if n.get("operation_kind", "") not in OPERATIONS:
			d.append(VectorVerseValidationDiagnostic.make("E_OPERATION_UNKNOWN", "Operation is not part of the canonical compiler contract.", "graph", "error", "node", n.get("source_block_id", n.get("node_id", ""))))
		if n.get("atom_schema_version", "").is_empty(): d.append(VectorVerseValidationDiagnostic.make("E_ATOM_VERSION_MISSING", "Atom schema version is required.", "graph", "error", "node", n.get("source_block_id", "")))
		if strict and not n.has("target_support"): d.append(VectorVerseValidationDiagnostic.make("E_TARGET_SUPPORT_MISSING", "Node must declare target support.", "backend", "error", "node", n.get("source_block_id", "")))
	return d

static func _required_inputs(ir: Dictionary, nodes: Dictionary) -> Array[Dictionary]:
	var d: Array[Dictionary] = []
	var incoming := {}
	for e in ir.get("control_edges", []) + ir.get("data_edges", []): incoming["%s:%s" % [e.get("to_node", ""), e.get("to_port", "")]] = true
	for n in nodes.values():
		for p in n.get("ports", []):
			if p.get("direction", "") == "input" and p.get("required", false) and not incoming.has("%s:%s" % [n.node_id, p.id]):
				d.append(VectorVerseValidationDiagnostic.make("E_REQUIRED_INPUT_MISSING", "Required input is not connected.", "graph", "error", "port", n.get("source_block_id", n.node_id), p.id))
	return d

static func _control_cycles(ir: Dictionary, nodes: Dictionary) -> Array[Dictionary]:
	var adj := {}; var indegree := {}
	for id in nodes: adj[id]=[]; indegree[id]=0
	for e in ir.get("control_edges", []):
		var a=e.get("from_node",""); var b=e.get("to_node","")
		if adj.has(a) and indegree.has(b): adj[a].append(b); indegree[b]+=1
	var q=[]
	for id in indegree:
		if indegree[id]==0:q.append(id)
	var seen=0
	while not q.is_empty():
		var x=q.pop_front(); seen+=1
		for y in adj[x]:
			indegree[y] -= 1
			if indegree[y] == 0:
				q.append(y)
	if seen != nodes.size() and not nodes.values().any(func(n): return n.get("operation_kind","")=="LOOP_CTRL"):
		return [VectorVerseValidationDiagnostic.make("E_INVALID_CONTROL_CYCLE", "Control cycle requires an explicit Loop operation.", "graph")]
	return []

static func _event_reachability(ir: Dictionary, nodes: Dictionary) -> Array[Dictionary]:
	var starts=[]; var adj={}
	for id in nodes: adj[id]=[]
	for n in nodes.values():
		if n.get("operation_kind","")=="EVENT_ENTRY": starts.append(n.node_id)
	for e in ir.get("control_edges",[]):
		if adj.has(e.get("from_node","")): adj[e.from_node].append(e.get("to_node",""))
	var reached={}; var q=starts.duplicate()
	while not q.is_empty():
		var x=q.pop_front()
		if reached.has(x):continue
		reached[x]=true
		for y in adj.get(x,[]):q.append(y)
	var d: Array[Dictionary]=[]
	for n in nodes.values():
		if n.get("effect_class","")!="PURE" and not reached.has(n.node_id): d.append(VectorVerseValidationDiagnostic.make("E_EVENT_UNREACHABLE", "Effectful/stateful block is not reachable from an Event Entry.", "graph", "error", "node", n.get("source_block_id",n.node_id)))
	return d

static func _variables(ir: Dictionary, nodes: Dictionary) -> Array[Dictionary]:
	var binds={}; var d: Array[Dictionary]=[]
	for n in nodes.values():
		if n.get("operation_kind","")=="VAR_BIND": binds["%s:%s" % [n.parameters.get("scope_id","root"),n.parameters.get("symbol","")]]=true
	for n in nodes.values():
		if n.get("operation_kind","")=="VAR_READ":
			var key="%s:%s" % [n.parameters.get("scope_id","root"),n.parameters.get("symbol","")]
			if not binds.has(key): d.append(VectorVerseValidationDiagnostic.make("E_VARIABLE_UNBOUND", "Variable read has no bind in the same scope.", "scope", "error", "node", n.get("source_block_id",n.node_id)))
	return d

static func _loops(ir: Dictionary, nodes: Dictionary) -> Array[Dictionary]:
	var d: Array[Dictionary]=[]
	for n in nodes.values():
		if n.get("operation_kind","")=="LOOP_CTRL" and int(n.get("parameters",{}).get("max_iterations",0)) <= 0: d.append(VectorVerseValidationDiagnostic.make("E_LOOP_BOUND_INVALID", "Loop requires a positive deterministic max_iterations bound.", "graph", "error", "node", n.get("source_block_id",n.node_id)))
	return d

static func _states(ir: Dictionary, nodes: Dictionary) -> Array[Dictionary]:
	var writes={}; var d: Array[Dictionary]=[]
	for n in nodes.values():
		if n.get("operation_kind","") in ["STATE_READ","STATE_WRITE"]:
			if n.parameters.get("lifetime","") not in ["session","persistent"]: d.append(VectorVerseValidationDiagnostic.make("E_STATE_LIFETIME_INVALID", "State lifetime must be session or persistent.", "state", "error", "node", n.get("source_block_id",n.node_id)))
		if n.get("operation_kind","")=="STATE_WRITE": writes[n.parameters.get("state_id","")]=true
	for n in nodes.values():
		if n.get("operation_kind","")=="STATE_READ" and not writes.has(n.parameters.get("state_id","")): d.append(VectorVerseValidationDiagnostic.make("E_STATE_READ_BEFORE_WRITE", "State read has no matching write in this graph.", "state", "error", "node", n.get("source_block_id",n.node_id)))
	return d
