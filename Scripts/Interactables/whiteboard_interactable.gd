extends Area2D

## Sprint Whiteboard & Kanban Board
## Used in Floor 1 Meeting Room & Floor 2 Developer Wing for sprint planning & ticket tracking.

signal board_inspected(board_id: String)

@export var board_id: String = "sprint_kanban_01"
@export var interaction_text: String = "[F] Inspect Sprint Board"
@export var board_title: String = "Sprint 1 — Student Learning Portal"
@export var board_description: String = "Dependencies:\n• Ticket #1 (Backend): Define Teacher/Student Serializer Contract [Kenna]\n• Ticket #3 (Frontend): Teacher Progress Cards (BLOCKED by #1) [Abel]\n• Ticket #101 (QA): Mobile Viewport Navbar Fix [Trainee]"

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var board_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	add_to_group("whiteboards")
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
	board_inspected.emit(board_id)

	var dialogue_box = get_tree().current_scene.get_node_or_null("DialogueBox")
	if dialogue_box and dialogue_box.has_method("start"):
		dialogue_box.start([
			{"name": board_title, "text": board_description}
		])


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
