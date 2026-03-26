# school_map_tutorial.gd — Triggers tutorial dialogue on first visit
# Attach to the SchoolMap root node in school_map.tscn
extends Node2D

@onready var character_data = get_node("/root/CharacterData")

var tutorial_lines: Array = [
	{ "name": "", "text": "Welcome to your new school!" },
	{ "name": "", "text": "Use WASD or Arrow Keys to move around." },
	{ "name": "", "text": "Hold Shift to sprint." },
	{ "name": "", "text": "Press F near objects and people to interact." },
	{ "name": "", "text": "Press E to open your inventory." },
	{ "name": "", "text": "Press X to open your Laptop (DjangoOS)." },
	{ "name": "", "text": "Good luck on your journey!" },
]

func _ready():
	if character_data and not character_data.has_seen_tutorial:
		# Wait a moment for the scene to fully load
		await get_tree().create_timer(0.5).timeout
		_start_tutorial()

func _start_tutorial():
	# Freeze the player
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = false

	# Find the dialogue box
	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.dialogue_finished.connect(_on_tutorial_finished, CONNECT_ONE_SHOT)
		dialogue_box.start(tutorial_lines)
	else:
		# No dialogue box found, just mark as done
		_on_tutorial_finished()

func _on_tutorial_finished():
	character_data.has_seen_tutorial = true

	# Unfreeze the player
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = true

func _get_dialogue_box():
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	for child in get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	return null
