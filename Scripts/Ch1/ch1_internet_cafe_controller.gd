# ch1_internet_cafe_controller.gd — SpaghettiGuyNPC cutscene controller
# Attach to SpaghettiGuyNPC (CharacterBody2D) in internet_cafe_map_cutscene.tscn
extends CharacterBody2D

const CHAT_BUBBLE_SCENE = preload("res://Scenes/UI/chat_bubble.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")
const CODING_UI_SCENE = preload("res://Scenes/Games/coding_challenge_ui.tscn")

func _get_gendered_texture(full_path: String) -> Texture2D:
	var prefix = "Female_" if character_data and character_data.selected_gender == "female" else "Male_"
	var last_slash = full_path.rfind("/")
	var folder = full_path.substr(0, last_slash + 1)
	var file_name = full_path.substr(last_slash + 1)
	var tex = load(folder + prefix + file_name)
	if not tex:
		tex = load(full_path) # Fallback
	return tex

@onready var character_data = get_node("/root/CharacterData")
@onready var interaction_label: Label = $Label

var player: Node2D = null
var spaghetti_guy: Node2D = null
var dialogue_box = null

var _cutscene_running: bool = false
var _teaching_canvas: CanvasLayer = null
var _dialogue_log: Array = []  # stores all dialogue lines shown during cutscene
var _log_overlay: CanvasLayer = null  # dialogue log overlay UI

# ── Interaction System (matches dialogue_interactable.gd) ─────────────

var player_is_inside: bool = false
var _label_tween: Tween = null

func _ready():
	spaghetti_guy = self

	if interaction_label:
		interaction_label.text = "(F) to Talk"
		interaction_label.visible = false
		interaction_label.modulate.a = 0.0

	_create_interaction_area()

func _create_interaction_area():
	var area = Area2D.new()
	area.name = "InteractableArea"
	area.collision_layer = 1
	area.collision_mask = 0

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	area.add_child(shape)

	var s = GDScript.new()
	s.source_code = "extends Area2D\n\nfunc interact():\n\tget_parent().interact()\n"
	s.reload()
	area.set_script(s)
	add_child(area)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("refresh_ch1_internet_cafe_quest"):
		qm.refresh_ch1_internet_cafe_quest()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = true
		player = body
		_show_label()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		_hide_label()

func interact():
	if _cutscene_running:
		return

	if character_data.ch1_spaghetti_guy_cutscene_done:
		dialogue_box = _get_dialogue_box()
		if dialogue_box:
			dialogue_box.start([{"name": "Spaghetti Guy", "text": "Hey! Keep practicing Python — you're doing great! 😄"}])
		return

	_cutscene_running = true
	_start_cutscene()

# ── CUTSCENE ──────────────────────────────────────────────────────────

func _start_cutscene():
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.hide_quest()

	dialogue_box = _get_dialogue_box()

	var pname = "You"
	if character_data and character_data.player_name != "":
		pname = character_data.player_name

	# Freeze player
	if player:
		player.can_move = false
		player.can_interact = false
		player.block_ui_input = true  # Block inventory/laptop during cutscene
		player.set_physics_process(false)
		if "current_dir" in player and player.has_method("play_idle_animation"):
			player.play_idle_animation(player.current_dir)
		elif player.has_node("AnimatedSprite2D"):
			var sprite = player.get_node("AnimatedSprite2D")
			if "current_dir" in player:
				sprite.play("player_idle_" + player.current_dir)

	# ─── PHASE 1: Initial Encounter ────────────────────────────────

	var b1 = _start_bubble_on(player, [
		{ "name": pname, "text": "Hey, have you seen the owner? I wanna use one of the PCs." }
	])
	if b1: await b1.dialogue_finished
	await get_tree().create_timer(0.2).timeout

	var b2 = _start_bubble_on(spaghetti_guy, [
		{ "name": "Spaghetti Guy", "text": "Oh, the owner? He just stepped out for a bit." },
		{ "name": "Spaghetti Guy", "text": "Said he'd be back soon — just grabbed something real quick." }
	])
	if b2: await b2.dialogue_finished
	await get_tree().create_timer(0.2).timeout

	var b3 = _start_bubble_on(player, [
		{ "name": pname, "text": "Ah alright, guess I'll just wait then." }
	])
	if b3: await b3.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	# ─── PHASE 2: Visual Novel Scenes ──────────────────────────────

	_show_fullscreen_image(_get_gendered_texture("res://Textures/Spag_guy_at_internet_cafe_scenes/Notices_Coding.png"))

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": pname, "text": "Wait... is that code on your screen?" },
			{ "name": pname, "text": "What are you working on?" },
			{ "name": "Spaghetti Guy", "text": "Oh this? Yeah! I'm building something pretty cool." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	_show_fullscreen_image(_get_gendered_texture("res://Textures/Spag_guy_at_internet_cafe_scenes/Showing_Coding.png"))

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Spaghetti Guy", "text": "I'm actually a college student. [color=#f0c674]IT major[/color]!" },
			{ "name": "Spaghetti Guy", "text": "Right now I'm coding the [color=#f0c674]backend[/color] for my personal website." },
			{ "name": "Spaghetti Guy", "text": "It's all in [color=#f0c674]Python[/color] — using a framework called [color=#f0c674]Django[/color]." },
			{ "name": pname, "text": "Whoa, that's awesome! That looks so complicated though..." },
			{ "name": "Spaghetti Guy", "text": "Haha, it looks scary at first, but it's actually pretty fun once you get the hang of it!" },
			{ "name": pname, "text": "I've always wanted to learn how to [color=#f0c674]code[/color]... I just never knew where to start." },
			{ "name": "Spaghetti Guy", "text": "Well, you're in luck! [color=#f0c674]Python[/color] is actually the best language to start with." }
		])
		await dialogue_box.dialogue_finished

	# ─── PHASE 3: Teaching Offer ───────────────────────────────────

	_hide_fullscreen_image()
	await get_tree().create_timer(0.3).timeout

	var b4 = _start_bubble_on(spaghetti_guy, [
		{ "name": "Spaghetti Guy", "text": "Hey, tell you what..." },
		{ "name": "Spaghetti Guy", "text": "Since we're both waiting for the owner anyway..." },
		{ "name": "Spaghetti Guy", "text": "Want me to teach you some [color=#f0c674]Python basics[/color]? It won't take long!" }
	])
	if b4: await b4.dialogue_finished
	await get_tree().create_timer(0.2).timeout

	var b5 = _start_bubble_on(player, [
		{ "name": pname, "text": "Really? You'd do that?" },
		{ "name": pname, "text": "Sure! I actually have my laptop with me right here." },
		{ "name": pname, "text": "We can try it out while we wait for the owner!" }
	])
	if b5: await b5.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	# ─── DEBUG SKIP IDE ────────────────────────────────────────────
	# @TODO: CHANGE THIS TO false WHEN DONE TESTING
	var DEBUG_SKIP_IDE = false
	if DEBUG_SKIP_IDE:
		await _play_completion_sequence(pname)
		return
	# ─── END OF DEBUG SKIP IDE ────────────────────────────────────────────
	
	# ─── PHASE 4: Guided Coding Challenges ─────────────────────────
	# The IDE opens and STAYS OPEN. Spaghetti Guy guides via dialogue
	# box ON TOP of the IDE. Player types code. Rinse and repeat.

	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 50
	canvas_layer.name = "ChallengeCanvasLayer"
	get_tree().current_scene.add_child(canvas_layer)

	var ui = CODING_UI_SCENE.instantiate()
	ui.hide_close_button = true
	canvas_layer.add_child(ui)

	# Wait one frame for the UI's _ready() to finish connecting signals
	await get_tree().process_frame

	# CRITICAL: Disconnect the Continue button's default handler
	# which calls queue_free() — we need the UI to persist across challenges
	if ui.continue_button.pressed.is_connected(ui._on_continue_pressed):
		ui.continue_button.pressed.disconnect(ui._on_continue_pressed)
	ui.close_button.visible = false
	ui.continue_button.visible = true # Explicitly keep this on for the popup constraints

	# Add the 📜 Log button to the IDE
	_create_log_button(canvas_layer)

	# ── IDE SPOTLIGHT TUTORIAL (first time only) ───────────────────────
	if character_data and not character_data.has_seen_ide_tutorial:
		var _tut_overlay = await _create_ide_tutorial_overlay()
		if _tut_overlay:
			# Find the log button we just created
			var log_btn = canvas_layer.get_node_or_null("LogButton")
			
			_tut_overlay.start_tutorial([
				{
					"text": "Welcome to the [color=#f0c674]Code Editor[/color]!\nThis is where you type your code.",
					"highlight_node": ui.code_edit,
					"tooltip_side": "left"
				},
				{
					"text": "This is the [color=#f0c674]Terminal[/color].\nErrors and success messages appear here.",
					"highlight_node": ui.terminal_strip,
					"tooltip_side": "top"
				},
				{
					"text": "Click [color=#f0c674]Alt Tab[/color] to switch between the IDE and the Browser view.",
					"highlight_node": ui.alt_tab_button,
					"tooltip_side": "right"
				},
				{
					"text": "The [color=#f0c674]📜 Log[/color] button lets you review past dialogue if you forget instructions.",
					"highlight_node": log_btn,
					"tooltip_side": "bottom"
				},
				{
					"text": "When you're done writing code, click [color=#f0c674]▶ Run[/color] to execute it!",
					"highlight_node": ui.run_button,
					"tooltip_side": "top"
				},
				{
					"text": "The [color=#f0c674]🎒 Use Items[/color] button lets you use inventory items during a challenge.\nItems can give you hints or boosts!",
					"highlight_node": ui.item_button,
					"tooltip_side": "bottom"
				},
			])
			await _tut_overlay.tutorial_finished
			_tut_overlay.queue_free()
			character_data.has_seen_ide_tutorial = true

	# Disable Use Items button during internet cafe cutscene
	if ui.item_button:
		ui.item_button.disabled = true

	# Raise the dialogue box layer ABOVE the IDE so it renders on top
	dialogue_box = _get_dialogue_box()
	var _original_dialogue_layer = 10
	if dialogue_box and dialogue_box is CanvasLayer:
		_original_dialogue_layer = dialogue_box.layer
		dialogue_box.layer = 60  # Above the IDE at layer 50

	# ── CHALLENGE 1: Print Statement ──────────────────────────────

	var ch1_data = _make_challenge(
		"spag_print", "Write a Print Statement", "python", "hello.py",
		["# Your first Python program!", "# Write your code below:"],
		["Write a print statement that says: Hello, World!"],
		"Type your code here...",
		["print('Hello, World!')", "print(\"Hello, World!\")"],
		"Hello, World!",
		"SyntaxError: invalid syntax — check your spelling and quotes!",
		[
			"The format is 'print(\"Text\")'.",
			"Use 'Hello, World!' as the text.",
			"Don't forget the quotes and parentheses."
		]
	)

	ui.load_challenge(ch1_data)
	ui.lock_typing(true) # lock while talking

	# Guidance dialogue ON TOP of the IDE (layer is already raised)
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Spaghetti Guy", "text": "Alright! The very first thing you learn in any language is how to [color=#f0c674]print[/color] something to the screen." },
			{ "name": "Spaghetti Guy", "text": "In Python, you use the [color=#f0c674]print()[/color] function." },
			{ "name": "Spaghetti Guy", "text": "The format is [color=#f0c674]print('Your text here')[/color]." },
			{ "name": "Spaghetti Guy", "text": "Use it to output [color=#f0c674]'Hello, World!'[/color]." },
			{ "name": "Spaghetti Guy", "text": "Don't forget the [color=#f0c674]parentheses[/color] and the [color=#f0c674]quotes[/color]! Then hit ▶ Run!" }
		])
		await dialogue_box.dialogue_finished

	ui.lock_typing(false) # unlock for player to type

	# Wait for the player to complete (poll is_completed)
	while not ui.is_completed:
		await get_tree().create_timer(0.1).timeout

	# Wait for the player to press "Next" on the results overlay
	await ui.continue_button.pressed
	ui.results_overlay.visible = false
	ui.lock_typing(true)

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Spaghetti Guy", "text": "Nice! You got it! See, that wasn't so hard!" },
			{ "name": "Spaghetti Guy", "text": "You just wrote your very first line of [color=#f0c674]Python code[/color]!" },
			{ "name": "Spaghetti Guy", "text": "Now let's try something a bit different..." }
		])
		await dialogue_box.dialogue_finished

	# ── CHALLENGE 2: Create a Variable ────────────────────────────

	var ch2_data = _make_challenge(
		"spag_variable", "Create a Variable", "python", "variables.py",
		["# Variables store data for later use", "# Create a variable below:"],
		["Create a variable called 'name' and set it to 'DjangoQuest'"],
		"Type your code here...",
		["name = 'DjangoQuest'", "name = \"DjangoQuest\"", "name='DjangoQuest'", "name=\"DjangoQuest\""],
		"Variable 'name' created with value: DjangoQuest",
		"NameError: name is not defined — make sure you use the = sign!",
		[
			"The format is 'variable = value'.",
			"Use 'name' as the variable and 'DjangoQuest' as the value.",
			"Don't forget the quotes around DjangoQuest!"
		]
	)

	ui.load_challenge(ch2_data)

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Spaghetti Guy", "text": "Now let's learn about [color=#f0c674]variables[/color]." },
			{ "name": "Spaghetti Guy", "text": "[color=#f0c674]Variables[/color] are like containers that hold data." },
			{ "name": "Spaghetti Guy", "text": "In Python, you just write the [color=#f0c674]name[/color], an [color=#f0c674]equals sign[/color], and the [color=#f0c674]value[/color]." },
			{ "name": "Spaghetti Guy", "text": "The format is [color=#f0c674]variable = 'value'[/color]." },
			{ "name": "Spaghetti Guy", "text": "Create one named [color=#f0c674]name[/color] and assign it the text [color=#f0c674]'DjangoQuest'[/color]. No special keyword needed! Then hit ▶ Run." }
		])
		await dialogue_box.dialogue_finished

	ui.lock_typing(false)

	while not ui.is_completed:
		await get_tree().create_timer(0.1).timeout

	await ui.continue_button.pressed
	ui.results_overlay.visible = false
	ui.lock_typing(true)

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Spaghetti Guy", "text": "You're getting the hang of this!" },
			{ "name": "Spaghetti Guy", "text": "[color=#f0c674]Variables[/color] are super important — you'll use them everywhere in programming." },
			{ "name": "Spaghetti Guy", "text": "One more challenge. Let's combine both things we learned!" }
		])
		await dialogue_box.dialogue_finished

	# ── CHALLENGE 3: Print a Variable ─────────────────────────────

	var ch3_data = _make_challenge(
		"spag_print_var", "Print a Variable", "python", "print_var.py",
		["# Let's combine what we learned!", "name = 'DjangoQuest'", "", "# Print the value of 'name' below:"],
		["Use print() to display the value of the variable 'name'"],
		"Type your code here...",
		["print(name)"],
		"DjangoQuest",
		"SyntaxError: unexpected character — don't put quotes around variable names!",
		[
			"The format is 'print(variable)'.",
			"Place 'name' inside the print statement.",
			"Do not use quotes around the variable name."
		]
	)

	ui.load_challenge(ch3_data)

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Spaghetti Guy", "text": "Now let's combine both things we learned!" },
			{ "name": "Spaghetti Guy", "text": "You already have a [color=#f0c674]variable[/color] called [color=#f0c674]'name'[/color] set to 'DjangoQuest'." },
			{ "name": "Spaghetti Guy", "text": "Use [color=#f0c674]print()[/color] but put the variable name INSIDE — [color=#f0c674]no quotes[/color] this time!" },
			{ "name": "Spaghetti Guy", "text": "Use the format [color=#f0c674]print(variable)[/color]." },
			{ "name": "Spaghetti Guy", "text": "Call the [color=#f0c674]print()[/color] function and pass [color=#f0c674]name[/color] as the argument." },
			{ "name": "Spaghetti Guy", "text": "Notice: no quotes around 'name' — because it's a [color=#f0c674]variable[/color], not literal text!" }
		])
		await dialogue_box.dialogue_finished

	ui.lock_typing(false)

	while not ui.is_completed:
		await get_tree().create_timer(0.1).timeout

	await ui.continue_button.pressed
	ui.results_overlay.visible = false

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Spaghetti Guy", "text": "You nailed it! You're a natural!" },
			{ "name": "Spaghetti Guy", "text": "You just learned [color=#f0c674]print statements[/color], [color=#f0c674]variables[/color], AND how to use them together!" }
		])
		await dialogue_box.dialogue_finished

	# Restore dialogue box layer to original
	if dialogue_box and dialogue_box is CanvasLayer:
		dialogue_box.layer = _original_dialogue_layer

	# Close the IDE
	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()

	await get_tree().create_timer(0.3).timeout

	await _play_completion_sequence(pname)


func _play_completion_sequence(pname: String):
	# ─── PHASE 5: Completion ───────────────────────────────────────

	_show_fullscreen_image(_get_gendered_texture("res://Textures/Spag_guy_at_internet_cafe_scenes/Spag_Praising_Player.png"))

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Spaghetti Guy", "text": "You did great! Seriously, you're a natural at this!" },
			{ "name": "Spaghetti Guy", "text": "Keep practicing and you'll be building your own projects in no time!" },
			{ "name": pname, "text": "Thanks so much! That was actually really fun!" }
		])
		await dialogue_box.dialogue_finished

	await get_tree().create_timer(0.3).timeout

	_show_fullscreen_image(_get_gendered_texture("res://Textures/Spag_guy_at_internet_cafe_scenes/Internet_Cafe_Owner_Comes_Back.png"))

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Internet Cafe Owner", "text": "Hey guys! Sorry for the wait, I'm back!" },
			{ "name": "Spaghetti Guy", "text": "Oh, welcome back! Perfect timing, we were just wrapping up." },
			{ "name": pname, "text": "Well, I was originally here to play some games since my laptop can't handle them..." },
			{ "name": pname, "text": "But at the very least, I came here and learned something new!" },
			{ "name": "Spaghetti Guy", "text": "Haha, that's the spirit! Gaming is fun, but [color=#f0c674]coding[/color] is a superpower!" },
			{ "name": "Internet Cafe Owner", "text": "Sounds like you had a productive time! The PCs are all yours now." }
		])
		await dialogue_box.dialogue_finished

	_hide_fullscreen_image()

	await _play_epilogue_sequence(pname)


func _play_epilogue_sequence(pname: String):
	# ─── PHASE 6: Epilogue — Graduation & College ───────────────────

	# Top-down: player reflects on the experience
	await get_tree().create_timer(0.4).timeout

	var ref1 = _start_bubble_on(player, [
		{ "name": pname, "text": "I may not have played the games I wanted to play today..." },
		{ "name": pname, "text": "But I learned something new and honestly... it was worth it." },
		{ "name": pname, "text": "Coming here was definitely not a waste of time." }
	])
	if ref1: await ref1.dialogue_finished

	await get_tree().create_timer(0.5).timeout

	# Cinematic centered text: "Then came graduation day..."
	_show_centered_text("Then came graduation day...")
	await get_tree().create_timer(3.0).timeout
	await _fade_out_centered_text()

	await get_tree().create_timer(0.3).timeout

	# Graduation image + narration
	_show_fullscreen_image(_get_gendered_texture("res://Textures/SHS_Graduation_Picture.png"))

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": pname, "text": "We actually did it... we graduated Senior High School." },
			{ "name": pname, "text": "All those late nights studying, the quizzes, the friendships we built along the way..." },
			{ "name": pname, "text": "It all led to this moment." },
			{ "name": pname, "text": "But our journey doesn't end here." }
		])
		await dialogue_box.dialogue_finished

	# Cinematic centered text: "And now... college."
	_show_centered_text("And now... college.")
	await get_tree().create_timer(3.0).timeout
	await _fade_out_centered_text()

	await get_tree().create_timer(0.3).timeout

	# College image
	_show_fullscreen_image(load("res://Textures/COLLEGE.png"))

	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": pname, "text": "Here we are now... college." },
			{ "name": pname, "text": "A brand new chapter, a bigger world, and so much more to learn." },
			{ "name": pname, "text": "The journey continues..." }
		])
		await dialogue_box.dialogue_finished

	# Mark done
	character_data.ch1_spaghetti_guy_cutscene_done = true
	_cutscene_running = false

	# Re-enable Use Items button
	var _challenge_ui = get_tree().get_first_node_in_group("coding_challenge_ui")
	if _challenge_ui == null:
		for node in get_tree().current_scene.get_children():
			if node.has_method("load_challenge"):
				_challenge_ui = node
				break
	if _challenge_ui and "item_button" in _challenge_ui and _challenge_ui.item_button:
		_challenge_ui.item_button.disabled = false

	# Restore player controls
	if player:
		player.block_ui_input = false
		player.can_move = true
		player.can_interact = true
		player.set_physics_process(true)

	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr:
		quest_mgr.clear_quest()

	# Transition to college_map.tscn with smooth crossfade
	await get_tree().create_timer(0.5).timeout
	var scene_trans = get_node_or_null("/root/SceneTransition")
	if scene_trans:
		scene_trans.transition_to_scene("res://Scenes/Ch2/College Indoor/college_map.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/Ch2/College Indoor/college_map.tscn")

	print("Ch1InternetCafeController: Epilogue completed — transitioning to college!")

# ── Custom Challenge Builder (all free_type) ──────────────────────────

func _make_challenge(id: String, title: String, topic: String, file_name: String,
	code_lines: Array, mission_steps: Array, placeholder: String,
	expected_answers: Array, correct_output: String, error_output: String, progressive_hints: Array = []) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"topic": topic,
		"type": "free_type",
		"file_name": file_name,
		"code_lines": code_lines,
		"mission_steps": mission_steps,
		"placeholder": placeholder,
		"expected_answers": expected_answers,
		"correct_output": correct_output,
		"error_output": error_output,
		"progressive_hints": progressive_hints,
		"show_output": true,
		"hint": "",
		"timed": false
	}

# ── Chat Bubble Helper ────────────────────────────────────────────────

func _start_bubble_on(target_node: Node2D, lines: Array) -> Node:
	if not target_node or not is_instance_valid(target_node):
		return null
	var bubble = CHAT_BUBBLE_SCENE.instantiate()
	target_node.add_child(bubble)
	if bubble.has_method("start"):
		bubble.start(lines)
	elif bubble.has_method("show_lines"):
		bubble.show_lines(lines)
	return bubble

# ── Fullscreen Image (fills entire viewport) ──────────────────────────

func _show_fullscreen_image(texture: Texture2D):
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.texture = texture
		img_rect.visible = true
	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if placeholder:
		placeholder.visible = false
	_teaching_canvas.visible = true

func _show_placeholder_image(text: String):
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.visible = false
	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if not placeholder:
		placeholder = _create_placeholder_panel()
		_teaching_canvas.add_child(placeholder)
	var lbl = placeholder.get_node_or_null("VBox/Text")
	if lbl:
		lbl.text = text
	placeholder.visible = true
	_teaching_canvas.visible = true

func _hide_fullscreen_image():
	if _teaching_canvas:
		# Remove any centered text label before hiding
		var ct = _teaching_canvas.get_node_or_null("CenteredTextLabel")
		if ct:
			ct.queue_free()
		_teaching_canvas.visible = false

func _fade_out_centered_text():
	if _teaching_canvas:
		var ct = _teaching_canvas.get_node_or_null("CenteredTextLabel")
		if ct:
			var tw = get_tree().create_tween()
			tw.tween_property(ct, "modulate:a", 0.0, 1.0)
			await tw.finished
			ct.queue_free()

func _show_centered_text(text: String):
	_ensure_teaching_canvas()
	# Hide image + placeholder, show just black bg with centered text
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.visible = false
	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if placeholder:
		placeholder.visible = false

	# Remove old centered text if any
	var old_ct = _teaching_canvas.get_node_or_null("CenteredTextLabel")
	if old_ct:
		old_ct.queue_free()

	var label = Label.new()
	label.name = "CenteredTextLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1.0))
	
	var custom_font = load("res://Textures/Fonts/Pixelify_Sans/static/PixelifySans-Regular.ttf")
	if custom_font:
		label.add_theme_font_override("font", custom_font)
		
	label.modulate.a = 0.0
	_teaching_canvas.add_child(label)
	_teaching_canvas.visible = true

	# Subtle fade-in
	var tw = get_tree().create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT)

func _ensure_teaching_canvas():
	if _teaching_canvas:
		return
	_teaching_canvas = CanvasLayer.new()
	_teaching_canvas.layer = 5
	_teaching_canvas.name = "FullscreenImageCanvas"
	get_tree().current_scene.add_child(_teaching_canvas)

	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_teaching_canvas.add_child(bg)

	var img_rect = TextureRect.new()
	img_rect.name = "TextureRect"
	img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_teaching_canvas.add_child(img_rect)

func _create_placeholder_panel() -> CenterContainer:
	var center = CenterContainer.new()
	center.name = "PlaceholderPanel"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 350)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.4, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var icon = Label.new()
	icon.text = "📖"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon)

	var text_label = Label.new()
	text_label.name = "Text"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(text_label)

	var hint = Label.new()
	hint.text = "— Visual Novel Scene —"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(hint)

	return center

# ── Label Fade Helpers (same as dialogue_interactable.gd) ─────────────

func _show_label():
	if not interaction_label:
		return
	interaction_label.text = "(F) to Talk"
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

# ── Helpers ───────────────────────────────────────────────────────────

func _get_dialogue_box():
	var boxes = get_tree().get_nodes_in_group("dialogue_box")
	if boxes.size() > 0:
		return boxes[0]
	var root = get_tree().current_scene
	for child in root.get_children():
		if child.has_method("start") and child is CanvasLayer:
			return child
	var instance = DIALOGUE_BOX_SCENE.instantiate()
	root.add_child(instance)
	return instance

# ── Black Screen (no placeholder, just black bg + dialogue) ───────────

func _show_black_screen():
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.visible = false
	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if placeholder:
		placeholder.visible = false
	_teaching_canvas.visible = true

# ── Dialogue Logging ──────────────────────────────────────────────────

func _log_dialogue(lines: Array):
	for line in lines:
		_dialogue_log.append(line)

func _show_dialogue_with_log(dbox, lines: Array):
	_log_dialogue(lines)
	dbox.start(lines)

# ── Dialogue Log Overlay UI ──────────────────────────────────────────

func _create_log_button(parent_canvas: CanvasLayer):
	# Create a small "📜 Log" button in the top-left of the IDE
	var btn = Button.new()
	btn.name = "LogButton"
	btn.text = "📜 Log"
	btn.custom_minimum_size = Vector2(70, 30)
	btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	btn.offset_left = 10
	btn.offset_right = 80
	btn.offset_top = 6
	btn.offset_bottom = 36

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.28, 0.9)
	style.border_color = Color(0.45, 0.55, 0.85, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.25, 0.25, 0.4, 0.95)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	btn.add_theme_font_size_override("font_size", 12)

	btn.pressed.connect(_toggle_log_overlay)
	parent_canvas.add_child(btn)

func _toggle_log_overlay():
	if _log_overlay and is_instance_valid(_log_overlay):
		_log_overlay.visible = not _log_overlay.visible
		if _log_overlay.visible:
			_refresh_log_content()
		return

	# Create new log overlay
	_log_overlay = CanvasLayer.new()
	_log_overlay.layer = 70  # above dialogue and IDE
	_log_overlay.name = "DialogueLogOverlay"
	get_tree().current_scene.add_child(_log_overlay)

	# Semi-transparent backdrop
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_overlay.add_child(backdrop)

	# Main panel
	var panel = PanelContainer.new()
	panel.name = "LogPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -250
	panel.offset_bottom = 250

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	panel_style.border_color = Color(0.45, 0.55, 0.85, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	_log_overlay.add_child(panel)

	# VBox
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title bar
	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)

	var title = Label.new()
	title.text = "📜 Dialogue Log"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 28)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.3, 0.1, 0.1, 0.8)
	close_style.set_corner_radius_all(4)
	close_style.set_content_margin_all(2)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	close_btn.pressed.connect(func(): _log_overlay.visible = false)
	title_bar.add_child(close_btn)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.55))
	vbox.add_child(sep)

	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.name = "LogScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var log_vbox = VBoxContainer.new()
	log_vbox.name = "LogContent"
	log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(log_vbox)

	_refresh_log_content()

func _refresh_log_content():
	if not _log_overlay or not is_instance_valid(_log_overlay):
		return

	var log_content = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll/LogContent")
	if not log_content:
		return

	# Clear existing entries
	for child in log_content.get_children():
		child.queue_free()

	# Populate from _dialogue_log
	for entry in _dialogue_log:
		var line_label = RichTextLabel.new()
		line_label.bbcode_enabled = true
		line_label.fit_content = true
		line_label.scroll_active = false
		line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_label.add_theme_font_size_override("normal_font_size", 13)

		var speaker = entry.get("name", "???")
		var text = entry.get("text", "")
		var name_color = "#a3c4f3" if speaker == "Spaghetti Guy" else ("#f0c674" if speaker == "Internet Cafe Owner" else "#c8e6c9")

		line_label.text = "[color=" + name_color + "][b]" + speaker + ":[/b][/color] [color=#d4d4d8]" + text + "[/color]"
		log_content.add_child(line_label)

	# Scroll to bottom
	var scroll = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll")
	if scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# ── IDE Tutorial Overlay Helper ──────────────────────────────────────────────

func _create_ide_tutorial_overlay():
	var TUTORIAL_OVERLAY_SCRIPT = preload("res://Scripts/UI/tutorial_overlay.gd")
	var overlay = CanvasLayer.new()
	overlay.set_script(TUTORIAL_OVERLAY_SCRIPT)
	overlay.layer = 150
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(overlay)
	await get_tree().process_frame
	return overlay
