extends Area2D

## Server Rack Terminal Console
## Used in Floor 3 Server Room for monitoring and incident triage (Chapter 12).

signal server_console_interacted(is_emergency: bool)
signal migration_executed()

@export var rack_id: String = "server_rack_03"
@export var interaction_text: String = "[F] Access Server Console"
@export var is_in_emergency: bool = false
@export var is_resolved: bool = false
@export var is_locked: bool = false
@export var lock_message: String = "Server console is locked. Production operations restricted."

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var rack_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var is_animating: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	add_to_group("server_racks")
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	_update_animation_state()


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
		_show_feedback(lock_message, Color(1.0, 0.4, 0.4, 1.0))
		return

	server_console_interacted.emit(is_in_emergency)

	if anim_sprite and anim_sprite.sprite_frames:
		if is_in_emergency and not is_resolved:
			if anim_sprite.sprite_frames.has_animation("terminal_active"):
				anim_sprite.play("terminal_active")
		else:
			if anim_sprite.sprite_frames.has_animation("normal_idle"):
				anim_sprite.play("normal_idle")


func trigger_emergency_state(emergency: bool) -> void:
	is_in_emergency = emergency
	is_resolved = not emergency
	_update_animation_state()
	if emergency:
		interaction_text = "[F] Triage Critical Error!"
	else:
		interaction_text = "[F] Access Server Console"
	if player_is_inside:
		_show_label()


func resolve_emergency() -> void:
	is_in_emergency = false
	is_resolved = true
	_update_animation_state()
	migration_executed.emit()
	interaction_text = "[F] Check Server Health (200 OK)"
	_show_feedback("HTTP 200 OK — Production Restored", Color(0.4, 1.0, 0.5, 1.0))


func _update_animation_state() -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	if is_in_emergency and not is_resolved:
		if anim_sprite.sprite_frames.has_animation("emergency_alert"):
			anim_sprite.play("emergency_alert")
	elif is_resolved:
		if anim_sprite.sprite_frames.has_animation("terminal_active"):
			anim_sprite.play("terminal_active")
	else:
		if anim_sprite.sprite_frames.has_animation("normal_idle"):
			anim_sprite.play("normal_idle")


func _show_feedback(msg: String, col: Color) -> void:
	if interaction_label == null:
		return
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()
	interaction_label.text = msg
	interaction_label.visible = true
	interaction_label.modulate = col

	_label_tween = create_tween()
	_label_tween.tween_interval(1.8)
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
	if is_in_emergency and not is_resolved:
		interaction_label.modulate = Color(1.0, 0.3, 0.3, 0.0)
	else:
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
