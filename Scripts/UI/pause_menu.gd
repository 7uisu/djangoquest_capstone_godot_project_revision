extends CanvasLayer

@onready var overlay = $Overlay
@onready var resume_btn = $Overlay/CenterContainer/VBoxContainer/ResumeButton
@onready var settings_btn = $Overlay/CenterContainer/VBoxContainer/SettingsButton
@onready var main_menu_btn = $Overlay/CenterContainer/VBoxContainer/MainMenuButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.hide()
	resume_btn.pressed.connect(_on_resume_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		var current_scene = get_tree().current_scene
		if current_scene and (current_scene.name == "MainMenu" or current_scene.name == "IntroSlides" or current_scene.name == "LoginScreen"):
			return
		
		if not get_tree().paused:
			_pause_game()
		else:
			if overlay.visible:
				_unpause_game()

func _pause_game():
	# Show/hide enroll button based on login status
	get_tree().paused = true
	overlay.show()

func _unpause_game():
	get_tree().paused = false
	overlay.hide()

func _on_resume_pressed():
	_unpause_game()

func _on_settings_pressed():
	print("Settings not implemented yet")

func _on_main_menu_pressed():
	_unpause_game()
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

