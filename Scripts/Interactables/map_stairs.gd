# map_stairs.gd — Generic script for stair transitions
extends Area2D

@export var interaction_text: String = "(F) to Go Up/Down"
@export var target_scene: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO
## Direction the player should face when entering this map (e.g. "up", "down", "left", "right")
@export var entry_direction: String = "up"

@onready var interaction_label: Label = $Label
var player_is_inside: bool = false
var _label_tween: Tween = null
var has_interacted: bool = false

func _ready():
	# Connect signals dynamically so we don't need to do it in the Godot Inspectot
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
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
		has_interacted = false # RESET interaction so it works again if re-entered
		_hide_label()

# Called by the player's _input()
func interact():
	print("map_stairs: interact() called! has_interacted=", has_interacted, ", target_scene=", target_scene)
	if has_interacted:
		print("map_stairs: ignored because has_interacted is true")
		return
		
	has_interacted = true
	
	# Face the player appropriately before transitioning
	var player = get_tree().get_nodes_in_group("player")
	if player.size() > 0:
		var p = player[0]
		if entry_direction != "none":
			p.current_dir = entry_direction
			if p.has_method("play_idle_animation"):
				p.play_idle_animation(entry_direction)
		
	# Trigger the scene transition
	if target_scene != "":
		var scene_transition = get_node("/root/SceneTransition")
		if scene_transition:
			scene_transition.transition_to_scene(target_scene, spawn_position, entry_direction)

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
