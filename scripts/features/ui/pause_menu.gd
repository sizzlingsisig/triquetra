extends CanvasLayer
class_name PauseMenu

@onready var _resume_button: Button = $Panel/ResumeButton
@onready var _quit_button: Button = $Panel/QuitButton

# Preload the game state machine script for static enum access and type safety.
const GameStateMachine = preload("res://scripts/features/game/game_state_machine.gd")
var _game_state_machine: GameStateMachine


func _ready() -> void:
	_game_state_machine = get_node_or_null("/root/GameStateMachine") as GameStateMachine
	if _resume_button:
		_resume_button.pressed.connect(_on_resume_pressed)
	if _quit_button:
		_quit_button.pressed.connect(_on_quit_pressed)
	hide()
	# Connect to state machine for show/hide
	if _game_state_machine:
		_game_state_machine.state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state == GameStateMachine.GameState.PAUSED:
		show()
		if _resume_button:
			_resume_button.grab_focus()
	else:
		hide()


func _on_resume_pressed() -> void:
	if _game_state_machine and _game_state_machine.has_method("toggle_pause"):
		_game_state_machine.toggle_pause()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
