class_name Hitbox extends Area2D

@export var damage: int = 1
@export var attack_form: StringName = &"Sword"

var _hitlog: HitLog
var _lifetime: float

func setup(damage_val: int, form: StringName, hitlog: HitLog, lifetime: float) -> void:
    damage = damage_val
    attack_form = form
    _hitlog = hitlog
    _lifetime = lifetime

func _ready() -> void:
    monitorable = false
    monitoring = true
    set_collision_layer_value(1, false)
    set_collision_layer_value(2, false)
    set_collision_layer_value(3, false)
    set_collision_layer_value(4, false)
    set_collision_mask_value(2, true)
    area_entered.connect(_on_area_entered)

    if _lifetime > 0.0:
        var timer: Timer = Timer.new()
        timer.one_shot = true
        add_child(timer)
        timer.timeout.connect(queue_free)
        timer.start(_lifetime)

func _on_area_entered(area: Area2D) -> void:
    if not area is Hurtbox:
        return
    if _hitlog and _hitlog.has_hit(area):
        return
    var hurtbox: Hurtbox = area as Hurtbox
    if _hitlog:
        _hitlog.record_hit(area)
    hurtbox.receive_hit(self)