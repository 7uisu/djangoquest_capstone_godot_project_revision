extends Area2D

## Workstation / Desk Interactable
## Interacting opens the developer tools (Fake IDE, Fake Browser, GetHub Issues, or target UI scene).

signal workstation_used(workstation_id: String)

@export var workstation_id: String = "trainee_desk"
@export var interaction_text: String = "[F] Use Workstation"
@export var is_locked: bool = false
@export var lock_message: String = "You don't need to use this computer right now."
@export var target_scene: PackedScene = null

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var desk_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var is_active: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	add_to_group("workstations")
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	if anim_sprite:
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = true
		_show_label()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		_hide_label()


## Called by the player's interaction check
func interact() -> void:
	if is_locked:
		_show_locked_feedback()
		return

	if anim_sprite and anim_sprite.sprite_frames:
		if anim_sprite.sprite_frames.has_animation("use"):
			anim_sprite.play("use")
		elif anim_sprite.sprite_frames.has_animation("active"):
			anim_sprite.play("active")

	workstation_used.emit(workstation_id)

	# Transition to target scene or Fake IDE if assigned
	if target_scene:
		_transition_to_scene()


func _transition_to_scene() -> void:
	var scene_transition = get_node_or_null("/root/SceneTransition")
	if scene_transition and scene_transition.has_method("change_scene_to_packed"):
		scene_transition.change_scene_to_packed(target_scene)
	elif scene_transition and scene_transition.has_method("change_scene"):
		scene_transition.change_scene(target_scene.resource_path)
	else:
		get_tree().change_scene_to_packed(target_scene)


func _show_locked_feedback() -> void:
	if interaction_label == null:
		return
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()
	interaction_label.text = lock_message
	interaction_label.visible = true
	interaction_label.modulate = Color(1.0, 0.4, 0.4, 1.0)

	_label_tween = create_tween()
	_label_tween.tween_interval(1.5)
	_label_tween.tween_property(interaction_label, "modulate:a", 0.0, 0.3)
	_label_tween.tween_callback(func():
		interaction_label.text = interaction_text
		interaction_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if player_is_inside:
			_show_label()
		else:
			interaction_label.visible = false
	)


func _show_label() -> void:
	if interaction_label == null:
		return
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()
	interaction_label.text = interaction_text
	interaction_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	interaction_label.visible = true
	_label_tween = create_tween()
	_label_tween.tween_property(interaction_label, "modulate:a", 1.0, 0.2)


func _hide_label() -> void:
	if interaction_label == null:
		return
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()
	_label_tween = create_tween()
	_label_tween.tween_property(interaction_label, "modulate:a", 0.0, 0.2)
	_label_tween.tween_callback(func(): interaction_label.visible = false)


func set_locked(locked: bool, message: String = "") -> void:
	is_locked = locked
	if not message.is_empty():
		lock_message = message
