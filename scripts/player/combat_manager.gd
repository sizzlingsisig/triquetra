extends Node
class_name CombatManager

## Manages player combat: attack area, hit detection, hit tracking.

signal attack_window_opened()
signal attack_window_closed()
signal hit_registered(target: Node)

@export var attack_area_forward_offset: float = 24.0

var _player: CharacterBody2D = null
var _attack_area: Area2D = null
var _attack_area_base_position: Vector2 = Vector2.ZERO
var _hit_tracking: Dictionary = {}
var _visuals_manager = null

func setup(player: CharacterBody2D, attack_area: Area2D, visuals_manager = null) -> void:
	_player = player
	_attack_area = attack_area
	_visuals_manager = visuals_manager
	_cache_attack_area_base()

func _cache_attack_area_base() -> void:
	if _attack_area:
		_attack_area_base_position = _attack_area.position

func set_attack_area_active(is_active: bool, facing_left: bool) -> void:
	if not _attack_area:
		return
	
	_attack_area.monitoring = is_active
	_attack_area.monitorable = is_active
	
	var jump_offset: Vector2 = Vector2.ZERO
	if _visuals_manager and _visuals_manager.has_method("get_jump_offset"):
		jump_offset = _visuals_manager.get_jump_offset()
	
	if is_active:
		_hit_tracking.clear()
		var forward_sign: float = -1.0 if facing_left else 1.0
		_attack_area.position = _attack_area_base_position + Vector2(attack_area_forward_offset * forward_sign, 0.0) + jump_offset
		attack_window_opened.emit()
	else:
		_attack_area.position = _attack_area_base_position + jump_offset
		attack_window_closed.emit()

func apply_hit_detection(active_form: StringName) -> void:
	if not _attack_area:
		return
	if not _attack_area.monitoring:
		return

	for overlap in _attack_area.get_overlapping_areas():
		if not overlap:
			continue
		if overlap.name != "AttackHitbox":
			continue

		var enemy_node: Node = overlap.get_parent()
		if not enemy_node:
			continue

		var enemy_id := enemy_node.get_instance_id()
		if _hit_tracking.get(enemy_id, false):
			continue
		_hit_tracking[enemy_id] = true

		if enemy_node.has_method("receive_player_hit"):
			enemy_node.receive_player_hit(active_form)
			hit_registered.emit(enemy_node)

func receive_enemy_hit(active_state: Node) -> void:
	if not active_state:
		return
	if active_state.has_method("receive_lethal_damage"):
		active_state.receive_lethal_damage()

func reset() -> void:
	_hit_tracking.clear()
	if _attack_area:
		_attack_area.position = _attack_area_base_position
		_attack_area.monitoring = false
		_attack_area.monitorable = false

func get_attack_area() -> Area2D:
	return _attack_area