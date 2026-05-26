extends CanvasLayer

@onready var overlay = $Overlay
@onready var resume_btn = $Overlay/CenterContainer/VBoxContainer/ResumeButton
@onready var settings_btn = $Overlay/CenterContainer/VBoxContainer/SettingsButton
@onready var main_menu_btn = $Overlay/CenterContainer/VBoxContainer/MainMenuButton
var _settings_overlay: Control = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.hide()
	resume_btn.pressed.connect(_on_resume_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	_build_settings_popup()

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		var current_scene = get_tree().current_scene
		if current_scene and (current_scene.name == "MainMenu" or current_scene.name == "IntroSlides" or current_scene.name == "LoginScreen"):
			return
		
		var is_story_mode = false
		if current_scene and (current_scene.name.contains("School") or current_scene.name.contains("Dorm") or current_scene.name.contains("Chapter") or get_tree().get_nodes_in_group("player").size() > 0):
			is_story_mode = true

		if is_story_mode:
			return # Let the Laptop UI handle pauses for story mode
		
		# Else, it's learning or challenge mode
		if not get_tree().paused:
			_pause_game()
		else:
			if overlay.visible:
				_unpause_game()

func _pause_game():
	get_tree().paused = true
	overlay.show()

func _unpause_game():
	get_tree().paused = false
	if _settings_overlay:
		_settings_overlay.visible = false
	overlay.hide()

func _on_resume_pressed():
	if _settings_overlay:
		_settings_overlay.visible = false
	_unpause_game()

func _on_settings_pressed():
	if _settings_overlay:
		_settings_overlay.visible = true

func _on_main_menu_pressed():
	if CustomConfirm:
		CustomConfirm.prompt("Exit Game", "Are you sure you want to go back to Main Menu?", func():
			_unpause_game()
			get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
		)
	else:
		_unpause_game()
		get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

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
	dimmer.color = Color(0.0, 0.0, 0.0, 0.72)
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
