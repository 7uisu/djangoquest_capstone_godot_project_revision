# main_menu.gd — Main menu with Continue, New Game, Learning, and Challenge modes
extends Control

var ChallengePickerUI = preload("res://Scenes/Games/challenge_picker_ui.tscn")
var EnrollPopupScene = preload("res://Scenes/UI/enroll_popup.tscn")

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var story_button: Button = $VBoxContainer/StoryButton
@onready var learning_button: Button = $VBoxContainer/LearningButton
@onready var challenge_button: Button = $VBoxContainer/ChallengeButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var testing_button: Button = $TestingButton
@onready var enroll_button: Button = $VBoxContainer/EnrollButton
@onready var unenroll_button: Button = $VBoxContainer/UnenrollButton
@onready var logout_button: Button = $VBoxContainer/LogoutButton
@onready var login_button: Button = $VBoxContainer/LoginButton

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)
	story_button.pressed.connect(_on_story_pressed)
	learning_button.pressed.connect(_on_learning_pressed)
	challenge_button.pressed.connect(_on_challenge_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	testing_button.pressed.connect(_on_testing_pressed)
	enroll_button.pressed.connect(_on_enroll_pressed)
	unenroll_button.pressed.connect(_on_unenroll_pressed)
	logout_button.pressed.connect(_on_logout_pressed)
	login_button.pressed.connect(_on_login_pressed)
	
	ApiManager.unenroll_completed.connect(_on_unenroll_completed)

	# Show enroll and logout buttons only if logged in
	var is_logged_in = ApiManager.is_logged_in()
	enroll_button.visible = is_logged_in
	unenroll_button.visible = is_logged_in
	logout_button.visible = is_logged_in
	
	# Show login button only if NOT logged in
	login_button.visible = not is_logged_in

	# Enable learning mode now that it's implemented
	learning_button.disabled = false
	# Enable challenge mode
	challenge_button.disabled = false

	# ── Set up Continue button ────────────────────────────────────────
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		# Check for cloud save (async) if logged in
		if is_logged_in:
			continue_button.text = "Continue (checking...)"
			continue_button.disabled = true
			sm.cloud_save_checked.connect(_on_cloud_save_checked, CONNECT_ONE_SHOT)
			sm.check_cloud_save()
		else:
			# Guest — just check local save
			if sm.has_save():
				continue_button.disabled = false
				var summary = sm.get_save_summary()
				if summary.has("player_name"):
					continue_button.text = "Continue (%s)" % summary["player_name"]
			else:
				continue_button.disabled = true
				continue_button.text = "Continue"
	else:
		continue_button.disabled = true

func _on_cloud_save_checked(_has_cloud: bool):
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
		continue_button.disabled = false
		var summary = sm.get_save_summary()
		if summary.has("player_name"):
			continue_button.text = "Continue (%s)" % summary["player_name"]
		else:
			continue_button.text = "Continue"
	else:
		continue_button.disabled = true
		continue_button.text = "Continue"

func _on_continue_pressed():
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.load_game()

func _on_story_pressed():
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
		CustomConfirm.prompt(
			"New Game",
			"Starting a new game will overwrite your current save. Continue?",
			func():
				sm.delete_save()
				sm.prepare_new_game_session_data()
				get_tree().change_scene_to_file("res://Scenes/UI/gender_select.tscn")
		)
	else:
		if sm:
			sm.prepare_new_game_session_data()
		get_tree().change_scene_to_file("res://Scenes/UI/gender_select.tscn")

func _on_learning_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/learning_mode.tscn")

func _on_challenge_pressed():
	# Open challenge picker UI
	var challenge_picker = ChallengePickerUI.instantiate()
	add_child(challenge_picker)

func _on_quit_pressed():
	CustomConfirm.prompt(
		"Quit Game", 
		"Are you sure you want to quit?", 
		func(): get_tree().quit()
	)

func _on_testing_pressed():
	get_tree().change_scene_to_file("res://Scenes/Ch1/school_map_npc_challenges_testing.tscn")

func _on_enroll_pressed():
	var popup = EnrollPopupScene.instantiate()
	add_child(popup)

func _on_unenroll_pressed():
	unenroll_button.text = "Unenrolling..."
	unenroll_button.disabled = true
	ApiManager.unenroll_from_class()

func _on_unenroll_completed(success: bool, message: String):
	unenroll_button.text = message
	await get_tree().create_timer(3.0).timeout
	unenroll_button.text = "Unenroll from Class"
	unenroll_button.disabled = false

func _on_logout_pressed():
	# Clear account save on logout, keep guest save
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.clear_account_save()
	ApiManager.logout()
	get_tree().change_scene_to_file("res://Scenes/UI/login_screen.tscn")

func _on_login_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/login_screen.tscn")
