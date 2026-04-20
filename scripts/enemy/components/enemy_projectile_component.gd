extends Node
class_name EnemyProjectileComponent

const ENEMY_ARROW_PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemy/enemy_arrow_projectile.tscn")

signal projectile_hit_target(body: Node, hit_position: Vector2)

var _enemy: Enemy
var _sprite: AnimatedSprite2D
var _projectile_spawn: Node2D

func setup(enemy: Enemy, sprite: AnimatedSprite2D, projectile_spawn: Node2D) -> void:
	_enemy = enemy
	_sprite = sprite
	_projectile_spawn = projectile_spawn

func spawn_arrow(facing_left: bool, arrow_speed: float, arrow_lifetime: float) -> void:
	if ENEMY_ARROW_PROJECTILE_SCENE == null:
		return
	var arrow: EnemyArrowProjectile = ENEMY_ARROW_PROJECTILE_SCENE.instantiate() as EnemyArrowProjectile
	if arrow == null:
		return
	var direction: Vector2 = Vector2.LEFT if facing_left else Vector2.RIGHT
	var start_position: Vector2 = _get_arrow_spawn_position(direction)

	var host: Node = _enemy.get_parent() if _enemy else null
	if host:
		host.add_child(arrow)
	else:
		add_child(arrow)

	if not arrow.hit_target.is_connected(_on_arrow_projectile_hit):
		arrow.hit_target.connect(_on_arrow_projectile_hit)
	arrow.launch(start_position, direction, arrow_speed, arrow_lifetime)

func _get_arrow_spawn_position(direction: Vector2) -> Vector2:
	if _projectile_spawn:
		return _projectile_spawn.global_position
	if _sprite:
		return _sprite.global_position + Vector2(direction.x * 20.0, -8.0)
	if _enemy:
		return _enemy.global_position + Vector2(direction.x * 20.0, -8.0)
	return Vector2.ZERO

func _on_arrow_projectile_hit(body: Node, hit_position: Vector2) -> void:
	projectile_hit_target.emit(body, hit_position)
