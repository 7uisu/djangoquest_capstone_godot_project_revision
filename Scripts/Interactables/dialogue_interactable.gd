# dialogue_interactable.gd — Interactable that triggers dialogue
# Each line can independently use VISUAL_NOVEL or CHAT_BUBBLE mode.
extends Area2D

## Which dialogue UI to use for this NPC.
enum DialogueMode { VISUAL_NOVEL, CHAT_BUBBLE }

## NPC skin — drag any NPC spritesheet here to change appearance per-instance
@export var npc_texture: Texture2D

@export var interaction_text: String = "(F) to Talk"
@export var speaker_name: String = "???"
@export var speaker_portrait: Texture2D = null

## Dialogue lines — each entry is one text box.
@export_group("Dialogue Line 1")
@export_multiline var dialogue_line_1: String = "Hello, adventurer!"
@export var dialogue_line_1_mode: DialogueMode = DialogueMode.VISUAL_NOVEL

@export_group("Dialogue Line 2")
@export_multiline var dialogue_line_2: String = ""
@export var dialogue_line_2_mode: DialogueMode = DialogueMode.VISUAL_NOVEL

@export_group("Dialogue Line 3")
@export_multiline var dialogue_line_3: String = ""
@export var dialogue_line_3_mode: DialogueMode = DialogueMode.VISUAL_NOVEL

@export_group("Dialogue Line 4")
@export_multiline var dialogue_line_4: String = ""
@export var dialogue_line_4_mode: DialogueMode = DialogueMode.VISUAL_NOVEL

@export_group("Dialogue Line 5")
@export_multiline var dialogue_line_5: String = ""
@export var dialogue_line_5_mode: DialogueMode = DialogueMode.VISUAL_NOVEL

@export_group("")

const CHAT_BUBBLE_SCENE = preload("res://Scenes/UI/chat_bubble.tscn")

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var _label_tween: Tween = null
var _chat_bubble_instance: Control = null

# Queue of dialogue groups: each is { "mode": DialogueMode, "lines": Array }
var _dialogue_queue: Array = []
var _is_sequencing: bool = false

func _ready():
	if npc_texture:
		$AnimatedSprite2D.sprite_frames = _build_sprite_frames(npc_texture)
		$AnimatedSprite2D.play("idle_down")
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
	print("dialogue_interactable: interact() called on ", name)
	if _is_sequencing:
		print("dialogue_interactable: blocked by _is_sequencing")
		return  # Already playing dialogue

	# External controller override (e.g. professor lesson controllers)
	if has_meta("lesson_controller"):
		print("dialogue_interactable: has lesson_controller meta!")
		var ctrl = get_meta("lesson_controller")
		if ctrl and ctrl.has_method("_on_professor_interacted"):
			print("dialogue_interactable: calling controller._on_professor_interacted()")
			ctrl._on_professor_interacted()
			return
		else:
			print("dialogue_interactable: ctrl invalid or missing method. ctrl=", ctrl)

	var all_lines = _build_dialogue_lines()
	if all_lines.is_empty():
		print("dialogue_interactable: no dialogue lines, returning")
		return

	# Group consecutive lines that share the same mode
	_dialogue_queue = _group_lines_by_mode(all_lines)
	_is_sequencing = true
	_play_next_group()

## Build lines with per-line mode info.
func _build_dialogue_lines() -> Array:
	var lines: Array = []
	var raw = [
		[dialogue_line_1, dialogue_line_1_mode],
		[dialogue_line_2, dialogue_line_2_mode],
		[dialogue_line_3, dialogue_line_3_mode],
		[dialogue_line_4, dialogue_line_4_mode],
		[dialogue_line_5, dialogue_line_5_mode],
	]
	for entry in raw:
		var text = entry[0]
		var mode = entry[1]
		if text != "":
			lines.append({
				"name": speaker_name,
				"text": text,
				"portrait": speaker_portrait,
				"mode": mode,
			})
	return lines

## Group consecutive lines that share the same mode into batches.
## Returns: Array of { "mode": DialogueMode, "lines": Array[Dict] }
func _group_lines_by_mode(all_lines: Array) -> Array:
	var groups: Array = []
	var current_mode = all_lines[0]["mode"]
	var current_lines: Array = []

	for line in all_lines:
		if line["mode"] == current_mode:
			current_lines.append(line)
		else:
			groups.append({ "mode": current_mode, "lines": current_lines })
			current_mode = line["mode"]
			current_lines = [line]
	# Push the last group
	if current_lines.size() > 0:
		groups.append({ "mode": current_mode, "lines": current_lines })

	return groups

## Play the next group in the queue. Called after each group finishes.
func _play_next_group():
	if _dialogue_queue.is_empty():
		_is_sequencing = false
		return

	var group = _dialogue_queue.pop_front()
	var mode = group["mode"]
	var lines = group["lines"]

	match mode:
		DialogueMode.VISUAL_NOVEL:
			var dialogue_box = _get_dialogue_box()
			if dialogue_box:
				# Connect to finished signal for this batch
				if not dialogue_box.dialogue_finished.is_connected(_on_group_finished):
					dialogue_box.dialogue_finished.connect(_on_group_finished)
				dialogue_box.start(lines, speaker_portrait)
			else:
				_play_next_group()  # Skip if no box found
		DialogueMode.CHAT_BUBBLE:
			var bubble = _get_or_create_chat_bubble()
			if bubble:
				if not bubble.dialogue_finished.is_connected(_on_group_finished):
					bubble.dialogue_finished.connect(_on_group_finished)
				bubble.start(lines, speaker_portrait)
			else:
				_play_next_group()

## When a dialogue group finishes, play the next one.
func _on_group_finished():
	_play_next_group()

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

## Lazily create a ChatBubble as a child of this NPC node.
func _get_or_create_chat_bubble() -> Control:
	# Reuse existing instance if available
	if _chat_bubble_instance and is_instance_valid(_chat_bubble_instance):
		return _chat_bubble_instance
	# Instantiate the placeholder chat bubble scene
	_chat_bubble_instance = CHAT_BUBBLE_SCENE.instantiate()
	add_child(_chat_bubble_instance)
	return _chat_bubble_instance

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

# ─── Sprite Helper ───────────────────────────────────────────────────────────

func _build_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var frames = SpriteFrames.new()
	# Remove the auto-created "default" animation
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# Animation definitions: [name, y, height, [x_offsets]]
	var anims = [
		["idle_down",                64, 64, [576, 608, 640, 672, 704, 736]],
		["idle_left",                64, 64, [384, 416, 448, 480, 512, 544]],
		["idle_right",               64, 64, [0, 32, 64, 96, 128, 160]],
		["idle_up",                  64, 64, [192, 224, 256, 288, 320, 352]],
		["walking_down",            128, 64, [576, 608, 640, 672, 704, 736]],
		["walking_left",            128, 64, [384, 416, 448, 480, 512, 544]],
		["walking_right",           128, 64, [0, 32, 64, 96, 128, 160]],
		["walking_up",              128, 64, [192, 224, 256, 288, 320, 352]],
		["phone_in_animation_down", 384, 64, [192, 224, 256, 288, 320, 352]],
		["phone_out_animation_down",384, 64, [0, 32, 64, 96, 128, 160]],
		["phone_out_idle_down",     384, 64, [160]],
		["reading_down",            448, 64, [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352]],
	]

	for anim in anims:
		var anim_name: String = anim[0]
		var y: int = anim[1]
		var h: int = anim[2]
		var x_offsets: Array = anim[3]

		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 5.0)

		for x in x_offsets:
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(x, y, 32, h)
			frames.add_frame(anim_name, atlas)

	return frames
