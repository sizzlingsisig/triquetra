extends Area2D
class_name ArrowProjectile

@export var speed: float = 450.0
@export var lifetime: float = 1.5
@export var max_distance: float = 400.0

var _direction: Vector2 = Vector2.RIGHT
var _attack_form: StringName = &"Bow"
var _spawn_position: Vector2 = Vector2.ZERO
func initialize(direction: Vector2, form: StringName) -> void:
    _direction = direction.normalized()
    _attack_form = form
    _spawn_position = global_position
    rotation = _direction.angle()

    add_to_group("projectile")
    set_collision_layer_value(6, true)
    set_collision_mask_value(8, true)
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
    # New system: HurtboxComponent detects arrow via "projectile" group
    if area is HurtboxComponent:
        queue_free()
        return