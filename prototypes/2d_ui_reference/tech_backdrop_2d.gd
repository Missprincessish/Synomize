# Reference-only flat prototype. The authoritative product scene is spatial 3D.
extends Control

var scan_position := 0.0
var morph_radius := 0.0
var morph_alpha := 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	scan_position = fmod(scan_position + delta * 85.0, max(size.y, 1.0))
	if morph_alpha > 0.0:
		morph_radius += delta * 760.0
		morph_alpha = maxf(0.0, morph_alpha - delta * 0.8)
	queue_redraw()

func pulse_morph() -> void:
	morph_radius = 20.0
	morph_alpha = 0.9

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("02070a"))

	var center := size * 0.5
	for x in range(0, int(size.x) + 1, 48):
		var fade := 0.025 + 0.035 * (1.0 - absf(float(x) - center.x) / maxf(center.x, 1.0))
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.0, 1.0, 0.65, fade), 1.0)
	for y in range(0, int(size.y) + 1, 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.0, 0.8, 1.0, 0.035), 1.0)

	for i in 42:
		var px := fmod(float(i * 173 + 41), maxf(size.x, 1.0))
		var py := fmod(float(i * 97 + 29), maxf(size.y, 1.0))
		var glow := 0.25 + 0.45 * sin(Time.get_ticks_msec() * 0.0015 + i)
		draw_circle(Vector2(px, py), 1.4, Color(0.2, 0.95, 1.0, glow))

	draw_line(Vector2(0, scan_position), Vector2(size.x, scan_position), Color(0.0, 1.0, 0.65, 0.11), 2.0)
	if morph_alpha > 0.0:
		draw_arc(center, morph_radius, 0.0, TAU, 96, Color(0.0, 1.0, 0.72, morph_alpha), 3.0)
		draw_arc(center, morph_radius * 0.72, 0.0, TAU, 96, Color(0.0, 0.75, 1.0, morph_alpha * 0.65), 2.0)
