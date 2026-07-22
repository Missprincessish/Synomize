class_name VectorVerseMorphingPanel2DReference
extends PanelContainer

const GREEN := Color("24ff9a")
const CYAN := Color("41dfff")
const BLACK := Color("03080b")

var mode := "idle"
var morph_value := 0.0
var target_morph := 0.0
var pulse_energy := 0.0
var sweep := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_update_pivot)
	_update_pivot()
	set_process(true)

func set_mode(next_mode: String) -> void:
	mode = next_mode
	target_morph = {
		"idle": 0.0,
		"routing": 0.38,
		"compiled": 0.70,
		"verified": 1.0
	}.get(mode, 0.0)
	pulse_morph()

func pulse_morph() -> void:
	pulse_energy = 1.0

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func _process(delta: float) -> void:
	morph_value = lerpf(morph_value, target_morph, 1.0 - exp(-delta * 5.5))
	pulse_energy = maxf(0.0, pulse_energy - delta * 1.25)
	sweep = fmod(sweep + delta * 0.12, 1.0)
	var breathing := sin(Time.get_ticks_msec() * 0.0022) * 0.0015
	var impact := sin((1.0 - pulse_energy) * PI) * pulse_energy * 0.012
	scale = Vector2.ONE * (1.0 + breathing + impact)
	queue_redraw()

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return

	var pulse := pulse_energy
	var cut := lerpf(22.0, 54.0, morph_value) + pulse * 14.0
	var shoulder := lerpf(74.0, 126.0, morph_value)
	var notch := lerpf(8.0, 25.0, morph_value)
	var shape := _panel_shape(Rect2(Vector2.ZERO, size), cut, shoulder, notch)

	draw_colored_polygon(shape, BLACK)
	draw_polyline(_closed(shape), Color(GREEN, 0.64 + pulse * 0.28), 2.2 + pulse * 1.8, true)

	for layer in 3:
		var inset := 7.0 + layer * 7.0
		var inner_rect := Rect2(Vector2(inset, inset), size - Vector2.ONE * inset * 2.0)
		var inner := _panel_shape(inner_rect, maxf(8.0, cut - inset * 0.45), maxf(30.0, shoulder - inset), maxf(3.0, notch - layer * 2.0))
		var tint := CYAN if layer == 1 else GREEN
		draw_polyline(_closed(inner), Color(tint, 0.14 - layer * 0.025 + pulse * 0.08), 1.0, true)

	_draw_power_rails(cut, shoulder)
	_draw_corner_modules(cut)
	_draw_circuitry()
	_draw_core_indicator()

func _panel_shape(rect: Rect2, cut: float, shoulder: float, notch: float) -> PackedVector2Array:
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var mid_y := (top + bottom) * 0.5
	return PackedVector2Array([
		Vector2(left + cut, top),
		Vector2(right - cut, top),
		Vector2(right, top + cut),
		Vector2(right, mid_y - shoulder),
		Vector2(right - notch, mid_y - shoulder + 18.0),
		Vector2(right - notch, mid_y + shoulder - 18.0),
		Vector2(right, mid_y + shoulder),
		Vector2(right, bottom - cut),
		Vector2(right - cut, bottom),
		Vector2(left + cut, bottom),
		Vector2(left, bottom - cut),
		Vector2(left, mid_y + shoulder),
		Vector2(left + notch, mid_y + shoulder - 18.0),
		Vector2(left + notch, mid_y - shoulder + 18.0),
		Vector2(left, mid_y - shoulder),
		Vector2(left, top + cut)
	])

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result

func _draw_power_rails(cut: float, shoulder: float) -> void:
	var rail_y := 11.0
	var rail_start := cut + 56.0
	var rail_end := size.x - cut - 56.0
	var lit_end := lerpf(rail_start, rail_end, sweep)
	draw_line(Vector2(rail_start, rail_y), Vector2(rail_end, rail_y), Color(GREEN, 0.16), 3.0)
	draw_line(Vector2(rail_start, rail_y), Vector2(lit_end, rail_y), Color(CYAN, 0.92), 2.0)
	draw_line(Vector2(rail_start, size.y - rail_y), Vector2(rail_end, size.y - rail_y), Color(GREEN, 0.16), 3.0)
	draw_line(Vector2(rail_end, size.y - rail_y), Vector2(rail_end - (lit_end - rail_start), size.y - rail_y), Color(GREEN, 0.72), 2.0)

	var center_y := size.y * 0.5
	for side_x in [14.0, size.x - 14.0]:
		draw_line(Vector2(side_x, center_y - shoulder + 28.0), Vector2(side_x, center_y + shoulder - 28.0), Color(CYAN, 0.38), 2.0)
		for index in 5:
			var y := center_y - 54.0 + index * 27.0
			draw_circle(Vector2(side_x, y), 2.2, Color(GREEN, 0.75))

func _draw_corner_modules(cut: float) -> void:
	var length := 46.0 + morph_value * 20.0
	var alpha := 0.38 + pulse_energy * 0.4
	var corners := [
		[Vector2(cut + 12.0, 23.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(size.x - cut - 12.0, 23.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(cut + 12.0, size.y - 23.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
		[Vector2(size.x - cut - 12.0, size.y - 23.0), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)]
	]
	for module in corners:
		var origin: Vector2 = module[0]
		var horizontal: Vector2 = module[1]
		var vertical: Vector2 = module[2]
		draw_line(origin, origin + horizontal * length, Color(GREEN, alpha), 3.0)
		draw_line(origin, origin + vertical * 18.0, Color(CYAN, alpha), 2.0)
		draw_circle(origin, 3.5 + pulse_energy * 2.0, Color(CYAN, alpha))

func _draw_circuitry() -> void:
	var center_y := size.y * 0.5
	var alpha := 0.11 + morph_value * 0.08
	for index in 6:
		var offset := float(index * 31)
		var left_path := PackedVector2Array([
			Vector2(28.0, 112.0 + offset),
			Vector2(46.0 + offset * 0.12, 112.0 + offset),
			Vector2(58.0 + offset * 0.12, 124.0 + offset),
			Vector2(94.0, 124.0 + offset)
		])
		draw_polyline(left_path, Color(GREEN, alpha), 1.0, true)
		var mirrored := PackedVector2Array()
		for point in left_path:
			mirrored.append(Vector2(size.x - point.x, size.y - point.y + center_y * 0.0))
		draw_polyline(mirrored, Color(CYAN, alpha), 1.0, true)

func _draw_core_indicator() -> void:
	var center := Vector2(size.x * 0.5, 25.0)
	var spin := Time.get_ticks_msec() * 0.0015
	draw_arc(center, 12.0 + morph_value * 3.0, spin, spin + PI * 1.35, 24, Color(CYAN, 0.75), 2.0, true)
	draw_arc(center, 18.0 + pulse_energy * 8.0, -spin, -spin + PI, 24, Color(GREEN, 0.48), 1.0, true)
	draw_circle(center, 2.5, Color(GREEN, 0.95))
