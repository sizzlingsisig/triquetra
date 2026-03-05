extends CharacterBody2D

enum Form { SWORD, SPEAR, BOW }

var current_form = Form.SWORD

func update_animation(state: String):
	var prefix = ""

	match current_form:
		Form.SWORD:
			prefix = "sword_"
		Form.SPEAR:
			prefix = "spear_"
		Form.BOW:
			prefix = "bow_"

	$AnimatedSprite2D.play(prefix + state)
