# Scripts/UI/login_screen.gd
# Login screen shown before the main menu.
# Supports email/password login and "Play as Guest" skip.
extends Control

@onready var email_input: LineEdit = $CenterContainer/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $CenterContainer/VBoxContainer/PasswordHBox/PasswordInput
@onready var toggle_password_btn: Button = $CenterContainer/VBoxContainer/PasswordHBox/TogglePasswordBtn
@onready var login_button: Button = $CenterContainer/VBoxContainer/LoginButton
@onready var guest_button: Button = $CenterContainer/VBoxContainer/GuestButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel

var _loading_overlay = null

func _ready():
	login_button.pressed.connect(_on_login_pressed)
	guest_button.pressed.connect(_on_guest_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	ApiManager.login_completed.connect(_on_login_completed)
	
	email_input.text_changed.connect(_on_input_changed)
	password_input.text_changed.connect(_on_input_changed)
	toggle_password_btn.toggled.connect(_on_toggle_password)
	_update_login_button_state()

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
		_show_loading("Opening main menu...")
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
	_show_loading("Logging in...")
	ApiManager.login(email, password)

func _on_login_completed(success: bool, message: String):
	_update_login_button_state()
	guest_button.disabled = false
	status_label.text = message

	if success:
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		CharacterData.api_username = ApiManager.get_username()
		
		# Pre-fetch cloud save to check for conflicts or promotion
		var sm = get_node_or_null("/root/SaveManager")
		if sm:
			status_label.text = "Checking cloud saves..."
			_show_loading("Checking cloud saves...")
			sm.cloud_save_checked.connect(_on_cloud_save_checked_for_login, CONNECT_ONE_SHOT)
			sm.check_cloud_save()
		else:
			_proceed_to_main_menu()
	else:
		_hide_loading()
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _on_cloud_save_checked_for_login(has_cloud: bool):
	var sm = get_node_or_null("/root/SaveManager")
	var has_guest = sm.has_guest_save() if sm and sm.has_method("has_guest_save") else false
	var has_local_account = sm.has_local_account_save() if sm and sm.has_method("has_local_account_save") else false
	
	if has_guest and has_cloud:
		_hide_loading()
		CustomConfirm.prompt(
			"Use Account Save?",
			"This account already has an online save. Use the account save now? Your guest save will stay on this laptop.",
			_confirm_use_account_save,
			_keep_playing_as_guest
		)
	elif has_guest and not has_cloud and not has_local_account:
		_hide_loading()
		CustomConfirm.prompt(
			"Move Guest Save?",
			"This account has no save yet. Move your guest save to this account?",
			_move_guest_save_to_account,
			_confirm_use_account_save
		)
	else:
		# Normal login
		_proceed_to_main_menu()

func _proceed_to_main_menu():
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

func _confirm_use_account_save() -> void:
	_show_loading("Opening account save...")
	_proceed_to_main_menu()

func _keep_playing_as_guest() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.clear_account_save()
	ApiManager.logout()
	CharacterData.api_username = ""
	_show_loading("Opening guest save...")
	_proceed_to_main_menu()

func _move_guest_save_to_account() -> void:
	status_label.text = "Promoting guest save to your account..."
	_show_loading("Promoting guest save to your account...")
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.promote_guest_to_account()
	_proceed_to_main_menu()

func _show_loading(message: String) -> void:
	if _loading_overlay and is_instance_valid(_loading_overlay):
		if _loading_overlay.has_method("set_subtitle"):
			_loading_overlay.set_subtitle(message)
		return
	var LoadingOverlay = load("res://Scripts/UI/loading_overlay.gd")
	if LoadingOverlay:
		_loading_overlay = LoadingOverlay.create(get_tree(), message)

func _hide_loading() -> void:
	if _loading_overlay and is_instance_valid(_loading_overlay):
		_loading_overlay.dismiss()
	_loading_overlay = null

func _on_guest_pressed():
	CharacterData.api_username = ""
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

func _on_quit_pressed():
	CustomConfirm.prompt(
		"Quit Game", 
		"Are you sure you want to quit?", 
		func(): get_tree().quit()
	)

func _on_input_changed(_text: String):
	_update_login_button_state()

func _on_toggle_password(button_pressed: bool):
	password_input.secret = not button_pressed
	if button_pressed:
		toggle_password_btn.text = "✖️"
	else:
		toggle_password_btn.text = "👁️"

func _update_login_button_state():
	if email_input.text.strip_edges() == "" or password_input.text.strip_edges() == "":
		login_button.disabled = true
		login_button.modulate = Color(0.5, 0.5, 0.5, 0.5) # Dark and transparent
	else:
		login_button.disabled = false
		login_button.modulate = Color(1.0, 1.0, 1.0, 1.0) # Bright and clickable
