extends Node
class_name EnemyAnimationComponent

var _sprite: AnimatedSprite2D
var _attack_index: int = 0

func setup(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite

func has_animation(animation_name: StringName) -> bool:
	if _sprite == null or _sprite.sprite_frames == null:
		return false
	return _sprite.sprite_frames.has_animation(animation_name)

func play_if_exists(animation_name: StringName) -> bool:
	if not has_animation(animation_name):
		return false
	_sprite.play(animation_name)
	return true

func play_next_attack_animation(attack_animations: Array[StringName]) -> bool:
	if attack_animations.is_empty():
		return false

	for _attempt in range(attack_animations.size()):
		var animation_name: StringName = attack_animations[_attack_index]
		_attack_index = (_attack_index + 1) % attack_animations.size()
		if play_if_exists(animation_name):
			return true

	return false

func is_facing_left() -> bool:
	if _sprite == null:
		return false
	return _sprite.flip_h
