# door.gd — Unified door interactable script
# Replaces both front_door_1.gd and sideway_right_door_1.gd
extends Area2D

@export var interaction_text: String = "(F) to Interact"
@export var show_once: bool = false
@export var is_locked: bool = false
@export var lock_message: String = "This door is locked."

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var door_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var has_interacted: bool = false
var player_is_inside: bool = false
var is_door_open: bool = false
var is_animating: bool = false
var _label_tween: Tween = null

func _ready():
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	if anim_sprite:
		# Use animation_looped because door animations have loop=true in SpriteFrames.
		# animation_finished does NOT fire for looping animations in Godot 4.
		if not anim_sprite.animation_looped.is_connected(_on_animation_looped):
			anim_sprite.animation_looped.connect(_on_animation_looped)
		anim_sprite.play("close_idle")

	is_door_open = false
	if door_collision:
		door_collision.disabled = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = true
		_show_label()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		_hide_label()

# Called by the player's _input() — the door does NOT poll input itself
func interact():
	if show_once and has_interacted:
		return

	if is_animating:
		return

	if is_locked:
		_show_locked_feedback()
		return

	is_animating = true
	has_interacted = true

	if is_door_open:
		anim_sprite.play("close_animation")
	else:
		anim_sprite.play("open_animation")

# Called when a looping animation completes one full loop
func _on_animation_looped():
	if not is_animating:
		return

	is_animating = false

	if anim_sprite.animation == "open_animation":
		is_door_open = true
		anim_sprite.play("open_idle")
		if door_collision:
			door_collision.disabled = true

	elif anim_sprite.animation == "close_animation":
		is_door_open = false
		anim_sprite.play("close_idle")
		if door_collision:
			door_collision.disabled = false

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

# --- Lock mechanic ---

func unlock():
	is_locked = false

func lock():
	is_locked = true

func _show_locked_feedback():
	if not interaction_label:
		return
	var original_text = interaction_label.text
	interaction_label.text = lock_message
	interaction_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	await get_tree().create_timer(1.2).timeout
	interaction_label.remove_theme_color_override("font_color")
	if player_is_inside:
		interaction_label.text = original_text
	else:
		_hide_label()
