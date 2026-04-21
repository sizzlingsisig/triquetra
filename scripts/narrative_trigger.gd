extends Node

## Triggers dialogue sequences at appropriate narrative moments.

@onready var _dialogue_manager: Node = $/root/DialogueManager
@onready var _game_manager: Node = $/root/GameManager
@onready var _game_state_machine: Node = $/root/GameStateMachine

func _ready() -> void:
	if _game_manager:
		_game_manager.timeline_reset_requested.connect(_on_timeline_reset)
	
	if _game_state_machine:
		_game_state_machine.state_changed.connect(_on_state_changed)
	
	if _dialogue_manager:
		_dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	
	# Trigger start dialogue when game begins
	call_deferred("_trigger_start_dialogue")

func _on_dialogue_ended() -> void:
	# After death dialogue ends, trigger timeline reset
	if _game_state_machine and _game_state_machine.get_state() == _game_state_machine.GameState.GAME_OVER:
		_trigger_timeline_reset()

func _trigger_timeline_reset() -> void:
	if _game_manager:
		_game_manager.request_timeline_reset("death_dialogue_complete")

func _trigger_start_dialogue() -> void:
	if _dialogue_manager:
		_dialogue_manager.start_dialogue(_dialogue_manager.DialogueType.START)

func _on_state_changed(previous_state: int, current_state: int) -> void:
	# Trigger mid dialogue when entering playing state after start dialogue
	if previous_state == _game_state_machine.GameState.DIALOGUE and current_state == _game_state_machine.GameState.PLAYING:
		# Start a timer to trigger mid dialogue after a short delay
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(_trigger_mid_dialogue)
	
	# Trigger death dialogue when entering game over state
	if current_state == _game_state_machine.GameState.GAME_OVER:
		call_deferred("_trigger_death_dialogue")

func _trigger_mid_dialogue() -> void:
	if _dialogue_manager and not _dialogue_manager.is_showing_dialogue():
		_dialogue_manager.start_dialogue(_dialogue_manager.DialogueType.MID)

func _trigger_death_dialogue() -> void:
	if _dialogue_manager:
		_dialogue_manager.start_dialogue(_dialogue_manager.DialogueType.DEATH)

func _on_timeline_reset(_reason: StringName) -> void:
	# Reset happens, then start dialogue will be triggered by state change
	pass