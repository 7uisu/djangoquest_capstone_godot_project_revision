extends Area2D

## Animated Locker / Container Interactable
## Plays opening animation, awards item (or displays item popup), and updates locker state.

signal locker_opened(item_id: String)

@export var locker_id: String = "locker_01"
@export var interaction_text: String = "[F] Search Locker"
@export var empty_text: String = "You already got the things inside."
@export var is_locked: bool = false
@export var lock_message: String = "This locker is locked."

## Item rewards (optional)
@export var item_id: String = "green_badge"
@export var item_name: String = "Green Intern Lanyard"
@export var item_description: String = "Official DJQ Corp temporary intern pass."
@export var item_icon: Texture2D = null
@export var auto_add_to_inventory: bool = true

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var locker_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var is_open: bool = false
var is_empty: bool = false
var is_animating: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	add_to_group("lockers")
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	if anim_sprite:
		if not anim_sprite.animation_finished.is_connected(_on_animation_finished):
			anim_sprite.animation_finished.connect(_on_animation_finished)
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("close_idle"):
			anim_sprite.play("close_idle")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = true
		_show_label()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		_hide_label()
		if is_open and not is_animating:
			_close_locker()


func interact() -> void:
	if is_animating:
		return

	if is_locked:
		_show_feedback(lock_message, Color(1.0, 0.4, 0.4, 1.0))
		return

	if is_empty or is_open:
		_show_feedback(empty_text, Color(0.8, 0.8, 0.8, 1.0))
		return

	# Play open animation
	is_animating = true
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("open_animation"):
		anim_sprite.play("open_animation")
	else:
		_complete_open()


func _on_animation_finished() -> void:
	if not is_animating or anim_sprite == null:
		return
	if anim_sprite.animation == "open_animation":
		_complete_open()


func _complete_open() -> void:
	is_animating = true
	is_open = true
	is_empty = true

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("open_idle"):
		anim_sprite.play("open_idle")

	# The popup owns the inventory insertion when available, avoiding duplicate rewards.
	var item_popup = get_node_or_null("/root/ItemPopup")
	if item_popup and item_popup.has_method("show_item"):
		await item_popup.show_item(item_id, item_name, item_description, item_icon)
	elif auto_add_to_inventory and not item_id.is_empty():
		var inv = get_node_or_null("/root/InventoryManager")
		if inv and inv.has_method("add_item"):
			inv.add_item(item_id, item_name, item_description, item_icon, 1)

	is_animating = false
	await _close_locker()
	locker_opened.emit(item_id)
	_show_feedback("Retrieved " + item_name + "!", Color(0.4, 1.0, 0.5, 1.0))


func _close_locker() -> void:
	if not is_open or is_animating:
		return
	is_animating = true
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("close_animation"):
		anim_sprite.play("close_animation")
		await anim_sprite.animation_finished
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("close_idle"):
		anim_sprite.play("close_idle")
	is_open = false
	is_animating = false
	if player_is_inside:
		_show_label()


func _show_feedback(msg: String, col: Color) -> void:
	if interaction_label == null:
		return
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()
	interaction_label.text = msg
	interaction_label.visible = true
	interaction_label.modulate = col

	_label_tween = create_tween()
	_label_tween.tween_interval(1.5)
	_label_tween.tween_property(interaction_label, "modulate:a", 0.0, 0.3)
	_label_tween.tween_callback(func():
		interaction_label.text = empty_text if is_empty else interaction_text
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
	interaction_label.text = empty_text if is_empty else interaction_text
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
