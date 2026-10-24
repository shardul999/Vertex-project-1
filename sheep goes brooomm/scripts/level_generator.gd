extends Node2D
## Builds the endless world in chunks to the right of the player and
## deletes chunks that fall far behind. Difficulty (0 to 1) grows with distance.

const SpikeStrip := preload("res://scripts/spike_strip.gd")
const Saw := preload("res://scripts/saw.gd")

const GROUND_MIN := 270.0   # highest the ground goes (smaller y = higher)
const GROUND_MAX := 450.0   # lowest the ground goes
const DEPTH := 800.0        # how far ground blocks extend downwards

## Optional art: drag textures here in the Inspector (select the World node).
@export var ground_texture: Texture2D
@export var spike_texture: Texture2D
@export var saw_texture: Texture2D

var next_x := -20.0    # where the next chunk starts
var ground_y := 400.0  # current ground height


func generate_until(limit_x: float) -> void:
	while next_x < limit_x:
		var d := minf(1.0, next_x / 16000.0)
		# [weight, function]; some chunks only appear after some distance
		var options := [
			[3.0, _chunk_flat],
			[3.0, _chunk_gap],
			[2.0, _chunk_step],
			[2.0 if d > 0.08 else 0.0, _chunk_floaters],
			[2.0 if d > 0.15 else 0.0, _chunk_saw],
			[1.5 if d > 0.3 else 0.0, _chunk_spike_block],
		]
		var total := 0.0
		for o in options:
			total += o[0]
		var roll := randf() * total
		for o in options:
			roll -= o[0]
			if roll <= 0.0:
				o[1].call(d)
				break


func cull_before(x: float) -> void:
	for child in get_children():
		if child.has_meta("right") and child.get_meta("right") < x:
			child.queue_free()


# ---------- Chunk types ----------

# Flat ground, often with a strip of spikes to hop over
func _chunk_flat(d: float) -> void:
	var length := randf_range(380, 640)
	_add_ground(next_x, length)
	if randf() < 0.45 + 0.4 * d:
		var count := int(randf_range(2, 3.99 + 2 * d))   # 2 to 5 spikes wide
		_add_spikes(next_x + randf_range(140, maxf(141, length - 140 - count * 24)), ground_y, count)
	next_x += length


# A pit to jump across, landing a little higher or lower
func _chunk_gap(d: float) -> void:
	var new_y := clampf(ground_y + randf_range(-70, 70), GROUND_MIN, GROUND_MAX)
	var gap := randf_range(80, 120 + 70 * d)
	if ground_y - new_y > 40:
		gap = minf(gap, 140)   # climbing gaps stay shorter so they're always makeable
	next_x += gap
	ground_y = new_y
	var length := randf_range(220, 380)
	_add_ground(next_x, length)
	next_x += length


# A ledge up or down
func _chunk_step(_d: float) -> void:
	var change := randf_range(40, 100) * (1 if randf() < 0.5 else -1)
	ground_y = clampf(ground_y + change, GROUND_MIN, GROUND_MAX)
	var length := randf_range(260, 420)
	_add_ground(next_x, length)
	next_x += length


# Floating platforms over a bottomless pit
func _chunk_floaters(d: float) -> void:
	var count := 3 if d > 0.5 else 2
	var x := next_x + randf_range(90, 130)
	var y := ground_y
	for i in count:
		var w := randf_range(120, 170) - 40 * d
		y = clampf(y - randf_range(-40, 80), 210, 430)
		_add_block(x, y, w, 22)
		x += w + randf_range(90, 125 + 40 * d)
	next_x = x
	ground_y = clampf(y + randf_range(-30, 60), GROUND_MIN, GROUND_MAX)
	var length := randf_range(300, 440)
	_add_ground(next_x, length)
	next_x += length


# A saw bobbing up and down: roll under while it's up, or jump it while it's down
func _chunk_saw(d: float) -> void:
	var length := 560.0
	_add_ground(next_x, length)
	var saw := Saw.new()
	saw.position = Vector2(next_x + length / 2, ground_y - 90)
	saw.speed = randf_range(1.7, 2.3) + d * 1.2
	saw.phase = randf() * TAU
	saw.texture = saw_texture
	saw.set_meta("right", next_x + length)
	add_child(saw)
	next_x += length


# A raised block with spikes on both sides
func _chunk_spike_block(d: float) -> void:
	var length := 620.0
	_add_ground(next_x, length)
	_add_spikes(next_x + 120, ground_y, 4)
	_add_block(next_x + 276, ground_y - 70, 110, 70)
	_add_spikes(next_x + 446, ground_y, 3 + roundi(d))
	next_x += length


# ---------- Building blocks ----------

func _add_ground(x: float, width: float) -> void:
	_add_block(x, ground_y, width, DEPTH)


## A solid rectangle with its top-left corner at (x, y)
func _add_block(x: float, y: float, w: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x, y)
	body.set_meta("right", x + w)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(w / 2, h / 2)
	body.add_child(shape)

	if ground_texture:
		var tex := TextureRect.new()
		tex.texture = ground_texture
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_TILE
		tex.size = Vector2(w, h)
		body.add_child(tex)
	else:
		var fill := ColorRect.new()
		fill.size = Vector2(w, h)
		body.add_child(fill)
		var top := ColorRect.new()
		top.size = Vector2(w, 6)
		body.add_child(top)
	add_child(body)


func _add_spikes(x: float, ground: float, count: int) -> void:
	var spikes := SpikeStrip.new()
	spikes.count = count
	spikes.texture = spike_texture
	spikes.position = Vector2(x, ground)
	spikes.set_meta("right", x + count * SpikeStrip.WIDTH)
	add_child(spikes)
