# shop_npc.gd — IT Staff NPC that opens the item shop
# Attach to an Area2D node in the scene. Add a Label child named "Label"
# and an AnimatedSprite2D or Sprite2D for the NPC visual.
extends Area2D

@export var interaction_text: String = "(F) Shop"
@export var npc_name: String = "IT Staff"
@export var npc_texture: Texture2D

@onready var interaction_label: Label = $Label

var player_is_inside: bool = false
var _label_tween: Tween = null
var _shop_ui_instance = null
var _is_shop_open: bool = false

var _shop_ui_scene = preload("res://Scenes/UI/shop_ui.tscn")

# Dialogue box reference — set by the scene controller or found automatically
var dialogue_box = null

func _ready():
	if npc_texture and has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.sprite_frames = _build_sprite_frames(npc_texture)
		$AnimatedSprite2D.play("idle_down")

	if interaction_label:
		interaction_label.text = interaction_text
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = true
		_show_label()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		_hide_label()

func interact():
	if _is_shop_open:
		return

	# Find dialogue box in the scene
	dialogue_box = _get_dialogue_box()

	# Show bored IT Staff dialogue, then open shop
	if dialogue_box:
		_set_player_movement(false)

		var dialogues = [
			{ "name": npc_name, "text": "..." },
			{ "name": npc_name, "text": "Oh. You again." },
			{ "name": npc_name, "text": "What do you want? I've got stuff... if you've got credits." },
		]

		# Pick a random opening line for variety
		var openers = [
			[
				{ "name": npc_name, "text": "..." },
				{ "name": npc_name, "text": "Yeah?" },
				{ "name": npc_name, "text": "Take a look. I don't have all day... actually I do. But still." },
			],
			[
				{ "name": npc_name, "text": "*sigh*" },
				{ "name": npc_name, "text": "Welcome to the supply closet. Don't touch anything you can't afford." },
			],
			[
				{ "name": npc_name, "text": "Oh. A customer." },
				{ "name": npc_name, "text": "I was about to take my 4th nap. Make it quick." },
			],
			[
				{ "name": npc_name, "text": "..." },
				{ "name": npc_name, "text": "Credits for items. Items for survival. It's a beautiful system." },
			],
		]

		dialogues = openers[randi() % openers.size()]

		dialogue_box.start(dialogues, null)
		await dialogue_box.dialogue_finished

		_open_shop()
	else:
		# No dialogue box found, just open shop directly
		_open_shop()

func _open_shop():
	_is_shop_open = true
	_set_player_movement(false)

	_shop_ui_instance = _shop_ui_scene.instantiate()
	get_tree().current_scene.add_child(_shop_ui_instance)
	_shop_ui_instance.shop_closed.connect(_on_shop_closed)
	_shop_ui_instance.open()

func _on_shop_closed():
	_is_shop_open = false
	if _shop_ui_instance:
		_shop_ui_instance.shop_closed.disconnect(_on_shop_closed)
		_shop_ui_instance.queue_free()
		_shop_ui_instance = null
	_set_player_movement(true)

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _set_player_movement(enabled: bool) -> void:
	var player = _find_player()
	if player and "can_move" in player:
		player.can_move = enabled

func _show_label():
	if not interaction_label:
		return
	interaction_label.text = interaction_text
	interaction_label.visible = true
	_kill_label_tween()
	_label_tween = create_tween()
	_label_tween.tween_property(interaction_label, "modulate:a", 1.0, 0.15)

func _hide_label():
	if not interaction_label:
		return
	_kill_label_tween()
	_label_tween = create_tween()
	_label_tween.tween_property(interaction_label, "modulate:a", 0.0, 0.15)
	_label_tween.tween_callback(func(): interaction_label.visible = false)

func _kill_label_tween():
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()

func _get_dialogue_box():
	var scene = get_tree().current_scene
	if not scene: return null

	# 1. Try finding by name
	var box = scene.find_child("DialogueBox", true, false)
	if box: return box

	# 2. Auto-spawn it if completely missing from the testing scene!
	var db_scene = load("res://Scenes/UI/dialogue_box.tscn")
	if db_scene:
		box = db_scene.instantiate()
		box.name = "DialogueBox"
		scene.add_child(box)
		return box

	return null

# ─── Sprite Helper ───────────────────────────────────────────────────────────

func _build_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var frames = SpriteFrames.new()
	# Remove the auto-created "default" animation
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# Animation definitions: [name, y, height, [x_offsets]]
	var anims = [
		["idle_down",                64, 64, [576, 608, 640, 672, 704, 736]],
		["idle_left",                64, 64, [384, 416, 448, 480, 512, 544]],
		["idle_right",               64, 64, [0, 32, 64, 96, 128, 160]],
		["idle_up",                  64, 64, [192, 224, 256, 288, 320, 352]],
		["walking_down",            128, 64, [576, 608, 640, 672, 704, 736]],
		["walking_left",            128, 64, [384, 416, 448, 480, 512, 544]],
		["walking_right",           128, 64, [0, 32, 64, 96, 128, 160]],
		["walking_up",              128, 64, [192, 224, 256, 288, 320, 352]],
		["phone_in_animation_down", 384, 64, [192, 224, 256, 288, 320, 352]],
		["phone_out_animation_down",384, 64, [0, 32, 64, 96, 128, 160]],
		["phone_out_idle_down",     384, 64, [160]],
		["reading_down",            448, 64, [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352]],
	]

	for anim in anims:
		var anim_name: String = anim[0]
		var y: int = anim[1]
		var h: int = anim[2]
		var x_offsets: Array = anim[3]

		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 5.0)

		for x in x_offsets:
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(x, y, 32, h)
			frames.add_frame(anim_name, atlas)

	return frames
