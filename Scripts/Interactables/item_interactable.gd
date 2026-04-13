# item_interactable.gd — Interactable that shows dialogue, then gives an item
# Attach to an Area2D node.  Works like dialogue_interactable but also adds an
# item to InventoryManager after the dialogue finishes, then removes itself.
extends Area2D

@export var interaction_text: String = "(F) to Pick Up"

## Item data — set these in the inspector
@export var item_id: String = "example_item"
@export var item_name: String = "Mysterious Item"
@export var item_description: String = "A curious object."
@export var item_icon: Texture2D = null

## Dialogue lines shown before picking up the item
@export var speaker_name: String = ""
@export_multiline var dialogue_line_1: String = "You found something!"
@export_multiline var dialogue_line_2: String = ""
@export_multiline var dialogue_line_3: String = ""

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var has_been_picked_up: bool = false
var _label_tween: Tween = null

func _ready():
	# Check if this item was already picked up in a previous session
	var cd = get_node_or_null("/root/CharacterData")
	if cd and name in cd.picked_up_items:
		has_been_picked_up = true
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		return

	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	# Auto-set the Sprite2D texture to match the item_icon export
	var sprite = get_node_or_null("Sprite2D")
	if sprite and item_icon:
		sprite.texture = item_icon

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not has_been_picked_up:
		player_is_inside = true
		_show_label()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		_hide_label()

## Called by the player's _input() when pressing interact
func interact():
	if has_been_picked_up:
		return

	var lines = _build_dialogue_lines()
	if lines.is_empty():
		# No dialogue — just pick up immediately
		_give_item()
		return

	# Show dialogue first, then give item when dialogue ends
	var dialogue_box = _get_dialogue_box()
	if dialogue_box:
		# Connect to dialogue_finished to give the item after dialogue ends
		if not dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
			dialogue_box.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
		dialogue_box.start(lines, null)
	else:
		# Fallback: no dialogue box found, just give item
		_give_item()

func _on_dialogue_finished():
	_give_item()

func _give_item():
	has_been_picked_up = true

	# Register this pickup so it won't respawn on reload
	var cd = get_node_or_null("/root/CharacterData")
	if cd and not (name in cd.picked_up_items):
		cd.picked_up_items.append(name)

	# Determine quantity to give (check CodingItems for pickup_quantity)
	var qty = 1
	if CodingItems.ITEMS.has(item_id):
		qty = CodingItems.ITEMS[item_id].get("pickup_quantity", 1)

	# Add to inventory
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		inv.add_item(item_id, item_name, item_description, item_icon, qty)

	# Show pickup message via player's Guide2Label
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("show_guide2_message"):
		players[0].show_guide2_message("Obtained: " + item_name, 2.5)

	# Remove from world
	_hide_label()
	visible = false
	# Disable collision so it can't be interacted with again
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

func _build_dialogue_lines() -> Array:
	var lines: Array = []
	var raw_lines = [dialogue_line_1, dialogue_line_2, dialogue_line_3]
	for line_text in raw_lines:
		if line_text != "":
			lines.append({
				"name": speaker_name,
				"text": line_text,
				"portrait": null
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

# --- Label fade helpers ---

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
