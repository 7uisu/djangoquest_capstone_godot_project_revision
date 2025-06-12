extends Area2D

@export var interaction_text: String = "(F) to Interact"
@onready var interaction_label: Label = $Label
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var door_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

@export var show_once: bool = false
var has_interacted: bool = false
var player_is_inside: bool = false
var is_door_open: bool = false
var is_animating: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("is_player"):
		player_is_inside = true
		if interaction_label:
			interaction_label.visible = true
			interaction_label.text = interaction_text

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("is_player"):
		player_is_inside = false
		if interaction_label:
			interaction_label.visible = false

func _ready():
	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
	
	# Debug prints
	print("Static body found: ", static_body != null)
	print("Door collision found: ", door_collision != null)
	
	# Connect the animation finished signal
	if anim_sprite:
		# Check if signal connection works
		if not anim_sprite.animation_finished.is_connected(_on_animation_finished):
			anim_sprite.animation_finished.connect(_on_animation_finished)
			print("Animation finished signal connected")
		
		# Start with door closed
		anim_sprite.play("close_idle")
		print("Playing close_idle animation")
	
	# Make sure door starts closed with collision enabled
	is_door_open = false
	if door_collision:
		door_collision.disabled = false
		print("Door collision enabled at start")
	else:
		print("ERROR: Door collision not found!")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact") and player_is_inside and not is_animating:
		interact()

func interact():
	if show_once and has_interacted:
		return
	
	if is_animating:
		print("Already animating, ignoring interaction")
		return
	
	print("Interact called - Door open: ", is_door_open)
	is_animating = true
	has_interacted = true
	
	if is_door_open:
		# Close the door
		print("Starting close_animation")
		anim_sprite.play("close_animation")
	else:
		# Open the door
		print("Starting open_animation")
		anim_sprite.play("open_animation")
	
	# Backup timer in case animation_finished doesn't fire
	get_tree().create_timer(1.0).timeout.connect(_on_animation_backup_timeout)

func _on_animation_finished():
	is_animating = false
	print("Animation finished: ", anim_sprite.animation)
	
	if anim_sprite.animation == "open_animation":
		# Door just finished opening
		is_door_open = true
		anim_sprite.play("open_idle")
		# Disable collision when door is open
		if door_collision:
			door_collision.disabled = true
			print("Door collision disabled - door is open")
		print("Door is now open")
		
	elif anim_sprite.animation == "close_animation":
		# Door just finished closing
		is_door_open = false
		anim_sprite.play("close_idle")
		# Enable collision when door is closed
		if door_collision:
			door_collision.disabled = false
			print("Door collision enabled - door is closed")
		print("Door is now closed")

func _on_animation_backup_timeout():
	if is_animating:
		print("Animation backup timeout triggered")
		_on_animation_finished()
