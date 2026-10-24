extends Node2D
## Runs the game: title, death and restart, the camera, streaming the
## world, the lava wall and falling into pits.

const PX_PER_METRE := 40.0
const PIT_Y := 680.0          # below this you've fallen into a pit
const PLAYER_SCREEN_X := 0.38 # where the ball sits across the screen (0 = left edge)

## Optional: drag a background image here in the Inspector (select Main).
@export var background_texture: Texture2D

enum State { TITLE, PLAY, DEAD }
var state := State.TITLE
var max_x := 0.0
var user_paused := false

@onready var world := $World
@onready var player := $Player
@onready var lava := $LavaWall
@onready var camera: Camera2D = $Camera2D
@onready var hud := $HUD


func _ready() -> void:
	player.died.connect(_on_player_died)
	if background_texture:
		var bg := TextureRect.new()
		bg.texture = background_texture
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		$Background.add_child(bg)
	_follow_camera(1.0)
	if Tuning.skip_title:
		_start()
	else:
		hud.show_screen("title")
		_sync_pause()


func _process(delta: float) -> void:
	hud.set_score(_distance(), Tuning.best)
	hud.update_debug(player)
	lava.visible = Tuning.chaser_on
	if state != State.PLAY or get_tree().paused:
		return

	max_x = maxf(max_x, player.position.x)
	_follow_camera(minf(1.0, delta * 7.0))
	var view_w := get_viewport_rect().size.x
	world.generate_until(camera.position.x + view_w + 900)
	world.cull_before(camera.position.x - view_w)

	if player.position.y > PIT_Y:
		player.die("Fell into a pit")
	elif Tuning.chaser_on:
		lava.advance(delta, player.position.x, max_x)
		if player.position.x - player.RADIUS < lava.wall_x:
			player.die("Caught by the lava wall")


func _follow_camera(weight: float) -> void:
	var view_w := get_viewport_rect().size.x
	var target_x: float = player.position.x + view_w * (0.5 - PLAYER_SCREEN_X)
	camera.position = Vector2(lerpf(camera.position.x, target_x, weight), 270)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tune"):
		hud.toggle_panel()
	elif event.is_action_pressed("pause"):
		if hud.is_panel_open():
			hud.toggle_panel()
		elif state == State.PLAY:
			user_paused = not user_paused
			hud.show_screen("pause" if user_paused else "")
	elif event.is_action_pressed("debug"):
		Tuning.show_debug = not Tuning.show_debug
	elif event.is_action_pressed("restart") and state != State.TITLE:
		_restart()
	elif event.is_action_pressed("start"):
		if state == State.TITLE:
			_start()
		elif state == State.DEAD:
			_restart()
	else:
		return
	get_viewport().set_input_as_handled()
	_sync_pause()


func _sync_pause() -> void:
	get_tree().paused = state == State.TITLE or user_paused or hud.is_panel_open()


func _start() -> void:
	state = State.PLAY
	hud.show_screen("")
	_sync_pause()


func _restart() -> void:
	Tuning.skip_title = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _distance() -> int:
	return int(maxf(0.0, max_x) / PX_PER_METRE)


func _on_player_died(cause: String) -> void:
	state = State.DEAD
	Tuning.save_best(_distance())
	_burst(player.position)
	await get_tree().create_timer(0.65).timeout
	if state == State.DEAD:
		hud.show_dead(cause, _distance(), Tuning.best)


# The ball pops into little red bits
func _burst(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.amount = 26
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180
	p.initial_velocity_min = 150
	p.initial_velocity_max = 520
	p.gravity = Vector2(0, 1500)
	p.scale_amount_min = 5
	p.scale_amount_max = 9
	p.color = Color("e63946")
	add_child(p)
	p.emitting = true
