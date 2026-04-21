extends Node

## Manages dialogue flow and state for the looping narrative.
## Tracks loop count, player choices, and selects appropriate dialogue.

signal dialogue_started(dialogue_type: StringName)
signal dialogue_line_shown(speaker: StringName, text: String, side: StringName)
signal dialogue_ended()

enum DialogueType {
	START,
	MID,
	DEATH
}

enum Alignment {
	CALAMITY,  # Protect Pandora
	DOUBT,     # Hesitate/question
	REJECT     # Attack/turn against
}

const DIALOGUE_DATA = {
	1: {  # Loop 1 - Ignorance
		"start": [
			{"speaker": "Sword", "text": "Stay behind us, child.", "side": "left"},
			{"speaker": "Spear", "text": "Something's coming.", "side": "left"},
			{"speaker": "Bow", "text": "...We won't let them touch you.", "side": "left"},
			{"speaker": "Pandora", "text": "Why do they want me...?", "side": "left"}
		],
		"mid": [
			{"speaker": "Enemy Knight", "text": "Step aside. You don't understand what you protect.", "side": "right"},
			{"speaker": "Sword", "text": "We understand enough.", "side": "left"}
		],
		"death": [
			{"speaker": "Pandora", "text": "...we failed?", "side": "left"},
			{"speaker": "Sword", "text": "No. We begin again.", "side": "left"}
		]
	},
	2: {  # Loop 2 - Awareness
		"start": [
			{"speaker": "Bow", "text": "...We've done this before.", "side": "left"},
			{"speaker": "Spear", "text": "Don't start that again.", "side": "left"},
			{"speaker": "Sword", "text": "Focus. Protect the child.", "side": "left"}
		],
		"mid": [
			{"speaker": "Enemy Knight", "text": "You've died here before. How many times will you repeat this mistake?", "side": "right"},
			{"speaker": "Spear", "text": "As many times as it takes.", "side": "left"}
		],
		"death": [
			{"speaker": "Bow", "text": "They remembered us...", "side": "left"},
			{"speaker": "Pandora", "text": "Why does it feel like we've lost more than once?", "side": "left"}
		]
	},
	3: {  # Loop 3 - Doubt
		"start": [
			{"speaker": "Sword", "text": "...Something is wrong.", "side": "left"},
			{"speaker": "Spear", "text": "We protect. That is all that matters.", "side": "left"},
			{"speaker": "Bow", "text": "Is it?", "side": "left"}
		],
		"mid": [
			{"speaker": "Enemy", "text": "She is not what you think.", "side": "right"},
			{"speaker": "Sword", "text": "Explain.", "side": "left"},
			{"speaker": "Enemy", "text": "She is the reason this world keeps ending.", "side": "right"}
		],
		"mid_wait": [
			{"speaker": "Enemy", "text": "You are not saving her. You are delaying everything else.", "side": "right"}
		],
		"mid_interrupt": [
			{"speaker": "Spear", "text": "Enough talk.", "side": "left"}
		],
		"death": [
			{"speaker": "Sword", "text": "...What if they're right?", "side": "left"}
		]
	},
	4: {  # Loop 4 - Truth
		"start": [
			{"speaker": "Pandora", "text": "...Why do they look at me like that?", "side": "left"},
			{"speaker": "Bow", "text": "Because they know.", "side": "left"}
		],
		"mid": [
			{"speaker": "Boss", "text": "You have doomed us all—again.", "side": "right"},
			{"speaker": "Sword", "text": "Then tell us the truth.", "side": "left"},
			{"speaker": "Boss", "text": "She is not your ward. She is the end.", "side": "right"}
		],
		"mid_protect": [
			{"speaker": "Spear", "text": "We don't abandon her.", "side": "left"}
		],
		"mid_hesitate": [
			{"speaker": "Bow", "text": "...What if protecting her is the mistake?", "side": "left"}
		],
		"mid_attack": [
			{"speaker": "Sword", "text": "No more words.", "side": "left"}
		],
		"death": [
			{"speaker": "Pandora", "text": "...Why do you keep choosing this?", "side": "left"}
		]
	},
	5: {  # Loop 5+ - Alignment System
		"start": [
			{"speaker": "Pandora", "text": "You chose me... again.", "side": "left"}
		],
		"start_doubt": [
			{"speaker": "Sword", "text": "We need answers.", "side": "left"}
		],
		"start_reject": [
			{"speaker": "Pandora", "text": "...You're afraid of me now.", "side": "left"}
		],
		"mid": [
			{"speaker": "Boss", "text": "Your persistence is admirable, but futile.", "side": "right"}
		],
		"death": [
			{"speaker": "Sword", "text": "Again...", "side": "left"}
		]
	}
}

var _game_manager: Node
var _game_state_machine: Node
var _current_loop: int = 1
var _current_alignment: Alignment = Alignment.CALAMITY
var _dialogue_ui: Control
var _current_dialogue_lines: Array = []
var _current_line_index: int = 0
var _is_showing_dialogue: bool = false
var _player_choice_made: bool = false
var _player_choice: StringName = &""

func _ready() -> void:
	if _dialogue_ui:
		return  # Already initialized
	
	_game_manager = get_node_or_null("/root/GameManager")
	_game_state_machine = get_node_or_null("/root/GameStateMachine")
	
	if _game_manager:
		_game_manager.timeline_reset_requested.connect(_on_timeline_reset)
		_current_loop = _game_manager.get_persistent_flag(&"loop_count", 1)
		_update_alignment_from_flags()
	
	# Create dialogue UI
	_create_dialogue_ui()

func _input(event: InputEvent) -> void:
	if not _is_showing_dialogue:
		return
	
	if event.is_action_pressed("ui_accept"):  # Space key
		if _dialogue_ui.get_node("ContinueButton").visible:
			_on_continue_pressed()
		elif _dialogue_ui.get_node("WaitButton").visible:
			_on_wait_pressed()
		elif _dialogue_ui.get_node("ProtectButton").visible:
			_on_protect_pressed()
	
	if event is InputEventKey and event.pressed:
		if _dialogue_ui.get_node("WaitButton").visible and event.keycode == KEY_1:
			_on_wait_pressed()
		elif _dialogue_ui.get_node("InterruptButton").visible and event.keycode == KEY_2:
			_on_interrupt_pressed()
		elif _dialogue_ui.get_node("ProtectButton").visible and event.keycode == KEY_1:
			_on_protect_pressed()
		elif _dialogue_ui.get_node("HesitateButton").visible and event.keycode == KEY_2:
			_on_hesitate_pressed()
		elif _dialogue_ui.get_node("AttackButton").visible and event.keycode == KEY_3:
			_on_attack_pressed()

func _create_dialogue_ui() -> void:
	_dialogue_ui = Control.new()
	_dialogue_ui.name = "DialogueUI"
	_dialogue_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialogue_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create a theme for better styling
	var theme = Theme.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.8)
	panel_style.border_color = Color(1, 1, 1, 1)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	theme.set_stylebox("panel", "Panel", panel_style)
	
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	button_style.border_color = Color(1, 1, 1, 1)
	button_style.border_width_left = 1
	button_style.border_width_right = 1
	button_style.border_width_top = 1
	button_style.border_width_bottom = 1
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	theme.set_stylebox("normal", "Button", button_style)
	
	var button_hover_style = StyleBoxFlat.new()
	button_hover_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
	button_hover_style.border_color = Color(1, 1, 1, 1)
	button_hover_style.border_width_left = 1
	button_hover_style.border_width_right = 1
	button_hover_style.border_width_top = 1
	button_hover_style.border_width_bottom = 1
	button_hover_style.corner_radius_top_left = 5
	button_hover_style.corner_radius_top_right = 5
	button_hover_style.corner_radius_bottom_left = 5
	button_hover_style.corner_radius_bottom_right = 5
	theme.set_stylebox("hover", "Button", button_hover_style)
	
	_dialogue_ui.theme = theme
	
	# Left bubble (Guardians/Pandora)
	var left_bubble = Panel.new()
	left_bubble.name = "LeftBubble"
	left_bubble.custom_minimum_size = Vector2(350, 120)
	left_bubble.position = Vector2(50, 350)
	left_bubble.visible = false
	
	var left_label = Label.new()
	left_label.name = "LeftLabel"
	left_label.position = Vector2(15, 15)
	left_label.size = Vector2(320, 90)
	left_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	left_label.add_theme_font_size_override("font_size", 16)
	left_bubble.add_child(left_label)
	_dialogue_ui.add_child(left_bubble)
	
	# Right bubble (Enemies)
	var right_bubble = Panel.new()
	right_bubble.name = "RightBubble"
	right_bubble.custom_minimum_size = Vector2(350, 120)
	right_bubble.position = Vector2(600, 350)
	right_bubble.visible = false
	
	var right_label = Label.new()
	right_label.name = "RightLabel"
	right_label.position = Vector2(15, 15)
	right_label.size = Vector2(320, 90)
	right_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	right_label.add_theme_font_size_override("font_size", 16)
	right_bubble.add_child(right_label)
	_dialogue_ui.add_child(right_bubble)
	
	# Continue button
	var continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue (Space)"
	continue_button.position = Vector2(475, 480)
	continue_button.size = Vector2(100, 40)
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	_dialogue_ui.add_child(continue_button)
	
	# Choice buttons for player decisions
	var wait_button = Button.new()
	wait_button.name = "WaitButton"
	wait_button.text = "1: Wait"
	wait_button.position = Vector2(400, 480)
	wait_button.size = Vector2(80, 40)
	wait_button.visible = false
	wait_button.pressed.connect(_on_wait_pressed)
	_dialogue_ui.add_child(wait_button)
	
	var interrupt_button = Button.new()
	interrupt_button.name = "InterruptButton"
	interrupt_button.text = "2: Interrupt"
	interrupt_button.position = Vector2(490, 480)
	interrupt_button.size = Vector2(100, 40)
	interrupt_button.visible = false
	interrupt_button.pressed.connect(_on_interrupt_pressed)
	_dialogue_ui.add_child(interrupt_button)
	
	var protect_button = Button.new()
	protect_button.name = "ProtectButton"
	protect_button.text = "1: Protect"
	protect_button.position = Vector2(350, 480)
	protect_button.size = Vector2(80, 40)
	protect_button.visible = false
	protect_button.pressed.connect(_on_protect_pressed)
	_dialogue_ui.add_child(protect_button)
	
	var hesitate_button = Button.new()
	hesitate_button.name = "HesitateButton"
	hesitate_button.text = "2: Hesitate"
	hesitate_button.position = Vector2(440, 480)
	hesitate_button.size = Vector2(90, 40)
	hesitate_button.visible = false
	hesitate_button.pressed.connect(_on_hesitate_pressed)
	_dialogue_ui.add_child(hesitate_button)
	
	var attack_button = Button.new()
	attack_button.name = "AttackButton"
	attack_button.text = "3: Attack"
	attack_button.position = Vector2(540, 480)
	attack_button.size = Vector2(80, 40)
	attack_button.visible = false
	attack_button.pressed.connect(_on_attack_pressed)
	_dialogue_ui.add_child(attack_button)
	
	get_tree().root.call_deferred("add_child", _dialogue_ui)

func start_dialogue(dialogue_type: DialogueType) -> void:
	if _is_showing_dialogue:
		return
	
	_is_showing_dialogue = true
	_current_line_index = 0
	_player_choice_made = false
	_player_choice = &""
	
	var type_key = _get_type_key(dialogue_type)
	_current_dialogue_lines = _get_dialogue_lines(type_key)
	
	if _current_dialogue_lines.is_empty():
		_end_dialogue()
		return
	
	_game_state_machine.enter_dialogue("dialogue_started")
	dialogue_started.emit(type_key)
	
	_show_next_line()

func _get_type_key(dialogue_type: DialogueType) -> StringName:
	match dialogue_type:
		DialogueType.START:
			return &"start"
		DialogueType.MID:
			return &"mid"
		DialogueType.DEATH:
			return &"death"
	return &"start"

func _get_dialogue_lines(type_key: StringName) -> Array:
	var loop_data = DIALOGUE_DATA.get(min(_current_loop, 5), DIALOGUE_DATA[1])
	
	# Handle special cases for loop 3+ with choices
	if _current_loop >= 3 and type_key == &"mid":
		if _player_choice == &"wait":
			return loop_data.get("mid_wait", loop_data["mid"])
		elif _player_choice == &"interrupt":
			return loop_data.get("mid_interrupt", loop_data["mid"])
		elif _player_choice == &"protect":
			return loop_data.get("mid_protect", loop_data["mid"])
		elif _player_choice == &"hesitate":
			return loop_data.get("mid_hesitate", loop_data["mid"])
		elif _player_choice == &"attack":
			return loop_data.get("mid_attack", loop_data["mid"])
	
	# Handle loop 5+ alignment variations
	if _current_loop >= 5 and type_key == &"start":
		if _current_alignment == Alignment.DOUBT:
			return loop_data.get("start_doubt", loop_data["start"])
		elif _current_alignment == Alignment.REJECT:
			return loop_data.get("start_reject", loop_data["start"])
	
	return loop_data.get(type_key, [])

func _show_next_line() -> void:
	if _current_line_index >= _current_dialogue_lines.size():
		_end_dialogue()
		return
	
	var line = _current_dialogue_lines[_current_line_index]
	var speaker = line["speaker"]
	var text = line["text"]
	var side = line["side"]
	
	# Hide all bubbles first
	_dialogue_ui.get_node("LeftBubble").visible = false
	_dialogue_ui.get_node("RightBubble").visible = false
	_dialogue_ui.get_node("ContinueButton").visible = false
	_hide_choice_buttons()
	
	# Show appropriate bubble
	if side == "left":
		var bubble = _dialogue_ui.get_node("LeftBubble")
		var label = bubble.get_node("LeftLabel")
		label.text = text
		bubble.visible = true
	elif side == "right":
		var bubble = _dialogue_ui.get_node("RightBubble")
		var label = bubble.get_node("RightLabel")
		label.text = text
		bubble.visible = true
	
	# Check if this is a choice point
	if _is_choice_point():
		_show_choice_buttons()
	else:
		_dialogue_ui.get_node("ContinueButton").visible = true
	
	dialogue_line_shown.emit(speaker, text, side)
	_current_line_index += 1

func _is_choice_point() -> bool:
	# Choice points in loop 3 mid dialogue
	if _current_loop == 3 and _current_line_index == 2:  # After enemy says "She is the reason this world keeps ending."
		return true
	# Choice points in loop 4 mid dialogue
	if _current_loop >= 4 and _current_line_index == 3:  # After boss says "She is not your ward. She is the end."
		return true
	return false

func _show_choice_buttons() -> void:
	_hide_choice_buttons()
	
	if _current_loop == 3:
		_dialogue_ui.get_node("WaitButton").visible = true
		_dialogue_ui.get_node("InterruptButton").visible = true
	elif _current_loop >= 4:
		_dialogue_ui.get_node("ProtectButton").visible = true
		_dialogue_ui.get_node("HesitateButton").visible = true
		_dialogue_ui.get_node("AttackButton").visible = true

func _hide_choice_buttons() -> void:
	_dialogue_ui.get_node("WaitButton").visible = false
	_dialogue_ui.get_node("InterruptButton").visible = false
	_dialogue_ui.get_node("ProtectButton").visible = false
	_dialogue_ui.get_node("HesitateButton").visible = false
	_dialogue_ui.get_node("AttackButton").visible = false

func _on_continue_pressed() -> void:
	_show_next_line()

func _on_wait_pressed() -> void:
	_player_choice = &"wait"
	_update_alignment(Alignment.DOUBT)
	_show_next_line()

func _on_interrupt_pressed() -> void:
	_player_choice = &"interrupt"
	_update_alignment(Alignment.REJECT)
	_show_next_line()

func _on_protect_pressed() -> void:
	_player_choice = &"protect"
	_update_alignment(Alignment.CALAMITY)
	_show_next_line()

func _on_hesitate_pressed() -> void:
	_player_choice = &"hesitate"
	_update_alignment(Alignment.DOUBT)
	_show_next_line()

func _on_attack_pressed() -> void:
	_player_choice = &"attack"
	_update_alignment(Alignment.REJECT)
	_show_next_line()

func _end_dialogue() -> void:
	_is_showing_dialogue = false
	_hide_choice_buttons()
	_dialogue_ui.get_node("LeftBubble").visible = false
	_dialogue_ui.get_node("RightBubble").visible = false
	_dialogue_ui.get_node("ContinueButton").visible = false
	
	_game_state_machine.exit_dialogue("dialogue_ended")
	dialogue_ended.emit()

func _on_timeline_reset(_reason: StringName) -> void:
	_current_loop += 1
	if _game_manager:
		_game_manager.set_persistent_flag(&"loop_count", _current_loop)
		_game_manager.set_persistent_flag(&"last_choice", _player_choice)
		_game_manager.set_persistent_flag(&"alignment", _current_alignment)

func _update_alignment(alignment: Alignment) -> void:
	_current_alignment = alignment
	if _game_manager:
		_game_manager.set_persistent_flag(&"alignment", alignment)

func _update_alignment_from_flags() -> void:
	if _game_manager:
		_current_alignment = _game_manager.get_persistent_flag(&"alignment", Alignment.CALAMITY)

func get_current_loop() -> int:
	return _current_loop

func get_current_alignment() -> Alignment:
	return _current_alignment

func is_showing_dialogue() -> bool:
	return _is_showing_dialogue