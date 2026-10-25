extends Area2D

## Pantry Espresso & Coffee Dispenser
## Used in Floor 2 Pantry for August's Coffee Run sidequest and morning developer life.

signal coffee_brewed()

@export var interaction_text: String = "[F] Brew Coffee"
@export var brewing_time: float = 1.2
@export var coffee_item_id: String = "hot_coffee"
@export var coffee_item_name: String = "Steaming Ceramic Coffee Mug"
@export var coffee_item_description: String = "Freshly brewed dark roast. Perfect fuel for a long debugging session."
@export var coffee_icon: Texture2D = null

@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var machine_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var player_is_inside: bool = false
var is_brewing: bool = false
var _label_tween: Tween = null


func _ready() -> void:
	add_to_group("coffee_machines")
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
	if is_brewing:
		return

	is_brewing = true
	_show_feedback("Brewing fresh roast...", Color(1.0, 0.85, 0.4, 1.0))

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("brewing"):
		anim_sprite.play("brewing")

	var timer = get_tree().create_timer(brewing_time)
	await timer.timeout

	is_brewing = false
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")

	# The popup adds the item itself; use the complete signature to avoid duplicates.
	var item_popup = get_node_or_null("/root/ItemPopup")
	if item_popup and item_popup.has_method("show_item"):
		await item_popup.show_item(coffee_item_id, coffee_item_name, coffee_item_description, coffee_icon)
	else:
		var inv = get_node_or_null("/root/InventoryManager")
		if inv and inv.has_method("add_item"):
			inv.add_item(coffee_item_id, coffee_item_name, coffee_item_description, coffee_icon, 1)

	coffee_brewed.emit()
	_show_feedback("Coffee Ready!", Color(0.4, 1.0, 0.5, 1.0))


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
