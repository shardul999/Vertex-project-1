extends Area2D
## A row of spikes sitting on the ground. Its origin is the bottom-left corner.
## Touching it kills the player (1 health).

const WIDTH := 24.0    # one spike
const HEIGHT := 22.0

var count := 3
var texture: Texture2D


func _ready() -> void:
	# Hitbox a little smaller than the drawing, which feels fairer
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(count * WIDTH - 8, HEIGHT - 6)
	shape.shape = rect
	shape.position = Vector2(count * WIDTH / 2, -(HEIGHT - 6) / 2)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die("Popped on a spike")


func _draw() -> void:
	for i in count:
		var x := i * WIDTH
		if texture:
			draw_texture_rect(texture, Rect2(x, -HEIGHT, WIDTH, HEIGHT), false)
		else:
			var points := PackedVector2Array([Vector2(x, 0), Vector2(x + WIDTH / 2, -HEIGHT), Vector2(x + WIDTH, 0)])
			draw_colored_polygon(points, Color("dde4ec"))
			points.append(points[0])
			draw_polyline(points, Color("24324d"), 2)
