# player.gd
extends CharacterBody2D

const MOVEMENT_SPEED = 225.0

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

func _ready():
	add_to_group("player")  # Add this line
	if camera:
		camera.make_current()
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager:
		tutorial_manager.page_collected.connect(_on_page_collected)
	update_pages_label()
	update_player_name_label()

func _process(_delta):
	if not can_move:
		velocity = Vector2.ZERO
		return
		
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	
	velocity = direction.normalized() * MOVEMENT_SPEED if direction != Vector2.ZERO else Vector2.ZERO
	
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

func _physics_process(_delta):
	move_and_slide()
	if velocity == Vector2.ZERO:
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
		"right":
			return "right"
		"left":
			return "left"
		"up":
			return "up"
		"down":
			return "down"
		_:
			return "down"  # Default fallback

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

func _input(event):
	if event.is_action_pressed("interact") and can_interact:
		for area in interaction_area.get_overlapping_areas():
			if area.has_method("interact"):
				area.interact()
				break

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.has_method("is_player"):
		can_interact = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.has_method("is_player"):
		can_interact = false

func is_player() -> bool:
	return true

func _on_page_collected(page_number, title, command):
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
			player_name_label.visible = true
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
