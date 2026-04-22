# school_map_tutorial.gd — Interactive controls tutorial on first visit
# Attach to the SchoolMap root node in school_map.tscn
# Shows button key scenes on the player and waits for actual input before advancing.
extends Node2D

const TUTORIAL_OVERLAY_SCRIPT = preload("res://Scripts/UI/tutorial_overlay.gd")

@onready var character_data = get_node("/root/CharacterData")

# Button key scene paths
const KEY_SCENES = {
	"wasd": "res://Scenes/Button Keys/wasd_button.tscn",
	"arrow": "res://Scenes/Button Keys/arrow_button.tscn",
	"shift": "res://Scenes/Button Keys/shift_button.tscn",
	"f": "res://Scenes/Button Keys/f_button.tscn",
	"e": "res://Scenes/Button Keys/e_button.tscn",
	"esc": "res://Scenes/Button Keys/esc_button.tscn",
}

var _active_key_nodes: Array = []  # currently visible key button scene instances
var _tutorial_overlay = null
var _player: Node2D = null
var _dialogue_box = null

func _ready():
	if character_data and not character_data.has_seen_tutorial:
		await get_tree().create_timer(0.5).timeout
		_start_tutorial()

func _start_tutorial():
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

	# Freeze the player
	if _player:
		_player.can_move = false
		_player.block_ui_input = true

	_dialogue_box = _get_dialogue_box()
	if not _dialogue_box:
		_on_tutorial_finished()
		return

	# ── Step 1: WASD / Arrow Keys (wait for move) ────────────────────────
	_show_key_nodes(["wasd", "arrow"])
	if _dialogue_box:
		_dialogue_box.start([
			{ "name": "", "text": "Welcome to your new school!" },
		])
		await _dialogue_box.dialogue_finished

	# Show movement instruction — player must actually move
	if _dialogue_box:
		_dialogue_box.start([
			{ "name": "", "text": "Use [color=#f0c674]WASD[/color] or [color=#f0c674]Arrow Keys[/color] to move around." },
		])
		await _dialogue_box.dialogue_finished

	# Temporarily allow movement so player can move
	if _player:
		_player.can_move = true
		_player.block_ui_input = true
	
	# Wait for actual movement input
	await _wait_for_movement()

	# Re-freeze
	if _player:
		_player.can_move = false
	_hide_key_nodes()

	await get_tree().create_timer(0.3).timeout

	# ── Step 2: Hold Shift to Sprint (info only) ─────────────────────────
	_show_key_nodes(["shift"])
	if _dialogue_box:
		_dialogue_box.start([
			{ "name": "", "text": "Hold [color=#f0c674]Shift[/color] to sprint." },
		])
		await _dialogue_box.dialogue_finished
	_hide_key_nodes()

	await get_tree().create_timer(0.2).timeout

	# ── Step 3: Press F to Interact (info only) ──────────────────────────
	_show_key_nodes(["f"])
	if _dialogue_box:
		_dialogue_box.start([
			{ "name": "", "text": "Press [color=#f0c674]F[/color] near objects and people to interact." },
		])
		await _dialogue_box.dialogue_finished
	_hide_key_nodes()

	await get_tree().create_timer(0.2).timeout

	# ── Step 4: Press E for Inventory (wait for E) ───────────────────────
	_show_key_nodes(["e"])
	if _dialogue_box:
		_dialogue_box.start([
			{ "name": "", "text": "Press [color=#f0c674]E[/color] to open your inventory." },
		])
		await _dialogue_box.dialogue_finished

	# Allow inventory toggle
	if _player:
		_player.block_ui_input = false

	# Wait for player to press E
	await _wait_for_action("toggle_inventory")
	_hide_key_nodes()

	# Wait for inventory to actually open
	await get_tree().create_timer(0.3).timeout

	# Spotlight the inventory panel
	var inv_ui = _player.inventory_ui if _player and "inventory_ui" in _player else null
	if inv_ui and inv_ui.is_open:
		_tutorial_overlay = await _create_tutorial_overlay()
		_tutorial_overlay.start_tutorial([
			{
				"text": "This is your [color=#f0c674]Inventory[/color].\nIf you get any items, you can [color=#f0c674]right-click[/color] to view what they do.",
				"highlight_node": inv_ui.panel if "panel" in inv_ui else null,
				"tooltip_side": "right"
			}
		])
		await _tutorial_overlay.tutorial_finished
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null

	# Close inventory
	if inv_ui and inv_ui.is_open and inv_ui.has_method("close"):
		inv_ui.close()

	# Block UI again briefly
	if _player:
		_player.block_ui_input = true

	character_data.has_seen_inventory_tutorial = true
	await get_tree().create_timer(0.3).timeout

	# ── Step 5: Press Esc for Laptop (wait for Esc) ──────────────────────
	_show_key_nodes(["esc"])
	if _dialogue_box:
		_dialogue_box.start([
			{ "name": "", "text": "Press [color=#f0c674]Esc[/color] to open your Laptop." },
		])
		await _dialogue_box.dialogue_finished

	# Allow laptop toggle
	if _player:
		_player.block_ui_input = false
		_player.can_move = false

	# Wait for Esc
	await _wait_for_action("ui_cancel")
	_hide_key_nodes()

	# Explicitly open the laptop (no built-in Esc handler exists)
	var laptop = get_node_or_null("/root/GlobalLaptopUI")
	if laptop and laptop.has_method("open") and not laptop.is_open:
		laptop.open()

	# Wait for laptop UI to finish opening
	await get_tree().create_timer(0.5).timeout

	# ── Laptop Sub-Tutorial ──────────────────────────────────────────────
	if laptop and laptop.is_open:
		await _run_laptop_tutorial(laptop)

	character_data.has_seen_laptop_tutorial = true
	await get_tree().create_timer(0.2).timeout

	# ── Step 6: Wrap up ──────────────────────────────────────────────────
	if _dialogue_box:
		_dialogue_box.start([
			{ "name": "", "text": "Good luck on your journey!" },
		])
		await _dialogue_box.dialogue_finished

	_on_tutorial_finished()

# ── Laptop Sub-Tutorial ──────────────────────────────────────────────────────

func _run_laptop_tutorial(laptop) -> void:
	# We need to reference specific UI parts — laptop builds them dynamically
	# Use find_child to locate key elements
	_tutorial_overlay = await _create_tutorial_overlay()

	# Step 1: Explain the laptop
	_tutorial_overlay.start_tutorial([
		{
			"text": "This is your [color=#f0c674]Laptop[/color]!\nYou can access apps from here.",
			"highlight_node": laptop.screen_panel if "screen_panel" in laptop else null,
			"tooltip_side": "bottom"
		}
	])
	await _tutorial_overlay.tutorial_finished
	_tutorial_overlay.queue_free()

	# Step 2: Spotlight the Quest Log icon
	var quest_log_btn = _find_app_button(laptop, "quest_log")
	if quest_log_btn:
		_tutorial_overlay = await _create_tutorial_overlay()
		_tutorial_overlay.start_tutorial([
			{
				"text": "[color=#f0c674]Quest Log[/color] — View and track your quests here.",
				"highlight_node": quest_log_btn,
				"tooltip_side": "bottom"
			}
		])
		await _tutorial_overlay.tutorial_finished
		_tutorial_overlay.queue_free()

	# Step 3: SIS notice
	_tutorial_overlay = await _create_tutorial_overlay()
	var sis_btn = _find_app_button(laptop, "sis")
	_tutorial_overlay.start_tutorial([
		{
			"text": "The [color=#f0c674]SIS[/color] (Student Information System) will become active when you reach [color=#f0c674]College[/color].",
			"highlight_node": sis_btn,
			"tooltip_side": "bottom"
		}
	])
	await _tutorial_overlay.tutorial_finished
	_tutorial_overlay.queue_free()
	_tutorial_overlay = null

	# Close laptop
	if laptop.has_method("close"):
		laptop.close()
	await get_tree().create_timer(0.3).timeout

# ── Key Node Management ──────────────────────────────────────────────────────

func _show_key_nodes(key_ids: Array) -> void:
	_hide_key_nodes()
	if not _player:
		return
	var offset_x = 0.0
	var total_width = key_ids.size() * 120.0  # 120 spacing
	var start_x = -total_width / 2.0 + 60.0  # center them
	for key_id in key_ids:
		if KEY_SCENES.has(key_id):
			var scene = load(KEY_SCENES[key_id])
			if scene:
				var instance = scene.instantiate()
				instance.position = Vector2(start_x + offset_x, -50)
				instance.scale = Vector2(2.0, 2.0)  # scale up (sprites are 17x16px)
				_player.add_child(instance)
				_active_key_nodes.append(instance)
				# Auto-play all AnimatedSprite2D animations
				_play_all_animations(instance)
				offset_x += 120.0

func _hide_key_nodes() -> void:
	for node in _active_key_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_active_key_nodes.clear()

# ── Wait Helpers ─────────────────────────────────────────────────────────────

func _wait_for_movement() -> void:
	while true:
		await get_tree().process_frame
		var dir = Input.get_vector("left", "right", "up", "down")
		if dir.length() > 0.1:
			# Wait a moment so they actually see themselves moving
			await get_tree().create_timer(0.5).timeout
			return

func _wait_for_action(action_name: String) -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed(action_name):
			return

# ── Tutorial Finished ────────────────────────────────────────────────────────

func _on_tutorial_finished():
	character_data.has_seen_tutorial = true
	character_data.has_seen_controls_tutorial = true

	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("refresh_ch1_school_quest"):
		qm.refresh_ch1_school_quest()

	# Unfreeze the player
	if _player:
		_player.can_move = true
		_player.block_ui_input = false

	_hide_key_nodes()

# ── Utility ──────────────────────────────────────────────────────────────────

func _get_dialogue_box():
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	for child in get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	return null

func _create_tutorial_overlay():
	var overlay = CanvasLayer.new()
	overlay.set_script(TUTORIAL_OVERLAY_SCRIPT)
	overlay.layer = 150
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(overlay)
	await get_tree().process_frame
	return overlay

func _find_app_button(laptop, app_id: String) -> Control:
	# Laptop builds desktop icons dynamically. Search for a button whose pressed
	# callback opens the given app. We search the desktop grid for buttons.
	if not laptop or not "desktop_view" in laptop:
		return null
	var desktop = laptop.desktop_view
	for child in _get_all_descendants(desktop):
		if child is Button:
			# The button text contains the app icon emoji — match by app name
			var search_names = {
				"sis": "🎓",
				"quest_log": "📋",
				"retro_browser": "🌐",
				"notes": "📝",
				"settings": "⚙️",
			}
			if search_names.has(app_id) and child.text.strip_edges() == search_names[app_id]:
				return child
	return null

func _get_all_descendants(node: Node) -> Array:
	var result = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_descendants(child))
	return result

func _play_all_animations(node: Node) -> void:
	if node is AnimatedSprite2D:
		node.play("default")
	for child in node.get_children():
		_play_all_animations(child)
