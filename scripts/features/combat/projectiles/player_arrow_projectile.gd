extends Area2D
class_name ArrowProjectile

@export var speed: float = 450.0
@export var lifetime: float = 1.5
@export var max_distance: float = 400.0

var _direction: Vector2 = Vector2.RIGHT
var _attack_form: StringName = &"Bow"
var _spawn_position: Vector2 = Vector2.ZERO
var _hit_entities: Array[int] = []

func initialize(direction: Vector2, form: StringName) -> void:
    _direction = direction.normalized()
    _attack_form = form
    _spawn_position = global_position
    rotation = _direction.angle()

    add_to_group("projectile")
    area_entered.connect(_on_area_entered)

    var timer: Timer = Timer.new()
    timer.one_shot = true
    add_child(timer)
    timer.timeout.connect(queue_free)
    timer.start(lifetime)

func _physics_process(delta: float) -> void:
    global_position += _direction * speed * delta

    if global_position.distance_to(_spawn_position) > max_distance:
        queue_free()

func _on_area_entered(area: Area2D) -> void:
    if not area.is_in_group("enemy_hurtbox") and not area.name.begins_with("AttackHitbox"):
        return

    var entity_id: int = area.get_instance_id()
    if entity_id in _hit_entities:
        return
    _hit_entities.append(entity_id)

    var enemy: Node = area.get_parent()
    if not enemy or not enemy.has_method("receive_player_hit"):
        return
    enemy.receive_player_hit(_attack_form)

    queue_free()