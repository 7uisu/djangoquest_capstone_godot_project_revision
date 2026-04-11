# dialogue_box.gd — Visual novel-style dialogue box
# Attach to the root CanvasLayer of dialogue_box.tscn
extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var text_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TextLabel
@onready var continue_indicator: Label = $Panel/MarginContainer/VBoxContainer/ContinueIndicator
@onready var portrait: TextureRect = $Panel/Portrait

# Typewriter settings
@export var chars_per_second: float = 40.0
@export var auto_advance_delay: float = 0.0  # 0 = manual advance only

var dialogue_lines: Array = []
var current_line_index: int = -1
var is_typing: bool = false
var is_active: bool = false
var _type_tween: Tween = null
var _indicator_tween: Tween = null
var choice_container: HBoxContainer = null
var is_waiting_for_choice: bool = false
var toggle_button: Button = null

signal choice_selected(choice_index: int)

func _ready():
	choice_container = HBoxContainer.new()
	choice_container.visible = false
	choice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_container.add_theme_constant_override("separation", 20)
	$Panel/MarginContainer/VBoxContainer.add_child(choice_container)

	# ── Create Toggle Button ──
	toggle_button = Button.new()
	toggle_button.name = "ToggleVisibilityButton"
	toggle_button.text = "👁 Hide"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 0
	style.border_color = Color(0.45, 0.55, 0.85, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	toggle_button.add_theme_stylebox_override("normal", style)
	toggle_button.add_theme_stylebox_override("hover", style)
	toggle_button.add_theme_stylebox_override("pressed", style)
	toggle_button.add_theme_color_override("font_color", Color(0.65, 0.82, 1, 1))

	var font_resource = preload("res://Textures/Fonts/Pixelify_Sans/PixelifySans-VariableFont_wght.ttf")
	toggle_button.add_theme_font_override("font", font_resource)
	toggle_button.add_theme_font_size_override("font_size", 13)
	
	toggle_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	toggle_button.offset_left = 40
	toggle_button.offset_top = -208
	toggle_button.offset_right = 110
	toggle_button.offset_bottom = -180
	
	toggle_button.visible = false
	toggle_button.pressed.connect(_on_toggle_button_pressed)
	add_child(toggle_button)

	visible = false
	panel.visible = false
	continue_indicator.visible = false
	_start_indicator_blink()

func _on_toggle_button_pressed():
	if panel.visible:
		panel.visible = false
		toggle_button.text = "👁 Show"
	else:
		panel.visible = true
		toggle_button.text = "👁 Hide"

func _input(event):
	if not is_active:
		return
		
	var is_left_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

	if not panel.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or is_left_click:
			panel.visible = true
			if toggle_button:
				toggle_button.text = "👁 Hide"
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			# Skip typewriter — show full text immediately
			_skip_typing()
			get_viewport().set_input_as_handled()
		elif not is_waiting_for_choice:
			# Advance to next line
			_advance()
			get_viewport().set_input_as_handled()

## Start a dialogue sequence.
## lines: Array of Dictionaries, each with:
##   "name": String — speaker name (optional, empty hides name)
##   "text": String — dialogue text
##   "portrait": Texture2D — speaker portrait (optional)
func start(lines: Array, speaker_portrait: Texture2D = null):
	if lines.is_empty():
		return

	dialogue_lines = lines
	current_line_index = -1
	is_active = true
	visible = true
	panel.visible = true
	if toggle_button:
		toggle_button.visible = true
		toggle_button.text = "👁 Hide"

	# Freeze the player
	_set_player_can_move(false)

	emit_signal("dialogue_started")
	_advance()

func _advance():
	current_line_index += 1

	if current_line_index >= dialogue_lines.size():
		_close()
		return

	var line = dialogue_lines[current_line_index]
	var speaker_name = line.get("name", "")
	var text = line.get("text", "")
	var line_portrait = line.get("portrait", null)

	# Update name
	if speaker_name != "":
		var display_name = speaker_name
		if display_name in ["Player", "Mateo", "Solmi", "You"]:
			if ApiManager.is_logged_in():
				display_name = ApiManager.get_username() + " (You)"
			else:
				display_name = "You"
		name_label.text = display_name
		name_label.visible = true
	else:
		name_label.visible = false

	# Update portrait
	if line_portrait is Texture2D:
		portrait.texture = line_portrait
		portrait.visible = true
	else:
		portrait.visible = false

	# Start typewriter
	continue_indicator.visible = false
	_type_text(text)

func _type_text(text: String):
	is_typing = true
	text_label.text = text
	text_label.visible_ratio = 0.0

	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()

	var duration = text.length() / chars_per_second
	_type_tween = create_tween()
	_type_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_type_tween.tween_callback(_on_typing_finished)

func _skip_typing():
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	text_label.visible_ratio = 1.0
	_on_typing_finished()

func _on_typing_finished():
	is_typing = false
	var line = dialogue_lines[current_line_index]
	var choices = line.get("choices", [])
	
	if choices.size() > 0:
		_show_choices(choices)
	else:
		continue_indicator.visible = true

func _show_choices(choices: Array):
	is_waiting_for_choice = true
	continue_indicator.visible = false
	
	for c in choice_container.get_children():
		c.queue_free()
		
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i]
		btn.add_theme_font_size_override("font_size", 16)
		# Add font to choice buttons
		var font_resource = preload("res://Textures/Fonts/Pixelify_Sans/PixelifySans-VariableFont_wght.ttf")
		btn.add_theme_font_override("font", font_resource)
		btn.pressed.connect(func(): _on_choice_pressed(i))
		choice_container.add_child(btn)
		
	choice_container.visible = true
	await get_tree().process_frame
	if choice_container.get_child_count() > 0:
		choice_container.get_child(0).grab_focus()

func _on_choice_pressed(index: int):
	is_waiting_for_choice = false
	choice_container.visible = false
	emit_signal("choice_selected", index)
	_advance()

func _close():
	is_active = false
	visible = false
	panel.visible = false
	if toggle_button:
		toggle_button.visible = false
	dialogue_lines.clear()
	current_line_index = -1

	# Unfreeze the player
	_set_player_can_move(true)

	emit_signal("dialogue_finished")

func _set_player_can_move(value: bool):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = value

func _start_indicator_blink():
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 0.3, 0.5)
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)
