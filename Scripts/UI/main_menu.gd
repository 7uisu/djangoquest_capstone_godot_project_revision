# main_menu.gd — Main menu with Story, Learning, and Challenge modes
extends Control

@onready var story_button: Button = $VBoxContainer/StoryButton
@onready var learning_button: Button = $VBoxContainer/LearningButton
@onready var challenge_button: Button = $VBoxContainer/ChallengeButton

func _ready():
	story_button.pressed.connect(_on_story_pressed)
	learning_button.pressed.connect(_on_learning_pressed)
	challenge_button.pressed.connect(_on_challenge_pressed)

	# Disable modes that aren't ready yet
	learning_button.disabled = true
	challenge_button.disabled = true

func _on_story_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/gender_select.tscn")

func _on_learning_pressed():
	pass  # TODO: Learning Mode

func _on_challenge_pressed():
	pass  # TODO: Challenge Mode
