# park_bench.gd — Interactable bench that lets the player sit down
# Attach to the root Area2D of a park bench scene.
extends Area2D

@export var interaction_text: String = "(F) to Sit"
@export var sit_direction: String = "down"  ## "up", "down", "left", "right"
@export var seat_offset: Vector2 = Vector2(0, 0)  ## Fine-tune seated position

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var is_occupied: bool = false
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
		# Don't hide the label if the player is sitting on this bench
		if is_occupied:
			return
		player_is_inside = false
		_hide_label()

## Called by the player's _input() when pressing interact
func interact():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]

	if is_occupied:
		# Stand up
		_stand_up(player)
	else:
		# Sit down
		_sit_down(player)

func _sit_down(player):
	is_occupied = true
	# --- Direction nudge (adjust pixel values here!) ---
	var direction_nudge := Vector2.ZERO
	match sit_direction:
		"up":    direction_nudge = Vector2(0, 0)   # nudge 2px up
		"down":  direction_nudge = Vector2(0, 0)    # no nudge
		"left":  direction_nudge = Vector2(-2, 0)   # nudge 2px left
		"right": direction_nudge = Vector2(2, 0)    # nudge 2px right
	player.global_position = global_position + seat_offset + direction_nudge
	player.can_move = false
	player.is_sitting = true
	player.play_sitting_animation(sit_direction)

	# Hide player shadow while sitting
	var shadow = player.get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false

	# Update label to show stand-up prompt
	if interaction_label:
		interaction_label.text = "(F) to Stand"

func _stand_up(player):
	is_occupied = false
	player.can_move = true
	player.is_sitting = false
	player.play_idle_animation(sit_direction)
	player.current_dir = sit_direction

	# Show player shadow again
	var shadow = player.get_node_or_null("Shadow")
	if shadow:
		shadow.visible = true

	# Update label back
	if interaction_label:
		interaction_label.text = interaction_text
	if not player_is_inside:
		_hide_label()

# --- Label fade helpers (same pattern as door.gd) ---

func _show_label():
	if not interaction_label:
		return
	if is_occupied:
		interaction_label.text = "(F) to Stand"
	else:
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
