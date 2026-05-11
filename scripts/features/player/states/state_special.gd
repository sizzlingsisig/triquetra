class_name StateSpecial
extends PlayerStateNode

const Fsm = preload("res://scripts/features/player/player_fsm.gd")

var _animation_finished: bool = false
var _timer: float = 0.0
const SPECIAL_DURATION: float = 1.2

func _ready() -> void:
	state_id = Fsm.PlayerStateNode.SPECIAL

func enter(_prev: int) -> void:
	_animation_finished = false
	_timer = 0.0
	var sprite: AnimatedSprite2D = _controller.get_sprite()
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func exit(_next: int) -> void:
	var sprite: AnimatedSprite2D = _controller.get_sprite()
	if sprite and sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.disconnect(_on_animation_finished)

func can_accept_command(_cmd: StringName) -> bool:
	return false

func handle_action(_cmd: StringName) -> bool:
	return false

func _on_animation_finished() -> void:
	_animation_finished = true

func physics_update(delta: float) -> void:
	_timer += delta
	if _movement:
		_movement.apply_movement(delta)
	if _timer >= SPECIAL_DURATION:
		_controller.velocity.x = 0.0
		_fsm.force_state(Fsm.PlayerStateNode.IDLE, &"timeout")
	elif _animation_finished:
		_controller.velocity.x = 0.0
		_fsm.force_state(Fsm.PlayerStateNode.IDLE, &"animation_finished")