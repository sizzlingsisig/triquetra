extends "res://scripts/player/states/base_guardian_state.gd"
class_name StateSpear

const PRIMARY_ATTACK_ANIMATIONS: Array[StringName] = [
	&"spear_attack",
	&"spear_attack_2"
]

var _primary_attack_index: int = 0

func _ready() -> void:
	form_id = &"Spear"

func enter(_previous_form: StringName) -> void:
	_primary_attack_index = 0
	_play_animation(&"spear_idle")

func handle_action(action_name: StringName) -> bool:
	if is_locked:
		return false

	match action_name:
		&"primary_attack":
			return _play_next_primary_attack()
		&"special":
			var played: bool = _play_first_available([&"spear_impale"])
			if played:
				_spawn_impale_fx()
				# 3D tracking VFX stub
				if _player and _player.has_method("shake_camera"):
					_player.shake_camera(6.0, 0.12)
			return played
		_:
			return false

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
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _play_next_primary_attack() -> bool:
	for _attempt in range(PRIMARY_ATTACK_ANIMATIONS.size()):
		var animation_name := PRIMARY_ATTACK_ANIMATIONS[_primary_attack_index]
		_primary_attack_index = (_primary_attack_index + 1) % PRIMARY_ATTACK_ANIMATIONS.size()
		if _play_first_available([animation_name]):
			return true

	return false
