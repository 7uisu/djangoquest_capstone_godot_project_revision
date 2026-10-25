extends Area2D

## Ch3 glass sliding door: opens automatically when an unlocked player enters.
@export var interaction_text: String = ""
@export var is_locked: bool = false
@export var lock_message: String = "This door is locked."
@export_enum("None", "Green OJT Badge", "Blue Developer Badge") var required_badge: String = "None"
@export var allow_interview_access: bool = false
@export var temporary_access_stages: PackedInt32Array = PackedInt32Array()

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var door_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside := false
var is_door_open := false
var is_animating := false
var _auto_state_pending := false
var _manual_lock := false
var _badge_access_override := false


func _ready() -> void:
	_manual_lock = is_locked
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0
	if anim_sprite:
		if not anim_sprite.animation_looped.is_connected(_on_animation_looped):
			anim_sprite.animation_looped.connect(_on_animation_looped)
		anim_sprite.play("close_idle")
	if door_collision:
		door_collision.disabled = false
	_sync_badge_lock()


func _process(_delta: float) -> void:
	_sync_badge_lock()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_is_inside = true
	_show_label()
	_update_for_player_presence()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_is_inside = false
	_hide_label()
	_update_for_player_presence()


## Kept for scripted choreography (e.g. August opening the door).
## Player input does not call this; normal use is automatic on area entry.
func interact() -> void:
	if is_animating:
		return
	if is_locked and not is_door_open:
		_show_locked_feedback()
		return
	if anim_sprite == null:
		return
	is_animating = true
	anim_sprite.play("close_animation" if is_door_open else "open_animation")


func _on_animation_looped() -> void:
	if not is_animating or anim_sprite == null:
		return
	is_animating = false
	if anim_sprite.animation == "open_animation":
		is_door_open = true
		anim_sprite.play("open_idle")
		if door_collision:
			door_collision.set_deferred("disabled", true)
	elif anim_sprite.animation == "close_animation":
		is_door_open = false
		anim_sprite.play("close_idle")
		if door_collision:
			door_collision.set_deferred("disabled", false)
	if _auto_state_pending:
		_update_for_player_presence()


func unlock() -> void:
	_manual_lock = false
	interaction_text = ""
	if interaction_label:
		interaction_label.text = interaction_text
	_sync_badge_lock()


func lock() -> void:
	_manual_lock = true
	_sync_badge_lock()


func set_badge_access_override(enabled: bool) -> void:
	_badge_access_override = enabled
	_sync_badge_lock()


func _sync_badge_lock() -> void:
	var should_be_locked := _manual_lock or not _has_badge_access()
	if should_be_locked == is_locked:
		return
	is_locked = should_be_locked
	if player_is_inside:
		_show_label()
	_update_for_player_presence()


func _has_badge_access() -> bool:
	if _badge_access_override:
		return true
	if required_badge == "None":
		return true
	var character_data := get_node_or_null("/root/CharacterData")
	if required_badge == "Green OJT Badge" and character_data and (character_data.ch3_has_green_badge or character_data.ch3_has_blue_badge):
		return true
	if required_badge == "Blue Developer Badge" and character_data and character_data.ch3_has_blue_badge:
		return true
	if allow_interview_access and character_data and character_data.ch3_receptionist_talked and not character_data.ch3_interview_passed:
		return true
	var story_stage := int(get_tree().root.get_meta("ch3_office_story_stage", 0))
	return temporary_access_stages.has(story_stage)


func _update_for_player_presence() -> void:
	_auto_state_pending = true
	if is_animating:
		return
	var should_be_open := player_is_inside and not is_locked
	if should_be_open != is_door_open:
		interact()
	else:
		_auto_state_pending = false


func _show_label() -> void:
	if interaction_label == null:
		return
	interaction_label.text = lock_message if is_locked else interaction_text
	interaction_label.visible = not interaction_label.text.is_empty()
	interaction_label.modulate.a = 1.0 if interaction_label.visible else 0.0


func _hide_label() -> void:
	if interaction_label:
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0


func _show_locked_feedback() -> void:
	if interaction_label:
		interaction_label.text = lock_message
		interaction_label.visible = true
		interaction_label.modulate.a = 1.0
