#  — Manages the Chapter 1 school classroom flow
# Add as a child Node of SchoolMap in school_map.tscn
#
# Flow:
#   Phase 1 (pre-teaching): Player walks freely. BFs at chair positions.
#   Phase 2 (teaching):     Player sits at chair19. Prof teaching cutscene + quiz.
#   Phase 3 (post-quiz):    Dialogue with best friends about comshop / 7-11.
#   Phase 4 (hallway):      BFs move to hallway. Interacting triggers next scene.
extends Node

const QUIZ_SCENE = preload("res://Scenes/Ch1/Games/Game Scenes/python_history_quiz_game.tscn")

@onready var character_data = get_node("/root/CharacterData")

# --- Chair / hallway positions ---
const PLAYER_CHAIR_POS = Vector2(-49, 669)        # SchoolChairFacingUp19
const MALE_BF_CHAIR_POS = Vector2(175, 669)        # SchoolChairFacingUp22
const FEMALE_BF_CHAIR_POS = Vector2(239, 669)      # SchoolChairFacingUp23
const MALE_BF_HALLWAY_POS = Vector2(418, 523)      # hallway after class
const FEMALE_BF_HALLWAY_POS = Vector2(467, 528)    # hallway after class

# Chair seat offset (same as the chairs use)
const CHAIR_SEAT_OFFSET = Vector2(0, -10)

# Node references — set in _ready()
var player: CharacterBody2D = null
var male_bf: CharacterBody2D = null
var female_bf: CharacterBody2D = null
var teacher: Area2D = null
var dialogue_box = null

var _is_fading: bool = false
var _teaching_image_rect: ColorRect = null  # DEPRECATED — kept for compatibility
var _hallway_dialogue_played: bool = false
var _did_remedial_class: bool = false

func _ready():
	# Wait a frame so all sibling nodes are ready
	await get_tree().process_frame
	_find_nodes()
	_setup_initial_state()

# -----------------------------------------------------------------------
#  SETUP
# -----------------------------------------------------------------------

func _find_nodes():
	var root = get_parent()  # SchoolMap
	player = _find_in_tree(root, "Player")
	male_bf = _find_in_tree(root, "MaleBestFriend")
	female_bf = _find_in_tree(root, "FemaleBestFriend")
	teacher = _find_in_tree(root, "SHSTeacherInteractable")
	dialogue_box = _get_dialogue_box()

func _find_in_tree(root: Node, node_name: String) -> Node:
	# Try direct child first
	var n = root.get_node_or_null(node_name)
	if n:
		return n
	# Try YSortLayer
	var ysort = root.get_node_or_null("YSortLayer")
	if ysort:
		n = ysort.get_node_or_null(node_name)
		if n:
			return n
	# Fallback: search all children
	for child in root.get_children():
		if child.name == node_name:
			return child
	return null

func _setup_initial_state():
	if not character_data:
		return

	# Lock exit doors until the player has spoken to their friends in the hallway
	var root = get_parent()
	var door1 = root.get_node_or_null("YSortLayer/ExitDoor1")
	var door2 = root.get_node_or_null("YSortLayer/ExitDoor2")
	if not character_data.ch1_post_quiz_dialogue_done:
		var locked_msg = "Now is not the time for that."
		if door1:
			door1.lock()
			door1.lock_message = locked_msg
		if door2:
			door2.lock()
			door2.lock_message = locked_msg

	if character_data.ch1_post_quiz_dialogue_done:
		# BFs have already left the hallway (hide and disable collision)
		for npc in [male_bf, female_bf]:
			if npc:
				npc.visible = false
				npc.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Update teacher dialogue
		if teacher:
			teacher.dialogue_line_1 = "Class is over. You can go now."
			teacher.dialogue_line_2 = ""
			teacher.dialogue_line_3 = ""
			teacher.dialogue_line_4 = ""
			teacher.dialogue_line_5 = ""
	elif character_data.ch1_quiz_done:
		# Phase 3 — post-quiz dialogue
		_enter_phase_3()
	elif character_data.ch1_teaching_done:
		# Teaching done but quiz not done — show quiz again
		_show_quiz()
	else:
		# Phase 1 — pre-teaching
		_enter_phase_1()

	_sync_school_quest()

# -----------------------------------------------------------------------
#  PHASE 1 — Pre-teaching (walk around freely, talk to prof to start)
# -----------------------------------------------------------------------

func _enter_phase_1():
	# Position best friends at their chair positions (seated)
	if male_bf:
		male_bf.position = MALE_BF_CHAIR_POS + CHAIR_SEAT_OFFSET
		var male_sprite = male_bf.get_node_or_null("AnimatedSprite2D")
		if male_sprite:
			male_sprite.play("male_student_idle_up")

	if female_bf:
		female_bf.position = FEMALE_BF_CHAIR_POS + CHAIR_SEAT_OFFSET
		var female_sprite = female_bf.get_node_or_null("AnimatedSprite2D")
		if female_sprite:
			female_sprite.play("female_student_idle_up")

	# Override the teacher's interact so we can intercept it
	if teacher:
		_override_teacher_interact()

func _override_teacher_interact():
	if not teacher:
		return

	# Disable the old teacher interactable so it doesn't conflict
	teacher.collision_layer = 0
	
	# Create a new interaction area just for this phase
	var area = Area2D.new()
	area.name = "TeacherLecturePromptArea"
	area.collision_layer = 1
	area.collision_mask = 0
	teacher.add_child(area)
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	area.add_child(shape)
	
	var script = GDScript.new()
	script.source_code = """extends Area2D
var controller = null
func interact():
	if controller: controller._show_lecture_prompt()
"""
	script.reload()
	area.set_script(script)
	area.set("controller", self)

func _show_lecture_prompt():
	if character_data.ch1_teaching_done:
		return
	
	if dialogue_box:
		var lines = [{
			"name": "Professor",
			"text": "Are you ready to start the lecture?",
			"choices": ["Yes", "No"]
		}]
		
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	if choice_index == 0:
		# Wait a tiny bit for the dialogue box to cleanly close and unfreeze the player,
		# then we immediately freeze them again for the cutscene.
		await get_tree().create_timer(0.1).timeout
		
		var area = teacher.get_node_or_null("TeacherLecturePromptArea")
		if area:
			area.queue_free()
		teacher.collision_layer = 1
		
		_enter_phase_2()

# -----------------------------------------------------------------------
#  PHASE 2 — Teaching cutscene
# -----------------------------------------------------------------------

func _enter_phase_2():
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.hide_quest()

	# 1. Freeze the player
	if player:
		player.can_move = false

	# 2. Fade out, sit player instantly, fade in
	await _fade_screen(true, 0.5)
	_sit_player_instantly()
	await _fade_screen(false, 0.5)

	# 3. Show the teaching cutscene sequence
	await _play_teaching_sequence()

	# 4. Mark teaching as done
	character_data.ch1_teaching_done = true

	# 5. Show the quiz
	_show_quiz()

func _sit_player_instantly():
	if not player:
		return
	player.position = PLAYER_CHAIR_POS + CHAIR_SEAT_OFFSET
	player.is_sitting = true
	player.play_sitting_animation("up")
	var shadow = player.get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false

func _play_teaching_sequence():
	# Multi-part teaching sequence with fullscreen slides + student banter
	# All lines use dialogue box + fullscreen images (no chat bubbles — they go off-screen)
	# Quiz-relevant terms are highlighted with [color=yellow][b]...[/b][/color]
	
	# Slide texture paths
	const SLIDES = "res://Textures/SHS_Prof_Teaching_Slides/"
	
	# Pick gender-appropriate student images
	var is_male = character_data.selected_gender == "male"
	var img_student_raising = SLIDES + ("StudentRaisingHandMale.png" if is_male else "StudentRaisingHandFemale.png")
	var img_student_talking = SLIDES + ("StudentTalkingMale.png" if is_male else "StudentTalkingFemale.png")
	var img_player_with_students = SLIDES + ("PlayerWithStudentsMale.png" if is_male else "PlayerWithStudentsFemale.png")
	
	# ─── Part 1: Introduction ──────────────────────────────────────────
	_show_teaching_image_fullscreen(SLIDES + "TeacherFacingStudentStanding.png")
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor", "text": "Good morning, class! Since you are all graduating soon, this will be our very last lesson." },
			{ "name": "Professor", "text": "And fittingly, today we'll be diving into the history of [color=#f0c674]Python[/color]." },
			{ "name": "Professor", "text": "Pay attention — there will be a [color=#f0c674]quiz[/color] at the end!" }
		])
		await dialogue_box.dialogue_finished
	
	# ─── Part 2: Creator & Origins (Quiz Q1, Q3, Q6) ─────────────────────
	_change_teaching_image(SLIDES + "TeacherFacingStudentPointingAtBoard.png")
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor", "text": "[color=#f0c674]Python[/color] was created by a Dutch programmer named [color=#f0c674]Guido van Rossum[/color]." },
			{ "name": "Professor", "text": "He began working on it back in [color=#f0c674]1989[/color] — that's over 30 years ago!" },
			{ "name": "Professor", "text": "Before Python, he worked on a language called [color=#f0c674]ABC[/color], which heavily influenced Python's clean structure." }
		])
		await dialogue_box.dialogue_finished
	
	# Student raises hand — "Is Python named after the snake?"
	_change_teaching_image(img_student_raising)
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Student", "text": "Sir! Is Python named after the snake? 🐍" }
		])
		await dialogue_box.dialogue_finished
	
	# Professor reacts (amused)
	_change_teaching_image(SLIDES + "TeacherFacingStudentArmsCrossed2.png")
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor", "text": "Ha! That's actually a very common misconception." },
			{ "name": "Professor", "text": "A lot of people think it's named after a snake, but nope!" }
		])
		await dialogue_box.dialogue_finished
	
	# ─── Part 3: The Name (Quiz Q2) ───────────────────────────────────
	_change_teaching_image(SLIDES + "TeacherFacingWWhiteboardLookingAtStudents1.png")
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor", "text": "The name actually comes from a British comedy show..." },
			{ "name": "Professor", "text": "[color=#f0c674]\"Monty Python's Flying Circus!\"[/color] Guido was a huge fan." },
			{ "name": "Professor", "text": "He wanted his programming language to be just as fun and approachable." }
		])
		await dialogue_box.dialogue_finished
	
	# Student reacts — surprised
	_change_teaching_image(img_student_talking)
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Student", "text": "Wait, so it's from a comedy show? That's actually cool!" }
		])
		await dialogue_box.dialogue_finished
	
	# Another student reacts — funny (use raising hand variant for variety)
	_change_teaching_image(img_student_raising)
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Student", "text": "I thought programmers were supposed to be serious... guess not! 😂" }
		])
		await dialogue_box.dialogue_finished
	
	# ─── Part 4: Design Goals, Zen, and Foundation (Quiz Q4, Q7, Q8, Q9) ───────────────────────────────
	_change_teaching_image(SLIDES + "TeacherFacingWWhiteboardLookingAtStudents2.png")
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor", "text": "Now, one of Python's core design goals is [color=#f0c674]readability and simplicity[/color]." },
			{ "name": "Professor", "text": "It even has a 19-principle guide for writing good code, called [color=#f0c674]The Zen of Python[/color]." },
			{ "name": "Professor", "text": "To protect and promote the language, the [color=#f0c674]Python Software Foundation[/color] was created!" }
		])
		await dialogue_box.dialogue_finished
	
	# Student raises hand — asks about readability
	_change_teaching_image(img_student_raising)
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Student", "text": "So that's why the code almost looks like plain English? That's neat!" }
		])
		await dialogue_box.dialogue_finished
	
	_change_teaching_image(SLIDES + "TeacherFacingStudentArmsCrossed1.png")
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor", "text": "Exactly! That's one of the reasons [color=#f0c674]Python[/color] is so popular with beginners." },
			{ "name": "Professor", "text": "Another major milestone was [color=#f0c674]Python 3.0[/color] released in [color=#f0c674]2008[/color], designed to fix old language flaws." }
		])
		await dialogue_box.dialogue_finished
	
	# ─── Part 5: Python Today (Quiz Q5, Q10) ───────────────────────────────
	_change_teaching_image(SLIDES + "TeacherFacingWWhiteboardLookingAtStudents3.png")
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor", "text": "Today, [color=#f0c674]Python[/color] is used everywhere. Even [color=#f0c674]NASA[/color] uses it for space-related tasks." },
			{ "name": "Professor", "text": "Companies like Google and Netflix also rely heavily on it." },
			{ "name": "Professor", "text": "It's also famous for its powerful web development framework, [color=#f0c674]Django[/color], which is what we will learn!" }
		])
		await dialogue_box.dialogue_finished
	
	# Student reacts — amazed
	_change_teaching_image(img_student_raising)
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Student", "text": "Wow, even NASA uses it?! That's awesome! 🚀" }
		])
		await dialogue_box.dialogue_finished
	
	_change_teaching_image(img_student_talking)
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Student", "text": "I can't wait to build a web app with Django!" }
		])
		await dialogue_box.dialogue_finished
	
	# ─── Part 6: Wrap-up & Quiz Announcement ──────────────────────────
	_change_teaching_image(SLIDES + "TeacherFacingStudentStanding.png")
	
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor", "text": "Alright class, that wraps up our lesson on [color=#f0c674]Python's history[/color]!" },
			{ "name": "Professor", "text": "The references for today's lesson are from [color=#f0c674]Python Crash Course (Matthes, 2023)[/color] and the official Python Documentation." },
			{ "name": "Professor", "text": "Now, let's see how well you were paying attention..." },
			{ "name": "Professor", "text": "Time for a quick [color=#f0c674]quiz[/color]! Good luck!" }
		])
		await dialogue_box.dialogue_finished
	
	# Hide the image before the quiz starts
	_hide_teaching_image()
	# Don't unfreeze the player yet — quiz comes next


# ── Fullscreen Teaching Image Helpers ─────────────────────────────────

var _teaching_canvas: CanvasLayer = null
var _teaching_texture_rect: TextureRect = null

func _show_teaching_image_fullscreen(texture_path: String):
	# Create the canvas layer if it doesn't exist yet
	if not _teaching_canvas:
		_teaching_canvas = CanvasLayer.new()
		_teaching_canvas.name = "TeachingImageLayer"
		_teaching_canvas.layer = 5
		get_parent().add_child(_teaching_canvas)
		
		_teaching_texture_rect = TextureRect.new()
		_teaching_texture_rect.name = "TeachingImage"
		_teaching_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_teaching_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_teaching_texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		_teaching_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_teaching_canvas.add_child(_teaching_texture_rect)
		
	# Load and set the texture
	var tex = load(texture_path)
	if tex:
		_teaching_texture_rect.texture = tex
	
	_teaching_canvas.visible = true

func _change_teaching_image(texture_path: String):
	if _teaching_texture_rect:
		var tex = load(texture_path)
		if tex:
			_teaching_texture_rect.texture = tex
		if _teaching_canvas:
			_teaching_canvas.visible = true
	else:
		_show_teaching_image_fullscreen(texture_path)

func _hide_teaching_image():
	if _teaching_canvas:
		_teaching_canvas.visible = false

func _cleanup_teaching_image():
	if _teaching_canvas:
		_teaching_canvas.queue_free()
		_teaching_canvas = null
		_teaching_texture_rect = null

## Spawn or reuse a chat bubble on any NPC node and start dialogue
func _start_bubble_on(npc: Node2D, bubble_scene: PackedScene, lines: Array):
	var bubble = npc.get_node_or_null("ChatBubble")
	if not bubble:
		bubble = bubble_scene.instantiate()
		bubble.name = "ChatBubble"
		npc.add_child(bubble)
	bubble.start(lines, null)
	return bubble

# -----------------------------------------------------------------------
#  QUIZ
# -----------------------------------------------------------------------

func _show_quiz():
	# ─── DEBUG SKIP QUIZ ────────────────────────────────────────────
	# @TODO: CHANGE THIS TO false WHEN DONE TESTING
	var DEBUG_SKIP_QUIZ = false
	if DEBUG_SKIP_QUIZ:
		_on_quiz_completed(3)
		return
	# ─── END OF DEBUG SKIP QUIZ ────────────────────────────────────────────

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.hide_quest()

	# Instantiate the quiz as a CanvasLayer overlay
	var quiz_canvas = CanvasLayer.new()
	quiz_canvas.name = "QuizOverlay"
	quiz_canvas.layer = 10
	get_parent().add_child(quiz_canvas)

	var quiz_instance = QUIZ_SCENE.instantiate()
	quiz_canvas.add_child(quiz_instance)

	# Connect to the quiz completed signal
	quiz_instance.quiz_completed.connect(_on_quiz_completed)

func _on_quiz_completed(score: int):
	print("Ch1Controller: Quiz completed with score: ", score)

	# Clean up quiz overlay
	var quiz_overlay = get_parent().get_node_or_null("QuizOverlay")
	if quiz_overlay:
		quiz_overlay.queue_free()

	if score >= 3:
		character_data.ch1_quiz_done = true
		_enter_phase_3()
	else:
		_enter_remedial_phase()

func _enter_remedial_phase():
	_did_remedial_class = true
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.hide_quest()
	# Freeze the player so they can't move during the long fade
	if player: player.can_move = false

	# Fade out
	await _fade_screen(true, 1.2)
	
	# Hide BFs
	if male_bf:
		male_bf.visible = false
		male_bf.process_mode = Node.PROCESS_MODE_DISABLED
	if female_bf:
		female_bf.visible = false
		female_bf.process_mode = Node.PROCESS_MODE_DISABLED
		
	# Ensure player remains seated
	_sit_player_instantly()
		
	# Fade back in
	await _fade_screen(false, 1.2)
	
	if dialogue_box:
		var lines = [
			{ "name": "Professor", "text": "It seems you didn't quite grasp the material." },
			{ "name": "Professor", "text": "Since the rest of the class has left, we will have a remedial session." }
		]
		dialogue_box.dialogue_finished.connect(_start_remedial_sequence, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _start_remedial_sequence():
	await _play_teaching_sequence()
	_show_quiz()

# -----------------------------------------------------------------------
#  PHASE 3 — Post-quiz: stand up, BFs move to hallway, player walks free
# -----------------------------------------------------------------------

func _enter_phase_3():
	# Freeze the player so they can't move during the long fade
	if player: player.can_move = false

	# Fade out first to hide transitions — make it longer and smoother
	await _fade_screen(true, 1.2)

	# Stand the player up
	if player:
		player.is_sitting = false
		player.can_move = true
		player.play_idle_animation("down")
		var shadow = player.get_node_or_null("Shadow")
		if shadow:
			shadow.visible = true

	# Move BFs to hallway silently (no dialogue yet)
	_place_bfs_in_hallway()

	# Fade back in (longer/smoother)
	await _fade_screen(false, 1.2)

	# Make the teacher say class is over
	if teacher:
		teacher.dialogue_line_1 = "Class is over. You can go now."
		teacher.dialogue_line_2 = ""
		teacher.dialogue_line_3 = ""
		teacher.dialogue_line_4 = ""
		teacher.dialogue_line_5 = ""

	# Set up interaction on BFs so player can talk to them in the hallway
	_setup_hallway_bf_interactions()

	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("reset_suppression"):
		qm.reset_suppression()
	_sync_school_quest()

func _place_bfs_in_hallway():
	if male_bf:
		male_bf.position = MALE_BF_HALLWAY_POS
		male_bf.visible = true
		male_bf.process_mode = Node.PROCESS_MODE_INHERIT
		var male_sprite = male_bf.get_node_or_null("AnimatedSprite2D")
		if male_sprite:
			male_sprite.play("male_student_idle_down")

	if female_bf:
		female_bf.position = FEMALE_BF_HALLWAY_POS
		female_bf.visible = true
		female_bf.process_mode = Node.PROCESS_MODE_INHERIT
		var female_sprite = female_bf.get_node_or_null("AnimatedSprite2D")
		if female_sprite:
			female_sprite.play("female_student_idle_down")

# -----------------------------------------------------------------------
#  HALLWAY INTERACTION — talk to BFs, then they walk away
# -----------------------------------------------------------------------


func _setup_hallway_bf_interactions():
	# If BFs already left (post-dialogue done), hide them and skip
	if character_data.ch1_post_quiz_dialogue_done:
		if male_bf:
			male_bf.visible = false
		if female_bf:
			female_bf.visible = false
		return

	_add_hallway_interactable(male_bf, "HallwayAreaMale")
	_add_hallway_interactable(female_bf, "HallwayAreaFemale")

func _add_hallway_interactable(npc: Node, area_name: String):
	if not npc:
		return

	# Don't duplicate
	if npc.get_node_or_null(area_name):
		return

	var area = Area2D.new()
	area.name = area_name
	area.collision_layer = 0
	area.collision_mask = 1  # detect player body
	npc.add_child(area)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	shape.position = Vector2(0, 9)
	area.add_child(shape)

	# Use the existing Label node on the NPC
	var label = npc.get_node_or_null("Label")
	if label:
		label.visible = false
		area.body_entered.connect(func(body):
			if body.is_in_group("player"):
				label.visible = true
		)
		area.body_exited.connect(func(body):
			if body.is_in_group("player"):
				label.visible = false
		)

	# Store a reference to the controller so interact() can call back
	area.set_meta("controller", self)

func _process(_delta):
	# Listen for interact key while near a hallway BF
	if _hallway_dialogue_played or not character_data.ch1_quiz_done or character_data.ch1_post_quiz_dialogue_done:
		return

	if Input.is_action_just_pressed("interact"):
		if _is_player_near_hallway_bf():
			_start_hallway_dialogue()

func _is_player_near_hallway_bf() -> bool:
	if not player:
		return false
	if male_bf and male_bf.visible:
		if player.global_position.distance_to(male_bf.global_position) < 35:
			return true
	if female_bf and female_bf.visible:
		if player.global_position.distance_to(female_bf.global_position) < 35:
			return true
	return false

func _start_hallway_dialogue():
	_hallway_dialogue_played = true

	# Freeze the player
	if player:
		player.can_move = false

	# Get the player name for dialogue
	var pname = "You"
	if character_data and character_data.player_name != "":
		pname = character_data.player_name

	var hallway_lines = []
	
	if _did_remedial_class:
		hallway_lines.append({ "name": "Male Best Friend", "text": "Hey, we waited for you! How was the remedial?" })
		hallway_lines.append({ "name": pname, "text": "It was rough, but I got through it." })
	else:
		hallway_lines.append({ "name": pname, "text": "Hey! Class is finally over." })
		
	hallway_lines.append_array([
		{ "name": pname, "text": "I'm planning on going to the computer shop after this." },
		{ "name": "Male Best Friend", "text": "Nice! We'll probably just hang out in front of 7-Eleven." },
		{ "name": "Female Best Friend", "text": "Yeah, we'll be there if you need us!" },
		{ "name": pname, "text": "Alright, see you guys later then!" }
	])

	if dialogue_box:
		dialogue_box.dialogue_finished.connect(_on_hallway_dialogue_finished, CONNECT_ONE_SHOT)
		dialogue_box.start(hallway_lines)
	else:
		_on_hallway_dialogue_finished()

func _on_hallway_dialogue_finished():
	# The DialogueBox automatically unfreezes the player on close.
	# Re-freeze them so they must wait for the BFs to walk away!
	if player: player.can_move = false

	# Hide the interaction labels
	for npc in [male_bf, female_bf]:
		if npc:
			var lbl = npc.get_node_or_null("Label")
			if lbl:
				lbl.visible = false

	# Play walk-away animation: BFs walk upward and disappear
	await _bfs_walk_away()

	# Mark as done
	character_data.ch1_post_quiz_dialogue_done = true
	
	# Unlock the exit doors now that we've talked to them
	var root = get_parent()
	var door1 = root.get_node_or_null("YSortLayer/ExitDoor1")
	var door2 = root.get_node_or_null("YSortLayer/ExitDoor2")
	if door1: door1.unlock()
	if door2: door2.unlock()

	# Unfreeze the player
	if player:
		player.can_move = true

	var qm2 = get_node_or_null("/root/QuestManager")
	if qm2 and qm2.has_method("reset_suppression"):
		qm2.reset_suppression()
	_sync_school_quest()

func _bfs_walk_away():
	# Both BFs turn to face up and walk upward out of view
	var walk_duration = 2.0
	var walk_distance = 200.0  # pixels upward

	# Play walking-up animations
	if male_bf:
		var male_sprite = male_bf.get_node_or_null("AnimatedSprite2D")
		if male_sprite:
			male_sprite.play("male_student_walking_up")
	if female_bf:
		var female_sprite = female_bf.get_node_or_null("AnimatedSprite2D")
		if female_sprite:
			female_sprite.play("female_student_walking_up")

	# Tween both BFs upward simultaneously
	var tween = create_tween().set_parallel(true)
	if male_bf:
		tween.tween_property(male_bf, "position:y", male_bf.position.y - walk_distance, walk_duration)
	if female_bf:
		tween.tween_property(female_bf, "position:y", female_bf.position.y - walk_distance, walk_duration)
	await tween.finished

	# Hide them and disable collision — they've "left" for 7-11
	for npc in [male_bf, female_bf]:
		if npc:
			npc.visible = false
			npc.process_mode = Node.PROCESS_MODE_DISABLED

# -----------------------------------------------------------------------
#  HELPERS
# -----------------------------------------------------------------------

func _fade_screen(fade_out: bool, duration: float = 0.5):
	var transition = get_node_or_null("/root/SceneTransition")
	if not transition: return
	var rect = transition.get_node_or_null("ColorRect")
	if not rect: return

	var target_alpha = 1.0 if fade_out else 0.0
	var tween = create_tween()
	tween.tween_property(rect, "color:a", target_alpha, duration).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _get_dialogue_box():
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	var root = get_parent()
	for child in root.get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	return null


func _sync_school_quest():
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("refresh_ch1_school_quest"):
		qm.refresh_ch1_school_quest()
