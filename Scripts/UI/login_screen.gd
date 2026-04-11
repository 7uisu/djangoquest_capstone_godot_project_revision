# Scripts/UI/login_screen.gd
# Login screen shown before the main menu.
# Supports email/password login and "Play as Guest" skip.
extends Control

@onready var email_input: LineEdit = $CenterContainer/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $CenterContainer/VBoxContainer/PasswordInput
@onready var login_button: Button = $CenterContainer/VBoxContainer/LoginButton
@onready var guest_button: Button = $CenterContainer/VBoxContainer/GuestButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel

func _ready():
	login_button.pressed.connect(_on_login_pressed)
	guest_button.pressed.connect(_on_guest_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	ApiManager.login_completed.connect(_on_login_completed)

	# Auto-login if a saved token exists
	if ApiManager.is_logged_in():
		status_label.text = "Welcome back, %s!" % ApiManager.get_username()
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		# Set the username in CharacterData
		CharacterData.api_username = ApiManager.get_username()
		await get_tree().create_timer(0.8).timeout
		get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if email == "" or password == "":
		status_label.text = "Please enter your email and password."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		return

	login_button.disabled = true
	guest_button.disabled = true
	status_label.text = "Logging in..."
	status_label.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	ApiManager.login(email, password)

func _on_login_completed(success: bool, message: String):
	login_button.disabled = false
	guest_button.disabled = false
	status_label.text = message

	if success:
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		CharacterData.api_username = ApiManager.get_username()
		await get_tree().create_timer(0.6).timeout
		get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
	else:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _on_guest_pressed():
	CharacterData.api_username = ""
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

func _on_quit_pressed():
	CustomConfirm.prompt(
		"Quit Game", 
		"Are you sure you want to quit?", 
		func(): get_tree().quit()
	)
