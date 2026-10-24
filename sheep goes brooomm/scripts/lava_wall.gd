extends Node2D
## A wall of lava that chases the player from the left.
## It is never more than CATCH_UP pixels behind, and speeds up with distance.

const CATCH_UP := 950.0

var wall_x := -700.0
var _time := 0.0


func advance(delta: float, player_x: float, max_x: float) -> void:
	_time += delta
	var speed := Tuning.wall_speed * (1.0 + max_x / 15000.0)
	wall_x = maxf(wall_x + speed * delta, player_x - CATCH_UP)
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array([Vector2(wall_x - 2000, -200)])
	for i in 26:
		var y := -200.0 + i * 40.0
		points.append(Vector2(wall_x + sin(y * 0.05 + _time * 6.0) * 10.0, y))
	points.append(Vector2(wall_x - 2000, 840))
	draw_colored_polygon(points, Color("ff7a3d"))
	draw_rect(Rect2(wall_x - 2000, -200, 1880, 1040), Color("c2410c"))
