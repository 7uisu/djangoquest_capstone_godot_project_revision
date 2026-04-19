# elevator_door_testing.gd — Elevator door interactable with floor selection UI for TESTING floors
# Attach to elevator_door_1.tscn root Area2D in the Shop and NPC Testing folder.
# Works like the standard elevator but points to the testing scene variants.
extends Area2D

@export var interaction_text: String = "(F) Elevator"

## Which floor is THIS elevator on? Must match one of the floor names below.
@export var current_floor: String = "Ground Floor"

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var door_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var is_animating: bool = false
var is_door_open: bool = false
var _label_tween: Tween = null
var _elevator_ui_instance = null

var _elevator_ui_scene = preload("res://Scenes/UI/elevator_ui.tscn")

# Floor definitions — scene paths and spawn positions
# Spawn position is slightly below the elevator so the player appears in front
const ELEVATOR_SPAWN_OFFSET = Vector2(0, 40)

const FLOORS = [
	{
		"name": "Ground Floor",
		"scene": "res://Scenes/Ch3/Shop and NPC Testing/main_office_3_floor_map_testing_shop_and_npc_challenges.tscn",
		"spawn": Vector2(608, 8)  # Between the two elevator doors + offset
	},
	{
		"name": "2nd Floor",
		"scene": "res://Scenes/Ch3/Shop and NPC Testing/main_office_3_floor_map_2nd_floor_testing_shop_and_npc_challenges.tscn",
		"spawn": Vector2(608, 8)
	},
	{
		"name": "3rd Floor",
		"scene": "res://Scenes/Ch3/Shop and NPC Testing/main_office_3_floor_map_3rd_floor_testing_shop_and_npc_challenges.tscn",
		"spawn": Vector2(608, 8)
	}
]

func _ready():
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	if anim_sprite:
		if not anim_sprite.animation_looped.is_connected(_on_animation_looped):
			anim_sprite.animation_looped.connect(_on_animation_looped)
		anim_sprite.play("close_idle")

	is_door_open = false
	if door_collision:
		door_collision.disabled = false

	# Connect area signals
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
	if is_animating:
		return
	if _elevator_ui_instance != null:
		return  # UI already open

	# Play door open animation
	is_animating = true
	anim_sprite.play("open_animation")

	# Wait for the animation to finish (one loop)
	await anim_sprite.animation_looped
	is_animating = false
	is_door_open = true
	anim_sprite.play("open_idle")
	if door_collision:
		door_collision.disabled = true

	# Now show the floor selection UI
	_open_floor_menu()

func _on_animation_looped():
	pass  # Handled by await in interact()

func _open_floor_menu():
	# Disable player movement while menu is open
	_set_player_movement(false)

	_elevator_ui_instance = _elevator_ui_scene.instantiate()
	get_tree().current_scene.add_child(_elevator_ui_instance)
	_elevator_ui_instance.setup(FLOORS, current_floor)
	_elevator_ui_instance.floor_selected.connect(_on_floor_selected)
	_elevator_ui_instance.cancelled.connect(_on_cancelled)

func _on_floor_selected(scene_path: String, _spawn_pos_ignored: Vector2):
	_cleanup_ui()

	# Face the player toward the elevator before transitioning
	var player = _find_player()
	if player:
		player.current_dir = "up"
		player.play_walk_animation("up")

	# Spawn exactly in front of the specific elevator door that was used
	var dynamic_spawn_pos = global_position + ELEVATOR_SPAWN_OFFSET

	# Use SceneTransition to change scenes
	var scene_transition = get_node("/root/SceneTransition")
	if scene_transition:
		scene_transition.transition_to_scene(scene_path, dynamic_spawn_pos, "up")

func _on_cancelled():
	_cleanup_ui()
	_set_player_movement(true)

	# Close the door back
	if is_door_open:
		is_animating = true
		anim_sprite.play("close_animation")
		await anim_sprite.animation_looped
		is_animating = false
		is_door_open = false
		anim_sprite.play("close_idle")
		if door_collision:
			door_collision.disabled = false

func _cleanup_ui():
	if _elevator_ui_instance:
		_elevator_ui_instance.floor_selected.disconnect(_on_floor_selected)
		_elevator_ui_instance.cancelled.disconnect(_on_cancelled)
		_elevator_ui_instance.queue_free()
		_elevator_ui_instance = null

func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _set_player_movement(enabled: bool) -> void:
	var player = _find_player()
	if player and "can_move" in player:
		player.can_move = enabled

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
