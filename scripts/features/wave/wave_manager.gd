extends Node
class_name WaveManager


## Wave definitions. Each entry: { enemy_count, spawn_interval, pre_wave_delay }
@export var waves: Array[Dictionary] = [
	{ "enemy_count": 2, "spawn_interval": 1.0, "pre_wave_delay": 0.0 },
	{ "enemy_count": 4, "spawn_interval": 1.2, "pre_wave_delay": 1.0 },
	{ "enemy_count": 6, "spawn_interval": 1.5, "pre_wave_delay": 1.5 },
	{ "enemy_count": 8, "spawn_interval": 1.5, "pre_wave_delay": 2.0 },
]

## PackedScene to instance for each enemy.
@export var enemy_scene: PackedScene = preload("res://scenes/enemy/enemy_knight2.tscn")

## Pause between wave clear and next wave start.
@export var wave_clear_pause: float = 2.0

## Fallback ground Y if raycast misses.
@export var ground_y: float = 358.0

## Collision layer for the ground (for raycasting spawn Y).
@export var ground_collision_layer: int = 7

## Path to the FormManager node for player tracking.
@export var form_manager_node: NodePath = NodePath("/root/Main/Player/FormManager")

## How enemies enter the arena.
## FALL: drop from above with landing VFX. SIDE: walk in from the edge.
enum EntranceMode {
	FALL,
	SIDE,
}


## ---- Internal state ----

var _wave_hud: WaveHUD
var _spawn_timer: Timer
var _game_state_machine: GameStateMachine
var _form_manager: FormManager
var _active_player: PlayerController

var _alive_enemies: int = 0
var _total_spawned: int = 0
var _wave_index: int = 0
var _is_wave_active: bool = false
var _alive_enemies_list: Array[Node] = []


## ---- Initialization ----

func _ready() -> void:
	# Find HUD child
	_wave_hud = get_node_or_null("HUD") as WaveHUD

	# Create spawn timer
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	# Game state machine (Autoload)
	_game_state_machine = get_node_or_null("/root/GameStateMachine") as GameStateMachine
	if _game_state_machine:
		_game_state_machine.state_changed.connect(_on_game_state_changed)

	# Form manager for player tracking
	_form_manager = get_node(form_manager_node) as FormManager
	if _form_manager:
		_form_manager.active_player_changed.connect(_on_active_player_changed)
		# Initial scan for the already-active player
		_scan_active_player()

	# Start if game is already playing
	if _game_state_machine and _game_state_machine.is_playing():
		_start_wave(0)


## Scan FormManager children for the active (non-disabled) player.
func _scan_active_player() -> void:
	if not _form_manager:
		return
	for child in _form_manager.get_children():
		if child is PlayerController and child.process_mode != Node.PROCESS_MODE_DISABLED:
			_on_active_player_changed(child)
			return


func _on_active_player_changed(player: PlayerController) -> void:
	# Disconnect old player's died signal
	if _active_player and _active_player.health_component:
		if _active_player.health_component.died.is_connected(_on_player_died):
			_active_player.health_component.died.disconnect(_on_player_died)

	_active_player = player

	# Connect new player's died signal
	if _active_player and _active_player.health_component:
		if not _active_player.health_component.died.is_connected(_on_player_died):
			_active_player.health_component.died.connect(_on_player_died)


## ---- Game State ----

func _on_game_state_changed(_previous: int, current: int) -> void:
	match current:
		GameStateMachine.GameState.PLAYING:
			if _wave_index == 0:
				_start_wave(0)
			elif _is_wave_active and _total_spawned < waves[_wave_index]["enemy_count"]:
				# Resume mid-wave spawning after unpause
				_spawn_timer.start()
		GameStateMachine.GameState.PAUSED:
			_spawn_timer.stop()
		GameStateMachine.GameState.GAME_OVER:
			_spawn_timer.stop()
			_clear_enemies()


## ---- Wave Flow ----

func _start_wave(index: int) -> void:
	if index >= waves.size():
		return
	_wave_index = index
	var wave: Dictionary = waves[index]
	_total_spawned = 0
	_alive_enemies = 0
	_is_wave_active = true

	# Ensure player is tracked
	if not _active_player:
		_scan_active_player()

	# Show wave label
	if _wave_hud:
		_wave_hud.show_wave_label(index + 1)

	# Delay then start spawning
	var delay: float = wave.get("pre_wave_delay", 0.0)
	if delay > 0.0:
		var delay_timer := get_tree().create_timer(delay)
		delay_timer.timeout.connect(_start_spawning.bind(wave))
	else:
		_start_spawning(wave)


func _start_spawning(wave: Dictionary) -> void:
	if not _is_wave_active:
		return
	_spawn_timer.wait_time = wave.get("spawn_interval", 1.0)
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	var wave: Dictionary = waves[_wave_index]
	if _total_spawned >= wave.get("enemy_count", 1):
		_spawn_timer.stop()
		return

	_spawn_enemy()
	_total_spawned += 1

	if _wave_hud:
		_wave_hud.update_enemies_label(_alive_enemies)

	if _total_spawned >= wave.get("enemy_count", 1):
		_spawn_timer.stop()


func _spawn_enemy() -> void:
	if not enemy_scene:
		return

	var enemy: Node2D = enemy_scene.instantiate()

	# Add to tree FIRST so @onready vars are available for entrance setup
	var main := get_parent()
	if main:
		main.add_child(enemy)

	_setup_entrance(enemy)

	# Track
	_alive_enemies += 1
	_alive_enemies_list.append(enemy)

	# Connect death signal (with enemy reference for safety)
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		if not health.died.is_connected(_on_enemy_died):
			health.died.connect(_on_enemy_died.bind(enemy))

	# Safety net: tree_exited for edge cases (out-of-bounds, etc.)
	if not enemy.tree_exited.is_connected(_on_enemy_tree_exited):
		enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))


## ---- Entrance Modes ----

## Pick a random entrance mode. 50/50 split between FALL and SIDE.
## Future: pass in enemy type so bosses always use FALL.
func _pick_entrance() -> EntranceMode:
	return EntranceMode.FALL if randf() < 0.5 else EntranceMode.SIDE


## Set up the enemy's position and behavior based on the chosen entrance.
func _setup_entrance(enemy: Node2D) -> void:
	match _pick_entrance():
		EntranceMode.FALL:
			_setup_fall_entrance(enemy)
		EntranceMode.SIDE:
			_setup_side_entrance(enemy)


## Enemy drops from above the camera viewport, disabled during the fall.
## On landing: enable the enemy + play spawn VFX.
func _setup_fall_entrance(enemy: Node2D) -> void:
	var target_pos: Vector2 = _get_spawn_position()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var start_y: float = viewport_rect.position.y - 100.0
	enemy.global_position = Vector2(target_pos.x, start_y)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "global_position", target_pos, 0.6)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(enemy):
			return
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		_spawn_spawn_effect(target_pos)
	)


## Enemy appears at the left or right edge of the camera and immediately
## starts chasing the player via their existing AI.
func _setup_side_entrance(enemy: Node2D) -> void:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()

	var from_left: bool = randf() < 0.5
	var edge_x: float = viewport_rect.position.x - 30.0 if from_left else viewport_rect.end.x + 30.0
	var ground_y_pos: float = _get_ground_y_at_x(edge_x)
	enemy.global_position = Vector2(edge_x, ground_y_pos)

	# Immediately notify the enemy of the player so they start chasing
	var player: PlayerController = _active_player
	if player and enemy.has_method(&"_on_target_entered"):
		enemy._on_target_entered(player)


## ---- Spawn Position ----

## Raycast for ground Y at an arbitrary X coordinate.
## Shared by fall and side entrances.
func _get_ground_y_at_x(x: float) -> float:
	var viewport := get_viewport()
	var world_2d := viewport.get_world_2d()
	var space_state := world_2d.get_direct_space_state()
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, -100.0), Vector2(x, 600.0))
	query.collision_mask = ground_collision_layer
	var result := space_state.intersect_ray(query)
	return (result.position.y - 30.0) if result else ground_y


## Returns a random position within the viewport at ground level.
## Used by FALL entrances as the landing target.
func _get_spawn_position() -> Vector2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var margin: float = 40.0
	var x: float = randf_range(
		viewport_rect.position.x + margin,
		viewport_rect.end.x - margin
	)
	x = clampf(x, 30.0, viewport_rect.size.x - 30.0)
	return Vector2(x, _get_ground_y_at_x(x))


## ---- Spawn Effect ----

func _spawn_spawn_effect(position: Vector2) -> void:
	var effect := WaveSpawnEffect.new()
	effect.global_position = position
	add_child(effect)


## ---- Enemy Tracking ----

func _on_enemy_died(enemy: Node) -> void:
	_alive_enemies = maxi(_alive_enemies - 1, 0)
	_alive_enemies_list.erase(enemy)

	if _wave_hud:
		_wave_hud.update_enemies_label(_alive_enemies)

	# Check wave cleared
	var wave: Dictionary = waves[_wave_index]
	if _alive_enemies <= 0 and _total_spawned >= wave.get("enemy_count", 1):
		_on_wave_cleared()


## Safety net: enemy removed from tree for any reason (out-of-bounds, etc.)
func _on_enemy_tree_exited(enemy: Node) -> void:
	if enemy in _alive_enemies_list:
		_on_enemy_died(enemy)


func _on_wave_cleared() -> void:
	_is_wave_active = false
	_spawn_timer.stop()

	var next_index := _wave_index + 1
	if next_index >= waves.size():
		# All waves complete -> victory
		if _game_state_machine:
			_game_state_machine.enter_victory(&"last_wave_cleared")
		if _wave_hud:
			_wave_hud.show_victory()
	else:
		# Schedule next wave
		var timer := get_tree().create_timer(wave_clear_pause)
		timer.timeout.connect(_start_wave.bind(next_index))


## ---- Player Death ----

func _on_player_died() -> void:
	_spawn_timer.stop()
	if _game_state_machine:
		_game_state_machine.enter_game_over(&"player_died")
	if _wave_hud:
		_wave_hud.show_game_over()
	_clear_enemies()


func _clear_enemies() -> void:
	for enemy in _alive_enemies_list:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_alive_enemies_list.clear()
	_alive_enemies = 0
