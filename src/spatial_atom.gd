class_name VectorVerseSpatialAtom
extends Area3D

var atom_id := ""
var display_name := ""
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var glow_material: StandardMaterial3D
var base_emission_energy := 2.6
var is_grabbed := false
var is_snapped := false
var is_available := true

func configure(id: String, title: String, sides: int, color: Color) -> void:
	atom_id = id
	display_name = title
	set_meta("interaction_id", id)
	collision_layer = 1
	collision_mask = 0

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "PhysicalAtomMesh"
	var prism := CylinderMesh.new()
	prism.top_radius = 0.82
	prism.bottom_radius = 0.82
	prism.height = 0.34
	prism.radial_segments = sides
	prism.rings = 1
	mesh_instance.mesh = prism
	mesh_instance.rotation_degrees.x = 90.0
	glow_material = StandardMaterial3D.new()
	glow_material.albedo_color = Color("07120f")
	glow_material.metallic = 0.82
	glow_material.roughness = 0.18
	glow_material.emission_enabled = true
	glow_material.emission = color
	glow_material.emission_energy_multiplier = base_emission_energy
	mesh_instance.material_override = glow_material
	add_child(mesh_instance)

	collision_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.9
	cylinder.height = 0.45
	collision_shape.shape = cylinder
	collision_shape.rotation_degrees.x = 90.0
	add_child(collision_shape)

	var label := Label3D.new()
	label.name = "AtomLabel"
	label.text = title
	label.font_size = 48
	label.pixel_size = 0.0042
	label.modulate = Color("d8fff0")
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	label.position.z = 0.22
	label.no_depth_test = true
	add_child(label)

func set_available(is_available: bool) -> void:
	self.is_available = is_available
	visible = is_available
	monitorable = is_available
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not is_available)

func set_highlighted(highlighted: bool) -> void:
	if glow_material == null or is_grabbed or is_snapped:
		return
	glow_material.emission_energy_multiplier = 6.0 if highlighted else base_emission_energy
	scale = Vector3.ONE * (1.08 if highlighted else 1.0)

func set_grabbed(grabbed: bool) -> void:
	is_grabbed = grabbed
	if collision_shape != null:
		collision_shape.set_deferred("disabled", grabbed or is_snapped or not is_available)
	if glow_material != null:
		glow_material.emission_energy_multiplier = 8.0 if grabbed else base_emission_energy
	if not is_snapped:
		scale = Vector3.ONE * (1.14 if grabbed else 1.0)

func return_to_staging(target: Vector3) -> void:
	is_snapped = false
	set_grabbed(false)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, 0.32)
	tween.tween_property(self, "scale", Vector3.ONE, 0.32)

func move_into_socket(target: Vector3) -> void:
	is_grabbed = false
	is_snapped = true
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if glow_material != null:
		glow_material.emission_energy_multiplier = 8.5
	scale = Vector3.ONE * 1.12
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, 0.46)
	tween.tween_property(self, "scale", Vector3.ONE * 0.88, 0.46)
	if glow_material != null:
		tween.tween_property(glow_material, "emission_energy_multiplier", 4.5, 0.62)

func move_to_history(target: Vector3) -> void:
	is_grabbed = false
	is_snapped = true
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, 0.38)
	tween.tween_property(self, "scale", Vector3.ONE * 0.46, 0.38)

func reset_for_choice(target: Vector3) -> void:
	is_snapped = false
	is_grabbed = false
	position = target
	scale = Vector3.ONE
	set_available(true)
