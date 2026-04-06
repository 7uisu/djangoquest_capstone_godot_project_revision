# main_menu.gd — Main menu with Story, Learning, and Challenge modes
extends Control

var ChallengePickerUI = preload("res://Scenes/Games/challenge_picker_ui.tscn")

@onready var story_button: Button = $VBoxContainer/StoryButton
@onready var learning_button: Button = $VBoxContainer/LearningButton
@onready var challenge_button: Button = $VBoxContainer/ChallengeButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var testing_button: Button = $TestingButton

func _ready():
	story_button.pressed.connect(_on_story_pressed)
	learning_button.pressed.connect(_on_learning_pressed)
	challenge_button.pressed.connect(_on_challenge_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	testing_button.pressed.connect(_on_testing_pressed)

	# Enable learning mode now that it's implemented
	learning_button.disabled = false
	# Enable challenge mode
	challenge_button.disabled = false

func _on_story_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/gender_select.tscn")

func _on_learning_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/learning_mode.tscn")

func _on_challenge_pressed():
	# Open challenge picker UI
	var challenge_picker = ChallengePickerUI.instantiate()
	add_child(challenge_picker)

func _on_quit_pressed():
	get_tree().quit()

func _on_testing_pressed():
	get_tree().change_scene_to_file("res://Scenes/Ch1/school_map_npc_challenges_testing.tscn")

