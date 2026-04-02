# challenge_npc.gd — NPC that triggers dialogue then a coding challenge
# Attach to an Area2D node. Player interacts → dialogue → coding challenge → reward
extends Area2D

## NPC skin — drag any NPC spritesheet here to change appearance per-instance
@export var npc_texture: Texture2D

## Interaction label text
@export var interaction_text: String = "(F) to Talk"

## NPC identity
@export var npc_name: String = "NPC"
@export_multiline var intro_line_1: String = "Hey there!"
@export_multiline var intro_line_2: String = "Can you help me with this coding problem?"
@export_multiline var intro_line_3: String = ""

## The challenge to load (must match an ID in coding_challenge_data.gd)
@export var challenge_id: String = ""

## Optional: which topic to search in (python, html, css, django)
@export var challenge_topic: String = "python"

## Reward item (after completing the challenge)
@export var reward_item_id: String = ""
@export var reward_item_name: String = ""
@export var reward_item_description: String = ""
@export var reward_item_icon: Texture2D = null

## Success/fail dialogue
@export_multiline var success_line: String = "Amazing! You did it! Here, take this as thanks."
@export_multiline var fail_line: String = "No worries, you can try again anytime!"

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var challenge_completed: bool = false
var _label_tween: Tween = null

const ChallengeData = preload("res://Scripts/Games/coding_challenge_data.gd")

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

func interact():

	# Trim whitespace from Inspector inputs
	challenge_id = challenge_id.strip_edges()
	challenge_topic = challenge_topic.strip_edges()

	if challenge_completed:
		var dialogue_box = _get_dialogue_box()
		if dialogue_box:
			dialogue_box.start([{"name": npc_name, "text": "Thanks again for your help! 😊"}])
		return

	# Show intro dialogue
	var lines = _build_intro_lines()
	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		if not dialogue_box.dialogue_finished.is_connected(_on_intro_finished):
			dialogue_box.dialogue_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
		dialogue_box.start(lines, null)
	else:
		_on_intro_finished()

func _on_intro_finished():

	# Freeze player while challenge is active
	_set_player_can_move(false)

	# Spawn the coding challenge UI inside a CanvasLayer so it renders on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # On top of everything
	canvas_layer.name = "ChallengeCanvasLayer"
	get_tree().current_scene.add_child(canvas_layer)

	var ui_scene = preload("res://Scenes/Games/coding_challenge_ui.tscn")
	var ui = ui_scene.instantiate()
	ui.hide_close_button = true  # Player must complete the challenge, no quitting
	canvas_layer.add_child(ui)

	# Find the challenge by ID
	var challenge = _find_challenge()
	if challenge.is_empty():
		push_warning("ChallengeNPC: Could not find challenge with id '" + challenge_id + "'")
		canvas_layer.queue_free()
		_set_player_can_move(true)
		return


	# Connect to challenge completion — pass the canvas_layer for cleanup
	ui.challenge_completed.connect(_on_challenge_completed.bind(canvas_layer))

	# Load the single challenge
	ui.load_challenge(challenge)

func _on_challenge_completed(success: bool, _challenge_id_result: String, canvas_layer: CanvasLayer):
	# Clean up the CanvasLayer (and UI inside it)
	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()

	# Keep player frozen for the result dialogue
	_set_player_can_move(false)

	# Show result dialogue
	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		# Unfreeze player when result dialogue finishes
		if not dialogue_box.dialogue_finished.is_connected(_on_result_dialogue_finished):
			dialogue_box.dialogue_finished.connect(_on_result_dialogue_finished, CONNECT_ONE_SHOT)

		if success:
			challenge_completed = true
			var lines = [{"name": npc_name, "text": success_line}]

			# Give reward item if defined
			if reward_item_id != "":
				var inv = get_node_or_null("/root/InventoryManager")
				if inv:
					inv.add_item(reward_item_id, reward_item_name, reward_item_description, reward_item_icon)
				lines.append({"name": npc_name, "text": "Here, take this: " + reward_item_name + "! 🎁"})

			dialogue_box.start(lines, null)
		else:
			dialogue_box.start([{"name": npc_name, "text": fail_line}], null)
	else:
		# No dialogue box — just unfreeze
		_set_player_can_move(true)

func _on_result_dialogue_finished():
	_set_player_can_move(true)

func _find_challenge() -> Dictionary:
	# Use the same static function the challenge picker uses
	var challenges = ChallengeData.get_challenges_by_topic(challenge_topic)

	for challenge in challenges:
		if challenge.get("id", "") == challenge_id:
			return challenge

	# Fallback: search ALL topics
	var all = ChallengeData.get_all_challenges()
	for challenge in all:
		if challenge.get("id", "") == challenge_id:
			return challenge

	return {}

func _build_intro_lines() -> Array:
	var lines: Array = []
	for line_text in [intro_line_1, intro_line_2, intro_line_3]:
		if line_text != "":
			lines.append({"name": npc_name, "text": line_text, "portrait": null})
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

func _set_player_can_move(value: bool):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = value

# ─── Label Fade Helpers ──────────────────────────────────────────────────────

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
		["idle_down",     75, 63, [576, 608, 640, 672, 704, 736]],
		["idle_left",     75, 63, [384, 416, 448, 480, 512]],
		["idle_right",    75, 63, [0, 32, 64, 96, 128, 160]],
		["idle_up",       75, 63, [192, 224, 256, 288, 320, 352]],
		["walking_down", 146, 46, [576, 608, 640, 672, 704, 736]],
		["walking_left", 146, 46, [384, 416, 448, 480, 512, 544]],
		["walking_right",146, 46, [0, 32, 64, 96, 128, 160]],
		["walking_up",   146, 46, [192, 224, 256, 288, 320, 352]],
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
