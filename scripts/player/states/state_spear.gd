extends "res://scripts/player/states/base_guardian_state.gd"
class_name StateSpear

## Spear form: reach-focused melee combo + impale special.

const PRIMARY_ATTACK_ANIMATIONS: Array[StringName] = [
	&"spear_attack",
	&"spear_attack_2"
]

var _primary_attack_index: int = 0
var _action_sm = null

func _ready() -> void:
	form_id = &"Spear"

func enter(_previous_form: StringName) -> void:
	_primary_attack_index = 0
	_play_animation(&"spear_idle")
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
	attack_action.attack_window_timing = Vector2(0.04, 0.16)
	_action_sm.add_action(&"Attack", attack_action)
	
	var special_action = ActionSpecialScript.new()
	special_action.special_animation = &"spear_impale"
	special_action.can_move_during = false
	special_action.duration = 0.4
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
			_spawn_impale_fx()
			if _player and _player.has_method("shake_camera"):
				_player.shake_camera(6.0, 0.12)
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

func should_open_attack_window(action_name: StringName) -> bool:
	if action_name == &"special":
		return true
	return action_name == &"primary_attack"

func _spawn_impale_fx() -> void:
	if not _player:
		return
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "SpearImpaleFx"
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 12
	particles.lifetime = 0.16
	particles.explosiveness = 1.0
	particles.spread = 24.0
	particles.direction = Vector2(0, -1)
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.2
	particles.modulate = Color(0.8, 1.0, 0.8, 0.7)
	particles.position = Vector2(0, -10)
	_player.add_child(particles)
	particles.emitting = true
	var cleanup_timer: SceneTreeTimer = _player.get_tree().create_timer(particles.lifetime + 0.2)
	cleanup_timer.timeout.connect(_cleanup_particles)

func _cleanup_particles() -> void:
	var fx = _player.get_node_or_null("SpearImpaleFx")
	if fx and is_instance_valid(fx):
		fx.queue_free()