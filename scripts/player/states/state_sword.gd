extends "res://scripts/player/states/base_guardian_state.gd"
class_name StateSword

## Sword form: fast melee combo + defensive block special.

const PRIMARY_ATTACK_ANIMATIONS: Array[StringName] = [
	&"sword_attack",
	&"sword_attack2",
	&"sword_attack3"
]

var _primary_attack_index: int = 0
var _action_sm = null

func _ready() -> void:
	form_id = &"Sword"

func enter(_previous_form: StringName) -> void:
	_primary_attack_index = 0
	_play_animation(&"sword_idle")
	_setup_action_state_machine()

func _setup_action_state_machine() -> void:
	if _action_sm:
		_action_sm.queue_free()
		_action_sm = null
	
	var ActionStateMachineScript = load("res://scripts/player/states/actions/action_state_machine.gd")
	_action_sm = ActionStateMachineScript.new()
	_player.add_child(_action_sm)
	_action_sm.setup(_player, _get_visuals_manager())
	
	var ActionIdleScript = load("res://scripts/player/states/actions/action_idle.gd")
	var ActionRunScript = load("res://scripts/player/states/actions/action_run.gd")
	var ActionAttackScript = load("res://scripts/player/states/actions/action_attack.gd")
	var ActionSpecialScript = load("res://scripts/player/states/actions/action_special.gd")
	
	_action_sm.add_action(&"Idle", ActionIdleScript.new())
	_action_sm.add_action(&"Run", ActionRunScript.new())
	
	var attack_action = ActionAttackScript.new()
	attack_action.attack_animations = PRIMARY_ATTACK_ANIMATIONS
	attack_action.attack_window_timing = Vector2(0.05, 0.18)
	_action_sm.add_action(&"Attack", attack_action)
	
	var special_action = ActionSpecialScript.new()
	special_action.special_animation = &"sword_block"
	special_action.can_move_during = false
	special_action.duration = 0.5
	_action_sm.add_action(&"Special", special_action)
	
	_action_sm.set_action(&"Idle")

func _get_visuals_manager() -> Node:
	if _player and _player.has_method("_visuals_manager"):
		var vm = _player.get("_visuals_manager")
		if vm:
			return vm
	return null

func handle_action(action_name: StringName) -> bool:
	if is_locked:
		return false
	
	if not _action_sm:
		return false
	
	match action_name:
		&"primary_attack":
			return _action_sm.set_action(&"Attack")
		&"special":
			return _action_sm.set_action(&"Special")
		_:
			return false

func can_accept_action(_action_name: StringName) -> bool:
	if is_locked:
		return false
	if _action_sm and not _action_sm.can_player_move():
		return false
	return true

func physics_update(delta: float) -> void:
	if _action_sm:
		_action_sm.physics_update(delta)

func update(delta: float) -> void:
	if _action_sm:
		_action_sm.update(delta)

func _spawn_block_fx() -> void:
	if not _player:
		return
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "SwordBlockFx"
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 10
	particles.lifetime = 0.18
	particles.explosiveness = 1.0
	particles.spread = 38.0
	particles.direction = Vector2(0, -1)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.3
	particles.modulate = Color(0.9, 0.9, 1.0, 0.7)
	particles.position = Vector2(0, -8)
	_player.add_child(particles)
	particles.emitting = true
	var cleanup_timer: SceneTreeTimer = _player.get_tree().create_timer(particles.lifetime + 0.2)
	cleanup_timer.timeout.connect(_cleanup_particles)

func _cleanup_particles() -> void:
	var fx = _player.get_node_or_null("SwordBlockFx")
	if fx and is_instance_valid(fx):
		fx.queue_free()