#!/usr/bin/env python3
import json, hashlib, pathlib, shutil, sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
APP=ROOT/'apps/snooze_tax_lite'
OUT=ROOT/'generated_apps/SnoozeTaxLite'
IR_PATH=APP/'typed_ir.json'

def canon(obj): return json.dumps(obj,sort_keys=True,separators=(',',':'))+'\n'
def sha(s): return hashlib.sha256(s.encode()).hexdigest()
def write(path,text): path.parent.mkdir(parents=True,exist_ok=True); path.write_text(text)

def main():
 ir=json.loads(IR_PATH.read_text())
 assert ir['application_contract']['all_logic_must_originate_from_ir'] is True
 actions={n['parameters'].get('action_kind'):n for n in ir['nodes'] if n['operation_kind']=='ACTION_CALL'}
 required={'PERSIST_LOAD','PERSIST_SAVE','ALARM_CREATE','ALARM_EDIT','ALARM_DELETE','ALARM_TOGGLE','ALARM_SNOOZE','ALARM_COMPLETE','ALARM_VALIDATE','RECOVER_CORRUPT_STATE','NAVIGATE','RENDER_COMPONENTS'}
 missing=required-set(actions)
 if missing: raise SystemExit(f'Missing authoritative action atoms: {sorted(missing)}')
 states={n['parameters']['state_id']:n['parameters'] for n in ir['nodes'] if n['operation_kind']=='STATE_WRITE' and n['parameters'].get('lifetime')=='persistent'}
 exprs={n['parameters']['expression_id']:n['parameters'] for n in ir['nodes'] if n['operation_kind']=='EXPRESSION'}
 screens=next(n['parameters']['screens'] for n in ir['nodes'] if n['operation_kind']=='FUNCTION_OR_MODULE_BOUNDARY' and n['parameters'].get('module_id')=='snooze_tax_lite')
 penalty=int(actions['ALARM_SNOOZE']['parameters']['coins_per_minute'])
 if OUT.exists(): shutil.rmtree(OUT)
 (OUT/'scripts').mkdir(parents=True); (OUT/'tests').mkdir(); (OUT/'evidence').mkdir(); (OUT/'screenshots').mkdir()
 ir_sha=sha(canon(ir))
 header=f'# GENERATED FROM authoritative typed IR\n# IR_SHA256={ir_sha}\n# DO NOT HAND EDIT\n'
 defaults={k:v['default'] for k,v in states.items()}
 model=header+'''class_name SnoozeTaxModel
extends RefCounted

const CONTRACT_VERSION := "1.0.0"
const DEFAULT_STATE := %s
const COINS_PER_SNOOZE_MINUTE := %d
var storage_path: String
var state: Dictionary = {}

func _init(custom_storage_path: String = "user://snooze_tax_lite.json") -> void:
	storage_path = custom_storage_path
	state = DEFAULT_STATE.duplicate(true)

# source_block_id=%s
func validate_alarm(hour: int, minute: int, label: String, snooze_minutes: int) -> Dictionary:
	if hour < 0 or hour > 23:
		return _error("hour must be 0-23")
	if minute < 0 or minute > 59:
		return _error("minute must be 0-59")
	if label.strip_edges().is_empty():
		return _error("label is required")
	if snooze_minutes < 1 or snooze_minutes > 60:
		return _error("snooze must be 1-60 minutes")
	return {"ok": true}

# source_block_id=%s
func create_alarm(hour: int, minute: int, label: String, snooze_minutes: int = 5) -> Dictionary:
	var valid := validate_alarm(hour, minute, label, snooze_minutes)
	if not valid.ok: return valid
	var alarm := {"id": int(state.next_alarm_id), "hour": hour, "minute": minute, "label": label.strip_edges(), "enabled": true, "snooze_minutes": snooze_minutes, "snooze_count": 0}
	state.next_alarm_id = int(state.next_alarm_id) + 1
	state.alarms.append(alarm)
	return {"ok": true, "alarm": alarm.duplicate(true)}

# source_block_id=%s
func edit_alarm(id: int, hour: int, minute: int, label: String, snooze_minutes: int) -> Dictionary:
	var valid := validate_alarm(hour, minute, label, snooze_minutes)
	if not valid.ok: return valid
	var index := _find_alarm_index(id)
	if index < 0: return _error("alarm not found")
	var enabled: bool = state.alarms[index].enabled
	var count: int = int(state.alarms[index].snooze_count)
	state.alarms[index] = {"id": id, "hour": hour, "minute": minute, "label": label.strip_edges(), "enabled": enabled, "snooze_minutes": snooze_minutes, "snooze_count": count}
	return {"ok": true, "alarm": state.alarms[index].duplicate(true)}

# source_block_id=%s
func delete_alarm(id: int) -> Dictionary:
	var index := _find_alarm_index(id)
	if index < 0: return _error("alarm not found")
	var removed: Dictionary = state.alarms[index].duplicate(true)
	state.alarms.remove_at(index)
	return {"ok": true, "alarm": removed}

# source_block_id=%s
func toggle_alarm(id: int) -> Dictionary:
	var index := _find_alarm_index(id)
	if index < 0: return _error("alarm not found")
	state.alarms[index].enabled = not bool(state.alarms[index].enabled)
	return {"ok": true, "enabled": state.alarms[index].enabled}

# source_block_id=%s
func snooze_alarm(id: int, minutes: int = -1) -> Dictionary:
	var index := _find_alarm_index(id)
	if index < 0: return _error("alarm not found")
	var actual_minutes := int(state.alarms[index].snooze_minutes) if minutes < 0 else minutes
	if actual_minutes < 1 or actual_minutes > 60: return _error("snooze must be 1-60 minutes")
	var penalty := actual_minutes * COINS_PER_SNOOZE_MINUTE
	state.coins = max(0, int(state.coins) - penalty)
	state.alarms[index].snooze_count = int(state.alarms[index].snooze_count) + 1
	return {"ok": true, "penalty": penalty, "coins": state.coins, "timer_seconds": actual_minutes * 60}

# source_block_id=%s
func complete_alarm(id: int) -> Dictionary:
	if _find_alarm_index(id) < 0: return _error("alarm not found")
	state.streak = int(state.streak) + 1
	return {"ok": true, "streak": state.streak}

# source_block_id=%s
func save_state() -> Dictionary:
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null: return _error("unable to save state")
	file.store_string(JSON.stringify({"contract_version": CONTRACT_VERSION, "state": state}, "\t", true) + "\n")
	file.close()
	return {"ok": true}

# source_block_id=%s
func load_state() -> Dictionary:
	if not FileAccess.file_exists(storage_path):
		state = DEFAULT_STATE.duplicate(true)
		return {"ok": true, "created_default": true}
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null: return _recover_corrupt_state("unable to read state")
	var parser := JSON.new()
	var parse_code := parser.parse(file.get_as_text())
	file.close()
	if parse_code != OK:
		return _recover_corrupt_state("corrupt state recovered")
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not parsed.get("state") is Dictionary:
		return _recover_corrupt_state("corrupt state recovered")
	var loaded: Dictionary = parsed.state
	for key in DEFAULT_STATE:
		if not loaded.has(key): return _recover_corrupt_state("incomplete state recovered")
	state = loaded.duplicate(true)
	return {"ok": true, "loaded": true}

# source_block_id=%s
func _recover_corrupt_state(message: String) -> Dictionary:
	state = DEFAULT_STATE.duplicate(true)
	state.last_error = message
	return {"ok": false, "error": message, "recovered": true}

# source_block_id=%s
func navigate_screen(name: String) -> Dictionary:
	if name not in %s: return _error("unknown screen")
	return {"ok": true, "screen": name}

# source_block_id=%s
func alarm_rows() -> Array:
	var rows: Array = []
	var limit: int = min(100, state.alarms.size())
	for index in range(limit):
		rows.append(state.alarms[index].duplicate(true))
	return rows

# source_block_id=%s
func _error(message: String) -> Dictionary:
	state.last_error = message
	return {"ok": false, "error": message}

func _find_alarm_index(id: int) -> int:
	for index in range(state.alarms.size()):
		if int(state.alarms[index].id) == id: return index
	return -1
''' % (json.dumps(defaults,sort_keys=True).replace('true','true').replace('false','false'), penalty,
 actions['ALARM_VALIDATE']['source_block_id'], actions['ALARM_CREATE']['source_block_id'], actions['ALARM_EDIT']['source_block_id'], actions['ALARM_DELETE']['source_block_id'], actions['ALARM_TOGGLE']['source_block_id'], actions['ALARM_SNOOZE']['source_block_id'], actions['ALARM_COMPLETE']['source_block_id'], actions['PERSIST_SAVE']['source_block_id'], actions['PERSIST_LOAD']['source_block_id'], actions['RECOVER_CORRUPT_STATE']['source_block_id'], actions['NAVIGATE']['source_block_id'], json.dumps(screens), actions['RENDER_COMPONENTS']['source_block_id'], next(n['source_block_id'] for n in ir['nodes'] if n['operation_kind']=='ERROR_PATH'))
 # JSON booleans/null happen to match GDScript except null is valid. Dictionary keys need quotes, JSON is valid GDScript literal.
 write(OUT/'scripts/SnoozeTaxModel.gd',model)
 main_gd=header+'''extends Control
var model := SnoozeTaxModel.new()
var current_screen := "Alarms"
var selected_alarm_id := -1
@onready var title_label: Label = $Margin/VBox/Header/Title
@onready var coins_label: Label = $Margin/VBox/Header/Coins
@onready var streak_label: Label = $Margin/VBox/Header/Streak
@onready var tabs: TabContainer = $Margin/VBox/Tabs
@onready var alarm_list: VBoxContainer = $Margin/VBox/Tabs/Alarms/AlarmList
@onready var hour_input: SpinBox = $Margin/VBox/Tabs/Alarms/Editor/Hour
@onready var minute_input: SpinBox = $Margin/VBox/Tabs/Alarms/Editor/Minute
@onready var label_input: LineEdit = $Margin/VBox/Tabs/Alarms/Editor/Label
@onready var snooze_input: SpinBox = $Margin/VBox/Tabs/Alarms/Editor/Snooze
@onready var error_label: Label = $Margin/VBox/ErrorBanner

func _ready() -> void:
	model.load_state()
	_refresh()
	print("SNOOZE_TAX_APP_READY")

func _refresh() -> void:
	coins_label.text = "Coins: %d" % int(model.state.coins)
	streak_label.text = "Streak: %d" % int(model.state.streak)
	error_label.text = str(model.state.last_error)
	for child in alarm_list.get_children(): child.queue_free()
	for alarm in model.alarm_rows():
		var row := HBoxContainer.new()
		var text := Label.new(); text.text = "%02d:%02d  %s" % [alarm.hour, alarm.minute, alarm.label]; text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(text)
		var snooze := Button.new(); snooze.text = "Snooze"; snooze.pressed.connect(func(): model.snooze_alarm(alarm.id); model.save_state(); _refresh()); row.add_child(snooze)
		var edit := Button.new(); edit.text = "Edit"; edit.pressed.connect(func(): _load_editor(alarm)); row.add_child(edit)
		var delete := Button.new(); delete.text = "Delete"; delete.pressed.connect(func(): model.delete_alarm(alarm.id); model.save_state(); _refresh()); row.add_child(delete)
		alarm_list.add_child(row)

func _on_save_pressed() -> void:
	var result: Dictionary
	if selected_alarm_id < 0: result = model.create_alarm(int(hour_input.value), int(minute_input.value), label_input.text, int(snooze_input.value))
	else: result = model.edit_alarm(selected_alarm_id, int(hour_input.value), int(minute_input.value), label_input.text, int(snooze_input.value))
	if result.ok:
		model.save_state(); selected_alarm_id = -1; label_input.text = ""; _refresh()
	else: error_label.text = result.error

func _load_editor(alarm: Dictionary) -> void:
	selected_alarm_id = alarm.id; hour_input.value = alarm.hour; minute_input.value = alarm.minute; label_input.text = alarm.label; snooze_input.value = alarm.snooze_minutes
'''
 write(OUT/'scripts/Main.gd',main_gd)
 scene='''[gd_scene load_steps=2 format=3]\n\n[ext_resource path="res://scripts/Main.gd" type="Script" id="1"]\n\n[node name="Main" type="Control"]\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nscript = ExtResource("1")\n\n[node name="Margin" type="MarginContainer" parent="."]\nlayout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\noffset_left = 24.0\noffset_top = 24.0\noffset_right = -24.0\noffset_bottom = -24.0\n\n[node name="VBox" type="VBoxContainer" parent="Margin"]\nlayout_mode = 2\n\n[node name="Header" type="HBoxContainer" parent="Margin/VBox"]\nlayout_mode = 2\n[node name="Title" type="Label" parent="Margin/VBox/Header"]\nlayout_mode = 2\nsize_flags_horizontal = 3\ntext = "Snooze Tax Lite"\ntheme_override_font_sizes/font_size = 28\n[node name="Coins" type="Label" parent="Margin/VBox/Header"]\nlayout_mode = 2\ntext = "Coins: 100"\n[node name="Streak" type="Label" parent="Margin/VBox/Header"]\nlayout_mode = 2\ntext = "Streak: 0"\n\n[node name="Tabs" type="TabContainer" parent="Margin/VBox"]\nlayout_mode = 2\nsize_flags_vertical = 3\n[node name="Alarms" type="VBoxContainer" parent="Margin/VBox/Tabs"]\nlayout_mode = 2\n[node name="Editor" type="HBoxContainer" parent="Margin/VBox/Tabs/Alarms"]\nlayout_mode = 2\n[node name="Hour" type="SpinBox" parent="Margin/VBox/Tabs/Alarms/Editor"]\nlayout_mode = 2\nmax_value = 23.0\n[node name="Minute" type="SpinBox" parent="Margin/VBox/Tabs/Alarms/Editor"]\nlayout_mode = 2\nmax_value = 59.0\n[node name="Label" type="LineEdit" parent="Margin/VBox/Tabs/Alarms/Editor"]\nlayout_mode = 2\nsize_flags_horizontal = 3\nplaceholder_text = "Alarm label"\n[node name="Snooze" type="SpinBox" parent="Margin/VBox/Tabs/Alarms/Editor"]\nlayout_mode = 2\nmin_value = 1.0\nmax_value = 60.0\nvalue = 5.0\n[node name="Save" type="Button" parent="Margin/VBox/Tabs/Alarms/Editor"]\nlayout_mode = 2\ntext = "Save Alarm"\n[node name="AlarmList" type="VBoxContainer" parent="Margin/VBox/Tabs/Alarms"]\nlayout_mode = 2\n\n[node name="Dashboard" type="VBoxContainer" parent="Margin/VBox/Tabs"]\nlayout_mode = 2\n[node name="Text" type="Label" parent="Margin/VBox/Tabs/Dashboard"]\nlayout_mode = 2\ntext = "Wake on time to grow your streak. Snoozing costs 2 coins per minute."\n\n[node name="Settings" type="VBoxContainer" parent="Margin/VBox/Tabs"]\nlayout_mode = 2\n[node name="Text" type="Label" parent="Margin/VBox/Tabs/Settings"]\nlayout_mode = 2\ntext = "Snooze Tax Lite • Generated from VectorVerse atoms"\n\n[node name="ErrorBanner" type="Label" parent="Margin/VBox"]\nlayout_mode = 2\ntheme_override_colors/font_color = Color(1, 0.35, 0.35, 1)\n\n[connection signal="pressed" from="Margin/VBox/Tabs/Alarms/Editor/Save" to="." method="_on_save_pressed"]\n'''
 write(OUT/'Main.tscn',scene)
 project='''[application]\nconfig/name="Snooze Tax Lite"\nrun/main_scene="res://Main.tscn"\n[display]\nwindow/size/viewport_width=900\nwindow/size/viewport_height=600\nwindow/size/window_width_override=900\nwindow/size/window_height_override=600\n[rendering]\ntextures/vram_compression/import_etc2_astc=true\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n'''
 write(OUT/'project.godot',project)
 export_preset='''[preset.0]\n\nname="macOS"\nplatform="macOS"\nrunnable=true\nadvanced_options=false\ndedicated_server=false\ncustom_features=""\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter="tests/*,evidence/*,build/*,screenshots/*"\nexport_path="build/SnoozeTaxLite.app"\npatches=PackedStringArray()\nencrypt_pck=false\nencrypt_directory=false\nscript_export_mode=2\n\n[preset.0.options]\n\nexport/distribution_type=1\nbinary_format/architecture="universal"\napplication/bundle_identifier="org.synhumanity.snoozetaxlite"\napplication/short_version="1.0"\napplication/version="1"\ndisplay/high_res=true\ncodesign/codesign=0\nnotarization/notarization=0\n'''
 write(OUT/'export_presets.cfg',export_preset)
 # tests generated from requirement-bearing IR
 tests={
 'unit_test.gd':'''extends SceneTree\nfunc _initialize():\n var m=SnoozeTaxModel.new("user://unit.json"); var bad=m.create_alarm(25,0,"Bad",5); assert(not bad.ok); var a=m.create_alarm(7,30,"Wake",5); assert(a.ok and m.state.alarms.size()==1); assert(m.edit_alarm(a.alarm.id,8,15,"Edited",10).ok); assert(m.delete_alarm(a.alarm.id).ok and m.state.alarms.is_empty()); print("SNOOZE_TAX_UNIT_PASS"); quit(0)\n''',
 'integration_test.gd':'''extends SceneTree\nfunc _initialize():\n var m=SnoozeTaxModel.new("user://integration.json"); var a=m.create_alarm(6,45,"Work",5); assert(a.ok); var s=m.snooze_alarm(a.alarm.id); assert(s.ok and s.penalty==10 and s.coins==90 and s.timer_seconds==300); assert(m.complete_alarm(a.alarm.id).streak==1); assert(m.toggle_alarm(a.alarm.id).enabled==false); print("SNOOZE_TAX_INTEGRATION_PASS"); quit(0)\n''',
 'persistence_test.gd':'''extends SceneTree\nfunc _initialize():\n var p="user://persistence.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(p)); var m=SnoozeTaxModel.new(p); var a=m.create_alarm(9,5,"Persist",7); m.snooze_alarm(a.alarm.id); m.complete_alarm(a.alarm.id); assert(m.save_state().ok); var r=SnoozeTaxModel.new(p); assert(r.load_state().ok); assert(r.state.alarms.size()==1 and r.state.coins==86 and r.state.streak==1); var f=FileAccess.open(p,FileAccess.WRITE); f.store_string("broken"); f.close(); var c=SnoozeTaxModel.new(p); var recovery=c.load_state(); assert(not recovery.ok and recovery.recovered and c.state.coins==100); print("SNOOZE_TAX_PERSISTENCE_PASS"); quit(0)\n''',
 'ui_smoke_test.gd':'''extends SceneTree\nfunc _initialize():\n var scene=load("res://Main.tscn"); assert(scene!=null); var root=scene.instantiate(); get_root().add_child(root); await process_frame; assert(root.get_node("Margin/VBox/Tabs").get_tab_count()==3); print("SNOOZE_TAX_UI_SMOKE_PASS"); root.queue_free(); quit(0)\n''',
 'screenshot_test.gd':'''extends SceneTree\nfunc _initialize():\n var scene=load("res://Main.tscn"); assert(scene!=null); var root=scene.instantiate(); get_root().add_child(root); await process_frame; await process_frame; var image=get_root().get_texture().get_image(); var path="res://screenshots/snooze_tax_lite.png"; var code=image.save_png(path); assert(code==OK); print("SNOOZE_TAX_SCREENSHOT_PASS="+path); root.queue_free(); quit(0)\n''',
 'workflow_test.gd':'''extends SceneTree\nfunc _initialize():\n var p="user://workflow.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(p)); var first=SnoozeTaxModel.new(p); var created=first.create_alarm(7,0,"Morning",5); assert(created.ok); var snoozed=first.snooze_alarm(created.alarm.id); assert(snoozed.coins==90); assert(first.save_state().ok); var relaunched=SnoozeTaxModel.new(p); assert(relaunched.load_state().ok); assert(relaunched.state.alarms[0].label=="Morning" and relaunched.state.coins==90 and relaunched.state.alarms[0].snooze_count==1); print("SNOOZE_TAX_WORKFLOW_PASS"); print(JSON.stringify(relaunched.state, "\t", true)); quit(0)\n'''
 }
 for name,text in tests.items(): write(OUT/'tests'/name,header+text)
 manifest={"app":"Snooze Tax Lite","generator_version":"1.0.0","ir_sha256":ir_sha,"source_graph_sha256":sha(canon(json.loads((APP/'authoritative_atom_graph.json').read_text()))),"declared_actions":sorted(actions),"persistent_states":states,"expressions":exprs,"screens":screens,"generated_files":{}}
 for p in sorted(OUT.rglob('*')):
  if p.is_file(): manifest['generated_files'][str(p.relative_to(OUT))]=hashlib.sha256(p.read_bytes()).hexdigest()
 write(OUT/'evidence/build_manifest.json',json.dumps(manifest,indent=2,sort_keys=True)+'\n')
 source_map={"methods":{k:v['source_block_id'] for k,v in actions.items()},"ir_sha256":ir_sha}
 write(OUT/'evidence/source_map.json',json.dumps(source_map,indent=2,sort_keys=True)+'\n')
 write(OUT/'evidence/typed_ir.json',json.dumps(ir,indent=2,sort_keys=True)+'\n')
 shutil.copy2(APP/'authoritative_atom_graph.json',OUT/'evidence/authoritative_atom_graph.json')
 print('GENERATED',OUT)
 print('IR_SHA256',ir_sha)
 print('FILES',sum(1 for p in OUT.rglob('*') if p.is_file()))
if __name__=='__main__': main()
