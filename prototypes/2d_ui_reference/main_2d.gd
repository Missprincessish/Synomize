# Reference-only flat prototype. The authoritative product scene is spatial 3D.
extends Control

const GREEN := Color("24ff9a")
const CYAN := Color("41dfff")
const MUTED := Color("7ca7ad")

var graph := VectorVerseVisualGraph.new()
var graph_row: HBoxContainer
var choices_row: HBoxContainer
var status_label: Label
var explanation_label: Label
var code_view: CodeEdit
var family_strip: HBoxContainer
var morphing_panel: VectorVerseMorphingPanel2DReference
var generate_button: Button
var compatible_after_start: Array[String] = []

func _ready() -> void:
	_build_interface()
	_refresh()

func _build_interface() -> void:
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 54)
	outer.add_theme_constant_override("margin_right", 54)
	outer.add_theme_constant_override("margin_top", 42)
	outer.add_theme_constant_override("margin_bottom", 42)
	add_child(outer)

	morphing_panel = VectorVerseMorphingPanel2DReference.new()
	morphing_panel.set_mode("idle")
	outer.add_child(morphing_panel)

	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 28)
	morphing_panel.add_child(inset)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	inset.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "VECTORVERSE // CONSTRUCTION CORE"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GREEN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	status_label = Label.new()
	status_label.text = "SYSTEM READY"
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", CYAN)
	header.add_child(status_label)

	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", GREEN)
	column.add_child(rule)

	var subtitle := Label.new()
	subtitle.text = "HUGE BLACK MORPHING WORKSPACE  •  DETERMINISTIC GDSCRIPT CORE"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", MUTED)
	column.add_child(subtitle)

	family_strip = HBoxContainer.new()
	family_strip.add_theme_constant_override("separation", 8)
	column.add_child(family_strip)
	for family in VectorVerseAtomCatalog.families():
		var chip := Label.new()
		chip.text = "  " + family.to_upper() + "  "
		chip.add_theme_font_size_override("font_size", 12)
		chip.add_theme_color_override("font_color", GREEN if family in ["Event", "Action"] else MUTED)
		chip.add_theme_stylebox_override("normal", _panel_style(Color("071216"), GREEN if family in ["Event", "Action"] else Color("214047"), 1, 6))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		family_strip.add_child(chip)

	column.add_child(_section_label("01  VISUAL GRAPH"))
	graph_row = HBoxContainer.new()
	graph_row.custom_minimum_size.y = 112
	graph_row.alignment = BoxContainer.ALIGNMENT_CENTER
	graph_row.add_theme_constant_override("separation", 18)
	column.add_child(graph_row)

	column.add_child(_section_label("02  COMPATIBLE NEXT CHOICES"))
	choices_row = HBoxContainer.new()
	choices_row.custom_minimum_size.y = 82
	choices_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choices_row.add_theme_constant_override("separation", 18)
	column.add_child(choices_row)

	explanation_label = Label.new()
	explanation_label.text = "Select the first compatible atom."
	explanation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation_label.add_theme_font_size_override("font_size", 16)
	explanation_label.add_theme_color_override("font_color", CYAN)
	column.add_child(explanation_label)

	var lower := HSplitContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.split_offset = 560
	column.add_child(lower)

	code_view = CodeEdit.new()
	code_view.editable = false
	code_view.custom_minimum_size = Vector2(560, 205)
	code_view.add_theme_font_size_override("font_size", 15)
	code_view.add_theme_color_override("font_color", Color("bafee1"))
	code_view.add_theme_color_override("background_color", Color("020608"))
	lower.add_child(code_view)

	var action_panel := VBoxContainer.new()
	action_panel.add_theme_constant_override("separation", 12)
	lower.add_child(action_panel)
	var output_title := _section_label("VALIDATION OUTPUT")
	action_panel.add_child(output_title)
	var note := Label.new()
	note.text = "Generated file\nres://generated/app_start_display_message.gd\n\nEvidence\nres://evidence/validation_evidence.json"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", MUTED)
	note.add_theme_font_size_override("font_size", 14)
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_panel.add_child(note)
	generate_button = Button.new()
	generate_button.text = "GENERATE  •  VALIDATE  •  RUN"
	generate_button.disabled = true
	generate_button.add_theme_stylebox_override("normal", _panel_style(Color("082019"), GREEN, 2, 8))
	generate_button.add_theme_stylebox_override("hover", _panel_style(Color("0b3026"), CYAN, 3, 8))
	generate_button.add_theme_stylebox_override("disabled", _panel_style(Color("050b0d"), Color("214047"), 1, 8))
	generate_button.add_theme_color_override("font_color", GREEN)
	generate_button.add_theme_color_override("font_disabled_color", MUTED)
	generate_button.pressed.connect(_generate_validate_run)
	action_panel.add_child(generate_button)
	var reset := Button.new()
	reset.text = "RESET VERTICAL SLICE"
	reset.add_theme_stylebox_override("normal", _panel_style(Color("081418"), CYAN, 2, 8))
	reset.add_theme_color_override("font_color", CYAN)
	reset.pressed.connect(_reset_graph)
	action_panel.add_child(reset)
func _insert_atom(atom_id: String) -> void:
	if graph.insert_atom(atom_id):
		var definition := VectorVerseAtomCatalog.atom(atom_id)
		explanation_label.text = definition.explanation
		if atom_id == "app_start":
			compatible_after_start = VectorVerseAtomCatalog.compatible_choices(graph.atom_ids)
			morphing_panel.set_mode("routing")
		else:
			morphing_panel.set_mode("compiled")
		status_label.text = "GRAPH READY // PRESS GENERATE" if graph.atom_ids == ["app_start", "display_message"] else "ATOM INSERTED // " + definition.display_name
		get_node("TechBackdrop").pulse_morph()
		_refresh()

func _generate_validate_run() -> void:
	var evidence := VectorVerseVerticalSliceValidator.validate_and_save(graph, compatible_after_start)
	code_view.text = VectorVerseGDScriptAdapter.generate(graph)
	if evidence.accepted:
		morphing_panel.set_mode("verified")
		status_label.text = "ACCEPTED // PARSED // RUNTIME VERIFIED"
		explanation_label.text = "Your visual program compiled and ran: Hello, Synomize!"
	else:
		status_label.text = "VALIDATION FAILED"
		explanation_label.text = str(evidence.errors)

func _reset_graph() -> void:
	graph.reset()
	compatible_after_start.clear()
	code_view.text = ""
	status_label.text = "SYSTEM READY"
	morphing_panel.set_mode("idle")
	explanation_label.text = "Select the first compatible atom."
	get_node("TechBackdrop").pulse_morph()
	_refresh()

func _refresh() -> void:
	_clear(graph_row)
	_clear(choices_row)

	if graph.atom_ids.is_empty():
		var empty := Label.new()
		empty.text = "[ EMPTY GRAPH ]"
		empty.add_theme_color_override("font_color", MUTED)
		graph_row.add_child(empty)
	else:
		for index in graph.atom_ids.size():
			if index > 0:
				var edge := Label.new()
				edge.text = "━━▶"
				edge.add_theme_color_override("font_color", GREEN)
				edge.add_theme_font_size_override("font_size", 22)
				graph_row.add_child(edge)
			graph_row.add_child(_atom_card(graph.atom_ids[index]))

	var choices := VectorVerseAtomCatalog.compatible_choices(graph.atom_ids)
	generate_button.disabled = graph.atom_ids != ["app_start", "display_message"]
	if choices.is_empty():
		var complete := Label.new()
		complete.text = "SEQUENCE COMPLETE // READY TO GENERATE"
		complete.add_theme_color_override("font_color", GREEN)
		choices_row.add_child(complete)
	else:
		for atom_id in choices:
			var choice := Button.new()
			var definition := VectorVerseAtomCatalog.atom(atom_id)
			choice.text = definition.shape.to_upper() + "  //  " + definition.display_name
			choice.custom_minimum_size = Vector2(330, 58)
			choice.add_theme_font_size_override("font_size", 15)
			choice.add_theme_color_override("font_color", Color("d7fff0"))
			choice.add_theme_stylebox_override("normal", _panel_style(Color("071519"), GREEN, 2, 10))
			choice.add_theme_stylebox_override("hover", _panel_style(Color("0b2a25"), CYAN, 3, 10))
			choice.pressed.connect(_insert_atom.bind(atom_id))
			choices_row.add_child(choice)

	choices_row.modulate.a = 0.0
	choices_row.scale = Vector2(0.94, 0.94)
	choices_row.pivot_offset = choices_row.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(choices_row, "modulate:a", 1.0, 0.32)
	tween.tween_property(choices_row, "scale", Vector2.ONE, 0.32)

func _atom_card(atom_id: String) -> PanelContainer:
	var definition := VectorVerseAtomCatalog.atom(atom_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(310, 92)
	card.add_theme_stylebox_override("panel", _panel_style(Color("071116"), GREEN, 2, 14))
	var text := Label.new()
	text.text = definition.shape.to_upper() + " SOCKET\n" + definition.family.to_upper() + " // " + definition.display_name
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Color("d2ffeb"))
	card.add_child(text)
	return card

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GREEN)
	return label

func _panel_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border, 0.18)
	style.shadow_size = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()
