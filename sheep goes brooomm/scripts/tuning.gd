extends Node
## Autoload (Project Settings > Globals). Holds every physics value the
## player reads, so the tuning panel can change them while the game runs.
## Values survive restarts because this node is never freed.
## Units are pixels and seconds. The ball radius is 18px.

# Ground movement
var max_speed := 420.0      # top rolling speed
var accel := 2400.0         # speed gained per second while holding a direction
var decel := 3000.0         # speed lost per second when no key is held
var turn_accel := 5600.0    # used instead of accel when pushing against your motion

# Air
var air_accel := 1500.0     # steering strength mid-air
var air_decel := 350.0      # slowdown mid-air with no key held
var air_drag := 0.45        # air resistance: share of velocity lost per second

# Jump
var jump_speed := 880.0     # upward launch speed
var gravity := 2600.0       # gravity while rising
var fall_mult := 1.7        # extra gravity while falling
var jump_cut_mult := 2.8    # extra gravity when jump is released early (short hop)
var apex_mult := 0.55       # lower gravity near the top of a held jump
var apex_threshold := 80.0  # vertical speed that counts as "near the top"
var max_fall := 1250.0      # terminal velocity

# Forgiveness
var coyote_time := 0.10     # can still jump this long after leaving a ledge
var jump_buffer := 0.13     # a jump pressed this early before landing still counts

# World
var chaser_on := true       # the lava wall chasing you
var wall_speed := 150.0     # lava wall starting speed

# Not physics
var show_debug := false
var skip_title := false     # set on restart so the title screen only shows once

const PRESETS := {
	"Snappy": {"max_speed": 480.0, "accel": 4200.0, "decel": 5200.0, "turn_accel": 9000.0, "air_accel": 2600.0, "air_drag": 0.2, "jump_speed": 980.0, "gravity": 3400.0, "fall_mult": 2.0, "jump_cut_mult": 3.5, "apex_mult": 0.7, "coyote_time": 0.08, "jump_buffer": 0.1},
	"Floaty": {"max_speed": 380.0, "accel": 1600.0, "decel": 1400.0, "turn_accel": 3000.0, "air_accel": 900.0, "air_drag": 0.9, "jump_speed": 700.0, "gravity": 1500.0, "fall_mult": 1.15, "jump_cut_mult": 1.8, "apex_mult": 0.35, "apex_threshold": 140.0, "max_fall": 700.0},
	"Icy": {"max_speed": 460.0, "accel": 900.0, "decel": 260.0, "turn_accel": 900.0, "air_decel": 80.0, "air_drag": 0.15},
}

# Slider definitions for the tuning panel: [property, label, min, max, step]
const SLIDERS := [
	["Ground movement", [
		["max_speed", "Top speed", 100, 800, 10],
		["accel", "Acceleration", 200, 8000, 50],
		["decel", "Deceleration", 100, 8000, 50],
		["turn_accel", "Turn speed", 200, 12000, 100],
	]],
	["Air", [
		["air_accel", "Air control", 0, 6000, 50],
		["air_decel", "Air brake", 0, 4000, 50],
		["air_drag", "Air resistance", 0, 3, 0.05],
	]],
	["Jump", [
		["jump_speed", "Jump strength", 300, 1400, 10],
		["gravity", "Gravity", 600, 6000, 50],
		["fall_mult", "Fall gravity x", 1, 4, 0.05],
		["jump_cut_mult", "Short hop gravity x", 1, 6, 0.1],
		["apex_mult", "Apex hang x", 0.2, 1, 0.05],
		["apex_threshold", "Apex window", 0, 300, 5],
		["max_fall", "Max fall speed", 300, 2500, 25],
	]],
	["Forgiveness", [
		["coyote_time", "Coyote time (s)", 0, 0.3, 0.01],
		["jump_buffer", "Jump buffer (s)", 0, 0.3, 0.01],
	]],
	["World", [
		["wall_speed", "Lava wall speed", 0, 400, 5],
	]],
]

var _defaults := {}
var best := 0
const SAVE_PATH := "user://save.cfg"


func _ready() -> void:
	# Remember the starting values so Reset can restore them
	for group in SLIDERS:
		for row in group[1]:
			_defaults[row[0]] = get(row[0])
	_setup_input()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = cfg.get_value("score", "best", 0)


func reset_values() -> void:
	for key in _defaults:
		set(key, _defaults[key])


func apply_preset(preset_name: String) -> void:
	reset_values()
	var preset: Dictionary = PRESETS.get(preset_name, {})
	for key in preset:
		set(key, preset[key])


func save_best(distance: int) -> void:
	if distance <= best:
		return
	best = distance
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.save(SAVE_PATH)


## Returns the current values as GDScript you can paste over the vars above.
func values_as_code() -> String:
	var lines: PackedStringArray = []
	for key in _defaults:
		lines.append("var %s := %s" % [key, str(float(get(key)))])
	return "\n".join(lines)


# Keyboard controls are added here in code so they can't get lost.
# You can also see/edit actions in Project Settings > Input Map.
func _setup_input() -> void:
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("jump", [KEY_SPACE, KEY_UP, KEY_W])
	_add_action("start", [KEY_ENTER, KEY_KP_ENTER])
	_add_action("restart", [KEY_R])
	_add_action("pause", [KEY_P, KEY_ESCAPE])
	_add_action("tune", [KEY_T])
	_add_action("debug", [KEY_G])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
