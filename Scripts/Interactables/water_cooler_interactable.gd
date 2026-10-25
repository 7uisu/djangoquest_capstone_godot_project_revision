extends Area2D

## Water Cooler & Dispenser
## Used in office corridors and break rooms. Restores focus and hydration.

signal water_dispensed()

@export var interaction_text: String = "[F] Drink Cold Water"
@export var hydration_message: String = "Hydrated Engineer! Focus and concentration restored."

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var cooler_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var is_dispensing: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	add_to_group("water_coolers")
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
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
	if is_dispensing:
		return

	is_dispensing = true
	_show_feedback("Dispensing water...", Color(0.4, 0.8, 1.0, 1.0))

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("dispense"):
		anim_sprite.play("dispense")

	var timer = get_tree().create_timer(1.0)
	await timer.timeout

	is_dispensing = false
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")

	water_dispensed.emit()
	_show_feedback(hydration_message, Color(0.3, 1.0, 0.6, 1.0))


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
