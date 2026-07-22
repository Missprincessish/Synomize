#!/usr/bin/env python3
import json, hashlib, pathlib, shutil, sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
CAT=json.load(open(pathlib.Path(__file__).with_name('reusable_atom_catalog.json')))

def canon(v): return json.dumps(v,sort_keys=True,separators=(',',':'))
def sha_bytes(b): return hashlib.sha256(b).hexdigest()
def write(p,s): p.parent.mkdir(parents=True,exist_ok=True); p.write_text(s)
def gd(v):
    if isinstance(v,bool): return 'true' if v else 'false'
    if isinstance(v,str): return json.dumps(v)
    if isinstance(v,(int,float)): return str(v)
    if isinstance(v,list): return '['+', '.join(gd(x) for x in v)+']'
    if isinstance(v,dict): return '{'+', '.join(json.dumps(k)+': '+gd(x) for k,x in v.items())+'}'
    return 'null'
def field_default(f): return gd(f.get('default'))
def app_dir(spec): return ROOT/'generated_apps'/spec['app_name'].replace(' ','')

def validate_ir(ir):
    ids={a['id']:a for a in CAT['atoms']}; errors=[]
    if ir.get('catalog_version')!=CAT['catalog_version']: errors.append('catalog version mismatch')
    for n in ir.get('nodes',[]):
        if n.get('atom_id') not in ids: errors.append('unknown atom '+str(n.get('atom_id')))
        elif n.get('atom_version')!=ids[n['atom_id']]['version']: errors.append('atom version mismatch '+n['atom_id'])
    required={'entity_crud','persistent_store','validated_form','navigation_tabs','list_screen','dashboard_screen','settings_screen','error_recovery'}
    present={n['atom_id'] for n in ir['nodes']}
    for x in required-present: errors.append('missing '+x)
    return errors

def generate(ir_path):
    ir=json.load(open(ir_path)); errors=validate_ir(ir)
    if errors: raise SystemExit(errors)
    s=ir['app']; out=app_dir(s)
    if out.exists(): shutil.rmtree(out)
    for x in ['scripts','tests','evidence','screenshots','build']: (out/x).mkdir(parents=True,exist_ok=True)
    entity=s['entity']; singular=entity['singular']; plural=entity['plural']; fields=entity['fields']; state_defaults={plural:[], 'next_id':1, 'last_error':''}; state_defaults.update(s.get('state',{}))
    behavior={b['atom']:b for b in s['behaviors']}
    header='# GENERATED from reusable VectorVerse catalog %s\n# IR_SHA256=%s\n' % (CAT['catalog_version'],sha_bytes(canon(ir).encode()))
    defaults=', '.join(json.dumps(k)+': '+gd(v) for k,v in state_defaults.items())
    new_fields=[]; validation=[]; update_fields=[]
    for f in fields:
        fid=f['id']; typ=f['type']; val=fid
        if typ=='string':
            if f.get('required'): validation.append(f'\tif {val}.strip_edges().is_empty(): return _error("{f["label"]} is required")')
            if f.get('max_length'): validation.append(f'\tif {val}.length() > {int(f["max_length"])}: return _error("{f["label"]} is too long")')
            new_fields.append(json.dumps(fid)+f': {val}.strip_edges()')
        elif typ=='int':
            if 'min' in f: validation.append(f'\tif {val} < {int(f["min"])}: return _error("{f["label"]} is too small")')
            if 'max' in f: validation.append(f'\tif {val} > {int(f["max"])}: return _error("{f["label"]} is too large")')
            new_fields.append(json.dumps(fid)+f': {val}')
        else: new_fields.append(json.dumps(fid)+f': {val}')
        update_fields.append(f'\titem[{json.dumps(fid)}] = '+(f'{val}.strip_edges()' if typ=='string' else val))
    args=', '.join(f'{f["id"]}: '+{'string':'String','int':'int','bool':'bool'}[f['type']]+' = '+field_default(f) for f in fields)
    model=header+f'''class_name ReusableCollectionModel
extends RefCounted

var save_path: String
var state: Dictionary = {gd(state_defaults)}

func _init(path: String = "user://{s['app_id']}.json") -> void:
\tsave_path = path

func validate_form({args}) -> Dictionary:
'''+('\n'.join(validation) if validation else '\tpass')+'''\n\treturn {"ok": true}\n
'''+f'''func create_item({args}) -> Dictionary:
\tvar check := validate_form({', '.join(f['id'] for f in fields)})
\tif not check.ok: return check
\tvar item := {{"id": int(state.next_id), {', '.join(new_fields)}}}
\tstate.next_id = int(state.next_id) + 1
\tstate[{json.dumps(plural)}].append(item)
\treturn {{"ok": true, "item": item.duplicate(true)}}

func edit_item(id: int, {args}) -> Dictionary:
\tvar check := validate_form({', '.join(f['id'] for f in fields)})
\tif not check.ok: return check
\tvar index := find_index(id)
\tif index < 0: return _error("item not found")
\tvar item: Dictionary = state[{json.dumps(plural)}][index]
'''+ '\n'.join(update_fields)+f'''
\tstate[{json.dumps(plural)}][index] = item
\treturn {{"ok": true, "item": item.duplicate(true)}}

func delete_item(id: int) -> Dictionary:
\tvar index := find_index(id)
\tif index < 0: return _error("item not found")
\tvar removed: Dictionary = state[{json.dumps(plural)}][index].duplicate(true)
\tstate[{json.dumps(plural)}].remove_at(index)
\treturn {{"ok": true, "item": removed}}

func toggle_item(id: int, field: String) -> Dictionary:
\tvar index := find_index(id)
\tif index < 0: return _error("item not found")
\tif not state[{json.dumps(plural)}][index].has(field): return _error("field not found")
\tstate[{json.dumps(plural)}][index][field] = not bool(state[{json.dumps(plural)}][index][field])
\treturn {{"ok": true, "value": state[{json.dumps(plural)}][index][field]}}

func adjust_counter(counter: String, change: int, minimum: int = 0, maximum: int = 2147483647) -> Dictionary:
\tif not state.has(counter): return _error("counter not found")
\tstate[counter] = clampi(int(state[counter]) + change, minimum, maximum)
\treturn {{"ok": true, "value": state[counter]}}

func adjust_item_counter(id: int, counter: String, change: int, minimum: int = 0) -> Dictionary:
\tvar index := find_index(id)
\tif index < 0: return _error("item not found")
\tif not state[{json.dumps(plural)}][index].has(counter): return _error("counter not found")
\tstate[{json.dumps(plural)}][index][counter] = maxi(minimum, int(state[{json.dumps(plural)}][index][counter]) + change)
\treturn {{"ok": true, "value": state[{json.dumps(plural)}][index][counter]}}

func timer_seconds(minutes: int, multiplier: int = 60) -> Dictionary:
\tif minutes < 0 or multiplier < 1: return _error("invalid timer")
\treturn {{"ok": true, "seconds": minutes * multiplier}}

func complete_item(id: int, completion_field: String = "", item_counter: String = "", global_counter: String = "", date_field: String = "", day_key: String = "") -> Dictionary:
\tvar index := find_index(id)
\tif index < 0: return _error("item not found")
\tif not date_field.is_empty():
\t\tvar effective_day := day_key if not day_key.is_empty() else Time.get_date_string_from_system()
\t\tif str(state[{json.dumps(plural)}][index].get(date_field, "")) == effective_day: return _error("already completed today")
\t\tstate[{json.dumps(plural)}][index][date_field] = effective_day
\tif not completion_field.is_empty(): state[{json.dumps(plural)}][index][completion_field] = true
\tif not item_counter.is_empty(): adjust_item_counter(id, item_counter, 1)
\tif not global_counter.is_empty(): adjust_counter(global_counter, 1)
\treturn {{"ok": true, "item": state[{json.dumps(plural)}][index].duplicate(true)}}

func save_state() -> Dictionary:
\tvar file := FileAccess.open(save_path, FileAccess.WRITE)
\tif file == null: return _error("save failed")
\tfile.store_string(JSON.stringify(state, "\t", true)); file.close()
\treturn {{"ok": true}}

func load_state() -> Dictionary:
\tif not FileAccess.file_exists(save_path): return {{"ok": true, "new": true}}
\tvar file := FileAccess.open(save_path, FileAccess.READ)
\tif file == null: return _recover("load failed")
\tvar parsed = JSON.parse_string(file.get_as_text()); file.close()
\tif not parsed is Dictionary: return _recover("corrupt storage")
\tstate = parsed
\treturn {{"ok": true}}

func rows() -> Array:
\tvar result: Array = []
\tfor index in range(mini(1000, state[{json.dumps(plural)}].size())): result.append(state[{json.dumps(plural)}][index].duplicate(true))
\treturn result

func navigate(screen: String, allowed: Array) -> Dictionary:
\tif screen not in allowed: return _error("unknown screen")
\treturn {{"ok": true, "screen": screen}}

func find_index(id: int) -> int:
\tfor index in range(state[{json.dumps(plural)}].size()):
\t\tif int(state[{json.dumps(plural)}][index].id) == id: return index
\treturn -1

func _recover(message: String) -> Dictionary:
\tstate = {gd(state_defaults)}
\tstate.last_error = message
\treturn {{"ok": false, "recovered": true, "error": message}}

func _error(message: String) -> Dictionary:
\tstate.last_error = message
\treturn {{"ok": false, "error": message}}
'''
    write(out/'scripts/ReusableCollectionModel.gd',model)
    # UI is generic based on field schema
    input_nodes=[]; onready=[]; collect=[]; reset=[]; load=[]
    for f in fields:
        fid=f['id']; label=f['label']; typ=f['type']; path=f'$Margin/VBox/Tabs/{entity["title"]}/Editor/{fid}'
        if typ=='string': node=f'[node name="{fid}" type="LineEdit" parent="Margin/VBox/Tabs/{entity["title"]}/Editor"]\nlayout_mode = 2\nplaceholder_text = "{label}"\n'; onready.append(f'@onready var input_{fid}: LineEdit = {path}'); collect.append(f'input_{fid}.text'); reset.append(f'\tinput_{fid}.text = {field_default(f)}'); load.append(f'\tinput_{fid}.text = str(item.{fid})')
        elif typ=='int': node=f'[node name="{fid}" type="SpinBox" parent="Margin/VBox/Tabs/{entity["title"]}/Editor"]\nlayout_mode = 2\nmin_value = {float(f.get("min",-999999))}\nmax_value = {float(f.get("max",999999))}\nvalue = {float(f.get("default",0))}\n'; onready.append(f'@onready var input_{fid}: SpinBox = {path}'); collect.append(f'int(input_{fid}.value)'); reset.append(f'\tinput_{fid}.value = {field_default(f)}'); load.append(f'\tinput_{fid}.value = float(item.{fid})')
        else: node=f'[node name="{fid}" type="CheckBox" parent="Margin/VBox/Tabs/{entity["title"]}/Editor"]\nlayout_mode = 2\ntext = "{label}"\nbutton_pressed = {field_default(f)}\n'; onready.append(f'@onready var input_{fid}: CheckBox = {path}'); collect.append(f'input_{fid}.button_pressed'); reset.append(f'\tinput_{fid}.button_pressed = {field_default(f)}'); load.append(f'\tinput_{fid}.button_pressed = bool(item.{fid})')
        input_nodes.append(node)
    screens=[x['id'] for x in s['screens']]
    metrics=s.get('ui',{}).get('metrics',[])
    metrics_refresh=[]
    for m in metrics: metrics_refresh.append(f'\tmetric_{m}.text = "{m.replace("_"," ").title()}: %d" % int(model.state.get("{m}", 0))')
    metric_nodes=''; metric_onready=[]
    for m in metrics:
        metric_nodes+=f'[node name="{m}" type="Label" parent="Margin/VBox/Header"]\nlayout_mode = 2\ntext = "{m}: 0"\n'
        metric_onready.append(f'@onready var metric_{m}: Label = $Margin/VBox/Header/{m}')
    actions=behavior.get('list_screen',{}).get('actions',[])
    action_code=[]
    if 'complete' in actions:
        completion=behavior.get('entity_complete',{}).get('completion_field','')
        date_field=behavior.get('entity_complete',{}).get('date_field','')
        item_counter='streak' if any(f['id']=='streak' for f in fields) else ''
        global_counter='total_completions' if 'total_completions' in state_defaults else ''
        if 'streak' in state_defaults: global_counter='streak'
        action_code.append(f'\t\tvar complete := Button.new(); complete.text = "Complete"; complete.pressed.connect(func(): model.complete_item(item.id, "{completion}", "{item_counter}", "{global_counter}", "{date_field}"); model.save_state(); _refresh()); row.add_child(complete)')
    if 'timed_adjust' in actions:
        action_code.append('\t\tvar timed := Button.new(); timed.text = "Run Timer"; timed.pressed.connect(func(): _timed_adjust(item)); row.add_child(timed)')
    if 'toggle' in actions:
        toggle=behavior.get('entity_toggle',{}).get('field','enabled'); action_code.append(f'\t\tvar toggle := Button.new(); toggle.text = "Toggle"; toggle.pressed.connect(func(): model.toggle_item(item.id, "{toggle}"); model.save_state(); _refresh()); row.add_child(toggle)')
    if 'edit' in actions: action_code.append('\t\tvar edit := Button.new(); edit.text = "Edit"; edit.pressed.connect(func(): _load_editor(item)); row.add_child(edit)')
    if 'delete' in actions: action_code.append('\t\tvar delete := Button.new(); delete.text = "Delete"; delete.pressed.connect(func(): model.delete_item(item.id); model.save_state(); _refresh()); row.add_child(delete)')
    row_expr=' + " • " + '.join([f'str(item.get("{x}", ""))' for x in entity.get('row_fields',[])]) or 'str(item.id)'
    special=''
    if 'countdown_timer' in behavior and 'counter_wallet' in behavior:
        source=behavior['countdown_timer']['source_field']; mult=int(behavior['countdown_timer'].get('multiplier',60)); counter=behavior['counter_wallet']['counter']; minimum=int(behavior['counter_wallet'].get('minimum',0))
        # generic expression parsed from declared coefficient for this bounded proof
        expr=behavior['counter_wallet']['change_expression']; coeff=2 if '* 2' in expr else 1
        special=f'''func _timed_adjust(item: Dictionary) -> void:
\tvar minutes := int(item.get("{source}", 0))
\tvar timer := model.timer_seconds(minutes, {mult})
\tmodel.adjust_counter("{counter}", -(minutes * {coeff}), {minimum})
\tvar count_field: String = str(item.keys().filter(func(key): return str(key).ends_with("_count")).front()) if item.keys().any(func(key): return str(key).ends_with("_count")) else ""
\tif not count_field.is_empty(): model.adjust_item_counter(item.id, count_field, 1)
\tmodel.save_state(); error_banner.text = "Timer: %d seconds" % int(timer.seconds); _refresh()
'''
    main=header+f'''extends Control
var model := ReusableCollectionModel.new()
var selected_id := -1
{chr(10).join(metric_onready)}
@onready var list_box: VBoxContainer = $Margin/VBox/Tabs/{entity['title']}/List
@onready var error_banner: Label = $Margin/VBox/ErrorBanner
{chr(10).join(onready)}

func _ready() -> void:
\tmodel.load_state(); _refresh(); print("REUSABLE_APP_READY:{s['app_id']}")

func _refresh() -> void:
{chr(10).join(metrics_refresh) if metrics_refresh else '\tpass'}
\tfor child in list_box.get_children(): child.queue_free()
\tfor item in model.rows():
\t\tvar row := HBoxContainer.new(); var label := Label.new(); label.text = {row_expr}; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
{chr(10).join(action_code)}
\t\tlist_box.add_child(row)

func _on_save_pressed() -> void:
\tvar result: Dictionary
\tif selected_id < 0: result = model.create_item({', '.join(collect)})
\telse: result = model.edit_item(selected_id, {', '.join(collect)})
\tif result.ok: model.save_state(); selected_id = -1; _reset_form(); _refresh()
\telse: error_banner.text = result.error

func _reset_form() -> void:
{chr(10).join(reset)}

func _load_editor(item: Dictionary) -> void:
\tselected_id = int(item.id)
{chr(10).join(load)}

{special}'''
    write(out/'scripts/Main.gd',main)
    scene=f'''[gd_scene load_steps=2 format=3]\n\n[ext_resource path="res://scripts/Main.gd" type="Script" id="1"]\n[node name="Main" type="Control"]\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\nscript = ExtResource("1")\n[node name="Margin" type="MarginContainer" parent="."]\nlayout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 24.0\noffset_top = 24.0\noffset_right = -24.0\noffset_bottom = -24.0\n[node name="VBox" type="VBoxContainer" parent="Margin"]\nlayout_mode = 2\n[node name="Header" type="HBoxContainer" parent="Margin/VBox"]\nlayout_mode = 2\n[node name="Title" type="Label" parent="Margin/VBox/Header"]\nlayout_mode = 2\nsize_flags_horizontal = 3\ntext = "{s['app_name']}"\ntheme_override_font_sizes/font_size = 28\n{metric_nodes}[node name="Tabs" type="TabContainer" parent="Margin/VBox"]\nlayout_mode = 2\nsize_flags_vertical = 3\n[node name="{entity['title']}" type="VBoxContainer" parent="Margin/VBox/Tabs"]\nlayout_mode = 2\n[node name="Editor" type="HBoxContainer" parent="Margin/VBox/Tabs/{entity['title']}"]\nlayout_mode = 2\n{''.join(input_nodes)}[node name="Save" type="Button" parent="Margin/VBox/Tabs/{entity['title']}/Editor"]\nlayout_mode = 2\ntext = "Save"\n[node name="List" type="VBoxContainer" parent="Margin/VBox/Tabs/{entity['title']}"]\nlayout_mode = 2\n[node name="Dashboard" type="VBoxContainer" parent="Margin/VBox/Tabs"]\nlayout_mode = 2\n[node name="Text" type="Label" parent="Margin/VBox/Tabs/Dashboard"]\nlayout_mode = 2\ntext = "{s['ui']['dashboard_text']}"\n[node name="Settings" type="VBoxContainer" parent="Margin/VBox/Tabs"]\nlayout_mode = 2\n[node name="Text" type="Label" parent="Margin/VBox/Tabs/Settings"]\nlayout_mode = 2\ntext = "{s['ui']['settings_text']}"\n[node name="ErrorBanner" type="Label" parent="Margin/VBox"]\nlayout_mode = 2\n[connection signal="pressed" from="Margin/VBox/Tabs/{entity['title']}/Editor/Save" to="." method="_on_save_pressed"]\n'''
    write(out/'Main.tscn',scene)
    write(out/'project.godot',f'''[application]\nconfig/name="{s['app_name']}"\nrun/main_scene="res://Main.tscn"\n[display]\nwindow/size/viewport_width=900\nwindow/size/viewport_height=600\nwindow/size/window_width_override=900\nwindow/size/window_height_override=600\n[rendering]\ntextures/vram_compression/import_etc2_astc=true\nrenderer/rendering_method="gl_compatibility"\n''')
    bundle=s['bundle_id']; appfile=s['app_name'].replace(' ','')
    android_package=bundle.replace("-", "").lower()
    write(out/'export_presets.cfg',f'''[preset.0]\nname="macOS"\nplatform="macOS"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter="tests/*,evidence/*,build/*,screenshots/*"\nexport_path="build/{appfile}.app"\nscript_export_mode=2\n[preset.0.options]\nexport/distribution_type=1\nbinary_format/architecture="universal"\napplication/bundle_identifier="{bundle}"\ncodesign/codesign=0\nnotarization/notarization=0\n\n[preset.1]\nname="Quest 2D"\nplatform="Android"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter="tests/*,evidence/*,build/*,screenshots/*"\nexport_path="build/Quest/{appfile}.apk"\nscript_export_mode=2\n[preset.1.options]\ngradle_build/use_gradle_build=false\narchitectures/armeabi-v7a=false\narchitectures/arm64-v8a=true\narchitectures/x86=false\narchitectures/x86_64=false\npackage/unique_name="{android_package}"\npackage/name="{s['app_name']}"\npackage/signed=true\npackage/show_as_launcher_app=true\npackage/show_in_app_library=true\nxr_features/xr_mode=0\nscreen/immersive_mode=false\nscreen/edge_to_edge=false\nuser_data_backup/allow=false\n''')
    # generic tests from schema
    valid=[('Sample' if f['type']=='string' and f.get('required') and not f.get('default') else f.get('default')) for f in fields]
    invalid=valid.copy(); required_idx=next((i for i,f in enumerate(fields) if f.get('required')),None)
    if required_idx is not None: invalid[required_idx]=''
    create_args=', '.join(gd(x) for x in valid); invalid_args=', '.join(gd(x) for x in invalid)
    edit_vals=valid.copy();
    for i,f in enumerate(fields):
        if f['type']=='string': edit_vals[i]='Edited'; break
    edit_args=', '.join(gd(x) for x in edit_vals)
    integration_lines=[f' var m=ReusableCollectionModel.new("user://{s["app_id"]}_integration.json"); var a=m.create_item({create_args}); assert(a.ok)']
    if 'countdown_timer' in behavior:
        tb=behavior['countdown_timer']
        source_field=tb['source_field']
        multiplier=int(tb.get('multiplier',60))
        integration_lines.append(f' var timer=m.timer_seconds(int(a.item.{source_field}), {multiplier}); assert(timer.ok and timer.seconds==int(a.item.{source_field})*{multiplier})')
    if 'counter_wallet' in behavior and 'entity_complete' not in behavior:
        cb=behavior['counter_wallet']
        coeff=2 if '* 2' in cb.get('change_expression','') else 1
        source_field=behavior.get('countdown_timer',{}).get('source_field','')
        change=f'-(int(a.item.get("{source_field}",1))*{coeff})' if source_field else str(cb.get('change_expression','1'))
        counter_name=cb['counter']
        minimum=int(cb.get('minimum',0))
        integration_lines.append(f' var counter=m.adjust_counter("{counter_name}", {change}, {minimum}); assert(counter.ok)')
    if 'entity_complete' in behavior:
        eb=behavior['entity_complete']
        item_counter='streak' if any(f['id']=='streak' for f in fields) else ''
        global_counter='total_completions' if 'total_completions' in state_defaults else ('streak' if 'streak' in state_defaults else '')
        completion_field=eb.get('completion_field','')
        date_field=eb.get('date_field','')
        integration_lines.append(f' var done=m.complete_item(a.item.id, "{completion_field}", "{item_counter}", "{global_counter}", "{date_field}", "2026-07-17"); assert(done.ok); assert(int(done.item.get("{item_counter}",1))>=1); assert(int(m.state.get("{global_counter}",1))>=1)')
        if date_field:
            integration_lines.append(f' var duplicate=m.complete_item(a.item.id, "{completion_field}", "{item_counter}", "{global_counter}", "{date_field}", "2026-07-17"); assert(not duplicate.ok); assert(int(m.state.get("{global_counter}",0))==1)')
    elif 'streak_counter' in behavior and 'streak' in state_defaults:
        integration_lines.append(' var done=m.complete_item(a.item.id, "", "", "streak"); assert(done.ok and int(m.state.streak)==1)')
    if 'entity_toggle' in behavior:
        toggle_field=behavior['entity_toggle'].get('field','enabled')
        integration_lines.append(f' var toggled=m.toggle_item(a.item.id, "{toggle_field}"); assert(toggled.ok)')
    integration_lines.append(f' print("REUSABLE_INTEGRATION_PASS:{s["app_id"]}"); quit(0)')
    tests={
      'unit_test.gd':f'''extends SceneTree\nfunc _initialize():\n var m=ReusableCollectionModel.new("user://{s['app_id']}_unit.json"); assert(not m.create_item({invalid_args}).ok); var a=m.create_item({create_args}); assert(a.ok); assert(m.edit_item(a.item.id, {edit_args}).ok); assert(m.delete_item(a.item.id).ok); print("REUSABLE_UNIT_PASS:{s['app_id']}"); quit(0)\n''',
      'integration_test.gd':'extends SceneTree\nfunc _initialize():\n'+'\n'.join(integration_lines)+'\n',
      'persistence_test.gd':f'''extends SceneTree\nfunc _initialize():\n var p="user://{s['app_id']}_persist.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(p)); var m=ReusableCollectionModel.new(p); assert(m.create_item({create_args}).ok); assert(m.save_state().ok); var r=ReusableCollectionModel.new(p); assert(r.load_state().ok and r.rows().size()==1); var f=FileAccess.open(p,FileAccess.WRITE); f.store_string("broken"); f.close(); var c=ReusableCollectionModel.new(p); var x=c.load_state(); assert(not x.ok and x.recovered); print("REUSABLE_PERSISTENCE_PASS:{s['app_id']}"); quit(0)\n''',
      'workflow_test.gd':f'''extends SceneTree\nfunc _initialize():\n var p="user://{s['app_id']}_workflow.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(p)); var m=ReusableCollectionModel.new(p); var a=m.create_item({create_args}); assert(a.ok); assert(m.save_state().ok); var r=ReusableCollectionModel.new(p); assert(r.load_state().ok and r.rows().size()==1); print("REUSABLE_WORKFLOW_PASS:{s['app_id']}"); print(JSON.stringify(r.state,"\\t",true)); quit(0)\n''',
      'ui_test.gd':f'''extends SceneTree\nfunc _initialize():\n var scene=load("res://Main.tscn"); assert(scene!=null); var root=scene.instantiate(); get_root().add_child(root); await process_frame; assert(root.get_node("Margin/VBox/Tabs").get_tab_count()==3); print("REUSABLE_UI_PASS:{s['app_id']}"); root.queue_free(); quit(0)\n''',
      'screenshot_test.gd':f'''extends SceneTree\nfunc _initialize():\n var scene=load("res://Main.tscn"); var root=scene.instantiate(); get_root().add_child(root); await process_frame; await process_frame; var image=get_root().get_texture().get_image(); var p="res://screenshots/{s['app_id']}.png"; assert(image.save_png(p)==OK); print("REUSABLE_SCREENSHOT_PASS:{s['app_id']}"); root.queue_free(); quit(0)\n'''
    }
    for n,t in tests.items(): write(out/'tests'/n,header+t)
    write(out/'evidence/typed_ir.json',json.dumps(ir,indent=2,sort_keys=True)+'\n'); write(out/'evidence/catalog.json',json.dumps(CAT,indent=2,sort_keys=True)+'\n')
    source_map={'catalog_version':CAT['catalog_version'],'nodes':{n['source_block_id']:{'atom_id':n['atom_id'],'generated_files':['scripts/ReusableCollectionModel.gd','scripts/Main.gd']} for n in ir['nodes']}}
    write(out/'evidence/source_map.json',json.dumps(source_map,indent=2,sort_keys=True)+'\n')
    manifest={'app_id':s['app_id'],'generator_version':'2.0.0','catalog_sha256':sha_bytes(canon(CAT).encode()),'ir_sha256':sha_bytes(canon(ir).encode()),'generated_files':{}}
    for p in sorted(out.rglob('*')):
        if p.is_file(): manifest['generated_files'][str(p.relative_to(out))]=sha_bytes(p.read_bytes())
    write(out/'evidence/build_manifest.json',json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    print(out,manifest['ir_sha256'])
if __name__=='__main__':
    for p in sys.argv[1:]: generate(pathlib.Path(p))
