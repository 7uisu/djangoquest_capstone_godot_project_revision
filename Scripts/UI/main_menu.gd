# main_menu.gd — Main menu with Continue, New Game, Learning, and Challenge modes
extends Control

var ChallengePickerUI = preload("res://Scenes/Games/challenge_picker_ui.tscn")
var EnrollPopupScene = preload("res://Scenes/UI/enroll_popup.tscn")
var _loading_overlay = null
var _settings_overlay: Control = null

@onready var continue_button: Button = $MenuScroll/MenuCenter/VBoxContainer/PrimaryButtons/ContinueButton
@onready var story_button: Button = $MenuScroll/MenuCenter/VBoxContainer/PrimaryButtons/StoryButton
@onready var learning_button: Button = $MenuScroll/MenuCenter/VBoxContainer/ModeButtons/LearningButton
@onready var challenge_button: Button = $MenuScroll/MenuCenter/VBoxContainer/ModeButtons/ChallengeButton
@onready var quit_button: Button = $MenuScroll/MenuCenter/VBoxContainer/FooterButtons/QuitButton
@onready var settings_button: Button = $MenuScroll/MenuCenter/VBoxContainer/FooterButtons/SettingsButton

@onready var account_status_label: Label = $ProfileCorner/ProfileVBox/AccountStatusLabel
@onready var logout_button: Button = $ProfileCorner/ProfileVBox/SessionButtons/LogoutButton
@onready var login_button: Button = $ProfileCorner/ProfileVBox/SessionButtons/LoginButton

@onready var enroll_button: Button = $EnrollCorner/AccountButtons/EnrollButton
@onready var unenroll_button: Button = $EnrollCorner/AccountButtons/UnenrollButton

@onready var testing_button: Button = $TestingButton

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)
	story_button.pressed.connect(_on_story_pressed)
	learning_button.pressed.connect(_on_learning_pressed)
	challenge_button.pressed.connect(_on_challenge_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
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
	login_button.text = "Login to Account"
	logout_button.text = "Logout / Switch Account"
	_update_account_status_label(is_logged_in)

	# Enable learning mode now that it's implemented
	learning_button.disabled = false
	# Enable challenge mode
	challenge_button.disabled = false
	_build_settings_popup()

	# ── Set up Continue button ────────────────────────────────────────
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		# Check for cloud save (async) if logged in
		if is_logged_in:
			continue_button.text = "Checking Account Save..."
			continue_button.disabled = true
			_show_loading("Checking account save...")
			sm.cloud_save_checked.connect(_on_cloud_save_checked, CONNECT_ONE_SHOT)
			sm.check_cloud_save()
		else:
			# Guest — just check local save
			if sm.has_save():
				continue_button.disabled = false
				var summary = sm.get_save_summary()
				if summary.has("player_name"):
					continue_button.text = "Continue Guest: %s" % summary["player_name"]
				else:
					continue_button.text = "Continue Guest Save"
			else:
				continue_button.disabled = true
				continue_button.text = "No Guest Save Found"
	else:
		continue_button.disabled = true
		continue_button.text = "Save System Unavailable"

func _on_cloud_save_checked(_has_cloud: bool):
	_hide_loading()
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
		continue_button.disabled = false
		var summary = sm.get_save_summary()
		if summary.has("player_name"):
			continue_button.text = "Continue Account: %s" % summary["player_name"]
		else:
			continue_button.text = "Continue Account Save"
	else:
		continue_button.disabled = true
		continue_button.text = "No Account Save Found"

func _update_account_status_label(is_logged_in: bool) -> void:
	if is_logged_in:
		var username = ApiManager.get_username()
		if username == "":
			username = "account"
		account_status_label.text = "Signed in as %s | saves sync online" % username
		account_status_label.add_theme_color_override("font_color", Color(0.62, 0.92, 0.72))
	else:
		account_status_label.text = "Guest mode | saves stay on this laptop"
		account_status_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.88))

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

func _on_settings_pressed() -> void:
	if _settings_overlay:
		_settings_overlay.visible = true

func _on_testing_pressed():
	get_tree().change_scene_to_file("res://Scenes/Ch3/Shop and NPC Testing/main_office_3_floor_map_testing_shop_and_npc_challenges.tscn")

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

func _build_settings_popup() -> void:
	if _settings_overlay:
		return

	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.visible = false
	add_child(_settings_overlay)

	var dimmer = ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.68)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.add_child(dimmer)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 235)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.16, 0.98)
	panel_style.border_color = Color(0.42, 0.5, 0.82, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Audio Settings"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.84, 0.89, 1.0))
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Adjust the background music and the sound effects separately."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.68, 0.8))
	vbox.add_child(subtitle)

	var audio_manager = _get_audio_manager()
	var music_volume = 0.75
	var sfx_volume = 0.85
	if audio_manager:
		music_volume = audio_manager.get_music_volume()
		sfx_volume = audio_manager.get_sfx_volume()

	_add_volume_row(vbox, "Background Music", music_volume, _on_music_volume_changed)
	_add_volume_row(vbox, "Sound Effects", sfx_volume, _on_sfx_volume_changed)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.pressed.connect(func(): _settings_overlay.visible = false)
	vbox.add_child(close_button)

func _add_volume_row(parent: VBoxContainer, label_text: String, current_value: float, changed_handler: Callable) -> void:
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	parent.add_child(block)

	var heading = Label.new()
	heading.text = label_text
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.86, 0.9, 0.98))
	block.add_child(heading)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	block.add_child(row)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = roundi(current_value * 100.0)
	row.add_child(slider)

	var value_label = Label.new()
	value_label.custom_minimum_size = Vector2(44, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d%%" % int(slider.value)
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	row.add_child(value_label)

	slider.value_changed.connect(changed_handler.bind(value_label))

func _on_music_volume_changed(value: float, value_label: Label) -> void:
	value_label.text = "%d%%" % int(round(value))
	var audio_manager = _get_audio_manager()
	if audio_manager:
		audio_manager.set_music_volume(value / 100.0)

func _on_sfx_volume_changed(value: float, value_label: Label) -> void:
	value_label.text = "%d%%" % int(round(value))
	var audio_manager = _get_audio_manager()
	if audio_manager:
		audio_manager.set_sfx_volume(value / 100.0)

func _get_audio_manager() -> Node:
	return get_node_or_null("/root/AudioManager")
