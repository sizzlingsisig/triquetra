class_name StateAttacking
extends PlayerStateNode

var _combo_index: int = 0
var _animations: Array[StringName] = [&"attack", &"attack2", &"attack3", &"run_attack"]
var _animation_finished: bool = false

func _ready() -> void:
	state_id = Fsm.PlayerStates.ATTACKING

func enter(_prev: int) -> void:
	_combo_index = 0
	_animation_finished = false
	_play_current_combo()
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
			_play_current_combo()
			return true
	return false

func _play_current_combo() -> void:
	var anim: StringName = _animations[_combo_index]
	_controller.spawn_hitbox()
	_controller.play_animation(String(anim))

func _on_animation_finished() -> void:
	_animation_finished = true

func physics_update(delta: float) -> void:
	if _movement:
		_movement.apply_movement(delta, 0.5)
	if _animation_finished:
		_fsm.force_state(Fsm.PlayerStates.IDLE, &"animation_finished")