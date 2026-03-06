extends "res://scripts/player/states/base_guardian_state.gd"
class_name StateSword

## Sword form: fast melee combo + defensive block special.

const PRIMARY_ATTACK_ANIMATIONS: Array[StringName] = [
	&"sword_attack",
	&"sword_attack2",
	&"sword_attack3"
]

var _primary_attack_index: int = 0


func _ready() -> void:
	form_id = &"Sword"
		
func enter(_previous_form: StringName) -> void:
	# Reset combo chain each time this form becomes active.
	_primary_attack_index = 0
	_play_animation(&"sword_idle")
	var guardian_sprite: AnimatedSprite2D = _player.get_node_or_null("GuardianSprite") as AnimatedSprite2D
	if guardian_sprite and not guardian_sprite.animation_finished.is_connected(_on_block_animation_finished):
		guardian_sprite.animation_finished.connect(_on_block_animation_finished)

func handle_action(action_name: StringName) -> bool:
	# Primary rotates through combo clips; special triggers block feedback.
	if is_locked:
		return false

	match action_name:
		&"primary_attack":
			return _play_next_primary_attack()
		&"special":
			_play_animation(&"sword_block")
			_spawn_block_fx()
			if _player and _player.has_method("shake_camera"):
				_player.shake_camera(10.0, 0.18)
			return true
		_:
			return false

func _on_block_animation_finished() -> void:
	if not _player:
		return
	var guardian_sprite: AnimatedSprite2D = _player.get_node_or_null("GuardianSprite") as AnimatedSprite2D
	if guardian_sprite and guardian_sprite.sprite_frames and guardian_sprite.animation == "sword_block":
		_play_animation(&"sword_idle")


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
