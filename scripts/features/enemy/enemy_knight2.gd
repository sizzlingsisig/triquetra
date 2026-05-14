class_name EnemyKnight2
extends BaseEnemy

## ---------------------------------------------------------------
## Knight-specific exports — tune per variant in the inspector
## ---------------------------------------------------------------

## Movement speed when chasing the player.
@export var chase_speed: float = 90.0

## Distance at which the knight starts an attack.
@export var attack_range: float = 40.0

## How long the hitbox stays active during an attack.
@export var attack_window_duration: float = 0.22

## Pause after an attack before returning to chase/idle.
@export var post_attack_pause: float = 0.55

## Duration of the hurt animation before recovery.
@export var hurt_recover_time: float = 0.18

## Delay before freeing the node after death animation starts.
@export var death_cleanup_delay: float = 0.28

## The knight cycles through these melee attack animations.
const ATTACK_ANIMS: Array[StringName] = [
	&"knight_attack1",
	&"knight_attack2",
	&"knight_attack3",
]

var _target: Node2D
var _attack_index: int = 0


## ---------------------------------------------------------------
## Initialization
## ---------------------------------------------------------------

func _ready() -> void:
	# Shift sprite left 76px when facing left (compensates for frame padding).
	sprite_flip_offset_x = -76.0
	# Disable enemy attacks for testing player → enemy damage.
	hitbox_forward_offset = 0.0
	hitbox_component.monitoring = false
	# Configure invulnerability to match hurt recovery time.
	hurtbox_component.invulnerability_duration = hurt_recover_time
	super()


## ---------------------------------------------------------------
## State virtual methods
## ---------------------------------------------------------------

func process_idle(_delta: float) -> void:
	# IDLE animations and behavior are handled on state entry.
	pass


func process_chase(_delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		state_machine.transition_to(BaseStateMachine.State.IDLE, &"target_lost")
		return

	var dir: float = signf(_target.global_position.x - global_position.x)
	velocity.x = dir * chase_speed
	set_facing_from_direction(dir)

	var dist: float = global_position.distance_to(_target.global_position)
	if dist <= attack_range:
		state_machine.transition_to(BaseStateMachine.State.ATTACK, &"in_range")


func process_attack(_delta: float) -> void:
	# Started and recovered on state entry via _on_state_changed.
	pass


func process_hurt(_delta: float) -> void:
	# Animation and recovery scheduled in _on_state_changed.
	pass


func process_dead(_delta: float) -> void:
	# Cleanup handled in _on_state_changed.
	pass


## ---------------------------------------------------------------
## Detection callbacks
## ---------------------------------------------------------------

func _on_target_entered(target: Node2D) -> void:
	_target = target
	if state_machine.get_state() == BaseStateMachine.State.IDLE:
		state_machine.transition_to(BaseStateMachine.State.CHASE, &"target_detected")


func _on_target_exited(exited: Node2D) -> void:
	if exited == _target:
		_target = null
		if state_machine.get_state() == BaseStateMachine.State.CHASE:
			state_machine.transition_to(BaseStateMachine.State.IDLE, &"target_lost")


## ---------------------------------------------------------------
## Damage pipeline
## ---------------------------------------------------------------

func _on_hurtbox_hit(source: Node, hit_position: Vector2) -> void:
	super(source, hit_position)  # Base handles flash, knockback, damage, hurt state
	# Knight-specific: enable invulnerability matching hurt animation duration
	hurtbox_component.make_invulnerable()


func _on_hitbox_hit(target: Node2D, _hit_position: Vector2) -> void:
	# Look for a HealthComponent on the hit target (player).
	var health: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.apply_damage(hitbox_component.damage)
		print("Player hit! Health: ", health.get_current_health(), "/", health.max_health)
	else:
		print("Hit connected but no HealthComponent on target: ", target.name)


## ---------------------------------------------------------------
## State machine callbacks
## ---------------------------------------------------------------

func _on_state_changed(_previous: int, next: int, _reason: StringName) -> void:
	match next:
		BaseStateMachine.State.IDLE:
			animated_sprite.play(&"knight_idle")

		BaseStateMachine.State.CHASE:
			animated_sprite.play(&"knight_run")

		BaseStateMachine.State.ATTACK:
			_start_attack()

		BaseStateMachine.State.HURT:
			animated_sprite.play(&"knight_hurt")
			state_machine.schedule_idle_recovery(hurt_recover_time)

		BaseStateMachine.State.DEAD:
			_start_death()


func _start_attack() -> void:
	var anim: StringName = ATTACK_ANIMS[_attack_index % ATTACK_ANIMS.size()]
	_attack_index += 1
	animated_sprite.play(anim)
	open_attack_window(attack_window_duration)
	# After the attack, return to chase/idle.
	state_machine.schedule_idle_recovery(post_attack_pause)


func _start_death() -> void:
	animated_sprite.play(&"knight_dead")
	# Disable collision after a moment so the body flies then falls through.
	var tree: SceneTree = get_tree()
	if tree:
		var collision_timer := tree.create_timer(0.15)
		collision_timer.timeout.connect(func() -> void:
			if collision_layer != 0:
				collision_layer = 0
				collision_mask = 0
		)
	var cleanup_timer := tree.create_timer(death_cleanup_delay)
	cleanup_timer.timeout.connect(queue_free)
