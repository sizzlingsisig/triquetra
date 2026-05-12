extends CharacterBody2D
class_name BaseEnemy

## ---------------------------------------------------------------
## Exports (configured per enemy type via inspector or subclass)
## ---------------------------------------------------------------

## Maximum health for this enemy.
@export var max_health: int = 2
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 1200.0

## If true, the sprite's default (unflipped) state faces left.
## If false, the default unflipped state faces right.
@export var sprite_faces_left_when_not_flipped: bool = false

## Friction applied when not actively moving (deceleration in px/s²).
@export var friction: float = 500.0

## How far in front of the enemy the hitbox is placed (pixels).
## Positive = in front when facing right. Mirrored automatically when facing left.
@export var hitbox_forward_offset: float = 0.0

## When non-zero, the AnimatedSprite2D's X shifts by this amount when facing
## left (negative = shift left). Restored to base position when facing right.
@export var sprite_flip_offset_x: float = 0.0



## ---------------------------------------------------------------
## Node references
## ---------------------------------------------------------------

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var detection_component: DetectionComponent = $DetectionComponent
@onready var state_machine: BaseStateMachine = $StateMachine

## ---------------------------------------------------------------
## Facing-dependent offsets
## ---------------------------------------------------------------

## Hitbox shape's Y from the scene (kept as-is, X is driven by forward offset).
var _hitbox_shape_base_y: float

## Sprite's base scale X and position X (stored at setup).
var _sprite_base_scale_x: float
var _sprite_base_x: float

## ---------------------------------------------------------------
## Initialization
## ---------------------------------------------------------------

func _ready() -> void:
	_setup_components()
	_connect_damage_signals()
	_connect_detection_signals()
	_connect_state_machine()


func _setup_components() -> void:
	if hitbox_component:
		hitbox_component.monitoring = false
		# Store sprite base values (scale/flip + position offset).
		if animated_sprite:
			_sprite_base_scale_x = animated_sprite.scale.x
			_sprite_base_x = animated_sprite.position.x
		var hitbox_shape := hitbox_component.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if hitbox_shape:
			_hitbox_shape_base_y = hitbox_shape.position.y
	if health_component:
		health_component.set_max_health(max_health)
	_sync_sprite_flip()


func _connect_damage_signals() -> void:
	if health_component and not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)
	if hurtbox_component and not hurtbox_component.hurtbox_hit.is_connected(_on_hurtbox_hit):
		hurtbox_component.hurtbox_hit.connect(_on_hurtbox_hit)
	if hitbox_component and not hitbox_component.hitbox_hit.is_connected(_on_hitbox_hit):
		hitbox_component.hitbox_hit.connect(_on_hitbox_hit)


func _connect_detection_signals() -> void:
	if detection_component:
		if not detection_component.target_entered.is_connected(_on_target_entered):
			detection_component.target_entered.connect(_on_target_entered)
		if not detection_component.target_exited.is_connected(_on_target_exited):
			detection_component.target_exited.connect(_on_target_exited)


func _connect_state_machine() -> void:
	if state_machine:
		if not state_machine.state_changed.is_connected(_on_state_changed):
			state_machine.state_changed.connect(_on_state_changed)


## ---------------------------------------------------------------
## Physics
## ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if state_machine:
		_dispatch_state_process(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta
		velocity.y = minf(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


## ---------------------------------------------------------------
## State dispatch — subclass these process_* methods
## ---------------------------------------------------------------

func _dispatch_state_process(delta: float) -> void:
	if state_machine == null:
		return
	match state_machine.get_state():
		BaseStateMachine.State.IDLE:
			_apply_horizontal_friction(delta)
			process_idle(delta)
		BaseStateMachine.State.CHASE:
			process_chase(delta)
		BaseStateMachine.State.ATTACK:
			_apply_horizontal_friction(delta)
			process_attack(delta)
		BaseStateMachine.State.HURT:
			_apply_horizontal_friction(delta)
			process_hurt(delta)
		BaseStateMachine.State.DEAD:
			_apply_horizontal_friction(delta)
			process_dead(delta)


## Virtual: override in subclass for enemy-specific behavior per state.
func process_idle(_delta: float) -> void:
	pass
func process_chase(_delta: float) -> void:
	pass
func process_attack(_delta: float) -> void:
	pass
func process_hurt(_delta: float) -> void:
	pass
func process_dead(_delta: float) -> void:
	pass


func _apply_horizontal_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)


## ---------------------------------------------------------------
## Damage pipeline
## ---------------------------------------------------------------

## Called when the hurtbox detects a player attack.
## Override in subclass for custom damage logic (blocking, multipliers, etc.).
func _on_hurtbox_hit(_source: Node, _hit_position: Vector2) -> void:
	if health_component:
		health_component.apply_damage(1)
	if state_machine:
		state_machine.transition_to(BaseStateMachine.State.HURT, &"damage_taken")


## Called when health reaches 0.
func _on_died() -> void:
	if state_machine:
		state_machine.force_transition_to(BaseStateMachine.State.DEAD, &"died")
	_disable_combat()


func _disable_combat() -> void:
	if hitbox_component:
		hitbox_component.set_deferred(&"monitoring", false)
		hitbox_component.set_deferred(&"monitorable", false)


## Called when the hitbox lands on a target (player).
## Override in subclass to apply damage + FX + knockback.
func _on_hitbox_hit(_target: Node2D, _hit_position: Vector2) -> void:
	pass


## ---------------------------------------------------------------
## Detection callbacks
## ---------------------------------------------------------------

## Called when a target enters detection range. Override in subclass.
func _on_target_entered(_target: Node2D) -> void:
	pass

## Called when a target leaves detection range. Override in subclass.
func _on_target_exited(_target: Node2D) -> void:
	pass


## ---------------------------------------------------------------
## State machine callbacks
## ---------------------------------------------------------------

## Called on every state transition. Override in subclass.
func _on_state_changed(_previous: int, _next: int, _reason: StringName) -> void:
	pass


## ---------------------------------------------------------------
## Attack window helpers
## ---------------------------------------------------------------

func open_attack_window(duration: float) -> void:
	if hitbox_component:
		hitbox_component.monitoring = true
	if duration > 0.0:
		var tree: SceneTree = get_tree()
		if tree:
			var timer: SceneTreeTimer = tree.create_timer(duration)
			timer.timeout.connect(_close_attack_window)


func _close_attack_window() -> void:
	if hitbox_component:
		hitbox_component.monitoring = false


## ---------------------------------------------------------------
## Facing direction
## ---------------------------------------------------------------

## Set facing from movement direction. [param direction] is a signed float.
func set_facing_from_direction(direction: float) -> void:
	if absf(direction) <= 0.01:
		return
	var is_left: bool = direction < 0.0
	_apply_sprite_flip(is_left)


func is_facing_left() -> bool:
	if animated_sprite == null:
		return false
	var is_neg: bool = animated_sprite.scale.x < 0.0
	if sprite_faces_left_when_not_flipped:
		return not is_neg
	return is_neg


func _apply_sprite_flip(is_left: bool) -> void:
	if animated_sprite == null:
		return
	# Manual flip via scale.x — mirrors around the sprite's position.
	var should_flip: bool = is_left
	if sprite_faces_left_when_not_flipped:
		should_flip = not is_left
	animated_sprite.scale.x = -absf(_sprite_base_scale_x) if should_flip else absf(_sprite_base_scale_x)

	# Shift sprite position on flip (compensates for asymmetric frames).
	if sprite_flip_offset_x != 0.0:
		animated_sprite.position.x = _sprite_base_x + (sprite_flip_offset_x if is_left else 0.0)

	# Place hitbox in front of the enemy based on facing direction.
	var hitbox_shape := hitbox_component.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if hitbox_shape and hitbox_forward_offset != 0.0:
		hitbox_shape.position.x = hitbox_forward_offset * (-1.0 if is_left else 1.0)
		hitbox_shape.position.y = _hitbox_shape_base_y


func _sync_sprite_flip() -> void:
	_apply_sprite_flip(false)
