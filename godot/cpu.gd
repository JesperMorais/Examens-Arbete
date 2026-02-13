#cpu.gd
extends StaticBody2D

var ball_pos : Vector2
var dist : int
var move_by : int
var win_height : int
var p_height : int

@onready var _ball: Node2D = $"../ball"
@onready var _paddle_speed: float = get_parent().PEDDLE_SPEED

func _ready() -> void:
	win_height = get_viewport_rect().size.y
	p_height = $ColorRect.get_size().y


func _process(delta: float) -> void:
	ball_pos = _ball.position
	dist = position.y - ball_pos.y

	if abs(dist) > _paddle_speed * delta:
		move_by = _paddle_speed * delta * signf(dist)
	else:
		move_by = dist
		
	position.y -= move_by
	
	position.y = clamp(position.y, p_height / 2, win_height - p_height / 2)
