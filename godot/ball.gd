extends CharacterBody2D

var win_size : Vector2
const START_SPEED : int = 500
const ACCEL : int = 50
var speed : int
var dir : Vector2
const MAX_Y_VECTOR : float = 0.6

@onready var _left_paddle: Node2D = $"../leftPaddle"
@onready var _cpu_paddle: Node2D = $"../CPUPaddle"
@onready var _right_paddle: Node2D = $"../rightPaddle"
@onready var _bounce_sfx: AudioStreamPlayer = $"../bounce"

func _ready() -> void:
	win_size = get_viewport_rect().size


func new_ball():
	position.x = win_size.x / 2
	position.y = randi_range(200, win_size.y - 200)
	speed = START_SPEED
	dir = random_direction()

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(dir * speed * delta)
	if collision:
		var collider = collision.get_collider()

		if collider == _left_paddle or collider == _cpu_paddle or collider == _right_paddle:
			speed += ACCEL
			dir = new_direc(collider)
			_bounce_sfx.play()
		else:
			dir = dir.bounce(collision.get_normal())	
		
	
func random_direction() -> Vector2:
	return Vector2([1, -1].pick_random(), randf_range(-1.0, 1.0)).normalized()
	
	
func new_direc(collider) -> Vector2:
	var dist := position.y - collider.position.y
	var new_dir := Vector2(
		-signf(dir.x),
		(dist / (collider.p_height / 2.0)) * MAX_Y_VECTOR
	)
	return new_dir.normalized()
