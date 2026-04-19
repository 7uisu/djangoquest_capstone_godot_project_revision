# challenge_npc.gd — NPC that triggers dialogue then a coding challenge
# Attach to an Area2D node. Player interacts → dialogue → coding challenge → reward
extends Area2D

@export var npc_texture: Texture2D
@export var interaction_text: String = "(F) to Talk"
@export var npc_name: String = "ChallengeNPC"

## The challenge to load (must match an ID in coding_challenge_data.gd)
@export var challenge_id: String = "dj_debug_01"

## Optional: which topic to search in (python, html, css, django)
@export var challenge_topic: String = "django"

## Economy & Tracking
@export var npc_id: String = "challenge_npc_1"
@export var reward_credits: int = 50

## Customizable Dialogue
@export_multiline var intro_line_1: String = "Hey there!"
@export_multiline var intro_line_2: String = "Think you know Django? Let's find out."
@export_multiline var success_line: String = "Amazing! You did it! Here are your credits."
@export_multiline var fail_line: String = "No worries, try again when you're ready!"

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var _label_tween: Tween = null
var _is_challenging: bool = false
var _last_choice: int = -1

const ChallengeData = preload("res://Scripts/Games/coding_challenge_data.gd")

func _ready():
	if npc_texture and has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.sprite_frames = _build_sprite_frames(npc_texture)
		$AnimatedSprite2D.play("idle_down")
		
	if interaction_label:
		# Update label if already defeated
		var cd = get_node_or_null("/root/CharacterData")
		if cd and cd.is_npc_defeated(npc_id):
			interaction_label.text = "(F) Rematch"
		else:
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
	if _is_challenging: return
	_is_challenging = true

	challenge_id = challenge_id.strip_edges()
	challenge_topic = challenge_topic.strip_edges()

	var cd = get_node_or_null("/root/CharacterData")
	var already_defeated = cd.is_npc_defeated(npc_id) if cd else false

	var dialogue_box = _get_dialogue_box()
	if not dialogue_box:
		_on_intro_finished()
		return

	_set_player_can_move(false)

	_last_choice = -1
	var custom_on_choice = func(index: int): _last_choice = index
	if not dialogue_box.choice_selected.is_connected(custom_on_choice):
		dialogue_box.choice_selected.connect(custom_on_choice)

	var dialogues = []
	if already_defeated:
		dialogues = [
			{ "name": npc_name, "text": "Back for a rematch? You won't get credits this time, but we can practice!" },
			{ "name": npc_name, "text": "Ready to code?", "choices": ["Accept Challenge", "Decline"] }
		]
	else:
		dialogues = _build_intro_lines()
		dialogues.append({ "name": npc_name, "text": "Reward: 💰 %d credits. Ready?" % reward_credits, "choices": ["Accept Challenge", "Decline"] })

	dialogue_box.start(dialogues, null)
	await dialogue_box.dialogue_finished

	if dialogue_box.choice_selected.is_connected(custom_on_choice):
		dialogue_box.choice_selected.disconnect(custom_on_choice)

	if _last_choice == 1 or _last_choice == -1: # Decline
		_is_challenging = false
		_set_player_can_move(true)
		return

	_on_intro_finished()

func _on_intro_finished():
	_set_player_can_move(false)

	# Spawn the coding challenge UI inside a CanvasLayer so it renders on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.name = "ChallengeCanvasLayer"
	get_tree().current_scene.add_child(canvas_layer)

	var ui_scene = preload("res://Scenes/Games/coding_challenge_ui.tscn")
	var ui = ui_scene.instantiate()
	ui.hide_close_button = true
	canvas_layer.add_child(ui)

	var challenge = _find_challenge()
	if challenge.is_empty():
		push_warning("ChallengeNPC: Could not find challenge with id '" + challenge_id + "'")
		canvas_layer.queue_free()
		_is_challenging = false
		_set_player_can_move(true)
		return

	ui.challenge_completed.connect(_on_challenge_completed.bind(canvas_layer))
	ui.load_challenge(challenge)

func _on_challenge_completed(success: bool, _challenge_id_result: String, canvas_layer: CanvasLayer):
	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()

	_set_player_can_move(false)

	var dialogue_box = _get_dialogue_box()
	if not dialogue_box:
		_on_result_dialogue_finished()
		return

	if not dialogue_box.dialogue_finished.is_connected(_on_result_dialogue_finished):
		dialogue_box.dialogue_finished.connect(_on_result_dialogue_finished, CONNECT_ONE_SHOT)

	var cd = get_node_or_null("/root/CharacterData")
	var already_defeated = cd.is_npc_defeated(npc_id) if cd else false

	if success:
		var lines = [{"name": npc_name, "text": success_line}]
		if not already_defeated and cd:
			cd.add_credits(reward_credits)
			cd.mark_npc_defeated(npc_id)
			lines.append({"name": npc_name, "text": "Here is your reward: 💰 %d credits! Spend them wisely." % reward_credits})
			if interaction_label:
				interaction_text = "(F) Rematch"
				interaction_label.text = interaction_text
		else:
			lines.append({"name": npc_name, "text": "Great job brushing up on your skills!"})
		dialogue_box.start(lines, null)
	else:
		dialogue_box.start([{"name": npc_name, "text": fail_line}], null)

func _on_result_dialogue_finished():
	_is_challenging = false
	_set_player_can_move(true)

func _find_challenge() -> Dictionary:
	var challenges = ChallengeData.get_challenges_by_topic(challenge_topic)
	for challenge in challenges:
		if challenge.get("id", "") == challenge_id:
			return challenge

	var all = ChallengeData.get_all_challenges()
	for challenge in all:
		if challenge.get("id", "") == challenge_id:
			return challenge
	return {}

func _build_intro_lines() -> Array:
	var lines: Array = []
	for line_text in [intro_line_1, intro_line_2]:
		if line_text != "":
			lines.append({"name": npc_name, "text": line_text, "portrait": null})
	return lines

func _get_dialogue_box():
	var scene = get_tree().current_scene
	if not scene: return null

	# 1. Try finding by name
	var box = scene.find_child("DialogueBox", true, false)
	if box: return box

	# 2. Auto-spawn it if completely missing from the testing scene!
	var db_scene = load("res://Scenes/UI/dialogue_box.tscn")
	if db_scene:
		box = db_scene.instantiate()
		box.name = "DialogueBox"
		scene.add_child(box)
		return box

	return null

func _set_player_can_move(value: bool):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = value

# ─── Label Fade Helpers ──────────────────────────────────────────────────────

func _show_label():
	if not interaction_label: return
	interaction_label.text = interaction_text
	interaction_label.visible = true
	_kill_label_tween()
	_label_tween = create_tween()
	_label_tween.tween_property(interaction_label, "modulate:a", 1.0, 0.15)

func _hide_label():
	if not interaction_label: return
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
	if frames.has_animation("default"):
		frames.remove_animation("default")

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
