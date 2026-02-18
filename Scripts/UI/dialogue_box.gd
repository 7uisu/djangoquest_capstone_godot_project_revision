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

func _ready():
	visible = false
	panel.visible = false
	continue_indicator.visible = false
	_start_indicator_blink()

func _input(event):
	if not is_active:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			# Skip typewriter — show full text immediately
			_skip_typing()
		else:
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
		name_label.text = speaker_name
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
	continue_indicator.visible = true

func _close():
	is_active = false
	visible = false
	panel.visible = false
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
