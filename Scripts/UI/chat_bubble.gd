# chat_bubble.gd — Chat-bubble-style dialogue (appears above NPC)
# Attach to the root Control of chat_bubble.tscn
# Instantiated as a child of the interactable NPC node.
extends Control

signal dialogue_started
signal dialogue_finished

@onready var panel: PanelContainer  = $Panel
@onready var name_label: Label      = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var text_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TextLabel
@onready var continue_indicator: Label = $Panel/MarginContainer/VBoxContainer/ContinueIndicator

# Typewriter settings
@export var chars_per_second: float = 40.0

var dialogue_lines: Array = []
var current_line_index: int = -1
var is_typing: bool = false
var is_active: bool = false
var _type_tween: Tween = null
var _indicator_tween: Tween = null

func _ready():
	visible = false
	continue_indicator.visible = false
	_start_indicator_blink()

func _process(_delta):
	if not is_active or not visible:
		return
	_clamp_to_viewport()

func _clamp_to_viewport():
	# Get camera and viewport info
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return

	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom
	# Camera visible area in world coords
	var cam_pos = camera.global_position
	var half_view = viewport_size / (2.0 * zoom)
	var cam_left = cam_pos.x - half_view.x
	var cam_top = cam_pos.y - half_view.y
	var cam_right = cam_pos.x + half_view.x
	var cam_bottom = cam_pos.y + half_view.y

	# Bubble size in world coords
	var bubble_size = panel.size / zoom
	var padding = 8.0  # pixels of padding from screen edge

	# Get parent NPC's world position as the anchor
	var npc_pos = get_parent().global_position if get_parent() else global_position

	# Default desired position: above the NPC, centered
	var desired_x = npc_pos.x - bubble_size.x / 2.0
	var desired_y = npc_pos.y - bubble_size.y - 60.0 / zoom.y  # 60px gap above NPC

	# Clamp X: keep bubble within left/right edges
	desired_x = clampf(desired_x, cam_left + padding, cam_right - bubble_size.x - padding)

	# Clamp Y: if bubble would go above camera top, push it below the NPC instead
	if desired_y < cam_top + padding:
		desired_y = npc_pos.y + 16.0 / zoom.y  # Below the NPC sprite
	desired_y = clampf(desired_y, cam_top + padding, cam_bottom - bubble_size.y - padding)

	global_position = Vector2(desired_x, desired_y)

func _input(event):
	if not is_active:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			_skip_typing()
		else:
			_advance()
		get_viewport().set_input_as_handled()

## Start a chat-bubble dialogue sequence.
## lines: Array of Dictionaries  { "name": String, "text": String }
func start(lines: Array, _speaker_portrait: Texture2D = null):
	if lines.is_empty():
		return

	dialogue_lines = lines
	current_line_index = -1
	is_active = true
	visible = true

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
	dialogue_lines.clear()
	current_line_index = -1

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
