# object_dialogue_interactable.gd — Interactable object (furniture, prop, sign) that shows dialogue in the bottom dialogue box.
extends Area2D

@export var interaction_text: String = "(F) to Inspect"
@export var show_label_once: bool = true  # If true, label text prompt only shows on first approach
@export var speaker_name: String = "Notice"
@export var speaker_portrait: Texture2D = null

@export_group("Dialogue Line 1")
@export_multiline var dialogue_line_1: String = "It's an ordinary office desk."

@export_group("Dialogue Line 2")
@export_multiline var dialogue_line_2: String = ""

@export_group("Dialogue Line 3")
@export_multiline var dialogue_line_3: String = ""

@export_group("Dialogue Line 4")
@export_multiline var dialogue_line_4: String = ""

@export_group("Dialogue Line 5")
@export_multiline var dialogue_line_5: String = ""

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var has_interacted: bool = false
var _label_tween: Tween = null
var _is_interacting: bool = false

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

func interact():
	if _is_interacting:
		return

	has_interacted = true

	var lines = _build_dialogue_lines()
	if lines.is_empty():
		return

	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		_is_interacting = true
		_hide_label()
		if not dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
			dialogue_box.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
		dialogue_box.start(lines, speaker_portrait)

func _on_dialogue_finished():
	_is_interacting = false
	if player_is_inside:
		_show_label()

func _build_dialogue_lines() -> Array:
	var lines: Array = []
	var raw = [dialogue_line_1, dialogue_line_2, dialogue_line_3, dialogue_line_4, dialogue_line_5]
	for text in raw:
		if text != "":
			lines.append({
				"name": speaker_name,
				"text": text,
				"portrait": speaker_portrait
			})
	return lines

func _get_dialogue_box():
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	var scene_root = get_tree().current_scene
	for child in scene_root.get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	return null

func _show_label():
	if not interaction_label:
		return
	if show_label_once and has_interacted:
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
