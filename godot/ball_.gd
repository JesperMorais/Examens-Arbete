extends Node2D

var velocity := Vector2.ZERO
var assigned_mac := ""

signal bounced
signal missed

var _screen_height: float
var _paddle_container: Node

@onready var _color_rect: ColorRect = $ColorRect

func _ready():
	_screen_height = get_viewport_rect().size.y
	_paddle_container = get_parent().get_parent().paddle_container

func set_color(c: Color):
	_color_rect.color = c

func _process(delta: float):
	position += velocity * delta

	if position.y > _screen_height:
		missed.emit()
		queue_free()
		return

	if velocity.y <= 0:
		return

	for paddle in _paddle_container.get_children():
		if paddle.assigned_mac == assigned_mac and _intersects_paddle(paddle):
			velocity.y = -abs(velocity.y)
			position.y = paddle.position.y - _screen_height / 2 + 255
			bounced.emit()
			break

func _intersects_paddle(paddle) -> bool:
	var my_rect := Rect2(position - Vector2(12, 12), Vector2(24, 24))
	var pad_rect := Rect2(paddle.position - paddle.size / 2, paddle.size)
	return my_rect.intersects(pad_rect)
