extends CharacterBody2D
## The red ball. All of the movement physics lives in _physics_process.
## Every number comes from the Tuning autoload so the panel can change it live.

signal died(cause: String)

const RADIUS := 36.0

## Optional: drag your ball sprite from the FileSystem dock onto this.
@export var texture: Texture2D

var coyote_timer := 0.0    # counts down after leaving the ground
var buffer_timer := 0.0    # counts down after pressing jump
var is_jumping := false    # true while rising from a jump (for the short hop)
var gravity_mode := "grounded"   # shown in the debug overlay
var alive := true

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	if texture:
		sprite.texture = texture
		var s := RADIUS * 2.0 / maxf(texture.get_width(), texture.get_height())
		sprite.scale = Vector2(s, s)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var on_floor := is_on_floor()
	var dir := Input.get_axis("move_left", "move_right")

	# --- Jump buffer: remember a jump press for a short time
	if Input.is_action_just_pressed("jump"):
		buffer_timer = Tuning.jump_buffer if Tuning.jump_buffer > 0.0 else delta
	else:
		buffer_timer = maxf(0.0, buffer_timer - delta)

	# --- Coyote time: you can still jump shortly after rolling off a ledge
	if on_floor:
		coyote_timer = Tuning.coyote_time if Tuning.coyote_time > 0.0 else delta
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	# --- Horizontal: acceleration, deceleration and turn speed
	var target := dir * Tuning.max_speed
	var turning := dir != 0.0 and velocity.x != 0.0 and signf(dir) != signf(velocity.x)
	var rate: float
	if on_floor:
		if dir == 0.0:
			rate = Tuning.decel
		elif turning:
			rate = Tuning.turn_accel
		else:
			rate = Tuning.accel
	else:
		# In the air, turning keeps the same turn/accel ratio as on the ground
		if dir == 0.0:
			rate = Tuning.air_decel
		elif turning:
			rate = Tuning.air_accel * (Tuning.turn_accel / Tuning.accel)
		else:
			rate = Tuning.air_accel
	velocity.x = move_toward(velocity.x, target, rate * delta)

	# --- Air resistance: lose a share of velocity every second while airborne
	if not on_floor:
		velocity.x *= maxf(0.0, 1.0 - Tuning.air_drag * delta)
		velocity.y *= maxf(0.0, 1.0 - Tuning.air_drag * 0.35 * delta)

	# --- Jump when a buffered press meets the coyote window
	if buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = -Tuning.jump_speed
		buffer_timer = 0.0
		coyote_timer = 0.0
		is_jumping = true
		on_floor = false
	if velocity.y >= 0.0:
		is_jumping = false

	# --- Gravity, shaped so the jump feels good
	var g: float = Tuning.gravity
	gravity_mode = "rise"
	if velocity.y > 0.0:
		g *= Tuning.fall_mult           # fall faster than you rise
		gravity_mode = "fall"
	elif is_jumping and not Input.is_action_pressed("jump"):
		g *= Tuning.jump_cut_mult       # let go early = short hop
		gravity_mode = "short hop"
	if not on_floor and Input.is_action_pressed("jump") and absf(velocity.y) < Tuning.apex_threshold:
		g = Tuning.gravity * Tuning.apex_mult   # float a little at the top
		gravity_mode = "apex hang"
	if on_floor:
		gravity_mode = "grounded"
	velocity.y = minf(velocity.y + g * delta, Tuning.max_fall)

	# --- Move and collide (Godot does the collision for us)
	var fall_speed := velocity.y
	move_and_slide()

func die(cause: String) -> void:
	if not alive:
		return
	alive = false
	visible = false
	died.emit(cause)
