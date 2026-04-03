# ch1_convenience_store_controller.gd — Internet cafe cutscene after bus fast travel
# Attach to a Node child of OutdoorMap in outdoor_map_convenience_store_cutscene2.tscn
#
# Flow:
#   1. Player bus-fast-travels to Internet Cafe area
#   2. Cutscene auto-triggers: player walks, BFs chat, teacher walks down
#   3. Fullscreen placeholder image + dialogue (teacher surprised)
#   4. Return to top-down: group conversation about college courses (IT/CS)
extends Node

const CHAT_BUBBLE_SCENE = preload("res://Scenes/UI/chat_bubble.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")

@onready var character_data = get_node("/root/CharacterData")

# --- Internet Cafe area positions ---
const INTERNET_CAFE_POS = Vector2(5809, 1389)       # Bus destination
const PLAYER_START_POS = Vector2(5809, 1389)          # Where player appears
const PLAYER_WALK_TARGET_X = 5858.0                   # Walk right to here
const TEACHER_START_POS = Vector2(6065, 1100)         # Teacher starts off-camera (above)
const TEACHER_WALK_TARGET = Vector2(6065, 1350)       # Teacher walks down to here

# Node references
var player: CharacterBody2D = null
var male_bf: CharacterBody2D = null
var female_bf: CharacterBody2D = null
var teacher: CharacterBody2D = null
var dialogue_box = null

var _cutscene_triggered: bool = false

# ── Fullscreen image helpers (same pattern as ch1_school_controller) ───
var _teaching_canvas: CanvasLayer = null
var _teaching_texture_rect: TextureRect = null
var _placeholder_label: Label = null

func _ready():
	await get_tree().process_frame
	_find_nodes()

	if character_data and character_data.ch1_convenience_store_cutscene_done:
		# Already done — hide NPCs
		_hide_npcs()
		return

	# Listen for bus fast travel completion
	var scene_transition = get_node_or_null("/root/SceneTransition")
	if scene_transition:
		scene_transition.fast_travel_completed.connect(_on_fast_travel_completed)

# -----------------------------------------------------------------------
#  SETUP
# -----------------------------------------------------------------------

func _find_nodes():
	var root = get_parent()
	player = _find_in_tree(root, "Player")
	male_bf = _find_in_tree(root, "MaleBestFriend")
	female_bf = _find_in_tree(root, "FemaleBestFriend")
	teacher = _find_in_tree(root, "SHSTeacher")
	dialogue_box = _get_dialogue_box()

	# Initially hide NPCs until the cutscene triggers
	if not character_data.ch1_convenience_store_cutscene_done:
		_hide_npcs()

func _find_in_tree(root: Node, node_name: String) -> Node:
	var n = root.get_node_or_null(node_name)
	if n: return n
	var ysort = root.get_node_or_null("YSortLayer")
	if ysort:
		n = ysort.get_node_or_null(node_name)
		if n: return n
	for child in root.get_children():
		if child.name == node_name:
			return child
	return null

func _hide_npcs():
	# Only hide teacher. BFs are naturally in the scene.
	if teacher:
		teacher.visible = false
		teacher.process_mode = Node.PROCESS_MODE_DISABLED

func _show_npcs():
	for npc in [male_bf, female_bf, teacher]:
		if npc:
			npc.visible = true
			npc.process_mode = Node.PROCESS_MODE_INHERIT

# -----------------------------------------------------------------------
#  CUTSCENE TRIGGER — fires when player fast-travels near the Internet Cafe
# -----------------------------------------------------------------------

func _on_fast_travel_completed(target_position: Vector2):
	# Only trigger near the internet cafe area
	if target_position.distance_to(INTERNET_CAFE_POS) > 100:
		return
	if _cutscene_triggered or character_data.ch1_convenience_store_cutscene_done:
		return

	_cutscene_triggered = true

	# Re-find nodes (player might have been recreated)
	_find_nodes()

	# Immediately set up positions while bus overlay may still be fading
	_setup_cutscene_positions()

	# Brief wait for the bus overlay to fully fade
	await get_tree().create_timer(0.1).timeout

	await _play_cutscene()

# -----------------------------------------------------------------------
#  PRE-POSITION everything so it's ready when the screen fades in
# -----------------------------------------------------------------------

func _setup_cutscene_positions():
	# Freeze player immediately and disable physics to prevent idle_down override
	if player:
		player.can_move = false
		player.can_interact = false
		player.set_physics_process(false)
		player.global_position = PLAYER_START_POS
		player.current_dir = "right"
		player.play_idle_animation("right")
		var cam = player.get_node_or_null("Camera2D")
		if cam: cam.force_update_scroll()

	# Show BFs (if hidden from previous cutscene completion), hide teacher (appears later)
	_show_npcs()
	if teacher:
		teacher.visible = false
		teacher.global_position = TEACHER_START_POS

	# Ensure BFs are at the exact requested positions and facing left
	if male_bf:
		male_bf.global_position = Vector2(5900, 1370)
		var sprite = male_bf.get_node_or_null("AnimatedSprite2D")
		if sprite: sprite.play("male_student_idle_left")

	if female_bf:
		female_bf.global_position = Vector2(5930, 1375)
		var sprite = female_bf.get_node_or_null("AnimatedSprite2D")
		if sprite: sprite.play("female_student_idle_left")

# -----------------------------------------------------------------------
#  MAIN CUTSCENE SEQUENCE
# -----------------------------------------------------------------------

func _play_cutscene():
	var pname = "You"
	if character_data and character_data.player_name != "":
		pname = character_data.player_name

	# 1. Player walks right to the BFs
	if player:
		player.current_dir = "right"
		player.play_walk_animation("right")
		var tween = create_tween()
		tween.tween_property(player, "global_position:x", PLAYER_WALK_TARGET_X, 1.0)
		await tween.finished
		player.current_dir = "right"
		player.play_idle_animation("right")

	await get_tree().create_timer(0.3).timeout

	# 4. BFs ask if you want something from the store — chat bubble on male BF
	var bf_bubble = _start_bubble_on(male_bf, [
		{ "name": "Male Best Friend", "text": "Alright, here we are!" },
		{ "name": "Male Best Friend", "text": "We're gonna grab some snacks before going home." },
		{ "name": "Male Best Friend", "text": "Want us to grab you anything?" }
	])
	if bf_bubble:
		await bf_bubble.dialogue_finished

	await get_tree().create_timer(0.2).timeout

	# Female BF chimes in
	var fbf_bubble = _start_bubble_on(female_bf, [
		{ "name": "Female Best Friend", "text": "They have great drinks inside." },
		{ "name": "Female Best Friend", "text": "We'll be right back!" }
	])
	if fbf_bubble:
		await fbf_bubble.dialogue_finished

	await get_tree().create_timer(0.3).timeout

	# 5. Teacher appears and walks down
	if teacher:
		teacher.visible = true
		teacher.global_position = TEACHER_START_POS
		var teacher_sprite = teacher.get_node_or_null("AnimatedSprite2D")
		if teacher_sprite:
			teacher_sprite.play("shs_prof_walking_down")

		var tween = create_tween()
		tween.tween_property(teacher, "global_position", TEACHER_WALK_TARGET, 2.5)
		await tween.finished

		if teacher_sprite:
			teacher_sprite.play("shs_prof_idle_down")

	await get_tree().create_timer(0.3).timeout

	# 6. Fullscreen placeholder image — teacher encounter
	_show_placeholder_image("TEACHER ENCOUNTER\n\nThe Professor bumps into the group\noutside the convenience store!")

	# 7. Dialogue over the image — group is surprised, casual small talk
	if dialogue_box:
		dialogue_box.start([
			{ "name": pname, "text": "Wait... Professor?! Is that you?!" },
			{ "name": "Male Best Friend", "text": "Whoa! Sir! What are you doing here?!" },
			{ "name": "Female Best Friend", "text": "No way! We didn't expect to see you outside of school!" },
			{ "name": "Professor", "text": "Haha! Well, well... I didn't expect to see you three here either!" },
			{ "name": "Professor", "text": "What, you think teachers don't go to convenience stores?" },
			{ "name": pname, "text": "Haha, no sir! It's just funny bumping into you like this." },
			{ "name": "Male Best Friend", "text": "Yeah, it's like seeing a celebrity in the wild!" },
			{ "name": "Professor", "text": "A celebrity? Ha! I wish. I'm just here for some coffee and a snack." },
			{ "name": "Female Best Friend", "text": "That's exactly what we came here for too!" },
			{ "name": "Professor", "text": "Great minds think alike, I suppose! How have you all been?" },
			{ "name": pname, "text": "We've been good, sir. Just relaxing after class." },
			{ "name": "Professor", "text": "Good, good. You all deserve a break after that quiz earlier." },
		])
		await dialogue_box.dialogue_finished

	# 8. Hide the fullscreen image — return to top-down view
	_hide_placeholder_image()

	await get_tree().create_timer(0.3).timeout

	# 9. Reposition characters for the conversation
	#    Teacher: idle left | BFs + Player: face right
	if teacher:
		var teacher_sprite = teacher.get_node_or_null("AnimatedSprite2D")
		if teacher_sprite:
			teacher_sprite.play("shs_prof_idle_left")

	if male_bf:
		var sprite = male_bf.get_node_or_null("AnimatedSprite2D")
		if sprite: sprite.play("male_student_idle_right")

	if female_bf:
		var sprite = female_bf.get_node_or_null("AnimatedSprite2D")
		if sprite: sprite.play("female_student_idle_right")

	if player:
		player.current_dir = "right"
		player.play_idle_animation("right")

	await get_tree().create_timer(0.2).timeout

	# 10. Teacher brings up the topic about what course to choose — bubble chat
	var teacher_bubble = _start_bubble_on(teacher, [
		{ "name": "Professor", "text": "By the way... since you are all graduating soon..." },
		{ "name": "Professor", "text": "Have you guys thought about what course you're gonna take in college?" }
	])
	if teacher_bubble:
		await teacher_bubble.dialogue_finished

	await get_tree().create_timer(0.2).timeout

	# 11. Group discussion about IT/CS — bubble chat
	var cb1 = _start_bubble_on(player, [{ "name": pname, "text": "Actually, I've been thinking about it a lot lately..." }])
	if cb1: await cb1.dialogue_finished

	var cb2 = _start_bubble_on(male_bf, [{ "name": "Male Best Friend", "text": "Same here! There are so many options, it's hard to decide." }])
	if cb2: await cb2.dialogue_finished

	var cb3 = _start_bubble_on(female_bf, [{ "name": "Female Best Friend", "text": "I know, right? I keep going back and forth." }])
	if cb3: await cb3.dialogue_finished

	var cb4 = _start_bubble_on(teacher, [
		{ "name": "Professor", "text": "Well, since you three seem pretty interested in technology..." },
		{ "name": "Professor", "text": "Have you considered taking IT or Computer Science?" }
	])
	if cb4: await cb4.dialogue_finished

	var cb5 = _start_bubble_on(player, [{ "name": pname, "text": "Actually, yeah! I've been looking into both of those." }])
	if cb5: await cb5.dialogue_finished

	var cb6 = _start_bubble_on(teacher, [
		{ "name": "Professor", "text": "Both are excellent choices. Let me explain the difference." },
		{ "name": "Professor", "text": "IT focuses more on managing and maintaining computer systems, networks, and infrastructure." },
		{ "name": "Professor", "text": "While Computer Science dives deeper into programming, algorithms, and software development." }
	])
	if cb6: await cb6.dialogue_finished

	var cb7 = _start_bubble_on(male_bf, [{ "name": "Male Best Friend", "text": "I think I'm leaning towards CS. I like the idea of building things from scratch." }])
	if cb7: await cb7.dialogue_finished

	var cb8 = _start_bubble_on(female_bf, [{ "name": "Female Best Friend", "text": "Hmm, I think IT sounds interesting too. I like troubleshooting stuff!" }])
	if cb8: await cb8.dialogue_finished

	var cb9 = _start_bubble_on(player, [{ "name": pname, "text": "Both sound amazing honestly. I'll figure it out soon." }])
	if cb9: await cb9.dialogue_finished

	var cb10 = _start_bubble_on(teacher, [
		{ "name": "Professor", "text": "Take your time. The important thing is to follow what excites you." },
		{ "name": "Professor", "text": "Whatever you choose, make sure you're passionate about it. That's what matters most." }
	])
	if cb10: await cb10.dialogue_finished

	var cb11 = _start_bubble_on(male_bf, [{ "name": "Male Best Friend", "text": "Thanks, Professor! That actually helps a lot." }])
	if cb11: await cb11.dialogue_finished

	var cb12 = _start_bubble_on(female_bf, [{ "name": "Female Best Friend", "text": "Yeah, thanks for the advice, sir!" }])
	if cb12: await cb12.dialogue_finished

	var cb13 = _start_bubble_on(teacher, [
		{ "name": "Professor", "text": "Of course! I'm always happy to help my students, even outside of school." },
		{ "name": "Professor", "text": "Well, I should get going. You three take care!" }
	])
	if cb13: await cb13.dialogue_finished

	var cb14 = _start_bubble_on(player, [{ "name": pname, "text": "Bye, Professor! See you at school!" }])
	if cb14: await cb14.dialogue_finished

	# 12. Teacher walks off screen (upwards)
	if teacher:
		var teacher_sprite = teacher.get_node_or_null("AnimatedSprite2D")
		if teacher_sprite:
			teacher_sprite.play("shs_prof_walking_up")

		var walk_tween = create_tween()
		walk_tween.tween_property(teacher, "global_position", TEACHER_START_POS, 2.5)
		await walk_tween.finished
		teacher.visible = false

	# BFs turn to face the player (who is on the left)
	if male_bf:
		var sprite = male_bf.get_node_or_null("AnimatedSprite2D")
		if sprite: sprite.play("male_student_idle_left")
		
	if female_bf:
		var sprite = female_bf.get_node_or_null("AnimatedSprite2D")
		if sprite: sprite.play("female_student_idle_left")

	await get_tree().create_timer(0.3).timeout

	# 13. Say goodbye to BFs via chat bubbles
	var bye_bubble = _start_bubble_on(player, [
		{ "name": pname, "text": "Alright, I'm heading to the computer shop now." },
		{ "name": pname, "text": "I'll see you guys at school!" }
	])
	if bye_bubble:
		await bye_bubble.dialogue_finished

	await get_tree().create_timer(0.2).timeout

	var mbf_bye = _start_bubble_on(male_bf, [
		{ "name": "Male Best Friend", "text": "Alright, see you!" }
	])
	if mbf_bye:
		await mbf_bye.dialogue_finished

	var fbf_bye = _start_bubble_on(female_bf, [
		{ "name": "Female Best Friend", "text": "Take care! See you at school!" }
	])
	if fbf_bye:
		await fbf_bye.dialogue_finished

	await get_tree().create_timer(0.3).timeout

	# 14. Player walks down a bit, then walks right. Fade out starts while walking
	var walk_right: Tween = null
	if player:
		# Player walks down to get out of BFs' way
		player.current_dir = "down"
		player.play_walk_animation("down")
		var walk_down = create_tween()
		walk_down.tween_property(player, "global_position:y", player.global_position.y + 40, 0.5)
		await walk_down.finished

		# Player walks right towards internet cafe
		player.current_dir = "right"
		player.play_walk_animation("right")
		walk_right = create_tween()
		walk_right.tween_property(player, "global_position:x", player.global_position.x + 150, 2.0)

		# Give them a split second to start walking right before starting the fade
		await get_tree().create_timer(0.4).timeout

	# 15. Fade to black, teleport to internet cafe door, fade in
	var scene_transition = get_node_or_null("/root/SceneTransition")
	if scene_transition:
		var cr = scene_transition.color_rect
		# Fade to black
		var fade_out = create_tween()
		fade_out.tween_property(cr, "color:a", 1.0, 0.5)
		await fade_out.finished

		# Hide BFs while screen is black
		if male_bf:
			male_bf.visible = false
		if female_bf:
			female_bf.visible = false

		# Teleport player to internet cafe door
		if player:
			# Kill the active walking tween so it doesn't override our teleport position
			if walk_right and walk_right.is_valid():
				walk_right.kill()
			player.global_position = Vector2(6714, 1425)
			player.current_dir = "up"
			player.play_idle_animation("up")
			var cam = player.get_node_or_null("Camera2D")
			if cam: cam.force_update_scroll()

		await get_tree().create_timer(0.3).timeout

		# Fade in
		var fade_in = create_tween()
		fade_in.tween_property(cr, "color:a", 0.0, 0.5)
		await fade_in.finished

	# 15. Mark cutscene as done
	character_data.ch1_convenience_store_cutscene_done = true

	# Re-enable physics but keep can_move false so player stays put
	# Player can still interact (press F) with the door
	if player:
		player.set_physics_process(true)
		player.can_move = false
		player.can_interact = true

	print("Ch1ConvenienceStoreController: Cutscene completed! Player at internet cafe door.")

# ── Chat Bubble Helper ────────────────────────────────────────────────

func _start_bubble_on(npc: Node2D, lines: Array):
	if not npc:
		return null
	var bubble = npc.get_node_or_null("ChatBubble")
	if not bubble:
		bubble = CHAT_BUBBLE_SCENE.instantiate()
		bubble.name = "ChatBubble"
		npc.add_child(bubble)
	bubble.start(lines, null)
	return bubble

# ── Fullscreen Placeholder Image ──────────────────────────────────────

func _show_placeholder_image(text: String):
	if not _teaching_canvas:
		_teaching_canvas = CanvasLayer.new()
		_teaching_canvas.name = "ConvStoreImageLayer"
		_teaching_canvas.layer = 5
		get_parent().add_child(_teaching_canvas)

		# Dark background
		var bg = ColorRect.new()
		bg.name = "Background"
		bg.color = Color(0.08, 0.08, 0.12, 1.0)
		bg.anchors_preset = Control.PRESET_FULL_RECT
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_teaching_canvas.add_child(bg)

		# Visual novel style centered panel
		var center_panel = PanelContainer.new()
		center_panel.name = "CenterPanel"
		center_panel.anchors_preset = Control.PRESET_CENTER
		center_panel.set_anchors_preset(Control.PRESET_CENTER)
		center_panel.custom_minimum_size = Vector2(700, 400)
		center_panel.position = Vector2(-350, -200)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.22, 1.0)
		style.border_color = Color(0.5, 0.5, 0.7, 0.8)
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(30)
		center_panel.add_theme_stylebox_override("panel", style)
		_teaching_canvas.add_child(center_panel)

		# VBox for content
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 20)
		center_panel.add_child(vbox)

		# Scene icon / visual indicator
		var icon_label = Label.new()
		icon_label.text = "📖"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 48)
		vbox.add_child(icon_label)

		# Placeholder label
		_placeholder_label = Label.new()
		_placeholder_label.name = "PlaceholderText"
		_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_placeholder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_placeholder_label.add_theme_font_size_override("font_size", 22)
		_placeholder_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		vbox.add_child(_placeholder_label)

		# Hint at bottom
		var hint_label = Label.new()
		hint_label.text = "— Visual Novel Scene —"
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size", 14)
		hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		vbox.add_child(hint_label)

	_placeholder_label.text = text
	_teaching_canvas.visible = true

func _hide_placeholder_image():
	if _teaching_canvas:
		_teaching_canvas.visible = false

# ── Helpers ───────────────────────────────────────────────────────────

func _get_dialogue_box():
	# First check if one already exists in the scene tree
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	var root = get_parent()
	for child in root.get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	# If not found, instantiate one from the scene
	var instance = DIALOGUE_BOX_SCENE.instantiate()
	root.add_child(instance)
	return instance
