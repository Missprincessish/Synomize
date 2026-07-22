class_name VectorVerseSpatialWorld
extends Node3D

signal block_placed(stage: int)

const GREEN := Color("24ff9a")
const CYAN := Color("41dfff")
const BLACK := Color("020507")
const EVENT_SOCKET_TARGET := Vector3(0.0, 3.47, 0.52)
const ACTION_SOCKET_TARGET := Vector3(2.25, 3.47, 0.52)
const DRAG_PLANE_Z := 0.72
const DRAG_THRESHOLD_PIXELS := 8.0
const SOCKET_SNAP_DISTANCE := 1.35
const MAGNETIC_DISTANCE := 0.95
const KID_PLACEMENT_TARGETS := [
	Vector3(-2.8, 4.3, 0.52), Vector3(0.0, 4.3, 0.52), Vector3(2.8, 4.3, 0.52),
	Vector3(2.8, 2.7, 0.52), Vector3(0.0, 2.7, 0.52), Vector3(-2.8, 2.7, 0.52),
	Vector3(0.0, 3.5, 0.52)
]

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var environment_node: WorldEnvironment = $WorldEnvironment
@onready var star_field: Node3D = $StarField
@onready var lighting: Node3D = $Lighting
@onready var floor_root: Node3D = $PolishedBlackFloor
@onready var circuit_root: Node3D = $CircuitPathways
@onready var panel_root: Node3D = $ConstructionPanel
@onready var staging_root: Node3D = $AtomStagingArea

var graph := VectorVerseVisualGraph.new()
var compatible_after_start: Array[String] = []
var app_start_atom: VectorVerseSpatialAtom
var display_message_atom: VectorVerseSpatialAtom
var panel_body: MeshInstance3D
var left_wing: MeshInstance3D
var right_wing: MeshInstance3D
var action_socket: Node3D
var generate_control: Area3D
var status_text: Label3D
var explanation_text: Label3D
var code_text: Label3D
var hovered_area: Area3D
var grabbed_atom: VectorVerseSpatialAtom
var grab_origin := Vector3.ZERO
var grab_start_screen := Vector2.ZERO
var grab_moved := false
var visual_time := 0.0
var nebula_layers: Array[MeshInstance3D] = []
var floating_particles: Array[MeshInstance3D] = []
var circuit_materials: Array[StandardMaterial3D] = []
var panel_glass: MeshInstance3D
var panel_halo: MeshInstance3D
var approved_blender_visuals: Node3D
var success_panel: Node3D
var success_heading: Label3D
var completion_actions: Node3D
var celebration_root: Node3D
var tier_one_palette: Node3D
var kid_flow: Array[Dictionary] = []
var kid_atoms: Array[VectorVerseSpatialAtom] = []
var kid_step := 0
var kid_path_complete := false
var kid_socket: Node3D
var star_buddy_preview: Node3D
var star_buddy_score_text: Label3D
var star_collected := false
var active_path := ""
var path_menu: Node3D
var export_panel: Node3D
var export_options: Node3D
var export_status: Label3D
var language_index := 0
var style_index := 0
var inventory_types: Dictionary = {}
var inventory_panel: Node3D
var inventory_cards: Node3D
var adult_preview: Node3D
var adult_task_labels: Array[Label3D] = []
var left_rail: Node3D
var right_rail: Node3D
var recent_choice_labels: Array[Label3D] = []
var progress_text: Label3D
var progress_segments: Array[MeshInstance3D] = []
var settings_panel: Node3D
var sound_enabled := true
var glow_enabled := true
var inventory_returns_to_path := false
const EXPORT_LANGUAGES := ["Godot GDScript", "Python", "C#", "JavaScript", "C++", "Swift", "Rust"]
const EXPORT_STYLES := ["Clean", "Playful", "Futuristic"]
const INVENTORY_PATH := "user://synomize_unique_inventory.json"
var socket_materials: Dictionary = {}
var socket_particles: Dictionary = {}
var instruction_before_grab := "Drop START Here"

func _ready() -> void:
	_build_environment()
	_build_floor_and_circuits()
	_build_panel()
	_build_visual_polish()
	_build_approved_blender_visuals()
	_build_atoms()
	_update_spatial_state()
	_load_unique_inventory()
	_show_path_menu()
	_activate_floor_strikes()
	_run_packaged_phase5_condition_proof()
	_run_packaged_phase6_state_proof()

func _build_environment() -> void:
	var environment := Environment.new()
	var panorama_texture := load("res://assets/skybox/alien_galaxy_panorama_4k.jpg") as Texture2D
	if panorama_texture != null:
		var panorama_material := PanoramaSkyMaterial.new()
		panorama_material.panorama = panorama_texture
		panorama_material.energy_multiplier = 0.72
		var sky := Sky.new()
		sky.sky_material = panorama_material
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		environment.sky = sky
		environment.background_mode = Environment.BG_SKY
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("010209")
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if panorama_texture != null else Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("183044")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.42
	environment.glow_strength = 1.22
	environment.glow_bloom = 0.26
	environment.fog_enabled = true
	environment.fog_light_color = Color("10213a")
	environment.fog_light_energy = 0.22
	environment.fog_density = 0.004
	environment_node.environment = environment

	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.022
	star_mesh.height = 0.044
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	var star_material := _emissive_material(Color("bdeaff"), 4.2, false)
	star_mesh.material = star_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = 150
	multimesh.mesh = star_mesh
	for index in multimesh.instance_count:
		var x := sin(float(index) * 12.9898) * 15.0
		var y := 1.0 + fmod(float(index * 47), 100.0) * 0.085
		var z := -3.0 - fmod(float(index * 31), 100.0) * 0.14
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, y, z)))
	var stars := MultiMeshInstance3D.new()
	stars.name = "GalaxyStars"
	stars.multimesh = multimesh
	star_field.add_child(stars)

	var key := DirectionalLight3D.new()
	key.name = "MoonKeyLight"
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_color = Color("8ab7d6")
	key.light_energy = 1.2
	key.shadow_enabled = true
	lighting.add_child(key)
	for light_data in [[Vector3(-5.0, 4.0, 5.0), GREEN], [Vector3(5.0, 3.0, 4.0), CYAN]]:
		var light := OmniLight3D.new()
		light.position = light_data[0]
		light.light_color = light_data[1]
		light.light_energy = 6.0
		light.omni_range = 8.0
		lighting.add_child(light)

func _build_floor_and_circuits() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(30.0, 30.0)
	var floor := MeshInstance3D.new()
	floor.name = "ReflectiveFloorSurface"
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("05070a")
	floor_material.metallic = 0.94
	floor_material.roughness = 0.12
	floor.material_override = floor_material
	floor_root.add_child(floor)

	for index in 11:
		var x := -7.5 + index * 1.5
		var rail_material := _emissive_material(GREEN if index % 2 == 0 else CYAN, 3.2, false)
		circuit_materials.append(rail_material)
		var rail := _box_mesh(Vector3(0.025, 0.014, 8.0), rail_material)
		rail.position = Vector3(x, 0.018, -0.5 - absf(x) * 0.18)
		circuit_root.add_child(rail)
	for side in [-1.0, 1.0]:
		for index in 5:
			var cross_material := _emissive_material(CYAN, 2.5, false)
			circuit_materials.append(cross_material)
			var cross_rail := _box_mesh(Vector3(2.2 + index * 0.45, 0.012, 0.025), cross_material)
			cross_rail.position = Vector3(side * (4.6 + index * 0.25), 0.02, 1.0 - index * 1.35)
			circuit_root.add_child(cross_rail)

func _build_approved_blender_visuals() -> void:
	var approved_scene := load("res://assets/approved/Synomize_Blender_Direct_v2.glb") as PackedScene
	if approved_scene == null:
		push_error("Approved Synomize Blender visual scene could not be loaded")
		return
	approved_blender_visuals = approved_scene.instantiate()
	approved_blender_visuals.name = "ApprovedBlenderDirectV2Visuals"
	add_child(approved_blender_visuals)
	_hide_procedural_visual_meshes(floor_root)
	_hide_procedural_visual_meshes(panel_root)
	_build_floor_reflections()

func _hide_procedural_visual_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and not _has_interaction_ancestor(child):
			(child as MeshInstance3D).visible = false
		_hide_procedural_visual_meshes(child)

func _has_interaction_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is Area3D:
			return true
		current = current.get_parent()
	return false

func _build_floor_reflections() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "FloorReflectionProbe"
	probe.position = Vector3(0.0, 1.7, 0.0)
	probe.size = Vector3(22.0, 7.0, 22.0)
	probe.origin_offset = Vector3(0.0, 1.2, 0.0)
	probe.box_projection = true
	probe.intensity = 1.35
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)

func _build_panel() -> void:
	panel_root.position = Vector3(0.0, 3.25, 0.0)
	panel_body = _box_mesh(Vector3(10.2, 5.45, 0.34), _panel_core_material())
	panel_body.name = "PhysicalBlackPanel"
	panel_root.add_child(panel_body)

	left_wing = _box_mesh(Vector3(0.9, 4.55, 0.28), _emissive_material(GREEN, 3.2, false))
	left_wing.name = "LeftMorphWing"
	left_wing.position = Vector3(-5.32, 0.0, 0.0)
	left_wing.scale.x = 0.05
	panel_root.add_child(left_wing)
	right_wing = _box_mesh(Vector3(0.9, 4.55, 0.28), _emissive_material(Color("00d8ff"), 3.8, false))
	right_wing.name = "RightMorphWing"
	right_wing.position.x = 5.32
	panel_root.add_child(right_wing)

	_build_neon_frame()
	status_text = _label3d("SYNOMIZE\nVisual Software Builder", Vector3(0.0, 2.04, 0.42), 64, Color.WHITE)
	status_text.name = "StatusText"
	panel_root.add_child(status_text)
	explanation_text = _label3d("Drop START Here", Vector3(0.0, -1.55, 0.42), 54, CYAN)
	explanation_text.name = "ExplanationText"
	panel_root.add_child(explanation_text)
	code_text = _label3d("", Vector3(0.0, -2.15, 0.25), 34, Color("6f9da7"))
	code_text.name = "GeneratedCodeText"
	code_text.visible = false
	panel_root.add_child(code_text)
	_build_success_panel()

	kid_socket = _create_socket("EventSocket3D", Vector3(0.0, 0.22, 0.26), 5, GREEN, true)
	action_socket = _create_socket("ActionSocket3D", Vector3(2.25, 0.22, 0.26), 3, CYAN, false)
	generate_control = _create_generate_control()
	_build_path_menu()
	_build_export_panel()
	_build_workspace_side_rails()
	_build_settings_panel()

func _build_success_panel() -> void:
	success_panel = Node3D.new()
	success_panel.name = "ProjectCelebration"
	success_panel.position = Vector3(0.0, -0.12, 0.62)
	panel_root.add_child(success_panel)

	success_heading = _label3d("You created \"Hello World\"", Vector3(0.0, 1.42, 0.14), 72, Color.WHITE)
	success_heading.name = "SuccessHeading"
	success_panel.add_child(success_heading)

	completion_actions = Node3D.new()
	completion_actions.name = "CompletionActions"
	_create_ui_button(completion_actions, "continue_building", "PLAY AGAIN", Vector3(-2.6, -0.25, 0.18), Vector3(2.2, 0.66, 0.12), CYAN)
	_create_ui_button(completion_actions, "open_export", "KEEP / EXPORT", Vector3(0.0, -0.25, 0.18), Vector3(2.45, 0.66, 0.12), Color("ffd45c"))
	_create_ui_button(completion_actions, "create_new", "MAIN MENU", Vector3(2.6, -0.25, 0.18), Vector3(2.2, 0.66, 0.12), GREEN)
	success_panel.add_child(completion_actions)

	celebration_root = Node3D.new()
	celebration_root.name = "CelebrationFireworksAndMist"
	success_panel.add_child(celebration_root)

	success_panel.visible = false

func _build_path_menu() -> void:
	path_menu = Node3D.new()
	path_menu.name = "QuickStartMenu"
	path_menu.position = Vector3(0.0, 0.0, 0.72)
	panel_root.add_child(path_menu)
	path_menu.add_child(_label3d("HOW DO YOU WANT TO START?", Vector3(0.0, 1.72, 0.12), 54, Color.WHITE))
	var scratch := _create_ui_button(path_menu, "path_scratch", "START FROM SCRATCH", Vector3(0.0, 0.72, 0.12), Vector3(5.8, 0.72, 0.12), GREEN)
	scratch.set_meta("choice_description", "Build a first Hello World creation one step at a time")
	var adult := _create_ui_button(path_menu, "path_adult", "EVERYDAY APPS", Vector3(-1.65, -0.28, 0.12), Vector3(2.8, 0.72, 0.12), CYAN)
	adult.set_meta("choice_description", "Build a useful daily checklist")
	var kids := _create_ui_button(path_menu, "path_kids", "MINI GAMES", Vector3(1.65, -0.28, 0.12), Vector3(2.8, 0.72, 0.12), Color("ff6bc4"))
	kids.set_meta("choice_description", "Build and play Star Buddy Adventure")
	var gallery := _create_ui_button(path_menu, "open_inventory", "MY CREATIONS", Vector3(0.0, -1.28, 0.12), Vector3(3.2, 0.58, 0.12), Color("6ea8ff"))
	gallery.set_meta("choice_description", "Reuse any creation type you have already made")
	path_menu.visible = false
	inventory_panel = Node3D.new()
	inventory_panel.name = "UniqueCreationInventory"
	inventory_panel.position = path_menu.position
	panel_root.add_child(inventory_panel)
	inventory_panel.add_child(_label3d("MY CREATIONS", Vector3(0.0, 1.72, 0.12), 54, Color.WHITE))
	_create_ui_button(inventory_panel, "close_inventory", "BACK", Vector3(-4.0, 1.72, 0.12), Vector3(1.25, 0.48, 0.1), CYAN)
	inventory_cards = Node3D.new()
	inventory_panel.add_child(inventory_cards)
	inventory_panel.visible = false
	_set_area_interactive(inventory_panel, false)

func _build_export_panel() -> void:
	export_panel = Node3D.new()
	export_panel.name = "ProtectedExportChoices"
	export_panel.position = Vector3(0.0, 0.0, 0.78)
	panel_root.add_child(export_panel)
	export_panel.add_child(_label3d("KEEP YOUR CREATION", Vector3(0.0, 1.72, 0.12), 54, Color.WHITE))
	export_options = Node3D.new()
	export_panel.add_child(export_options)
	_create_ui_button(export_options, "export_gallery", "KEEP IN MY GALLERY", Vector3(-2.25, 0.68, 0.12), Vector3(3.8, 0.68, 0.12), GREEN)
	_create_ui_button(export_options, "export_headset", "SAVE TO THIS HEADSET", Vector3(2.25, 0.68, 0.12), Vector3(3.8, 0.68, 0.12), CYAN)
	_create_ui_button(export_options, "export_file", "EXPORT A FILE", Vector3(-2.25, -0.22, 0.12), Vector3(3.8, 0.68, 0.12), Color("ffd45c"))
	_create_ui_button(export_options, "export_email", "EMAIL TO ADULT", Vector3(2.25, -0.22, 0.12), Vector3(3.8, 0.68, 0.12), Color("ff9bcf"))
	_create_ui_button(export_options, "export_language", "LANGUAGE: " + EXPORT_LANGUAGES[0], Vector3(-2.25, -1.12, 0.12), Vector3(3.8, 0.58, 0.12), Color("6ea8ff"))
	_create_ui_button(export_options, "export_style", "STYLE: " + EXPORT_STYLES[0], Vector3(2.25, -1.12, 0.12), Vector3(3.8, 0.58, 0.12), Color("8b5cff"))
	_create_ui_button(export_options, "close_export", "BACK", Vector3(-4.0, 1.72, 0.12), Vector3(1.25, 0.48, 0.1), CYAN)
	export_status = _label3d("Choose where to keep it", Vector3(0.0, -1.72, 0.12), 34, Color.WHITE)
	export_panel.add_child(export_status)
	export_panel.visible = false
	_set_area_interactive(export_panel, false)

func _build_workspace_side_rails() -> void:
	left_rail = Node3D.new()
	left_rail.name = "WorkspaceLeftRail"
	panel_root.add_child(left_rail)
	var left_surface := _box_mesh(Vector3(2.55, 4.9, 0.16), _metal_material(Color("020608"), 0.94, 0.08))
	left_surface.position = Vector3(-6.25, 0.0, 0.18)
	left_rail.add_child(left_surface)
	left_rail.add_child(_label3d("TOOLS", Vector3(-6.25, 2.05, 0.34), 38, Color.WHITE))
	var left_items := [
		["open_settings", "SETTINGS", "Changes comfort options"],
		["open_inventory", "MY CREATIONS", "Shows reusable saved creations"],
		["back_step", "BACK ONE STEP", "Removes the most recent choice"],
		["restart_path", "START OVER", "Restarts only this project path"],
		["exit_app", "EXIT", "Closes Synomize"]
	]
	for index in left_items.size():
		var item: Array = left_items[index]
		var button := _create_ui_button(left_rail, item[0], item[1], Vector3(-6.25, 1.35 - index * 0.78, 0.36), Vector3(2.15, 0.55, 0.1), CYAN if index < 2 else (GREEN if index < 4 else Color("ff6b74")))
		button.set_meta("choice_description", item[2])

	right_rail = Node3D.new()
	right_rail.name = "WorkspaceRightRail"
	panel_root.add_child(right_rail)
	var right_surface := _box_mesh(Vector3(2.75, 4.9, 0.16), _metal_material(Color("020608"), 0.94, 0.08))
	right_surface.position = Vector3(6.35, 0.0, 0.18)
	right_rail.add_child(right_surface)
	right_rail.add_child(_label3d("RECENT CHOICES", Vector3(6.35, 2.05, 0.34), 34, Color.WHITE))
	for index in 3:
		var label := _label3d("—", Vector3(6.35, 1.3 - index * 0.62, 0.34), 29, Color("c7eeee"))
		right_rail.add_child(label)
		recent_choice_labels.append(label)
	progress_text = _label3d("STEP 0 / 0", Vector3(6.35, -0.92, 0.34), 34, GREEN)
	right_rail.add_child(progress_text)
	for index in 7:
		var segment := _box_mesh(Vector3(0.27, 0.16, 0.08), _emissive_material(Color("17343b"), 0.5, false))
		segment.position = Vector3(5.42 + index * 0.31, -1.48, 0.34)
		right_rail.add_child(segment)
		progress_segments.append(segment)
	left_rail.visible = false
	right_rail.visible = false
	_set_area_interactive(left_rail, false)

func _build_settings_panel() -> void:
	settings_panel = Node3D.new()
	settings_panel.name = "ComfortSettings"
	settings_panel.position = Vector3(0.0, 0.0, 0.82)
	panel_root.add_child(settings_panel)
	settings_panel.add_child(_label3d("SETTINGS", Vector3(0.0, 1.55, 0.12), 54, Color.WHITE))
	_create_ui_button(settings_panel, "toggle_sound", "SOUND: ON", Vector3(0.0, 0.55, 0.12), Vector3(4.5, 0.68, 0.12), CYAN)
	_create_ui_button(settings_panel, "toggle_glow", "GLOW: ON", Vector3(0.0, -0.35, 0.12), Vector3(4.5, 0.68, 0.12), GREEN)
	_create_ui_button(settings_panel, "close_settings", "BACK", Vector3(0.0, -1.25, 0.12), Vector3(2.0, 0.58, 0.12), Color("6ea8ff"))
	settings_panel.visible = false
	_set_area_interactive(settings_panel, false)

func _create_ui_button(parent: Node3D, interaction_id: String, title: String, button_position: Vector3, button_size: Vector3, color: Color) -> Area3D:
	var button := Area3D.new()
	button.name = interaction_id
	button.set_meta("interaction_id", interaction_id)
	button.collision_layer = 1
	button.position = button_position
	button.add_child(_box_mesh(button_size, _glass_material(Color("071116"), color, 0.94)))
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = button_size + Vector3(0.0, 0.0, 0.12)
	shape_node.shape = shape
	button.add_child(shape_node)
	button.add_child(_label3d(title, Vector3(0.0, 0.0, 0.1), 32, Color.WHITE))
	parent.add_child(button)
	return button

func _build_tier_one_palette() -> void:
	tier_one_palette = Node3D.new()
	tier_one_palette.name = "SevenFirstTierBlocks"
	tier_one_palette.position = Vector3(0.0, -0.05, 0.68)
	panel_root.add_child(tier_one_palette)
	var title := _label3d("Choose What Happens Next", Vector3(0.0, 1.7, 0.16), 54, Color.WHITE)
	tier_one_palette.add_child(title)
	var families := ["Event", "Variable", "Action", "Condition", "Loop", "State", "Group"]
	var titles := ["START ADVENTURE", "NAME MY HERO", "SHOW A MESSAGE", "FIND A STAR?", "SPARKLE 3 TIMES", "REMEMBER SCORE", "SAVE POWER-UP"]
	var descriptions := ["Begins when the adventure opens", "Gives your hero a name", "Adds a message players can see", "Chooses what happens when a star is found", "Repeats a fun effect three times", "Keeps the score for later", "Makes this piece reusable"]
	var colors := [GREEN, CYAN, Color("8b5cff"), Color("ffd45c"), Color("ff6bc4"), Color("65ffbc"), Color("6ea8ff")]
	for index in families.size():
		var column := index % 4
		var row := index / 4
		var x := -3.45 + column * 2.3
		var y := 0.55 - row * 1.15
		var choice := _create_ui_button(tier_one_palette, "family_" + families[index].to_lower(), titles[index], Vector3(x, y, 0.12), Vector3(1.95, 0.78, 0.14), colors[index])
		choice.set_meta("choice_description", descriptions[index])
	tier_one_palette.visible = false
	_set_area_interactive(tier_one_palette, false)

func _set_area_interactive(root: Node, interactive: bool) -> void:
	for child in root.get_children():
		if child is Area3D:
			(child as Area3D).collision_layer = 1 if interactive else 0
		_set_area_interactive(child, interactive)

func _build_neon_frame() -> void:
	var frame_material := _emissive_material(GREEN, 4.0, false)
	for frame_data in [
		[Vector3(0.0, 2.6, 0.23), Vector3(9.6, 0.035, 0.035)],
		[Vector3(0.0, -2.6, 0.23), Vector3(9.6, 0.035, 0.035)],
		[Vector3(-4.85, 0.0, 0.23), Vector3(0.035, 4.9, 0.035)],
		[Vector3(4.85, 0.0, 0.23), Vector3(0.035, 4.9, 0.035)]
	]:
		var rail := _box_mesh(frame_data[1], frame_material)
		rail.position = frame_data[0]
		panel_root.add_child(rail)

func _create_socket(node_name: String, socket_position: Vector3, sides: int, color: Color, shown: bool) -> Node3D:
	var socket := Node3D.new()
	socket.name = node_name
	socket.position = socket_position
	var socket_material := _emissive_material(CYAN, 6.4, true)
	var outer := _prism_mesh(sides, 1.12, 0.055, socket_material)
	outer.rotation_degrees.x = 90.0
	socket.add_child(outer)
	var inner := _prism_mesh(sides, 0.88, 0.065, _metal_material(Color("020507"), 0.9, 0.16))
	inner.rotation_degrees.x = 90.0
	inner.position.z = 0.04
	socket.add_child(inner)
	var label := _label3d("START" if sides == 5 else "NEXT", Vector3(0.0, -1.32, 0.08), 42, Color.WHITE)
	socket.add_child(label)
	var particle_root := _build_socket_particles(socket)
	socket_materials[node_name] = socket_material
	socket_particles[node_name] = particle_root
	socket.visible = shown
	panel_root.add_child(socket)
	return socket

func _build_socket_particles(socket: Node3D) -> Node3D:
	var particle_root := Node3D.new()
	particle_root.name = "SocketSparkles"
	for index in 8:
		var sparkle := _prism_mesh(6, 0.025, 0.025, _emissive_material(CYAN, 4.2, true))
		var angle := TAU * float(index) / 8.0
		sparkle.position = Vector3(cos(angle) * 1.24, sin(angle) * 1.24, 0.1)
		particle_root.add_child(sparkle)
	socket.add_child(particle_root)
	return particle_root

func _create_generate_control() -> Area3D:
	var button := Area3D.new()
	button.name = "GenerateControl3D"
	button.set_meta("interaction_id", "generate")
	button.collision_layer = 1
	button.position = Vector3(0.0, -0.82, 0.34)
	var mesh := _box_mesh(Vector3(3.8, 0.52, 0.16), _emissive_material(GREEN, 2.8, false))
	button.add_child(mesh)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.8, 0.52, 0.3)
	shape_node.shape = shape
	button.add_child(shape_node)
	var label := _label3d("CREATE", Vector3(0.0, 0.0, 0.11), 44, Color("e0fff2"))
	button.add_child(label)
	button.visible = false
	panel_root.add_child(button)
	return button

func _build_visual_polish() -> void:
	_build_nebula_backdrop()
	_build_panel_glass_layers()
	_build_panel_corner_accents()
	_build_signature_arch()
	_build_hologram_columns()
	_build_floor_runway()
	_build_floating_particles()
	_build_ambient_audio()

func _build_nebula_backdrop() -> void:
	for layer_data in [
		[Vector3(-7.5, 6.8, -12.0), Vector3(8.0, 4.2, 0.2), Color("5726a8"), 0.16],
		[Vector3(7.0, 5.2, -15.0), Vector3(9.0, 5.0, 0.2), Color("114f9f"), 0.13],
		[Vector3(0.0, 9.0, -18.0), Vector3(12.0, 4.5, 0.2), Color("1f7a8c"), 0.09]
	]:
		var cloud := _box_mesh(layer_data[1], _emissive_material(Color(layer_data[2], layer_data[3]), 1.8, true))
		cloud.position = layer_data[0]
		cloud.rotation_degrees.z = -12.0 + nebula_layers.size() * 14.0
		star_field.add_child(cloud)
		nebula_layers.append(cloud)

func _build_panel_glass_layers() -> void:
	panel_glass = _box_mesh(Vector3(9.72, 4.92, 0.055), _glass_material(Color("03090b"), CYAN, 0.3))
	panel_glass.name = "FrostedGlassFace"
	panel_glass.position = Vector3(0.0, 0.0, 0.225)
	panel_root.add_child(panel_glass)
	panel_halo = _box_mesh(Vector3(11.1, 6.15, 0.05), _emissive_material(GREEN, 2.4, true))
	panel_halo.name = "PanelAura"
	panel_halo.position = Vector3(0.0, 0.0, -0.18)
	panel_root.add_child(panel_halo)

func _build_panel_corner_accents() -> void:
	for x in [-4.62, 4.62]:
		for y in [-2.35, 2.35]:
			var accent := _box_mesh(Vector3(0.42, 0.055, 0.055), _emissive_material(CYAN if x > 0.0 else GREEN, 5.2, false))
			accent.position = Vector3(x, y, 0.34)
			panel_root.add_child(accent)
			var vertical := _box_mesh(Vector3(0.055, 0.42, 0.055), accent.material_override)
			vertical.position = Vector3(x, y, 0.34)
			panel_root.add_child(vertical)

func _build_signature_arch() -> void:
	var arch_root := Node3D.new()
	arch_root.name = "SignatureEnergyArch"
	panel_root.add_child(arch_root)
	for index in 17:
		var t := float(index) / 16.0
		var angle := lerpf(PI * 0.10, PI * 0.90, t)
		var x := cos(angle) * 6.2
		var y := sin(angle) * 2.4 + 2.65
		var segment := _box_mesh(Vector3(0.42, 0.11, 0.11), _emissive_material(GREEN if index % 2 == 0 else CYAN, 5.2, false))
		segment.position = Vector3(x, y, 0.4)
		segment.rotation_degrees.z = rad_to_deg(angle) - 90.0
		arch_root.add_child(segment)

func _build_hologram_columns() -> void:
	for side in [-1.0, 1.0]:
		var column_root := Node3D.new()
		column_root.position = Vector3(side * 6.15, 0.0, 0.15)
		panel_root.add_child(column_root)
		for index in 7:
			var panel := _box_mesh(Vector3(0.38, 0.42, 0.06), _emissive_material(GREEN if side < 0.0 else CYAN, 3.8 - index * 0.25, true))
			panel.position = Vector3(0.0, -1.7 + index * 0.58, 0.0)
			panel.rotation_degrees.y = side * 12.0
			column_root.add_child(panel)

func _build_floor_runway() -> void:
	for index in 9:
		var z := 5.0 - index * 1.35
		var width := 1.4 + index * 0.42
		var strip := _box_mesh(Vector3(width, 0.018, 0.035), _emissive_material(GREEN if index % 2 == 0 else CYAN, 4.3, false))
		strip.position = Vector3(0.0, 0.026, z)
		circuit_root.add_child(strip)
	for side in [-1.0, 1.0]:
		var edge := _box_mesh(Vector3(0.035, 0.02, 11.0), _emissive_material(CYAN, 3.6, false))
		edge.position = Vector3(side * 3.65, 0.025, 0.0)
		circuit_root.add_child(edge)

func _build_floating_particles() -> void:
	for index in 28:
		var dot := _prism_mesh(6, 0.028 + float(index % 3) * 0.01, 0.035, _emissive_material(GREEN if index % 2 == 0 else CYAN, 4.0, true))
		var angle := float(index) * 2.39996
		var radius := 4.0 + fmod(float(index * 17), 50.0) * 0.08
		dot.position = Vector3(cos(angle) * radius, 1.1 + fmod(float(index * 29), 55.0) * 0.08, -2.0 + sin(angle) * radius)
		star_field.add_child(dot)
		floating_particles.append(dot)

func _build_ambient_audio() -> void:
	var player := AudioStreamPlayer.new()
	player.name = "AmbientSynthHum"
	var stream := load("res://assets/audio/vectorverse_ambient.wav")
	if stream != null:
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream = stream
		player.volume_db = -22.0
		player.autoplay = true
		add_child(player)

func _process(delta: float) -> void:
	visual_time += delta
	for index in nebula_layers.size():
		var cloud := nebula_layers[index]
		cloud.rotation_degrees.z += delta * (0.35 + index * 0.18)
		cloud.position.y += sin(visual_time * 0.18 + index) * delta * 0.018
	for index in floating_particles.size():
		var particle := floating_particles[index]
		particle.position.y += sin(visual_time * 0.45 + index * 0.7) * delta * 0.018
		particle.rotation_degrees.y += delta * (4.0 + index % 3)
	for index in circuit_materials.size():
		circuit_materials[index].emission_energy_multiplier = 2.6 + sin(visual_time * 1.6 - index * 0.22) * 1.25
	if panel_halo != null:
		panel_halo.scale = Vector3.ONE * (1.0 + sin(visual_time * 0.8) * 0.012)
	for socket_name in socket_particles:
		var particles := socket_particles[socket_name] as Node3D
		var socket := particles.get_parent() as Node3D
		if socket != null and socket.visible:
			particles.rotation_degrees.z += delta * 12.0
			particles.scale = Vector3.ONE * (1.0 + sin(visual_time * 1.7) * 0.035)
			var material := socket_materials.get(socket_name) as StandardMaterial3D
			if material != null:
				material.emission_energy_multiplier = 6.4 + sin(visual_time * 2.0) * 1.1

func _build_atoms() -> void:
	_start_selected_path("kids")

func _path_definition(path_id: String) -> Array[Dictionary]:
	match path_id:
		"scratch":
			return [
				{"id":"app_start", "title":"START", "sides":5, "color":GREEN, "help":"Starts your first creation"},
				{"id":"display_message", "title":"HELLO WORLD", "sides":3, "color":CYAN, "help":"Shows Hello World when it starts"}
			]
		"adult":
			return [
				{"id":"app_start", "title":"START DAY", "sides":5, "color":GREEN, "help":"Opens your daily checklist"},
				{"id":"string_value", "title":"ADD TASK", "sides":4, "color":CYAN, "help":"Adds Feed the dog to the checklist"},
				{"id":"display_message", "title":"SHOW LIST", "sides":3, "color":Color("8b5cff"), "help":"Shows today’s tasks"},
				{"id":"condition", "title":"TASK DONE?", "sides":6, "color":Color("ffd45c"), "help":"Checks whether the task is complete"},
				{"id":"loop", "title":"NEXT TASK", "sides":8, "color":Color("ff9bcf"), "help":"Moves to the next task"},
				{"id":"state_write", "title":"REMEMBER", "sides":16, "color":Color("65ffbc"), "help":"Remembers completed tasks"},
				{"id":"module_boundary", "title":"SAVE ROUTINE", "sides":10, "color":Color("6ea8ff"), "help":"Makes the checklist reusable tomorrow"}
			]
		_:
			return [
				{"id":"app_start", "title":"START GAME", "sides":5, "color":GREEN, "help":"Starts your Star Buddy adventure"},
				{"id":"string_value", "title":"NAME BUDDY", "sides":4, "color":CYAN, "help":"Names your new space buddy Nova"},
				{"id":"display_message", "title":"SAY HELLO", "sides":3, "color":Color("8b5cff"), "help":"Makes Nova welcome the player"},
				{"id":"condition", "title":"FOUND A STAR?", "sides":6, "color":Color("ffd45c"), "help":"Checks whether Nova found a star"},
				{"id":"loop", "title":"SPARKLE 3X", "sides":8, "color":Color("ff6bc4"), "help":"Makes the star sparkle three times"},
				{"id":"state_write", "title":"SAVE 1 STAR", "sides":16, "color":Color("65ffbc"), "help":"Remembers the star Nova collected"},
				{"id":"module_boundary", "title":"POWER-UP", "sides":10, "color":Color("6ea8ff"), "help":"Turns this adventure into a reusable power-up"}
			]

func _start_selected_path(path_id: String) -> void:
	active_path = path_id
	kid_step = 0
	kid_path_complete = false
	graph.reset()
	for atom in kid_atoms:
		if is_instance_valid(atom): atom.queue_free()
	kid_atoms.clear()
	kid_flow = _path_definition(path_id)
	for index in kid_flow.size():
		var item: Dictionary = kid_flow[index]
		var atom := VectorVerseSpatialAtom.new()
		atom.name = "GuidedTile%02d" % index
		atom.configure(item.id, item.title, item.sides, item.color)
		atom.set_meta("choice_description", item.help)
		atom.position = Vector3(0.0, 0.88, 2.1)
		staging_root.add_child(atom)
		atom.set_available(index == 0)
		kid_atoms.append(atom)
	app_start_atom = kid_atoms[0]
	display_message_atom = kid_atoms[1] if path_id == "scratch" else kid_atoms[2]
	_configure_kid_socket(kid_flow[0])
	explanation_text.text = kid_flow[0].help
	instruction_before_grab = kid_flow[0].help
	path_menu.visible = false if path_menu != null else false
	if path_menu != null: _set_area_interactive(path_menu, false)
	if export_panel != null:
		export_panel.visible = false
		_set_area_interactive(export_panel, false)
	status_text.visible = true
	success_panel.visible = false
	_set_area_interactive(success_panel, false)
	generate_control.visible = false
	left_rail.visible = true
	right_rail.visible = true
	_set_area_interactive(left_rail, true)
	_refresh_workspace_rails()

func _configure_kid_socket(item: Dictionary) -> void:
	var target := _current_kid_target()
	kid_socket.position = target - panel_root.global_position
	for child in kid_socket.get_children():
		child.queue_free()
	var material := _emissive_material(item.color, 6.4, true)
	var outer := _prism_mesh(int(item.sides), 1.12, 0.055, material)
	outer.rotation_degrees.x = 90.0
	kid_socket.add_child(outer)
	var inner := _prism_mesh(int(item.sides), 0.88, 0.065, _metal_material(Color("020507"), 0.94, 0.08))
	inner.rotation_degrees.x = 90.0
	inner.position.z = 0.04
	kid_socket.add_child(inner)
	kid_socket.add_child(_label3d("PLACE HERE", Vector3(0.0, -1.32, 0.08), 38, Color.WHITE))
	var particles := _build_socket_particles(kid_socket)
	socket_materials[kid_socket.name] = material
	socket_particles[kid_socket.name] = particles
	kid_socket.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if grabbed_atom != null:
			if event.position.distance_to(grab_start_screen) >= DRAG_THRESHOLD_PIXELS:
				grab_moved = true
			var world_position := _mouse_position_on_drag_plane(event.position)
			update_grab_world_position(world_position)
		else:
			_update_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var collider := _raycast(event.position)
		if collider is VectorVerseSpatialAtom:
			grab_start_screen = event.position
			grab_moved = false
			begin_grab(collider)
		else:
			activate_from_pointer(collider)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and grabbed_atom != null:
		var released_atom := grabbed_atom
		if grab_moved:
			update_grab_world_position(_mouse_position_on_drag_plane(event.position))
			release_grab()
		else:
			grabbed_atom = null
			_set_socket_targeting(released_atom.atom_id, false, false)
			released_atom.set_grabbed(false)
			activate_interaction_id(released_atom.atom_id)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_slice()

func _raycast(screen_position: Vector2) -> Object:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.get("collider")

func _update_hover(screen_position: Vector2) -> void:
	var next_hover := _raycast(screen_position) as Area3D
	if hovered_area == next_hover:
		return
	if hovered_area is VectorVerseSpatialAtom:
		(hovered_area as VectorVerseSpatialAtom).set_highlighted(false)
	hovered_area = next_hover
	if hovered_area is VectorVerseSpatialAtom:
		(hovered_area as VectorVerseSpatialAtom).set_highlighted(true)
	preview_interaction(hovered_area)

func preview_interaction(collider: Object) -> void:
	if collider != null and collider.has_meta("choice_description"):
		explanation_text.text = str(collider.get_meta("choice_description"))

func _mouse_position_on_drag_plane(screen_position: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.z) < 0.0001:
		return grabbed_atom.global_position if grabbed_atom != null else Vector3.ZERO
	var distance := (DRAG_PLANE_Z - origin.z) / direction.z
	return origin + direction * distance

# Mouse and future XR controllers share this grab lifecycle.
func begin_grab(collider: Object) -> bool:
	if not collider is VectorVerseSpatialAtom:
		return false
	var atom := collider as VectorVerseSpatialAtom
	if atom.is_snapped or not atom.is_available or not _is_atom_currently_compatible(atom.atom_id):
		return false
	grabbed_atom = atom
	grab_origin = atom.position
	atom.set_grabbed(true)
	explanation_text.text = str(kid_flow[kid_step].help) if kid_step < kid_flow.size() else "Ready to play"
	_set_socket_targeting(atom.atom_id, true, false)
	return true

func update_grab_world_position(world_position: Vector3) -> void:
	if grabbed_atom == null:
		return
	var target := socket_target_for_atom(grabbed_atom.atom_id)
	var distance := world_position.distance_to(target)
	if distance < MAGNETIC_DISTANCE:
		var magnetic_strength := 1.0 - distance / MAGNETIC_DISTANCE
		grabbed_atom.global_position = world_position.lerp(target, magnetic_strength * 0.34)
	else:
		grabbed_atom.global_position = world_position
	var in_range := grabbed_atom.global_position.distance_to(target) <= SOCKET_SNAP_DISTANCE
	_set_socket_targeting(grabbed_atom.atom_id, true, in_range)

func release_grab() -> bool:
	if grabbed_atom == null:
		return false
	var atom := grabbed_atom
	grabbed_atom = null
	var target := socket_target_for_atom(atom.atom_id)
	var accepted := atom.global_position.distance_to(target) <= SOCKET_SNAP_DISTANCE and _is_atom_currently_compatible(atom.atom_id)
	_set_socket_targeting(atom.atom_id, false, false)
	if accepted:
		atom.set_grabbed(false)
		activate_interaction_id(atom.atom_id)
		return true
	atom.return_to_staging(grab_origin)
	explanation_text.text = "Try Again"
	return false

func cancel_grab() -> void:
	if grabbed_atom == null:
		return
	var atom := grabbed_atom
	grabbed_atom = null
	_set_socket_targeting(atom.atom_id, false, false)
	atom.return_to_staging(grab_origin)

func socket_target_for_atom(atom_id: String) -> Vector3:
	return _current_kid_target()

func _current_kid_target() -> Vector3:
	if kid_step >= 0 and kid_step < KID_PLACEMENT_TARGETS.size():
		return KID_PLACEMENT_TARGETS[kid_step]
	return EVENT_SOCKET_TARGET

func _is_atom_currently_compatible(atom_id: String) -> bool:
	return kid_step < kid_flow.size() and atom_id == str(kid_flow[kid_step].id)

func _set_socket_targeting(atom_id: String, active: bool, locked: bool) -> void:
	var socket := kid_socket
	if socket == null:
		return
	var target_scale := 1.18 if locked else (1.08 if active else 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(socket, "scale", Vector3.ONE * target_scale, 0.12)
	var material := socket_materials.get(socket.name) as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = 9.0 if locked else (7.2 if active else 6.4)

# XRController3D raycasters can call this same method later with their collider.
func activate_from_pointer(collider: Object) -> void:
	if collider == null or not collider.has_meta("interaction_id"):
		return
	activate_interaction_id(str(collider.get_meta("interaction_id")))

func activate_interaction_id(interaction_id: String) -> void:
	if kid_step < kid_flow.size() and interaction_id == str(kid_flow[kid_step].id):
		_place_guided_tile()
		return
	match interaction_id:
		"path_scratch":
			_start_selected_path("scratch")
		"path_adult":
			_start_selected_path("adult")
		"path_kids":
			_start_selected_path("kids")
		"open_inventory":
			inventory_returns_to_path = not active_path.is_empty()
			_open_inventory()
		"close_inventory":
			if inventory_returns_to_path: _return_to_active_workspace()
			else: _show_path_menu()
		"open_settings":
			_open_settings()
		"close_settings":
			_return_to_active_workspace()
		"toggle_sound":
			_toggle_sound()
		"toggle_glow":
			_toggle_glow()
		"back_step":
			_back_one_step()
		"restart_path":
			if not active_path.is_empty(): _start_selected_path(active_path)
		"exit_app":
			get_tree().quit()
		"open_export":
			_open_export()
		"close_export":
			_close_export()
		"export_gallery":
			_keep_in_inventory()
		"export_headset":
			_save_to_headset()
		"export_file":
			export_status.text = "Choose language and style, then use the device file picker"
		"export_email":
			export_status.text = "Adult approval and an entered adult email are required"
		"export_language":
			_cycle_export_language()
		"export_style":
			_cycle_export_style()
		"app_start":
			_select_app_start()
		"display_message":
			_select_display_message()
		"generate":
			_generate_validate_run()
		"continue_building":
			_replay_active_result()
		"create_new":
			_show_path_menu()
		"collect_star":
			_collect_star()
		_ when interaction_id.begins_with("adult_task_"):
			_toggle_adult_task(int(interaction_id.trim_prefix("adult_task_")))
		_ when interaction_id.begins_with("reuse_"):
			_reuse_path(interaction_id.trim_prefix("reuse_"))
		_ when interaction_id.begins_with("family_"):
			_select_family(interaction_id.trim_prefix("family_"))

func _show_path_menu() -> void:
	active_path = ""
	path_menu.visible = true
	_set_area_interactive(path_menu, true)
	inventory_panel.visible = false
	_set_area_interactive(inventory_panel, false)
	export_panel.visible = false
	_set_area_interactive(export_panel, false)
	success_panel.visible = false
	_set_area_interactive(success_panel, false)
	generate_control.visible = false
	kid_socket.visible = false
	action_socket.visible = false
	for atom in kid_atoms:
		atom.visible = false
	left_rail.visible = false
	right_rail.visible = false
	_set_area_interactive(left_rail, false)
	status_text.visible = false
	explanation_text.visible = true
	explanation_text.text = "Pick one path — only that project will appear"

func _open_inventory() -> void:
	_hide_active_workspace()
	path_menu.visible = false
	_set_area_interactive(path_menu, false)
	for child in inventory_cards.get_children(): child.queue_free()
	var path_names := {"scratch":"HELLO WORLD", "adult":"DAILY CHECKLIST", "kids":"STAR BUDDY"}
	if inventory_types.is_empty():
		inventory_cards.add_child(_label3d("Finish a creation once to reuse it forever", Vector3(0.0, 0.3, 0.12), 40, Color.WHITE))
	else:
		var index := 0
		for path_id in ["scratch", "adult", "kids"]:
			if not inventory_types.has(path_id): continue
			var card := _create_ui_button(inventory_cards, "reuse_" + path_id, "USE " + path_names[path_id], Vector3(0.0, 0.72 - index * 0.9, 0.12), Vector3(5.2, 0.68, 0.12), GREEN if index % 2 == 0 else CYAN)
			card.set_meta("choice_description", "Reuses this completed creation without rebuilding it")
			index += 1
	inventory_panel.visible = true
	_set_area_interactive(inventory_panel, true)
	explanation_text.text = "Each creation type appears once and can be reused forever"

func _hide_active_workspace() -> void:
	kid_socket.visible = false
	generate_control.visible = false
	success_panel.visible = false
	_set_area_interactive(success_panel, false)
	for atom in kid_atoms: atom.visible = false
	left_rail.visible = false
	right_rail.visible = false
	_set_area_interactive(left_rail, false)

func _return_to_active_workspace() -> void:
	settings_panel.visible = false
	_set_area_interactive(settings_panel, false)
	inventory_panel.visible = false
	_set_area_interactive(inventory_panel, false)
	export_panel.visible = false
	_set_area_interactive(export_panel, false)
	left_rail.visible = true
	right_rail.visible = true
	_set_area_interactive(left_rail, true)
	for index in kid_atoms.size():
		kid_atoms[index].visible = index <= kid_step
	if kid_step < kid_flow.size():
		kid_socket.visible = true
	else:
		generate_control.visible = not success_panel.visible
	_refresh_workspace_rails()

func _open_settings() -> void:
	_hide_active_workspace()
	settings_panel.visible = true
	_set_area_interactive(settings_panel, true)
	explanation_text.text = "Comfort settings"

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	var player := get_node_or_null("AmbientSynthHum") as AudioStreamPlayer
	if player != null:
		if sound_enabled: player.play()
		else: player.stop()
	_set_button_text(settings_panel.get_node("toggle_sound") as Area3D, "SOUND: " + ("ON" if sound_enabled else "OFF"))

func _toggle_glow() -> void:
	glow_enabled = not glow_enabled
	if environment_node.environment != null:
		environment_node.environment.glow_enabled = glow_enabled
	_set_button_text(settings_panel.get_node("toggle_glow") as Area3D, "GLOW: " + ("ON" if glow_enabled else "OFF"))

func _back_one_step() -> void:
	if active_path.is_empty() or kid_step <= 0:
		explanation_text.text = "You are already at the first step"
		return
	if kid_step < kid_atoms.size():
		kid_atoms[kid_step].set_available(false)
	kid_step -= 1
	kid_path_complete = false
	graph.reset()
	generate_control.visible = false
	success_panel.visible = false
	_set_area_interactive(success_panel, false)
	if adult_preview != null: adult_preview.visible = false
	if star_buddy_preview != null: star_buddy_preview.visible = false
	kid_atoms[kid_step].reset_for_choice(Vector3(0.0, 0.88, 2.1))
	_configure_kid_socket(kid_flow[kid_step])
	explanation_text.text = str(kid_flow[kid_step].help)
	instruction_before_grab = explanation_text.text
	_refresh_workspace_rails()

func _refresh_workspace_rails() -> void:
	if right_rail == null or kid_flow.is_empty(): return
	progress_text.text = "STEP %d / %d" % [mini(kid_step, kid_flow.size()), kid_flow.size()]
	var recent: Array[String] = []
	for index in range(maxi(0, kid_step - 3), kid_step): recent.append(str(kid_flow[index].title))
	for index in recent_choice_labels.size():
		recent_choice_labels[index].text = recent[index] if index < recent.size() else "—"
	for index in progress_segments.size():
		progress_segments[index].material_override = _emissive_material(GREEN if index < kid_step else Color("17343b"), 3.8 if index < kid_step else 0.5, false)

func _load_unique_inventory() -> void:
	if not FileAccess.file_exists(INVENTORY_PATH): return
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		for path_id in parsed: inventory_types[str(path_id)] = true

func _persist_unique_inventory() -> void:
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(inventory_types.keys()) + "\n")
		file.close()

func _keep_in_inventory() -> void:
	if active_path.is_empty(): return
	inventory_types[active_path] = true
	_persist_unique_inventory()
	export_status.text = "Saved — reuse it forever from My Creations"

func _reuse_path(path_id: String) -> void:
	if not inventory_types.has(path_id): return
	_start_selected_path(path_id)
	for atom in kid_atoms: atom.visible = false
	kid_socket.visible = false
	kid_step = kid_flow.size()
	kid_path_complete = true
	_configure_final_graph()
	explanation_text.text = "Reused creation ready to run"
	generate_control.visible = true

func _open_export() -> void:
	_hide_active_workspace()
	success_panel.visible = false
	_set_area_interactive(success_panel, false)
	export_panel.visible = true
	_set_area_interactive(export_panel, true)
	export_status.text = "Choose where to keep it"

func _close_export() -> void:
	export_panel.visible = false
	_set_area_interactive(export_panel, false)
	success_panel.visible = true
	_set_area_interactive(success_panel, true)
	left_rail.visible = true
	right_rail.visible = true
	_set_area_interactive(left_rail, true)
	_refresh_workspace_rails()

func _save_to_headset() -> void:
	var file := FileAccess.open("user://%s.synomize" % active_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"project":active_path, "style":EXPORT_STYLES[style_index], "language":EXPORT_LANGUAGES[language_index]}) + "\n")
		file.close()
	export_status.text = "Saved privately on this headset"

func _cycle_export_language() -> void:
	language_index = (language_index + 1) % EXPORT_LANGUAGES.size()
	_set_button_text(export_options.get_node("export_language") as Area3D, "LANGUAGE: " + EXPORT_LANGUAGES[language_index])

func _cycle_export_style() -> void:
	style_index = (style_index + 1) % EXPORT_STYLES.size()
	_set_button_text(export_options.get_node("export_style") as Area3D, "STYLE: " + EXPORT_STYLES[style_index])

func _set_button_text(button: Area3D, value: String) -> void:
	for child in button.get_children():
		if child is Label3D:
			(child as Label3D).text = value
			return

func _place_guided_tile() -> void:
	if kid_step >= kid_flow.size():
		return
	var atom := kid_atoms[kid_step]
	atom.move_into_socket(_current_kid_target())
	kid_socket.visible = false
	_board_glow_ripple()
	block_placed.emit(kid_step + 1)
	get_tree().create_timer(0.5).timeout.connect(_advance_kid_path)

func _advance_kid_path() -> void:
	var completed_index := kid_step
	kid_atoms[completed_index].move_to_history(KID_PLACEMENT_TARGETS[completed_index])
	kid_step += 1
	_refresh_workspace_rails()
	if kid_step < kid_flow.size():
		var item: Dictionary = kid_flow[kid_step]
		kid_atoms[kid_step].set_available(true)
		_configure_kid_socket(item)
		explanation_text.text = item.help
		instruction_before_grab = item.help
		_morph_panel(mini(kid_step, 3))
		return
	kid_path_complete = true
	_configure_final_graph()
	explanation_text.text = "Your creation is ready to run"
	instruction_before_grab = explanation_text.text
	var label := generate_control.get_node_or_null("Label3D") as Label3D
	if label == null:
		for child in generate_control.get_children():
			if child is Label3D:
				label = child
				break
	if label != null:
		label.text = "PLAY MY GAME" if active_path == "kids" else "RUN MY APP"
	generate_control.visible = true
	generate_control.scale = Vector3(0.2, 0.2, 0.2)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(generate_control, "scale", Vector3.ONE, 0.42)
	_refresh_workspace_rails()

func _configure_final_graph() -> void:
	match active_path:
		"scratch":
			graph.reset()
			graph.insert_atom("app_start")
			compatible_after_start = VectorVerseCompatibilityFilter.choices_for_graph(graph).get("visible_choices", [])
			graph.insert_atom("display_message")
		"adult": graph.configure_program3("Feed the dog: complete")
		_: graph.configure_program3("Nova found a star!")

func _show_tier_one_palette() -> void:
	success_panel.visible = false
	status_text.visible = false
	explanation_text.visible = true
	explanation_text.text = "Point at a choice to see what it does"
	tier_one_palette.visible = true
	_set_area_interactive(tier_one_palette, true)
	tier_one_palette.scale = Vector3(0.75, 0.75, 0.75)
	var reveal := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(tier_one_palette, "scale", Vector3.ONE, 0.42)

func _select_family(family: String) -> void:
	match family:
		"condition": graph.configure_program2(true)
		"state": graph.configure_program3("Remembered by Synomize")
		"loop": graph.configure_loop_demo()
		"group": graph.configure_group_demo()
		"variable": graph.configure_variable_demo()
		_:
			graph.reset()
			graph.insert_atom("app_start")
			graph.insert_atom("display_message")
	tier_one_palette.visible = false
	_set_area_interactive(tier_one_palette, false)
	explanation_text.visible = true
	var ready_messages := {
		"event": "Your adventure can begin",
		"variable": "Your hero has a name",
		"action": "Your message is ready",
		"condition": "Your star choice is ready",
		"loop": "Your sparkle effect is ready",
		"state": "Your score can be remembered",
		"group": "Your reusable power-up is ready"
	}
	explanation_text.text = ready_messages.get(family, "Your next piece is ready")
	_activate_floor_strikes()
	block_placed.emit(3)
	generate_control.visible = true
	generate_control.scale = Vector3(0.2, 0.2, 0.2)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(generate_control, "scale", Vector3.ONE, 0.38)

func _select_app_start() -> void:
	if not graph.atom_ids.is_empty() or not graph.insert_atom("app_start"):
		return
	compatible_after_start = VectorVerseCompatibilityFilter.choices_for_graph(graph).get("visible_choices", [])
	app_start_atom.move_into_socket(EVENT_SOCKET_TARGET)
	display_message_atom.set_available(true)
	_reveal_socket(action_socket)
	explanation_text.text = "Choose Next"
	instruction_before_grab = "Choose Next"
	_board_glow_ripple()
	block_placed.emit(1)
	_morph_panel(1)

func _select_display_message() -> void:
	if graph.atom_ids != ["app_start"] or not graph.insert_atom("display_message"):
		return
	display_message_atom.move_into_socket(ACTION_SOCKET_TARGET)
	generate_control.visible = true
	generate_control.scale = Vector3(0.2, 0.2, 0.2)
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(generate_control, "scale", Vector3.ONE, 0.48)
	explanation_text.text = "Create"
	instruction_before_grab = "Create"
	_board_glow_ripple()
	block_placed.emit(2)
	_morph_panel(2)

func _generate_validate_run() -> void:
	if graph.atom_ids.is_empty():
		return
	var accepted := false
	if graph.atom_ids == ["app_start", "display_message"]:
		accepted = VectorVerseVerticalSliceValidator.validate_and_save(graph, compatible_after_start).accepted
	else:
		var validation := VectorVerseValidationPipeline.validate_graph(graph)
		if validation.accepted_for_backend:
			var generation := VectorVerseGDScriptAdapter.generate_from_ir(validation.ir)
			if generation.accepted:
				var generated_script := GDScript.new()
				generated_script.source_code = generation.source
				accepted = generated_script.reload() == OK and generated_script.can_instantiate()
				if accepted:
					var instance = generated_script.new()
					instance.execute()
					instance.free()
	if accepted:
		if kid_path_complete:
			_show_selected_result()
			return
		explanation_text.visible = false
		status_text.visible = false
		generate_control.visible = false
		code_text.visible = false
		_clear_builder_for_output()
		success_heading.text = "You created \"%s\"" % _current_project_name()
		success_heading.visible = true
		success_heading.modulate = Color.WHITE
		completion_actions.visible = false
		success_panel.visible = true
		success_panel.scale = Vector3(0.92, 0.92, 0.92)
		var entrance := create_tween()
		entrance.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		entrance.tween_property(success_panel, "scale", Vector3.ONE, 0.35)
		_play_completion_celebration()
		await get_tree().create_timer(1.55).timeout
		var mist := create_tween().set_parallel(true)
		mist.tween_property(success_heading, "scale", Vector3.ONE * 1.22, 0.42)
		mist.tween_property(success_heading, "modulate:a", 0.0, 0.42)
		await mist.finished
		success_heading.visible = false
		completion_actions.visible = true
		_morph_panel(3)
	else:
		explanation_text.text = "Try Again"

func _current_project_name() -> String:
	if kid_path_complete:
		match active_path:
			"scratch": return "Hello World"
			"adult": return "Daily Checklist"
			_: return "Star Buddy Adventure"
	match graph.graph_id:
		"demo_variable": return "Variable Message"
		"demo_bounded_loop": return "Repeating Action"
		"demo_reusable_group": return "Reusable Group"
		_ when graph.graph_id.begins_with("program2_"): return "Smart Decision"
		"program3_session_state": return "Memory"
		_: return "Hello World"

func _show_selected_result() -> void:
	inventory_types[active_path] = true
	_persist_unique_inventory()
	match active_path:
		"scratch": _show_hello_world_result()
		"adult": _show_daily_checklist()
		_: _show_star_buddy_game()

func _prepare_result_surface(title: String) -> void:
	explanation_text.visible = false
	status_text.visible = false
	generate_control.visible = false
	kid_socket.visible = false
	action_socket.visible = false
	for atom in kid_atoms: atom.visible = false
	success_panel.visible = true
	_set_area_interactive(success_panel, true)
	success_panel.scale = Vector3.ONE
	success_heading.visible = true
	success_heading.modulate = Color.WHITE
	success_heading.scale = Vector3.ONE
	success_heading.text = title
	completion_actions.visible = true
	left_rail.visible = true
	right_rail.visible = true
	_set_area_interactive(left_rail, true)
	_refresh_workspace_rails()

func _show_hello_world_result() -> void:
	_prepare_result_surface("HELLO WORLD!")
	if adult_preview != null: adult_preview.queue_free()
	if star_buddy_preview != null: star_buddy_preview.queue_free()
	_play_completion_celebration()
	_activate_floor_strikes()

func _show_daily_checklist() -> void:
	_prepare_result_surface("DAILY CHECKLIST")
	if adult_preview != null: adult_preview.queue_free()
	if star_buddy_preview != null: star_buddy_preview.queue_free()
	adult_preview = Node3D.new()
	adult_preview.name = "PlayableDailyChecklist"
	success_panel.add_child(adult_preview)
	adult_task_labels.clear()
	for index in 3:
		var names := ["FEED THE DOG", "DRINK WATER", "PACK MY BAG"]
		var task := _create_ui_button(adult_preview, "adult_task_%d" % index, "[ ]  " + names[index], Vector3(0.0, 0.72 - index * 0.62, 0.2), Vector3(5.4, 0.48, 0.1), CYAN if index % 2 == 0 else GREEN)
		for child in task.get_children():
			if child is Label3D:
				adult_task_labels.append(child)
	_play_completion_celebration()
	_activate_floor_strikes()

func _toggle_adult_task(index: int) -> void:
	if index < 0 or index >= adult_task_labels.size(): return
	var label := adult_task_labels[index]
	label.text = label.text.replace("[ ]", "[✓]") if "[ ]" in label.text else label.text.replace("[✓]", "[ ]")
	_activate_floor_strikes()

func _replay_active_result() -> void:
	match active_path:
		"kids": _play_star_buddy_animation()
		"adult":
			for label in adult_task_labels: label.text = label.text.replace("[✓]", "[ ]")
		_: _play_completion_celebration()

func _show_star_buddy_game() -> void:
	_prepare_result_surface("STAR BUDDY ADVENTURE")
	if star_buddy_preview != null:
		star_buddy_preview.queue_free()
	star_buddy_preview = Node3D.new()
	star_buddy_preview.name = "PlayableStarBuddyPreview"
	success_panel.add_child(star_buddy_preview)
	var body := _box_mesh(Vector3(1.0, 1.15, 0.34), _metal_material(Color("071417"), 0.92, 0.08))
	body.position = Vector3(-1.55, 0.28, 0.22)
	star_buddy_preview.add_child(body)
	var face := _prism_mesh(16, 0.62, 0.32, _emissive_material(CYAN, 2.8, false))
	face.rotation_degrees.x = 90.0
	face.position = Vector3(-1.55, 0.92, 0.3)
	star_buddy_preview.add_child(face)
	for eye_x in [-1.75, -1.35]:
		var eye := _prism_mesh(12, 0.075, 0.05, _emissive_material(GREEN, 8.0, false))
		eye.rotation_degrees.x = 90.0
		eye.position = Vector3(eye_x, 1.02, 0.51)
		star_buddy_preview.add_child(eye)
	var star := Area3D.new()
	star.name = "FoundStar"
	star.position = Vector3(1.55, 0.58, 0.34)
	star.set_meta("interaction_id", "collect_star")
	star.set_meta("choice_description", "Catch the star to earn a point")
	star.collision_layer = 1
	var star_mesh := _prism_mesh(5, 0.72, 0.2, _emissive_material(Color("ffe66a"), 8.0, false))
	star_mesh.rotation_degrees.x = 90.0
	star.add_child(star_mesh)
	var star_shape_node := CollisionShape3D.new()
	var star_shape := SphereShape3D.new()
	star_shape.radius = 0.82
	star_shape_node.shape = star_shape
	star.add_child(star_shape_node)
	star_buddy_preview.add_child(star)
	star_buddy_score_text = _label3d("HELP NOVA CATCH THE STAR!\nSCORE  0", Vector3(0.0, -0.82, 0.24), 48, Color.WHITE)
	star_buddy_preview.add_child(star_buddy_score_text)
	star_collected = false
	_play_star_buddy_animation()
	_activate_floor_strikes()

func _play_star_buddy_animation() -> void:
	if star_buddy_preview == null:
		return
	star_collected = false
	if star_buddy_score_text != null:
		star_buddy_score_text.text = "HELP NOVA CATCH THE STAR!\nSCORE  0"
	var star := star_buddy_preview.get_node_or_null("FoundStar") as Area3D
	if star != null:
		star.collision_layer = 1
		star.position = Vector3(1.55, 0.58, 0.34)
		star.scale = Vector3.ONE * 0.35
		var star_tween := create_tween().set_parallel(true)
		star_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		star_tween.tween_property(star, "scale", Vector3.ONE * 1.22, 0.5)
		star_tween.tween_property(star, "rotation_degrees:z", star.rotation_degrees.z + 360.0, 0.9)
		star_tween.chain().tween_property(star, "scale", Vector3.ONE, 0.25)
	_play_completion_celebration()
	_activate_floor_strikes()

func _collect_star() -> void:
	if star_collected or star_buddy_preview == null:
		return
	star_collected = true
	star_buddy_score_text.text = "NOVA CAUGHT THE STAR!\nSCORE  1"
	var star := star_buddy_preview.get_node_or_null("FoundStar") as Area3D
	if star != null:
		star.collision_layer = 0
		var caught := create_tween().set_parallel(true)
		caught.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		caught.tween_property(star, "position", Vector3(-1.55, 0.92, 0.42), 0.58)
		caught.tween_property(star, "scale", Vector3.ONE * 0.24, 0.58)
	_play_completion_celebration()
	_activate_floor_strikes()

func _play_completion_celebration() -> void:
	for child in celebration_root.get_children():
		child.queue_free()
	for index in 32:
		var color := GREEN if index % 2 == 0 else CYAN
		var spark := _prism_mesh(6, 0.035, 0.04, _emissive_material(color, 8.0, true))
		spark.position = Vector3(0.0, 0.65, 0.34)
		spark.scale = Vector3.ONE * 0.1
		celebration_root.add_child(spark)
		var angle := TAU * float(index) / 32.0
		var radius := 1.8 + float(index % 5) * 0.38
		var target := Vector3(cos(angle) * radius, 0.65 + sin(angle) * radius * 0.62, 0.42)
		var burst := create_tween().set_parallel(true)
		burst.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst.tween_property(spark, "position", target, 0.72 + float(index % 3) * 0.08)
		burst.tween_property(spark, "scale", Vector3.ONE * 1.35, 0.25)
		burst.chain().tween_property(spark, "scale", Vector3.ZERO, 0.5)
		burst.chain().tween_callback(spark.queue_free)
	for index in 7:
		var cloud := _box_mesh(Vector3(0.7, 0.18, 0.035), _emissive_material(Color("9eefff"), 1.4, true))
		cloud.position = Vector3(-2.4 + index * 0.8, 0.15 + sin(index) * 0.22, 0.25)
		celebration_root.add_child(cloud)
		var drift := create_tween().set_parallel(true)
		drift.tween_property(cloud, "position:y", cloud.position.y + 0.7, 1.4)
		drift.tween_property(cloud, "scale", Vector3(2.2, 0.25, 1.0), 1.4)
		drift.chain().tween_callback(cloud.queue_free)

func _clear_builder_for_output() -> void:
	var builder_nodes: Array[Node3D] = [panel_root.get_node("EventSocket3D") as Node3D, action_socket]
	for atom in kid_atoms:
		builder_nodes.append(atom)
	for node in builder_nodes:
		if node == null or not node.visible:
			continue
		var fade := create_tween()
		fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade.tween_property(node, "scale", Vector3.ONE * 0.05, 0.28)
		fade.tween_callback(node.hide)

func _reveal_socket(socket: Node3D) -> void:
	socket.visible = true
	socket.scale = Vector3(0.15, 0.15, 0.15)
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(socket, "scale", Vector3.ONE, 0.55)

func _board_glow_ripple() -> void:
	_activate_floor_strikes()
	var ripple_material := _emissive_material(CYAN, 6.0, true)
	var ripple := _box_mesh(Vector3(9.1, 0.035, 0.035), ripple_material)
	ripple.name = "BoardGlowRipple"
	ripple.position = Vector3(0.0, 0.0, 0.48)
	ripple.scale.x = 0.02
	panel_root.add_child(ripple)
	var ripple_tween := create_tween().set_parallel(true)
	ripple_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ripple_tween.tween_property(ripple, "scale:x", 1.0, 0.48)
	ripple_tween.tween_property(ripple_material, "emission_energy_multiplier", 0.0, 0.7)
	ripple_tween.chain().tween_callback(ripple.queue_free)

func _activate_floor_strikes() -> void:
	for index in 6:
		var strike_color := GREEN if index % 2 == 0 else CYAN
		var strike := _box_mesh(Vector3(0.035, 0.025, 1.5 + index * 0.42), _emissive_material(strike_color, 8.0, true))
		strike.position = Vector3(-5.0 + fmod(float(index * 23), 10.0), 0.045, 3.5 - index * 1.45)
		strike.scale.z = 0.02
		circuit_root.add_child(strike)
		var flash := create_tween()
		flash.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flash.tween_interval(index * 0.06)
		flash.tween_property(strike, "scale:z", 1.0, 0.22)
		flash.tween_property(strike, "scale", Vector3(1.0, 1.0, 0.05), 0.5)
		flash.tween_callback(strike.queue_free)

func _read_generated_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Generated GDScript saved to:\n" + path
	var source := file.get_as_text().strip_edges()
	file.close()
	return source

func _morph_panel(stage: int) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var width := 1.0 + stage * 0.018
	tween.tween_property(panel_body, "scale", Vector3(width, 1.0 + stage * 0.006, 1.0), 0.65)
	tween.tween_property(left_wing, "scale:x", 1.0 if stage > 0 else 0.05, 0.65)
	tween.tween_property(right_wing, "scale:x", 1.0 if stage > 0 else 0.05, 0.65)
	var pulse_color := CYAN if stage == 3 else GREEN
	var pulse := OmniLight3D.new()
	pulse.light_color = pulse_color
	pulse.light_energy = 12.0
	pulse.omni_range = 5.5
	pulse.position = Vector3(0.0, 0.0, 1.0)
	panel_root.add_child(pulse)
	var pulse_tween := create_tween()
	pulse_tween.tween_property(pulse, "light_energy", 0.0, 0.8)
	pulse_tween.tween_callback(pulse.queue_free)

func _reset_slice() -> void:
	get_tree().reload_current_scene()

func _update_spatial_state() -> void:
	status_text.text = "SYNOMIZE\nVisual Software Builder"
	if not kid_flow.is_empty():
		explanation_text.text = str(kid_flow[0].help)

func _run_packaged_phase5_condition_proof() -> void:
	if not OS.has_feature("android"):
		return
	for condition_value in [true, false]:
		var proof_graph := VectorVerseVisualGraph.new()
		proof_graph.configure_program2(condition_value)
		var validation := VectorVerseValidationPipeline.validate_graph(proof_graph)
		var generation := VectorVerseGDScriptAdapter.generate_from_ir(validation.ir)
		if not validation.accepted_for_backend or not generation.accepted:
			print("VECTORVERSE_PHASE5_QUEST_PROOF_FAILED")
			continue
		var generated_script := GDScript.new()
		generated_script.source_code = generation.source
		if generated_script.reload() != OK or not generated_script.can_instantiate():
			print("VECTORVERSE_PHASE5_QUEST_PARSE_FAILED")
			continue
		var instance = generated_script.new()
		var result: String = instance.execute()
		instance.free()
		print("VECTORVERSE_PHASE5_QUEST_%s=%s" % ["TRUE" if condition_value else "FALSE", result])

func _run_packaged_phase6_state_proof() -> void:
	if not OS.has_feature("android"):
		return
	var proof_graph := VectorVerseVisualGraph.new()
	proof_graph.configure_program3("Remember me exactly")
	var validation := VectorVerseValidationPipeline.validate_graph(proof_graph)
	var generation := VectorVerseGDScriptAdapter.generate_from_ir(validation.ir)
	if not validation.accepted_for_backend or not generation.accepted:
		print("VECTORVERSE_PHASE6_QUEST_PROOF_FAILED")
		return
	var generated_script := GDScript.new()
	generated_script.source_code = generation.source
	if generated_script.reload() != OK or not generated_script.can_instantiate():
		print("VECTORVERSE_PHASE6_QUEST_PARSE_FAILED")
		return
	var instance = generated_script.new()
	var result: String = instance.execute()
	instance.free()
	print("VECTORVERSE_PHASE6_QUEST_STATE=" + result)
	print("VECTORVERSE_PHASE6_QUEST_EXACT_READ_AFTER_WRITE=" + str(result == "Remember me exactly").to_lower())

func _box_mesh(mesh_size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = mesh_size
	instance.mesh = mesh
	instance.material_override = material
	return instance

func _prism_mesh(sides: int, radius: float, depth: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = sides
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = material
	return instance

func _label3d(text_value: String, label_position: Vector3, size_value: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = label_position
	label.font_size = size_value
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.96)
	label.no_depth_test = true
	return label

func _metal_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material

func _panel_core_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("010304")
	material.metallic = 0.94
	material.roughness = 0.08
	material.emission_enabled = true
	material.emission = Color("041713")
	material.emission_energy_multiplier = 0.72
	return material

func _glass_material(base_color: Color, glow_color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(base_color, alpha)
	material.metallic = 0.58
	material.roughness = 0.18
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = 0.42
	return material

func _emissive_material(color: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.28 if transparent else 1.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
