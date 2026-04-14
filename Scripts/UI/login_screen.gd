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

	# Add hint about making guest saves permanent
	var hint = Label.new()
	hint.text = "If you want your guest save to be permanent, register and login securely over the cloud."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 250
	
	$CenterContainer/VBoxContainer.add_child(hint)
	$CenterContainer/VBoxContainer.move_child(hint, guest_button.get_index() + 1)

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
		
		# Pre-fetch cloud save to check for conflicts or promotion
		var sm = get_node_or_null("/root/SaveManager")
		if sm:
			status_label.text = "Checking cloud saves..."
			sm.cloud_save_checked.connect(_on_cloud_save_checked_for_login, CONNECT_ONE_SHOT)
			sm.check_cloud_save()
		else:
			_proceed_to_main_menu()
	else:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _on_cloud_save_checked_for_login(has_cloud: bool):
	var sm = get_node_or_null("/root/SaveManager")
	var has_guest = FileAccess.file_exists(sm.GUEST_SAVE_FILE) if sm else false
	
	if has_guest and has_cloud:
		# CONFLICT: Cloud exists + local guest exists
		CustomConfirm.prompt(
			"Overwrite Guest Save?",
			"You have a local guest save, but this account already has a cloud save. Logging in will overwrite your guest save. Are you sure?",
			func():
			_proceed_to_main_menu()
			,
			func():
				ApiManager.logout()
				CharacterData.api_username = ""
				status_label.text = "Login cancelled."
				status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		)
	elif has_guest and not has_cloud:
		# PROMOTION: No cloud game, but guest exists
		status_label.text = "Promoting guest save to your account..."
		if sm:
			sm.promote_guest_to_account()
		await get_tree().create_timer(1.2).timeout
		_proceed_to_main_menu()
	else:
		# Normal login
		_proceed_to_main_menu()

func _proceed_to_main_menu():
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

func _on_guest_pressed():
	CharacterData.api_username = ""
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

func _on_quit_pressed():
	CustomConfirm.prompt(
		"Quit Game", 
		"Are you sure you want to quit?", 
		func(): get_tree().quit()
	)
