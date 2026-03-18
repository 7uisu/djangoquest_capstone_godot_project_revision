# gender_select.gd — Pick male or female character
extends Control

@onready var character_data = get_node("/root/CharacterData")
@onready var male_button: Button = $CenterContainer/HBoxContainer/MalePanel/MaleButton
@onready var female_button: Button = $CenterContainer/HBoxContainer/FemalePanel/FemaleButton

func _ready():
	male_button.pressed.connect(_on_male_pressed)
	female_button.pressed.connect(_on_female_pressed)

func _on_male_pressed():
	character_data.selected_gender = "male"
	get_tree().change_scene_to_file("res://Scenes/UI/intro_slides.tscn")

func _on_female_pressed():
	character_data.selected_gender = "female"
	get_tree().change_scene_to_file("res://Scenes/UI/intro_slides.tscn")

func _input(event):
	# Back to main menu with Escape
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
