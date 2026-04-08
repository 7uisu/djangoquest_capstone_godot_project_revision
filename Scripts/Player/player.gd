# player.gd
extends CharacterBody2D

const MOVEMENT_SPEED = 225.0
const SPRINT_MULTIPLIER = 1.5
const ACCELERATION = 12.0

var inventory_ui_scene = preload("res://Scenes/UI/inventory_ui.tscn")
var inventory_ui = null
var laptop_ui_scene = preload("res://Scenes/UI/laptop_ui.tscn")
var laptop_ui = null
const DECELERATION = 18.0

@onready var pages_label = $Camera2D/Guide1Label
@onready var guide2_label = $Camera2D/Guide2Label
@onready var player_name_label = $Camera2D/PlayerName
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var camera: Camera2D = $Camera2D
@onready var character_data = get_node("/root/CharacterData")

var current_interactive_object = null
var current_dir: String = "down"
var can_interact: bool = false
var can_move: bool = true
var is_sitting: bool = false
var block_ui_input: bool = false  # Set true during IDE/teaching to block E (inventory) and X (laptop)

func _ready():
	add_to_group("player")
	if camera:
		camera.make_current()
	if interaction_area != null:
		interaction_area.area_entered.connect(_on_interaction_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_exited)
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager:
		tutorial_manager.page_collected.connect(_on_page_collected)
	update_pages_label()
	update_player_name_label()
	# Instance inventory UI (available on every map)
	if inventory_ui_scene:
		inventory_ui = inventory_ui_scene.instantiate()
		get_tree().current_scene.add_child.call_deferred(inventory_ui)
	# Instance laptop UI (available on every map)
	if laptop_ui_scene:
		laptop_ui = laptop_ui_scene.instantiate()
		get_tree().current_scene.add_child.call_deferred(laptop_ui)
		
	# --- TEMP: Give 50 Encrypted Drives for testing ---
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		var icon = load("res://Textures/School Textures/Items/Interactable/Encrypted Drive-32x32.png")
		inv.add_item("encrypted_drive", "Encrypted Drive", "Automatically solves the challenge.", icon, 50)
	# --------------------------------------------------

func _physics_process(delta):
	# When sitting, freeze completely — no movement, no animation changes
	if is_sitting:
		velocity = Vector2.ZERO
		return

	if not can_move:
		velocity = velocity.lerp(Vector2.ZERO, DECELERATION * delta)
		move_and_slide()
		play_idle_animation(current_dir)
		return

	# --- Input ---
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	# --- Sprint ---
	var speed = MOVEMENT_SPEED
	if Input.is_action_pressed("sprint"):
		speed *= SPRINT_MULTIPLIER

	# --- Velocity with acceleration / deceleration ---
	var target_velocity = direction.normalized() * speed if direction != Vector2.ZERO else Vector2.ZERO

	if direction != Vector2.ZERO:
		velocity = velocity.lerp(target_velocity, ACCELERATION * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, DECELERATION * delta)
		# Snap to zero when close enough to avoid micro-drift
		if velocity.length() < 5.0:
			velocity = Vector2.ZERO

	# --- Direction tracking ---
	if direction != Vector2.ZERO:
		if direction.x > 0 and direction.y < 0:
			current_dir = "up_right"
		elif direction.x < 0 and direction.y < 0:
			current_dir = "up_left"
		elif direction.x > 0 and direction.y > 0:
			current_dir = "down_right"
		elif direction.x < 0 and direction.y > 0:
			current_dir = "down_left"
		elif direction.x > 0:
			current_dir = "right"
		elif direction.x < 0:
			current_dir = "left"
		elif direction.y > 0:
			current_dir = "down"
		elif direction.y < 0:
			current_dir = "up"

	# --- Move and animate ---
	move_and_slide()
	if velocity.length() < 5.0:
		play_idle_animation(current_dir)
	else:
		play_walk_animation(current_dir)

# Map diagonal directions to cardinal directions for animation
func get_animation_direction(direction: String) -> String:
	match direction:
		"up_right", "up_left":
			return "up"
		"down_right", "down_left":
			return "down"
		_:
			return direction if direction in ["right", "left", "up", "down"] else "down"

func play_idle_animation(direction: String) -> void:
	var anim_dir = get_animation_direction(direction)
	if character_data.selected_gender == "male":
		animated_sprite.play("male_idle_" + anim_dir)
	else:
		animated_sprite.play("female_idle_" + anim_dir)

func play_walk_animation(direction: String) -> void:
	var anim_dir = get_animation_direction(direction)
	if character_data.selected_gender == "male":
		animated_sprite.play("male_walking_" + anim_dir)
	else:
		animated_sprite.play("female_walking_" + anim_dir)

func play_sitting_animation(direction: String) -> void:
	var anim_dir = direction if direction in ["right", "left", "up", "down"] else "down"
	if character_data.selected_gender == "male":
		animated_sprite.play("male_sitting_" + anim_dir)
	else:
		animated_sprite.play("female_sitting_" + anim_dir)

func _input(event):
	# Closing must run even when can_move is false (open() freezes the player) and even if
	# block_ui_input is true, so overlays never get stuck. Opening still gated below.
	if event.is_action_pressed("toggle_inventory"):
		if inventory_ui and inventory_ui.is_open and inventory_ui.has_method("close"):
			inventory_ui.close()
			return

	if event.is_action_pressed("toggle_laptop"):
		if laptop_ui and laptop_ui.is_open and laptop_ui.has_method("close"):
			var qm_close = get_node_or_null("/root/QuestManager")
			laptop_ui.close()
			if qm_close:
				qm_close.show_quest()
			return

	# Interact (F) while frozen — e.g. Ch1 convenience cutscene leaves can_move false at the café door
	if event.is_action_pressed("interact") and can_interact and not block_ui_input:
		if not ((inventory_ui and inventory_ui.is_open) or (laptop_ui and laptop_ui.is_open)):
			for area in interaction_area.get_overlapping_areas():
				if area.has_method("interact"):
					print("Player: F pressed, interacting with: ", area.name)
					area.interact()
					break
		return

	# Block opening new UI during cutscenes / teaching / coding IDE
	if not can_move or block_ui_input:
		return

	# Toggle inventory (E key) — open only (close handled above)
	if event.is_action_pressed("toggle_inventory"):
		if laptop_ui and laptop_ui.is_open:
			return  # Don't open inventory while laptop is open
		if inventory_ui and inventory_ui.has_method("open") and inventory_ui.has_method("close"):
			if not inventory_ui.is_open:
				inventory_ui.open()
		return

	# Toggle laptop (X key) — open only
	if event.is_action_pressed("toggle_laptop"):
		if inventory_ui and inventory_ui.is_open:
			return  # Don't open laptop while inventory is open
		if laptop_ui and laptop_ui.has_method("open") and laptop_ui.has_method("close"):
			if not laptop_ui.is_open:
				var qm = get_node_or_null("/root/QuestManager")
				if qm:
					qm.hide_quest()
				laptop_ui.open()
		return

	# Don't allow other input while inventory or laptop is open
	if (inventory_ui and inventory_ui.is_open) or (laptop_ui and laptop_ui.is_open):
		return

# Use area detection for interactables (doors, NPCs, items are Area2D)
func _on_interaction_area_entered(area: Area2D) -> void:
	if area.has_method("interact"):
		can_interact = true

func _on_interaction_area_exited(area: Area2D) -> void:
	if area.has_method("interact"):
		# Only disable if no other interactable areas remain
		var still_overlapping = false
		for remaining in interaction_area.get_overlapping_areas():
			if remaining != area and remaining.has_method("interact"):
				still_overlapping = true
				break
		if not still_overlapping:
			can_interact = false

func is_player() -> bool:
	return true

func _on_page_collected(_page_number, _title, _command):
	update_pages_label()

func update_pages_label():
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager and pages_label:
		var collected = tutorial_manager.get_all_collected_pages().size()
		pages_label.text = "Pages: " + str(collected) + "/6"

func update_player_name_label():
	if player_name_label and character_data:
		if character_data.player_name != "":
			player_name_label.text = character_data.player_name
		else:
			player_name_label.text = "Player"
		player_name_label.visible = true

func show_guide2_message(text: String, duration: float = 3.0):
	if guide2_label:
		guide2_label.text = text
		guide2_label.visible = true
		await get_tree().create_timer(duration).timeout
		guide2_label.visible = false

func get_collected_pages() -> int:
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager:
		return tutorial_manager.get_all_collected_pages().size()
	return 0

func refresh_player_name():
	update_player_name_label()
