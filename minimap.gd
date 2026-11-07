extends Control

var player: Node3D
var map_points: Array[Vector2] = [
	Vector2(-190, -24), Vector2(-100, -72), Vector2(8, -56), Vector2(126, -18),
	Vector2(180, 62), Vector2(112, 142), Vector2(-18, 132), Vector2(-148, 72), Vector2(-190, -24),
	Vector2(-126, -132), Vector2(-75, -205), Vector2(5, -225),
	Vector2(40, -118), Vector2(112, -186), Vector2(214, -206)
]

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.025, 0.045, 0.06, 0.78), true)
	draw_rect(rect, Color(0.65, 0.75, 0.8, 0.85), false, 2.0)
	var center := size * 0.5
	var scale_factor := minf(size.x, size.y) / 560.0
	var loop := PackedVector2Array()
	for i in range(9):
		var p := map_points[i]
		loop.append(center + Vector2(p.x, p.y) * scale_factor)
	draw_polyline(loop, Color("#b8b7ae"), 5.0, true)
	for i in range(8, map_points.size() - 1):
		var p1 := center + Vector2(map_points[i].x, map_points[i].y) * scale_factor
		var p2 := center + Vector2(map_points[i + 1].x, map_points[i + 1].y) * scale_factor
		draw_line(p1, p2, Color("#a6aaa5"), 3.0, true)
	if player != null:
		var pos := player.global_position
		var marker := center + Vector2(pos.x, pos.z) * scale_factor
		draw_circle(marker, 6.0, Color("#ffcc4a"))
		draw_arc(marker, 9.0, 0.0, TAU, 20, Color.WHITE, 1.5)
	var label := "MINI MAP"
	draw_string(ThemeDB.fallback_font, Vector2(9, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
