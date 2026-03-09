# bus_fast_travel.gd — Interactable bus stop for fast travel on the outdoor map
# Attach to the BusFastTravel Area2D node.
extends Area2D

@export var interaction_text: String = "(F) to Travel"

## Define your bus stop destinations here in the inspector.
## Each destination has a name (shown on the button) and a position (where the player teleports).
@export var destination_names: PackedStringArray = ["School", "Park", "Town Center"]
@export var destination_positions: Array[Vector2] = [Vector2(500, 300), Vector2(1500, 800), Vector2(2500, 400)]

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var _label_tween: Tween = null
var _destination_ui_instance = null

var _destination_ui_scene = preload("res://Scenes/UI/bus_destination_ui.tscn")

func _ready():
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	# Connect area signals for player detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

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
	if _destination_ui_instance != null:
		return  # Already open

	_open_destination_menu()

func _open_destination_menu():
	# Disable player movement while menu is open
	_set_player_movement(false)

	_destination_ui_instance = _destination_ui_scene.instantiate()
	get_tree().current_scene.add_child(_destination_ui_instance)

	# Build destinations array and pass to the UI
	var destinations: Array = []
	for i in range(min(destination_names.size(), destination_positions.size())):
		destinations.append({
			"name": destination_names[i],
			"position": destination_positions[i]
		})

	_destination_ui_instance.setup(destinations)
	_destination_ui_instance.destination_selected.connect(_on_destination_selected)
	_destination_ui_instance.cancelled.connect(_on_destination_cancelled)

func _on_destination_selected(target_position: Vector2):
	_cleanup_ui()
	# Use SceneTransition's fast_travel to teleport with animation
	var scene_transition = get_node("/root/SceneTransition")
	if scene_transition:
		scene_transition.fast_travel(target_position)

func _on_destination_cancelled():
	_cleanup_ui()
	_set_player_movement(true)

func _cleanup_ui():
	if _destination_ui_instance:
		_destination_ui_instance.destination_selected.disconnect(_on_destination_selected)
		_destination_ui_instance.cancelled.disconnect(_on_destination_cancelled)
		_destination_ui_instance.queue_free()
		_destination_ui_instance = null

func _set_player_movement(enabled: bool) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and "can_move" in players[0]:
		players[0].can_move = enabled

# --- Label fade helpers (same pattern as dialogue_interactable.gd) ---

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
