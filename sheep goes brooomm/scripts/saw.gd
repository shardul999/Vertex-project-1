extends Area2D
## A spinning saw that bobs up and down. Touching it kills the player.

var radius := 30.0
var amplitude := 75.0   # how far it moves up and down from its start
var speed := 2.0        # how fast it bobs
var phase := 0.0        # where in the bob it starts
var texture: Texture2D

var _base_y := 0.0
var _time := 0.0
var _spin := 0.0


func _ready() -> void:
	_base_y = position.y
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius - 5   # a bit smaller than the drawing
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_time += delta
	_spin += delta * 9.0
	position.y = _base_y + sin(_time * speed + phase) * amplitude
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die("Sliced by a saw")


func _draw() -> void:
	# Track the saw slides along (drawn relative to where the saw is now)
	var offset := _base_y - position.y
	draw_line(Vector2(0, offset - amplitude - radius), Vector2(0, offset + amplitude), Color(0.14, 0.2, 0.3, 0.25), 3)
	draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
	if texture:
		draw_texture_rect(texture, Rect2(-radius, -radius, radius * 2, radius * 2), false)
	else:
		var points := PackedVector2Array()
		for i in 24:
			var r := radius - 7 if i % 2 else radius
			var a := TAU * i / 24.0
			points.append(Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(points, Color("dde4ec"))
		points.append(points[0])
		draw_polyline(points, Color("24324d"), 2)
		draw_circle(Vector2.ZERO, 7, Color("24324d"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
