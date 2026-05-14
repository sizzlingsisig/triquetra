class_name Hurtbox extends Area2D

@export var faction: Stats.Faction = Stats.Faction.PLAYER

var _host: Node

func _ready() -> void:
    _host = get_parent()
    _set_layer_for_faction()
    monitoring = false
    monitorable = true
    area_entered.connect(_on_area_entered)

func _set_layer_for_faction() -> void:
    match faction:
        Stats.Faction.PLAYER:
            set_collision_layer_value(1, true)
            set_collision_mask_value(3, true)
        Stats.Faction.ENEMY:
            set_collision_layer_value(2, true)
            set_collision_mask_value(4, true)

func receive_hit(hitbox: Hitbox) -> void:
    if _host and _host.has_method("take_damage"):
        _host.take_damage(hitbox.damage)

func _on_area_entered(area: Area2D) -> void:
    if area is Hitbox:
        receive_hit(area as Hitbox)