class_name StateBowAttack
extends PlayerStateNode

const Fsm = preload("res://scripts/features/player/player_fsm.gd")

var _combo_index: int = 0
var _animations: Array[StringName] = [&"shot", &"shot_2"]
var _animation_finished: bool = false

func _ready() -> void:
	state_id = Fsm.PlayerStates.BOW_ATTACK

func enter(_prev: int) -> void:
	_combo_index = 0
	_animation_finished = false
	_controller.spawn_arrow()
	_controller.play_animation(&"shot")
	var sprite: AnimatedSprite2D = _controller.get_sprite()
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func exit(_next: int) -> void:
	var sprite: AnimatedSprite2D = _controller.get_sprite()
	if sprite and sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.disconnect(_on_animation_finished)

func can_accept_command(cmd: StringName) -> bool:
	return cmd == Fsm.COMMAND_PRIMARY_ATTACK

func handle_action(cmd: StringName) -> bool:
	if cmd == Fsm.COMMAND_PRIMARY_ATTACK:
		if not _animation_finished:
			_combo_index = (_combo_index + 1) % _animations.size()
			_controller.spawn_arrow()
			_controller.play_animation(_animations[_combo_index])
			return true
	return false

func _on_animation_finished() -> void:
	_animation_finished = true

func physics_update(delta: float) -> void:
	_controller.velocity.x = 0.0
	if not _controller.is_on_floor() and _movement:
		_movement.apply_gravity(delta)
	if _animation_finished:
		_fsm.force_state(Fsm.PlayerStates.IDLE, &"animation_finished")
