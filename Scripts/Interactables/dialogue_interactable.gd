# dialogue_interactable.gd — Simple interactable that triggers visual novel dialogue
# Attach to an Area2D node. Add a Sprite2D/AnimatedSprite2D as a child for visuals.
extends Area2D

@export var interaction_text: String = "(F) to Talk"
@export var speaker_name: String = "???"
@export var speaker_portrait: Texture2D = null

## Dialogue lines — each entry is one text box.
## Set these in the inspector or override _get_dialogue_lines().
@export_multiline var dialogue_line_1: String = "Hello, adventurer!"
@export_multiline var dialogue_line_2: String = ""
@export_multiline var dialogue_line_3: String = ""
@export_multiline var dialogue_line_4: String = ""
@export_multiline var dialogue_line_5: String = ""

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var _label_tween: Tween = null

func _ready():
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = true
		_show_label()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		_hide_label()

## Called by the player's _input() when pressing interact
func interact():
	var lines = _build_dialogue_lines()
	if lines.is_empty():
		return

	# Find the dialogue box in the scene tree
	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start(lines, speaker_portrait)

func _build_dialogue_lines() -> Array:
	var lines: Array = []
	var raw_lines = [dialogue_line_1, dialogue_line_2, dialogue_line_3, dialogue_line_4, dialogue_line_5]
	for line_text in raw_lines:
		if line_text != "":
			lines.append({
				"name": speaker_name,
				"text": line_text,
				"portrait": speaker_portrait
			})
	return lines

func _get_dialogue_box():
	# Try to find an existing DialogueBox in the scene
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	# Fallback: search by class
	for node in get_tree().get_nodes_in_group(""):
		pass
	# Final fallback: look for it as a direct child of the current scene
	var scene_root = get_tree().current_scene
	for child in scene_root.get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	return null

# --- Label fade helpers (same pattern as door.gd) ---

func _show_label():
	if not interaction_label:
		return
	interaction_label.text = interaction_text
	interaction_label.visible = true
	_kill_label_tween()
	_label_tween = create_tween()
	_label_tween.tween_property(interaction_label, "modulate:a", 1.0, 0.15)

func _hide_label():
	if not interaction_label:
		return
	_kill_label_tween()
	_label_tween = create_tween()
	_label_tween.tween_property(interaction_label, "modulate:a", 0.0, 0.15)
	_label_tween.tween_callback(func(): interaction_label.visible = false)

func _kill_label_tween():
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()
