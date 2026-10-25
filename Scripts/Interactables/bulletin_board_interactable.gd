extends Area2D

## Floor Directory & Bulletin Board
## Displays company directory, office floor layout, and team announcements.

signal directory_viewed()

@export var board_id: String = "lobby_directory"
@export var interaction_text: String = "[F] View Floor Directory"
@export var directory_title: String = "DJQ Corp — Floor Directory"
@export var directory_text: String = "• Floor 1: Lobby Atrium, Reception, Meeting Room, QA & Design, Locker Room\n• Floor 2: DevOps, Frontend, Backend, Break Room, Pantry\n• Floor 3: Lead's Office, Server Room, IT Storage, Executive Boardroom"

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var board_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	add_to_group("bulletin_boards")
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
	directory_viewed.emit()

	var dialogue_box = get_tree().current_scene.get_node_or_null("DialogueBox")
	if dialogue_box and dialogue_box.has_method("start"):
		dialogue_box.start([
			{"name": directory_title, "text": directory_text}
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
