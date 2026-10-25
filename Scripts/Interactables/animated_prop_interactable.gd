extends Area2D

## General-Purpose Animated Prop Interactable
## Template for interactive world objects (coffee makers, water dispensers, server racks, etc.)

signal prop_interacted(prop_id: String)

@export var prop_id: String = "animated_prop"
@export var interaction_text: String = "[F] Interact"
@export var is_toggleable: bool = false
@export var is_locked: bool = false
@export var lock_message: String = "Nothing happens."

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var prop_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var is_active: bool = false
var is_animating: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	if anim_sprite:
		if not anim_sprite.animation_looped.is_connected(_on_animation_looped):
			anim_sprite.animation_looped.connect(_on_animation_looped)
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


func interact() -> void:
	if is_animating:
		return

	if is_locked:
		_show_locked_feedback()
		return

	prop_interacted.emit(prop_id)

	if anim_sprite and anim_sprite.sprite_frames:
		if is_toggleable:
			is_active = not is_active
			var target_anim = "active" if is_active else "idle"
			if anim_sprite.sprite_frames.has_animation(target_anim):
				anim_sprite.play(target_anim)
		else:
			if anim_sprite.sprite_frames.has_animation("interact"):
				is_animating = true
				anim_sprite.play("interact")


func _on_animation_looped() -> void:
	if not is_animating or anim_sprite == null:
		return
	is_animating = false
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")


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
