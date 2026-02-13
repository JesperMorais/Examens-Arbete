extends Node2D

var velocity := Vector2.ZERO
var smooth_velocity := Vector2.ZERO
@export var speed := 500
@export var radius := 0
var color := Color.RED
var mac := ""

const SMOOTH_FACTOR := 10.0 # ~same feel as 0.1 at 60fps

@onready var _label: Label = $macname

func _ready():
	_label.text = mac
	_label.position = Vector2(0, -radius - 10)
	queue_redraw()

func set_velocity(v: Vector2):
	velocity = v

func _process(delta: float):
	smooth_velocity = smooth_velocity.lerp(velocity, 1.0 - exp(-SMOOTH_FACTOR * delta))

	var old_pos := position
	position += smooth_velocity * delta * speed

	var screen_size := get_viewport_rect().size
	position.x = clamp(position.x, radius, screen_size.x - radius)
	position.y = clamp(position.y, radius, screen_size.y - radius)

	if position != old_pos:
		queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, radius, color)
