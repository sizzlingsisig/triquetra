extends Node
class_name EnemyMovementComponent

signal facing_changed(is_left: bool)

var _sprite: AnimatedSprite2D
var _enemy_attack_area: Area2D
var _sprite_faces_left_when_not_flipped: bool = false
var _enemy_attack_area_base_position: Vector2 = Vector2.ZERO
var _attack_area_offset_from_sprite_x: float = 0.0
var _facing_left: bool = false

func setup(sprite: AnimatedSprite2D, enemy_attack_area: Area2D, sprite_faces_left_when_not_flipped: bool) -> void:
	_sprite = sprite
	_enemy_attack_area = enemy_attack_area
	_sprite_faces_left_when_not_flipped = sprite_faces_left_when_not_flipped
	if _enemy_attack_area:
		_enemy_attack_area_base_position = _enemy_attack_area.position
	if _sprite != null:
		_attack_area_offset_from_sprite_x = _enemy_attack_area_base_position.x - _sprite.position.x
	else:
		_attack_area_offset_from_sprite_x = _enemy_attack_area_base_position.x
	_facing_left = _derive_facing_left_from_sprite()
	_update_attack_area_facing()

func set_facing_from_direction(direction: float) -> void:
	if _sprite == null:
		return
	if absf(direction) <= 0.01:
		return
	var previous_facing_left: bool = _facing_left
	_facing_left = direction < 0.0
	if _sprite_faces_left_when_not_flipped:
		_sprite.flip_h = not _facing_left
	else:
		_sprite.flip_h = _facing_left
	_update_attack_area_facing()
	if previous_facing_left != _facing_left:
		facing_changed.emit(_facing_left)

func is_facing_left() -> bool:
	return _facing_left

func try_get_player_move_speed(player: Node2D) -> float:
	if not is_instance_valid(player):
		return -1.0
	if player.has_method("get"):
		var movement_component: Variant = player.get("movement_component")
		if movement_component != null and movement_component.has_method("get"):
			var move_speed_value: Variant = movement_component.get("move_speed")
			if typeof(move_speed_value) in [TYPE_FLOAT, TYPE_INT]:
				var speed: float = float(move_speed_value)
				if speed > 0.0:
					return speed
	return -1.0

func _update_attack_area_facing() -> void:
	if _enemy_attack_area == null:
		return
	var next_x: float = _enemy_attack_area_base_position.x
	if _sprite != null:
		next_x = _sprite.position.x + (_attack_area_offset_from_sprite_x if _facing_left else -_attack_area_offset_from_sprite_x)
	else:
		var offset_x: float = absf(_enemy_attack_area_base_position.x)
		if _facing_left:
			offset_x = -offset_x
		next_x = offset_x
	_enemy_attack_area.position = Vector2(next_x, _enemy_attack_area_base_position.y)

func _derive_facing_left_from_sprite() -> bool:
	if _sprite == null:
		return false
	if _sprite_faces_left_when_not_flipped:
		return not _sprite.flip_h
	return _sprite.flip_h
