extends Area2D

## Office Multi-Function Printer & Scanner
## Used in Floor 1 Copy Corner for printing OJT Clearance and Sprint documents.

signal document_printed(doc_id: String)

@export var printer_id: String = "office_printer_01"
@export var interaction_text: String = "[F] Print OJT Clearance Forms"
@export var is_locked: bool = false
@export var lock_message: String = "No documents queued for printing."
@export var item_id: String = "ojt_clearance_forms"
@export var item_name: String = "Official OJT Clearance & Evaluation Forms"
@export var item_description: String = "Freshly printed evaluation dossier awaiting August and Ivana's signatures."
@export var item_icon: Texture2D = null

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var printer_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var is_printing: bool = false
var has_printed: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	add_to_group("printers")
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
	if is_printing:
		return

	if is_locked:
		_show_feedback(lock_message, Color(1.0, 0.4, 0.4, 1.0))
		return

	if has_printed:
		_show_feedback("Documents already printed.", Color(0.8, 0.8, 0.8, 1.0))
		return

	is_printing = true
	_show_feedback("Printing document...", Color(1.0, 0.85, 0.4, 1.0))

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("printing"):
		anim_sprite.play("printing")

	var timer = get_tree().create_timer(1.2)
	await timer.timeout

	is_printing = false
	has_printed = true

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")

	# Add to inventory
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("add_item"):
		inv.add_item(item_id, item_name, item_description, item_icon, 1)

	var item_popup = get_node_or_null("/root/ItemPopup")
	if item_popup and item_popup.has_method("show_item"):
		item_popup.show_item(item_name, item_description, item_icon)

	document_printed.emit(item_id)
	_show_feedback("Documents Collected!", Color(0.4, 1.0, 0.5, 1.0))


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
		interaction_label.text = "Tray Empty" if has_printed else interaction_text
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
	interaction_label.text = "Tray Empty" if has_printed else interaction_text
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
