extends Node
class_name EnemyCombatComponent

signal attack_window_opened
signal attack_window_closed
signal counter_attack_triggered

var _enemy: Enemy
var _enemy_attack_area: Area2D
var _attack_timer: Timer
var _attack_window_active: bool = false
var _attack_window_generation: int = 0
var _attacks_enabled: bool = false

func setup(enemy: Enemy, attack_area: Area2D, attack_timer: Timer, attack_interval: float, attacks_enabled: bool) -> void:
	_enemy = enemy
	_enemy_attack_area = attack_area
	_attack_timer = attack_timer
	if _attack_timer:
		_attack_timer.wait_time = max(attack_interval, 0.2)
	set_attack_enabled(attacks_enabled)

func set_attack_enabled(attacks_enabled: bool) -> void:
	_attacks_enabled = attacks_enabled
	if _attack_timer:
		if _attacks_enabled:
			if _attack_timer.is_stopped():
				_attack_timer.start()
		else:
			_attack_timer.stop()
	close_attack_window()
	if _enemy_attack_area:
		_enemy_attack_area.set_deferred("monitorable", _attacks_enabled)

func set_attack_interval(attack_interval: float) -> void:
	if _attack_timer:
		_attack_timer.wait_time = max(attack_interval, 0.2)

func open_attack_window(duration_seconds: float) -> void:
	if not _attacks_enabled or _enemy_attack_area == null:
		return

	_attack_window_active = true
	_attack_window_generation += 1
	var generation: int = _attack_window_generation
	_enemy_attack_area.set_deferred("monitoring", true)
	attack_window_opened.emit()

	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(max(duration_seconds, 0.05))
	timer.timeout.connect(func() -> void:
		if generation != _attack_window_generation:
			return
		close_attack_window()
	)

func close_attack_window() -> void:
	if _enemy_attack_area:
		_enemy_attack_area.set_deferred("monitoring", false)
	if _attack_window_active:
		_attack_window_active = false
		attack_window_closed.emit()

func is_attack_window_active() -> bool:
	return _attack_window_active

func trigger_counter_attack() -> void:
	if _attack_window_active:
		counter_attack_triggered.emit()
