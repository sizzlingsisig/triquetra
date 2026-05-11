extends Node
class_name EnemyTargetComponent

signal target_acquired(target: Node2D)
signal target_lost

var _enemy: Enemy
var _vision_raycast: RayCast2D
var _target_player: Node2D
var _target_player_path: NodePath = NodePath("")
var _vision_range: float = 190.0
var _vision_y_offset: float = 0.0
var _target_retry_delay: float = 0.4
var _target_retry_scheduled: bool = false
var _is_player_target: Callable

func setup(
	enemy: Enemy,
	vision_raycast: RayCast2D,
	target_player_path: NodePath,
	vision_range: float,
	vision_y_offset: float,
	target_retry_delay: float,
	is_player_target: Callable
) -> void:
	_enemy = enemy
	_vision_raycast = vision_raycast
	_target_player_path = target_player_path
	_vision_range = vision_range
	_vision_y_offset = vision_y_offset
	_target_retry_delay = target_retry_delay
	_is_player_target = is_player_target
	_target_player = _resolve_target_player()
	if _target_player == null:
		_schedule_target_retry()
	else:
		target_acquired.emit(_target_player)

func set_facing_left(is_left: bool) -> void:
	if _vision_raycast == null:
		return
	var direction_x: float = -1.0 if is_left else 1.0
	_vision_raycast.rotation = 0.0
	_vision_raycast.target_position = Vector2(direction_x * _vision_range, _vision_y_offset)

func physics_update() -> void:
	_refresh_target_player_if_needed()

func get_target_player() -> Node2D:
	return _target_player

func has_line_of_sight() -> bool:
	if _vision_raycast == null:
		return false
	if not is_instance_valid(_target_player):
		_refresh_target_player_if_needed()
		if not is_instance_valid(_target_player):
			return false
	_vision_raycast.force_raycast_update()
	if not _vision_raycast.is_colliding():
		return false
	var collider: Object = _vision_raycast.get_collider()
	return collider == _target_player

func get_detected_player() -> Node2D:
	if _vision_raycast == null:
		return null
	if not is_instance_valid(_target_player):
		_refresh_target_player_if_needed()
		if not is_instance_valid(_target_player):
			return null
	_vision_raycast.force_raycast_update()
	if not _vision_raycast.is_colliding():
		return null
	var collider: Object = _vision_raycast.get_collider()
	if collider == _target_player:
		return _target_player
	return null

func _refresh_target_player_if_needed() -> void:
	if is_instance_valid(_target_player):
		return
	var had_target: bool = _target_player != null
	_target_player = _resolve_target_player()
	if _target_player == null:
		if had_target:
			target_lost.emit()
		_schedule_target_retry()
	else:
		target_acquired.emit(_target_player)

func _schedule_target_retry() -> void:
	if _target_retry_scheduled:
		return
	_target_retry_scheduled = true
	var tree: SceneTree = get_tree()
	if tree == null:
		_target_retry_scheduled = false
		return
	var timer: SceneTreeTimer = tree.create_timer(maxf(_target_retry_delay, 0.0))
	timer.timeout.connect(_on_target_retry_timeout)

func _on_target_retry_timeout() -> void:
	_target_retry_scheduled = false
	if not is_instance_valid(_target_player):
		_target_player = _resolve_target_player()
		if _target_player != null:
			target_acquired.emit(_target_player)

func _resolve_target_player() -> Node2D:
	if _enemy == null:
		return null
	if _target_player_path != NodePath(""):
		var from_path: Node = _enemy.get_node_or_null(_target_player_path)
		if from_path is Node2D and _is_valid_player_target(from_path):
			return from_path as Node2D

	var tree: SceneTree = get_tree()
	if tree:
		var grouped: Node = tree.get_first_node_in_group("player")
		if grouped is Node2D and _is_valid_player_target(grouped):
			return grouped as Node2D

	if tree and tree.current_scene:
		var candidate: Node2D = _find_player_candidate(tree.current_scene)
		if candidate:
			return candidate

	return null

func _find_player_candidate(root: Node) -> Node2D:
	for child in root.get_children():
		if child is Node2D:
			var node2d: Node2D = child as Node2D
			if _is_valid_player_target(node2d):
				return node2d
		if child is Node:
			var nested: Node2D = _find_player_candidate(child as Node)
			if nested:
				return nested
	return null

func _is_valid_player_target(node: Node) -> bool:
	if node == null:
		return false
	if _is_player_target.is_valid():
		var result: Variant = _is_player_target.call(node)
		if typeof(result) == TYPE_BOOL:
			return bool(result)
	return false
