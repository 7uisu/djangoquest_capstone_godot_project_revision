# ch2_professor_markup_controller.gd — Year 1 Semester 1 Professor Controller
# Manages the teach-code-teach-code flow for Professor Markup (HTML, CSS & Web Basics)
# Attach to the college_map_manager or reference from it.
#
# Flow:
#   Player interacts with NPCMaleCollegeProf01 → lecture prompt →
#   5 modules of (Teaching placeholders + dialogue) then IDE coding challenges →
#   Mark ch2_y1s1_teaching_done = true
extends Node

const CODING_UI_SCENE = preload("res://Scenes/Games/coding_challenge_ui.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")
const GLOSSARY_POPUP_SCENE = preload("res://Scripts/UI/glossary_popup.gd")
const REMOVAL_QUIZ_SCENE = preload("res://Scenes/Games/removal_quiz_game.tscn")

@onready var character_data = get_node("/root/CharacterData")

var player: Node2D = null
var professor_npc: Area2D = null
var dialogue_box = null

var is_learning_mode: bool = false
var _cutscene_running: bool = false
var _teaching_canvas: CanvasLayer = null
var _dialogue_log: Array = []
var _log_overlay: CanvasLayer = null

var _challenge_canvas: CanvasLayer = null
var _challenge_ui: Node = null
var _original_dialogue_layer: int = 10

# ── Grade Evaluation Config ───────────────────────────────────────────
@export var deduction_wrong_attempt: float = 0.25
@export var deduction_hint_used: float = 0.50
@export var removal_pass_score: int = 3

# Reward variables (Hardcoded for script editing)
var reward_credits_retake_0: int = 100
var reward_credits_retake_1: int = 90
var reward_credits_retake_2: int = 80
var reward_credits_retake_3: int = 60
var reward_credits_retake_4_plus: int = 50

var _session_wrong_attempts: int = 0
var _session_hints_used: int = 0

var _removal_questions: Array = [
	{"question": "What HTTP method is used to retrieve a webpage?", "options": ["A) POST", "B) GET", "C) PUT", "D) DELETE"], "correct": 1},
	{"question": "What does HTML stand for?", "options": ["A) Hyper Tool Markup Language", "B) HyperText Markup Language", "C) Home Text Making Language", "D) HyperText Machine Logic"], "correct": 1},
	{"question": "Which HTML tag defines a paragraph?", "options": ["A) <h1>", "B) <div>", "C) <p>", "D) <span>"], "correct": 2},
	{"question": "What is the CSS Box Model order (inside out)?", "options": ["A) Margin, Border, Padding, Content", "B) Content, Padding, Border, Margin", "C) Border, Margin, Content, Padding", "D) Padding, Content, Margin, Border"], "correct": 1},
	{"question": "Which CSS property makes a container use Flexbox?", "options": ["A) position: flex", "B) layout: flexbox", "C) display: flex", "D) flex: enabled"], "correct": 2},
	{"question": "What does justify-content: center do in Flexbox?", "options": ["A) Centers items vertically", "B) Centers items along the main axis", "C) Adds padding to all sides", "D) Makes text bold"], "correct": 1},
	{"question": "What CSS feature adapts layout based on screen size?", "options": ["A) Flexbox", "B) Animations", "C) Media queries", "D) Variables"], "correct": 2},
	{"question": "What does a server send back after receiving a request?", "options": ["A) A cookie", "B) A response", "C) A token", "D) A redirect"], "correct": 1},
	{"question": "Which tag is used for the main heading of a page?", "options": ["A) <title>", "B) <header>", "C) <h1>", "D) <main>"], "correct": 2},
	{"question": "What does padding control in CSS?", "options": ["A) Space outside the element", "B) Space between content and border", "C) The element background color", "D) The font size"], "correct": 1}
]

# ── Public: called by college_map_manager to wire up ──────────────────
# Note: The manager handles NPC wiring (clearing dialogue, creating
# the interaction Area2D). This controller just needs to be referenced.

# ── Interaction Handler ───────────────────────────────────────────────

var retake_dialogues: Array = [
	# Index 0 — first time (normal intro, handled by existing code, leave empty or use as override)
	[],
	# Index 1 — retake 1
	[{ "name": "Professor Markup", "text": "Let's go through this again. Take your time." }],
	# Index 2 — retake 2
	[
		{ "name": "Professor Markup", "text": "Before we start —" },
		{ "name": "Professor Markup", "text": "What do you think went wrong last time?" }
	],
	# Index 3 — retake 3+
	[
		{ "name": "Professor Markup", "text": "I'm not going to pretend this has been easy." },
		{ "name": "Professor Markup", "text": "But I've seen students exactly where you are become the best in the class." },
		{ "name": "Professor Markup", "text": "One more time." }
	]
]

func _dispatch_rewards() -> void:
	var retake = character_data.ch2_y1s1_retake_count
	var credits_reward = 0
	match retake:
		0: credits_reward = reward_credits_retake_0
		1: credits_reward = reward_credits_retake_1
		2: credits_reward = reward_credits_retake_2
		3: credits_reward = reward_credits_retake_3
		_: credits_reward = reward_credits_retake_4_plus

	character_data.credits += credits_reward
	print("ProfMarkupController: Dispatched %d credits for retake %d" % [credits_reward, retake])

func _on_professor_interacted():
	print("ProfMarkupController: _on_professor_interacted() called!")
	if _cutscene_running:
		return
	
	# Find player
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	dialogue_box = _get_dialogue_box()
	print("ProfMarkupController: dialogue_box = ", dialogue_box)
	print("ProfMarkupController: character_data = ", character_data)
	
	if is_learning_mode:
		_cutscene_running = true
		_start_lesson_sequence()
		return
	
	if character_data and character_data.ch2_y1s1_teaching_done:
		# Post-completion dialogue
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Markup", "text": "You've completed all my lessons for this semester. Well done!" },
				{ "name": "Professor Markup", "text": "Keep practicing what you've learned. HTML and CSS are the foundation of everything." }
			])
		return
	
	if dialogue_box and character_data:
		var retake_count = character_data.ch2_y1s1_retake_count
		if retake_count > 0:
			var dialogue_index = min(retake_count, retake_dialogues.size() - 1)
			var dialogue_lines = retake_dialogues[dialogue_index]
			if dialogue_lines.size() > 0:
				dialogue_box.start(dialogue_lines)
				await dialogue_box.dialogue_finished
	
	# Show lecture prompt with choices
	if dialogue_box:
		var current_mod = 0
		if character_data:
			current_mod = character_data.ch2_y1s1_current_module
		
		var mod_names = ["How the Web Works", "HTML Documents", "CSS Styling", "Flexbox Layouts", "Responsiveness"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var lines = [{
			"name": "Professor Markup",
			"text": "Are you ready to start the lecture on " + mod_label + "?",
			"choices": ["Yes", "Not yet"]
		}]
		
		# Use choice_selected signal (same pattern as ch1_school_controller.gd)
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	print("ProfMarkupController: choice_index = ", choice_index)
	if choice_index == 0:
		_cutscene_running = true
		_start_lesson_sequence()


# ── LESSON SEQUENCE ───────────────────────────────────────────────────

func _start_lesson_sequence():
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.hide_quest()

	dialogue_box = _get_dialogue_box()
	
	# Freeze player
	if player:
		player.can_move = false
		player.can_interact = false
		player.set_physics_process(false)
		player.block_ui_input = true
		if player.has_method("play_idle_animation") and "current_dir" in player:
			player.play_idle_animation(player.current_dir)
	
	var current_module = 0
	if character_data:
		current_module = character_data.ch2_y1s1_current_module
	
	if is_learning_mode:
		current_module = 0
		
	# ─── DEBUG SKIP IDE ────────────────────────────────────────────
	# @TODO: CHANGE THIS TO false WHEN DONE TESTING
	var DEBUG_SKIP_IDE = false
	# ─── END OF DEBUG SKIP IDE ────────────────────────────────────
	
	# IDE is created lazily on first challenge (after teaching placeholders).
	_challenge_canvas = null
	_challenge_ui = null
	_session_wrong_attempts = 0
	_session_hints_used = 0
	
	# ─── Run modules from current progress ────────────────────────
	
	if current_module <= 0:
		await _play_module_1_web_basics(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y1s1_current_module = 1
	
	if current_module <= 1:
		await _play_module_2_html(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y1s1_current_module = 2
	
	if current_module <= 2:
		await _play_module_3_css(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y1s1_current_module = 3
	
	if current_module <= 3:
		await _play_module_4_flexbox(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y1s1_current_module = 4
	
	if current_module <= 4:
		await _play_module_5_responsiveness(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y1s1_current_module = 5
	
	# ─── All modules done ─────────────────────────────────────────
	
	# Restore dialogue box layer
	if dialogue_box and dialogue_box is CanvasLayer and not DEBUG_SKIP_IDE:
		dialogue_box.layer = _original_dialogue_layer
	
	# Close the IDE
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.queue_free()
	_challenge_canvas = null
	_challenge_ui = null
	
	if is_learning_mode:
		var parent_node = get_parent()
		if parent_node and parent_node.has_method("show_professor_selector_disabled"):
			parent_node.show_professor_selector_disabled()
	
	# ─── Grade Evaluation (normal mode, IDE was used) ────────────
	if not is_learning_mode and not DEBUG_SKIP_IDE:
		character_data.ch2_y1s1_wrong_attempts = _session_wrong_attempts
		character_data.ch2_y1s1_hints_used = _session_hints_used
		var grade_result = await _evaluate_and_finalize_grade()
		if grade_result == "fail" or grade_result == "inc_fail":
			if player:
				player.can_move = true
				player.can_interact = true
				player.set_physics_process(true)
				player.block_ui_input = false
			_cutscene_running = false
			var qm2 = get_node_or_null("/root/QuestManager")
			if qm2:
				qm2.show_quest()
			return
	
	await get_tree().create_timer(0.3).timeout
	
	# Completion dialogue
	dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor Markup", "text": "Outstanding work today, everyone." },
			{ "name": "Professor Markup", "text": "You now understand [color=#f0c674]how the web works[/color], [color=#f0c674]HTML structure[/color], [color=#f0c674]CSS styling[/color], [color=#f0c674]layouts[/color], and [color=#f0c674]responsiveness[/color]." },
			{ "name": "Professor Markup", "text": "These are the building blocks of every website you'll ever create." },
			{ "name": "Professor Markup", "text": "That concludes our semester. Keep practicing!" }
		])
		await dialogue_box.dialogue_finished
	
	# Mark complete
	if character_data and not is_learning_mode:
		character_data.ch2_y1s1_teaching_done = true
		_dispatch_rewards()
	
	# Unfreeze player
	if player:
		player.can_move = true
		player.can_interact = true
		player.set_physics_process(true)
		player.block_ui_input = false
	
	_cutscene_running = false

	# ─── Scene Transition ─────────────────────────────────────────
	if is_learning_mode:
		var parent_node = get_parent()
		if parent_node and parent_node.has_method("enable_professor_selector"):
			parent_node.enable_professor_selector()
		queue_free()
		return

	if qm:
		qm.show_quest()
		if qm.has_method("refresh_college_quest"):
			qm.refresh_college_quest()

# ── Teaching slides (Ch1-style) + lazy IDE ────────────────────────────

func _before_teaching_slides() -> void:
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.visible = false


## Show IDE first and let it paint, then remove teaching — avoids a flash of the map.
func _transition_from_teaching_to_ide(skip_ide: bool) -> void:
	if skip_ide:
		_hide_fullscreen_image()
		return
	await _ensure_challenge_ui()
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_hide_fullscreen_image()


func _show_challenge_canvas() -> void:
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.visible = true

func _await_challenge_done(ui) -> void:
	while not ui.is_completed:
		await get_tree().create_timer(0.1).timeout
	while not ui.results_overlay.visible:
		await get_tree().create_timer(0.1).timeout
	# Show the continue button and wait for the player to click it
	ui.continue_button.visible = true
	ui.continue_button.text = "Next ▸"
	await ui.continue_button.pressed
	ui.continue_button.visible = false
	ui.results_overlay.visible = false
	ui.lock_typing(true)

func _ensure_challenge_ui() -> Node:
	if _challenge_ui and is_instance_valid(_challenge_ui):
		return _challenge_ui
	_challenge_canvas = CanvasLayer.new()
	_challenge_canvas.layer = 50
	_challenge_canvas.name = "ChallengeCanvasLayer"
	get_tree().current_scene.add_child(_challenge_canvas)
	var dim_bg = ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 1.0)
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_challenge_canvas.add_child(dim_bg)

	_challenge_ui = CODING_UI_SCENE.instantiate()
	_challenge_ui.hide_close_button = true
	_challenge_canvas.add_child(_challenge_ui)
	await get_tree().process_frame
	if _challenge_ui.continue_button.pressed.is_connected(_challenge_ui._on_continue_pressed):
		_challenge_ui.continue_button.pressed.disconnect(_challenge_ui._on_continue_pressed)
	_challenge_ui.close_button.visible = false
	_challenge_ui.continue_button.visible = false
	_create_log_button(_challenge_canvas)
	dialogue_box = _get_dialogue_box()
	if dialogue_box and dialogue_box is CanvasLayer:
		_original_dialogue_layer = dialogue_box.layer
		dialogue_box.layer = 60
	return _challenge_ui


# ══════════════════════════════════════════════════════════════════════
#  MODULE 1 — How the Web Works
# ══════════════════════════════════════════════════════════════════════

func _play_module_1_web_basics(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching slides (1st half: visual lecture) ─────────────────
	_show_teaching_slide({
		"icon": "🌐",
		"title": "How the Web Works",
		"subtitle": "Understanding the request-response cycle",
		"bullets": [
			"You type a URL → Your [b]browser[/b] sends a request",
			"A [b]server[/b] receives the request and processes it",
			"The server sends back a [b]response[/b] (the webpage)",
			"This all happens in [b]milliseconds[/b]"
		],
		"header": "MODULE 1 — WEB BASICS",
		"slide_num": "1 / 10",
		"reference": "Source: Mozilla Developer Network - Web Docs"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Good morning, everyone. Welcome to your very first college lecture." },
			{ "name": "Professor Markup", "text": "Before we build anything… you need to understand what happens when you open a website." },
			{ "name": "Student", "text": "We just… type a URL and hit Enter?" },
			{ "name": "Professor Markup", "text": "That's what you see. But behind the scenes, a conversation is happening." },
			{ "name": "Professor Markup", "text": "Your [color=#f0c674]browser[/color] sends a [color=#f0c674]Request[/color] to a [color=#f0c674]server[/color]." },
			{ "name": "Professor Markup", "text": "The server processes it… and sends back a [color=#f0c674]Response[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	_show_teaching_slide({
		"icon": "📨",
		"title": "HTTP Methods",
		"subtitle": "How browsers talk to servers",
		"bullets": [
			"[b]GET[/b]  →  'Give me this page'  (viewing)",
			"[b]POST[/b] →  'Here is some data'  (submitting)",
			"Every URL visit = a GET request",
			"Every form submission = a POST request"
		],
		"code": "GET /home/ HTTP/1.1\nHost: www.example.com",
		"header": "MODULE 1 — WEB BASICS",
		"slide_num": "2 / 10",
		"reference": "Source: Web Development with HTML/CSS/JS (Lemay et al., 2021)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "So it's like sending a letter and getting a reply?" },
			{ "name": "Professor Markup", "text": "Exactly. Except it happens in milliseconds." },
			{ "name": "Professor Markup", "text": "The most common request is called a [color=#f0c674]GET[/color] request." },
			{ "name": "Professor Markup", "text": "When you visit a page, your browser says: '[color=#f0c674]GET[/color] me this resource.'" },
			{ "name": "Student", "text": "So every time I open Google… that's a [color=#f0c674]GET[/color] request?" },
			{ "name": "Professor Markup", "text": "Every single time." },
			{ "name": "Professor Markup", "text": "There's also [color=#f0c674]POST[/color] — that's when you submit data. Like filling out a form or logging in." },
			{ "name": "Professor Markup", "text": "Remember this flow: [color=#f0c674]Client[/color] sends [color=#f0c674]Request[/color] → [color=#f0c674]Server[/color] processes → Server sends [color=#f0c674]Response[/color]." },
			{ "name": "Professor Markup", "text": "Now let's put that knowledge to the test!" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"markup_web_basics", "Write an HTTP Request", "http", "request.txt",
		["# Write the HTTP method to request a homepage", "# Format: METHOD /path/ HTTP/1.1"],
		["Write a GET request for the /home/ path", "Why: HTTP GET is the fundamental method that all browsers use to retrieve web pages from servers."],
		"Type your request here...",
		["GET /home/ HTTP/1.1", "GET /home/ HTTP/1.1 "],
		"200 OK — Page loaded successfully!",
		"400 Bad Request — Check your HTTP method and path format!",
		[
			"The most common HTTP method for viewing pages is GET.",
			"Format: GET /home/ HTTP/1.1"
		]
	)
	
	ch_data["project_tree"] = {"request.txt": "file", "index.html": "file", "style.css": "file", "layout.css": "file", "responsive.css": "file"}
	ui.load_challenge(ch_data)
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Let's try it! Write an [color=#f0c674]HTTP GET[/color] request." },
			{ "name": "Professor Markup", "text": "The format is: [color=#f0c674]GET /home/ HTTP/1.1[/color]" },
			{ "name": "Professor Markup", "text": "Type it in and hit ▶ Run!" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	_session_wrong_attempts += ui.get_attempts()
	_session_hints_used += ui.get_hints_used()
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Well done! You just sent your first [color=#f0c674]HTTP request[/color]!" },
			{ "name": "Professor Markup", "text": "Every website you've ever visited started with exactly that." },
			{ "name": "Professor Markup", "text": "Now let's move on to what the server actually sends back…" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 2 — HTML Documents
# ══════════════════════════════════════════════════════════════════════

func _play_module_2_html(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	_show_teaching_slide({
		"icon": "📄",
		"title": "HTML — The Skeleton",
		"subtitle": "Every website starts with structure",
		"bullets": [
			"HTML = [b]HyperText Markup Language[/b]",
			"It defines [b]what[/b] content is, not how it looks",
			"Think of it as the [b]skeleton[/b] of a webpage",
			"Without HTML, there is no website"
		],
		"header": "MODULE 2 — HTML DOCUMENTS",
		"slide_num": "3 / 10",
		"reference": "Source: Responsive Web Design with HTML5 & CSS (Frain, 2022)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Now let me clarify something." },
			{ "name": "Professor Markup", "text": "You are not learning how to make websites look good." },
			{ "name": "Student", "text": "...then what are we learning?" },
			{ "name": "Professor Markup", "text": "You are learning how websites [color=#f0c674]exist[/color]." },
			{ "name": "Professor Markup", "text": "Underneath, every website is made of [color=#f0c674]HTML[/color]." },
			{ "name": "Professor Markup", "text": "If your site were a human, [color=#f0c674]HTML[/color] would be the [color=#f0c674]skeleton[/color]." },
			{ "name": "Student", "text": "So [color=#f0c674]HTML[/color] is like… the base layer?" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	_show_teaching_slide({
		"icon": "🏷️",
		"title": "Semantic Tags",
		"subtitle": "Tags carry meaning — not just appearance",
		"bullets": [
			"<h1>  =  a [b]heading[/b], not just 'big text'",
			"<p>   =  a [b]paragraph[/b], not just 'text'",
			"<a>   =  a [b]link[/b] to another page",
			"Good HTML → accessible, searchable, meaningful"
		],
		"code": "<body>\n  <h1>Hello</h1>\n  <p>World</p>\n</body>",
		"header": "MODULE 2 — HTML DOCUMENTS",
		"slide_num": "4 / 10",
		"reference": "Source: Responsive Web Design with HTML5 & CSS (Frain, 2022)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "More than that. It is the [color=#f0c674]structure[/color]." },
			{ "name": "Professor Markup", "text": "[color=#f0c674]HTML[/color] is made of [color=#f0c674]tags[/color]. Tags tell the browser what each piece of content means." },
			{ "name": "Professor Markup", "text": "A [color=#f0c674]<h1>[/color] is not just big text. It is a [color=#f0c674]heading[/color]." },
			{ "name": "Professor Markup", "text": "A [color=#f0c674]<p>[/color] is not just text. It is a [color=#f0c674]paragraph[/color]." },
			{ "name": "Professor Markup", "text": "That's why we call them [color=#f0c674]semantic tags[/color]." },
			{ "name": "Professor Markup", "text": "If you ignore [color=#f0c674]semantics[/color]… you build websites that look fine… but are fundamentally broken." },
			{ "name": "Professor Markup", "text": "Now let's write some [color=#f0c674]HTML[/color]!" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"markup_html", "Write HTML Tags", "html", "index.html",
		["<!DOCTYPE html>", "<html>", "<head><title>My Page</title></head>", "", "<!-- Add the body, heading, and paragraph tags below -->", "</html>"],
		["Add <body>, <h1>Hello</h1>, and <p>World</p> tags", "Why: HTML provides the core structure of the web. Headings and paragraphs define the semantic meaning of the text."],
		"Type your HTML here...",
		[
			"<body><h1>Hello</h1><p>World</p></body>",
			"<body>\n<h1>Hello</h1>\n<p>World</p>\n</body>",
			"<body> <h1>Hello</h1> <p>World</p> </body>"
		],
		"✅ Page rendered: Hello (heading) + World (paragraph)",
		"SyntaxError: Missing or mismatched tags — check your angle brackets!",
		[
			"Start with <body> and end with </body>.",
			"Inside body, add <h1>Hello</h1> and <p>World</p>"
		]
	)
	
	ch_data["project_tree"] = {"request.txt": "file", "index.html": "file", "style.css": "file", "layout.css": "file", "responsive.css": "file"}
	ui.load_challenge(ch_data)
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Add the [color=#f0c674]body[/color], a [color=#f0c674]heading[/color], and a [color=#f0c674]paragraph[/color] to this HTML document." },
			{ "name": "Professor Markup", "text": "Type: [color=#f0c674]<body><h1>Hello</h1><p>World</p></body>[/color]" },
			{ "name": "Professor Markup", "text": "Don't forget to [color=#f0c674]close every tag[/color] you open!" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	_session_wrong_attempts += ui.get_attempts()
	_session_hints_used += ui.get_hints_used()
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Excellent! You just wrote a complete [color=#f0c674]HTML document[/color]." },
			{ "name": "Professor Markup", "text": "The browser now knows what to display and what it means." },
			{ "name": "Professor Markup", "text": "But it looks ugly, right? That's where [color=#f0c674]CSS[/color] comes in…" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 3 — CSS Basics
# ══════════════════════════════════════════════════════════════════════

func _play_module_3_css(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	_show_teaching_slide({
		"icon": "🎨",
		"title": "CSS & The Box Model",
		"subtitle": "Everything on the web is a box",
		"bullets": [
			"CSS = [b]Cascading Style Sheets[/b]",
			"Controls [b]layout[/b], [b]colors[/b], [b]spacing[/b], [b]fonts[/b]",
			"Every element is a [b]box[/b] with 4 layers",
			"Content → Padding → Border → Margin"
		],
		"header": "MODULE 3 — CSS BASICS",
		"slide_num": "5 / 10",
		"reference": "Source: Responsive Web Design with HTML5 & CSS (Frain, 2022)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Now that we have structure… we fix the ugliness." },
			{ "name": "Student", "text": "Finally!" },
			{ "name": "Professor Markup", "text": "That ugliness was intentional. It forced you to focus on [color=#f0c674]structure[/color] first." },
			{ "name": "Professor Markup", "text": "[color=#f0c674]CSS[/color] controls [color=#f0c674]layout[/color], [color=#f0c674]spacing[/color], and [color=#f0c674]visual hierarchy[/color]." },
			{ "name": "Professor Markup", "text": "Repeat after me. Everything… is a [color=#f0c674]box[/color]." },
			{ "name": "Student", "text": "...everything is a [color=#f0c674]box[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	_show_teaching_slide({
		"icon": "📦",
		"title": "Inside vs Outside",
		"subtitle": "Padding lives inside — Margin lives outside",
		"bullets": [
			"[b]padding[/b]: space between content and border",
			"[b]margin[/b]: space between the box and neighbors",
			"[b]border[/b]: the visible edge of the box"
		],
		"code": ".box {\n  margin: 20px;   /* outside */\n  padding: 10px;  /* inside */\n}",
		"header": "MODULE 3 — CSS BASICS",
		"slide_num": "6 / 10",
		"reference": "Source: Responsive Web Design with HTML5 & CSS (Frain, 2022)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Yes. Even images. Even buttons. Everything." },
			{ "name": "Professor Markup", "text": "Each box has layers: [color=#f0c674]Content[/color] → [color=#f0c674]Padding[/color] → [color=#f0c674]Border[/color] → [color=#f0c674]Margin[/color]" },
			{ "name": "Professor Markup", "text": "[color=#f0c674]Padding[/color] is inside the box. [color=#f0c674]Margin[/color] is outside the box." },
			{ "name": "Professor Markup", "text": "Let's try styling a box!" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"markup_css", "Style a Box", "css", "style.css",
		["/* Style the div to have proper spacing */", ".box {", "", "    /* Add margin and padding below */", "", "}"],
		["Add margin: 20px; and padding: 10px; to the box", "Why: CSS controls visual layout. The Box Model (margins and padding) determines how elements are spaced."],
		"Type your CSS here...",
		[
			"margin: 20px;\n    padding: 10px;",
			"margin: 20px; padding: 10px;",
			"margin:20px;padding:10px;",
			"margin: 20px;\npadding: 10px;"
		],
		"✅ Box styled — margin: 20px, padding: 10px applied!",
		"Error: Invalid CSS property — check your syntax (property: value;)",
		[
			"CSS uses the format: property: value;",
			"Type: margin: 20px; and on the next line: padding: 10px;"
		]
	)
	
	ch_data["project_tree"] = {"request.txt": "file", "index.html": "file", "style.css": "file", "layout.css": "file", "responsive.css": "file"}
	ui.load_challenge(ch_data)
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Time to style! Add [color=#f0c674]margin[/color] and [color=#f0c674]padding[/color] to this box." },
			{ "name": "Professor Markup", "text": "Type: [color=#f0c674]margin: 20px;[/color] and [color=#f0c674]padding: 10px;[/color]" },
			{ "name": "Professor Markup", "text": "Remember: [color=#f0c674]margin[/color] is outside, [color=#f0c674]padding[/color] is inside!" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	_session_wrong_attempts += ui.get_attempts()
	_session_hints_used += ui.get_hints_used()
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Well done! You just controlled the [color=#f0c674]spacing[/color] of a box." },
			{ "name": "Professor Markup", "text": "Now you know the building block of all [color=#f0c674]CSS layouts[/color]." },
			{ "name": "Professor Markup", "text": "But individual boxes aren't enough. We need to [color=#f0c674]arrange[/color] them…" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 4 — Flexbox
# ══════════════════════════════════════════════════════════════════════

func _play_module_4_flexbox(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	_show_teaching_slide({
		"icon": "↔️",
		"title": "Flexbox Layouts",
		"subtitle": "Modern CSS layout made simple",
		"bullets": [
			"Before Flexbox: floats, hacks, pain",
			"[b]display: flex[/b] → turns a container into a flex container",
			"Items flow in one direction: [b]row[/b] or [b]column[/b]",
			"Easy alignment and spacing"
		],
		"header": "MODULE 4 — FLEXBOX",
		"slide_num": "7 / 10",
		"reference": "Source: MDN Web Docs - HTML & CSS"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Before modern CSS… developers suffered." },
			{ "name": "Student", "text": "That sounds dramatic." },
			{ "name": "Professor Markup", "text": "It is accurate. They used hacks. [color=#f0c674]Floats[/color]. Tables. Chaos." },
			{ "name": "Professor Markup", "text": "[color=#f0c674]Flexbox[/color] fixes that. It gives you control." },
			{ "name": "Professor Markup", "text": "It works in one direction: [color=#f0c674]Row[/color]… or [color=#f0c674]column[/color]." },
			{ "name": "Professor Markup", "text": "You define a [color=#f0c674]container[/color]… and everything inside becomes a [color=#f0c674]flex item[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	_show_teaching_slide({
		"icon": "◎",
		"title": "Centering & Alignment",
		"subtitle": "Finally — centering things that just works",
		"bullets": [
			"[b]justify-content[/b]: aligns items along the main axis",
			"[b]align-items[/b]: aligns items along the cross axis",
			"center, space-between, space-around, flex-start, flex-end"
		],
		"code": ".container {\n  display: flex;\n  justify-content: center;\n}",
		"header": "MODULE 4 — FLEXBOX",
		"slide_num": "8 / 10",
		"reference": "Source: MDN Web Docs - HTML & CSS"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "What if I want things centered?" },
			{ "name": "Professor Markup", "text": "You use [color=#f0c674]alignment properties[/color]. And for once… they actually make sense." },
			{ "name": "Professor Markup", "text": "Let me show you!" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"markup_flexbox", "Center with Flexbox", "css", "layout.css",
		["/* Center the items in this container */", ".container {", "", "    /* Make this a flex container and center items */", "", "}"],
		["Add display: flex; and justify-content: center;", "Why: Flexbox is a modern CSS layout module that allows you to easily align and distribute elements dynamically."],
		"Type your CSS here...",
		[
			"display: flex;\n    justify-content: center;",
			"display: flex; justify-content: center;",
			"display:flex;justify-content:center;",
			"display: flex;\njustify-content: center;"
		],
		"✅ Items are now centered using Flexbox!",
		"Error: Invalid layout — make sure you use display: flex first!",
		[
			"First, make the container a flex container with: display: flex;",
			"Then center items with: justify-content: center;"
		]
	)
	
	ch_data["project_tree"] = {"request.txt": "file", "index.html": "file", "style.css": "file", "layout.css": "file", "responsive.css": "file"}
	ui.load_challenge(ch_data)
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Make this container use [color=#f0c674]Flexbox[/color] and center the items." },
			{ "name": "Professor Markup", "text": "Type: [color=#f0c674]display: flex;[/color] and [color=#f0c674]justify-content: center;[/color]" },
			{ "name": "Professor Markup", "text": "Two lines. That's all it takes to center things properly!" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	_session_wrong_attempts += ui.get_attempts()
	_session_hints_used += ui.get_hints_used()
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Beautiful! Items are perfectly centered." },
			{ "name": "Professor Markup", "text": "[color=#f0c674]Flexbox[/color] is one of the most powerful tools in modern CSS." },
			{ "name": "Professor Markup", "text": "One more topic and we'll wrap up this semester…" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 5 — Responsiveness
# ══════════════════════════════════════════════════════════════════════

func _play_module_5_responsiveness(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	_show_teaching_slide({
		"icon": "📱",
		"title": "Responsive Design",
		"subtitle": "One website — every screen size",
		"bullets": [
			"Websites must work on [b]desktop[/b], [b]tablet[/b], and [b]phone[/b]",
			"A fixed layout will [b]break[/b] on small screens",
			"Responsive design [b]adapts[/b] the layout automatically",
			"The tool for this: [b]media queries[/b]"
		],
		"header": "MODULE 5 — RESPONSIVENESS",
		"slide_num": "9 / 10",
		"reference": "Source: MDN Web Docs - HTML & CSS"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Your site works on your laptop. Now open it on a [color=#f0c674]phone[/color]." },
			{ "name": "Student", "text": "...it's broken." },
			{ "name": "Professor Markup", "text": "Correct." },
			{ "name": "Student", "text": "So how do we fix that?" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	_show_teaching_slide({
		"icon": "📐",
		"title": "Media Queries",
		"subtitle": "Tell the browser: 'If the screen is small… change the layout'",
		"bullets": [
			"[b]@media[/b] lets you write conditional CSS",
			"Target specific screen widths (breakpoints)",
			"Good websites [b]adapt[/b] — bad websites [b]break[/b]"
		],
		"code": "@media (max-width: 600px) {\n  .container {\n    flex-direction: column;\n  }\n}",
		"header": "MODULE 5 — RESPONSIVENESS",
		"slide_num": "10 / 10",
		"reference": "Source: MDN Web Docs - HTML & CSS"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "With [color=#f0c674]media queries[/color]." },
			{ "name": "Professor Markup", "text": "You tell the browser: 'If the screen is small… change the layout.'" },
			{ "name": "Professor Markup", "text": "You design one system that [color=#f0c674]adapts[/color]. Good websites adjust automatically." },
			{ "name": "Professor Markup", "text": "Bad websites don't." },
			{ "name": "Professor Markup", "text": "Let's write your first [color=#f0c674]media query[/color]!" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"markup_responsive", "Write a Media Query", "css", "responsive.css",
		["/* Make the layout responsive for small screens */", "", "/* Write a media query for screens 600px or smaller */"],
		["Write a media query for max-width: 600px", "Why: Media queries allow your website to adapt its CSS responsively so it looks good on both phones and desktops."],
		"Type your CSS here...",
		[
			"@media (max-width: 600px) { }",
			"@media (max-width: 600px) {\n}",
			"@media (max-width: 600px) {}",
			"@media(max-width: 600px) { }",
			"@media(max-width:600px){ }",
			"@media (max-width: 600px) {\n\n}"
		],
		"✅ Media query active — layout adapts for small screens!",
		"Error: Invalid media query syntax — check your @media rule!",
		[
			"The syntax is: @media (condition) { }",
			"Type: @media (max-width: 600px) { }"
		]
	)
	
	ch_data["project_tree"] = {"request.txt": "file", "index.html": "file", "style.css": "file", "layout.css": "file", "responsive.css": "file"}
	ui.load_challenge(ch_data)
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Write a [color=#f0c674]media query[/color] that targets screens [color=#f0c674]600 pixels[/color] or smaller." },
			{ "name": "Professor Markup", "text": "Type: [color=#f0c674]@media (max-width: 600px) { }[/color]" },
			{ "name": "Professor Markup", "text": "This is how every [color=#f0c674]responsive[/color] website works!" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	_session_wrong_attempts += ui.get_attempts()
	_session_hints_used += ui.get_hints_used()
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Markup", "text": "Fantastic! You've written your first [color=#f0c674]media query[/color]!" },
			{ "name": "Professor Markup", "text": "Your layouts will now [color=#f0c674]adapt[/color] to any screen size." },
			{ "name": "Professor Markup", "text": "And with that… we've covered all the fundamentals!" }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════════════

func _evaluate_and_finalize_grade() -> String:
	var raw = GradeCalculator.compute_grade(_session_wrong_attempts, _session_hints_used, deduction_wrong_attempt, deduction_hint_used)
	character_data.ch2_y1s1_final_grade = raw
	
	print("--- DEBUG NORMAL GRADE EVALUATION ---")
	print("Wrong Attempts: ", _session_wrong_attempts, " | Hints Used: ", _session_hints_used)
	print("Raw Computed Grade: ", raw, " (", GradeCalculator.grade_to_label(raw), ")")
	print("-------------------------------------")
	
	dialogue_box = _get_dialogue_box()
	
	if GradeCalculator.is_passing(raw):
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor Markup", "text": "I've tallied your scores. You got a %s. You passed!" % GradeCalculator.grade_to_label(raw) }
			])
			await dialogue_box.dialogue_finished
		return "pass"
		
	elif GradeCalculator.is_inc(raw):
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor Markup", "text": "Your grade is... 4.0 (INC)." },
				{ "name": "Professor Markup", "text": "This means you didn't quite make the cut. However, you can take a removal exam." }
			])
			await dialogue_box.dialogue_finished
			
		var passed = await _launch_removal_exam()
		if passed:
			character_data.ch2_y1s1_final_grade = 3.0
			character_data.ch2_y1s1_removal_passed = true
			if dialogue_box:
				_show_dialogue_with_log(dialogue_box, [
					{ "name": "Professor Markup", "text": "You passed the removal exam! Your final grade is 3.0." }
				])
				await dialogue_box.dialogue_finished
			return "inc_pass"
		else:
			character_data.ch2_y1s1_final_grade = 5.0
			character_data.ch2_y1s1_removal_passed = false
			character_data.ch2_y1s1_retake_count += 1
			character_data.ch2_y1s1_current_module = 0
			if dialogue_box:
				_show_dialogue_with_log(dialogue_box, [
					{ "name": "Professor Markup", "text": "You failed the removal exam. Your final grade is 5.0." },
					{ "name": "Professor Markup", "text": "You'll have to retake my class." }
				])
				await dialogue_box.dialogue_finished
			# Ensure IDE resources and states are cleared
			return "inc_fail"
			
	else:
		character_data.ch2_y1s1_final_grade = 5.0
		character_data.ch2_y1s1_retake_count += 1
		character_data.ch2_y1s1_current_module = 0
		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor Markup", "text": "Your score was too low. Your final grade is 5.0 (FAILED)." },
				{ "name": "Professor Markup", "text": "You will have to completely retake this module." }
			])
			await dialogue_box.dialogue_finished
		return "fail"

func _launch_removal_exam() -> bool:
	var canvas = CanvasLayer.new()
	canvas.layer = 75
	get_tree().current_scene.add_child(canvas)
	
	var quiz = REMOVAL_QUIZ_SCENE.instantiate()
	quiz.all_questions = _removal_questions
	quiz.quiz_count = 5
	quiz.pass_score = removal_pass_score
	canvas.add_child(quiz)
	
	var score = await quiz.quiz_completed
	var passed = score >= removal_pass_score
	
	print("--- DEBUG REMOVAL EXAM ---")
	print("Removal Exam Score: ", score, "/", quiz.quiz_count)
	print("Removal Exam Passed? ", passed)
	print("--------------------------")
	
	canvas.queue_free()
	return passed

func _make_challenge(id: String, title: String, topic: String, file_name: String,
	code_lines: Array, mission_steps: Array, placeholder: String,
	expected_answers: Array, correct_output: String, error_output: String,
	progressive_hints: Array = []) -> Dictionary:
	
	var base_hint = progressive_hints[0] if progressive_hints.size() > 0 else "Read the professor's instructions carefully."

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
		"output_type": "browser" if topic in ["html", "css", "django"] else "terminal",
		"hint": base_hint,
		"timed": false
	}

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

func _log_dialogue(lines: Array):
	for line in lines:
		_dialogue_log.append(line)

func _show_dialogue_with_log(dbox, lines: Array):
	_log_dialogue(lines)
	dbox.start(lines)


# ── Fullscreen teaching (Ch1 pattern: layer 5, under dialogue layer 10) ───

func _show_fullscreen_image(texture: Texture2D) -> void:
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.texture = texture
		img_rect.visible = true
	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if placeholder:
		placeholder.visible = false
	_teaching_canvas.visible = true


func _show_placeholder_image(text: String) -> void:
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.visible = false
	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if not placeholder:
		placeholder = _create_placeholder_panel()
		_teaching_canvas.add_child(placeholder)
	var lbl = placeholder.find_child("Text", true, false)
	if lbl is Label:
		(lbl as Label).text = text
	placeholder.visible = true
	_teaching_canvas.visible = true


func _hide_fullscreen_image() -> void:
	if _teaching_canvas:
		var ct = _teaching_canvas.get_node_or_null("CenteredTextLabel")
		if ct:
			ct.queue_free()
		_teaching_canvas.visible = false


func _ensure_teaching_canvas() -> void:
	if _teaching_canvas:
		return
	_teaching_canvas = CanvasLayer.new()
	# Below dialogue_box (layer 10) so lines show on top of slides; same as ch1_internet_cafe_controller.
	_teaching_canvas.layer = 5
	_teaching_canvas.name = "ProfMarkupTeachingCanvas"
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
	# Push the panel upward so it sits ABOVE the dialogue box (~180px at bottom)
	center.offset_bottom = -200
	center.offset_top = 10

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 420)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.97)
	style.border_color = Color(0.30, 0.45, 0.75, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	# ── Outer VBox (header bar + body) ──
	var outer_vbox = VBoxContainer.new()
	outer_vbox.name = "OuterVBox"
	outer_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(outer_vbox)

	# ── Header bar (gradient-like accent strip) ──
	var header = PanelContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 56)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.14, 0.22, 0.42, 1.0)
	header_style.set_corner_radius_all(0)
	header_style.corner_radius_top_left = 14
	header_style.corner_radius_top_right = 14
	header_style.set_content_margin_all(12)
	header_style.content_margin_left = 20
	header.add_theme_stylebox_override("panel", header_style)
	outer_vbox.add_child(header)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	header.add_child(header_hbox)

	var header_icon = Label.new()
	header_icon.name = "HeaderIcon"
	header_icon.text = "🎓"
	header_icon.add_theme_font_size_override("font_size", 28)
	header_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(header_icon)

	var header_title = Label.new()
	header_title.name = "HeaderTitle"
	header_title.text = "LECTURE SLIDE"
	header_title.add_theme_font_size_override("font_size", 18)
	header_title.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var custom_font = load("res://Textures/Fonts/Pixelify_Sans/static/PixelifySans-Regular.ttf")
	if custom_font:
		header_title.add_theme_font_override("font", custom_font)
	header_hbox.add_child(header_title)

	var slide_num = Label.new()
	slide_num.name = "SlideNum"
	slide_num.text = ""
	slide_num.add_theme_font_size_override("font_size", 13)
	slide_num.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 0.7))
	slide_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(slide_num)

	# ── Body area ──
	var body_margin = MarginContainer.new()
	body_margin.name = "BodyMargin"
	body_margin.add_theme_constant_override("margin_left", 32)
	body_margin.add_theme_constant_override("margin_right", 32)
	body_margin.add_theme_constant_override("margin_top", 20)
	body_margin.add_theme_constant_override("margin_bottom", 24)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(body_margin)

	var body_vbox = VBoxContainer.new()
	body_vbox.name = "BodyVBox"
	body_vbox.add_theme_constant_override("separation", 14)
	body_margin.add_child(body_vbox)

	# ── slide icon (big centered emoji) ──
	var slide_icon = Label.new()
	slide_icon.name = "SlideIcon"
	slide_icon.text = "📖"
	slide_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slide_icon.add_theme_font_size_override("font_size", 44)
	body_vbox.add_child(slide_icon)

	# ── Slide title ──
	var title_label = Label.new()
	title_label.name = "SlideTitle"
	title_label.text = ""
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	if custom_font:
		title_label.add_theme_font_override("font", custom_font)
	body_vbox.add_child(title_label)

	# ── Subtitle / description ──
	var subtitle = Label.new()
	subtitle.name = "SlideSubtitle"
	subtitle.text = ""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.70, 0.82))
	body_vbox.add_child(subtitle)

	# ── Bullet points area (RichTextLabel for formatting) ──
	var bullets = RichTextLabel.new()
	bullets.name = "SlideBullets"
	bullets.bbcode_enabled = true
	bullets.fit_content = true
	bullets.scroll_active = false
	bullets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bullets.add_theme_font_size_override("normal_font_size", 17)
	bullets.add_theme_color_override("default_color", Color(0.82, 0.85, 0.95))
	body_vbox.add_child(bullets)

	# ── Code example panel (hidden by default) ──
	var code_panel = PanelContainer.new()
	code_panel.name = "CodePanel"
	code_panel.visible = false
	var code_style = StyleBoxFlat.new()
	code_style.bg_color = Color(0.06, 0.07, 0.11, 0.95)
	code_style.border_color = Color(0.25, 0.40, 0.65, 0.6)
	code_style.set_border_width_all(1)
	code_style.set_corner_radius_all(8)
	code_style.set_content_margin_all(14)
	code_panel.add_theme_stylebox_override("panel", code_style)
	body_vbox.add_child(code_panel)

	var code_label = Label.new()
	code_label.name = "CodeText"
	code_label.text = ""
	code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_label.add_theme_font_size_override("font_size", 15)
	code_label.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
	code_panel.add_child(code_label)

	# ── Legacy fallback text ──
	var text_label = Label.new()
	text_label.name = "Text"
	text_label.visible = false
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	body_vbox.add_child(text_label)

	# ── Footer ──
	var footer = Label.new()
	footer.name = "Footer"
	footer.text = "— Professor Markup's Lecture —"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.40, 0.45, 0.58, 0.6))
	body_vbox.add_child(footer)

	# ── Reference ──
	var reference = Label.new()
	reference.name = "ReferenceLabel"
	reference.text = ""
	reference.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reference.add_theme_font_size_override("font_size", 11)
	reference.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.8))
	body_vbox.add_child(reference)

	return center


# ── Structured Teaching Slide ─────────────────────────────────────────
# Richer alternative to _show_placeholder_image — displays a polished
# lecture slide with title, bullets, optional code, and slide numbering.
#
# slide_data keys:
#   icon       : String (emoji)         — default "📖"
#   title      : String                 — big slide title
#   subtitle   : String                 — smaller description
#   bullets    : Array[String]          — bullet-point lines (BBCode ok)
#   code       : String                 — optional code example shown in a code panel
#   slide_num  : String                 — e.g. "1 / 10" shown in header

func _show_teaching_slide(slide_data: Dictionary) -> void:
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.visible = false

	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if not placeholder:
		placeholder = _create_placeholder_panel()
		_teaching_canvas.add_child(placeholder)

	# Populate structured fields
	var icon_lbl = placeholder.find_child("SlideIcon", true, false)
	if icon_lbl is Label:
		icon_lbl.text = slide_data.get("icon", "📖")

	var title_lbl = placeholder.find_child("SlideTitle", true, false)
	if title_lbl is Label:
		title_lbl.text = slide_data.get("title", "")

	var subtitle_lbl = placeholder.find_child("SlideSubtitle", true, false)
	if subtitle_lbl is Label:
		var sub = slide_data.get("subtitle", "")
		subtitle_lbl.text = sub
		subtitle_lbl.visible = sub != ""

	var bullets_rtl = placeholder.find_child("SlideBullets", true, false)
	if bullets_rtl is RichTextLabel:
		var bullet_arr: Array = slide_data.get("bullets", [])
		if bullet_arr.size() > 0:
			var bb = ""
			for b in bullet_arr:
				bb += "[color=#7dacf0]  ●[/color]  " + GlossaryData.auto_link(b) + "\n"
			bullets_rtl.text = bb.strip_edges()
			bullets_rtl.visible = true
			# Wire glossary clicks — disconnect first to avoid duplicate connections
			if not bullets_rtl.meta_clicked.is_connected(_on_slide_glossary_clicked):
				bullets_rtl.meta_underlined = true
				bullets_rtl.meta_clicked.connect(_on_slide_glossary_clicked)
		else:
			bullets_rtl.visible = false

	var code_panel = placeholder.find_child("CodePanel", true, false)
	var code_text = placeholder.find_child("CodeText", true, false)
	var code_str: String = slide_data.get("code", "")
	if code_panel and code_text is Label:
		if code_str != "":
			code_text.text = code_str
			code_panel.visible = true
		else:
			code_panel.visible = false

	var slide_num_lbl = placeholder.find_child("SlideNum", true, false)
	if slide_num_lbl is Label:
		slide_num_lbl.text = slide_data.get("slide_num", "")

	var header_title = placeholder.find_child("HeaderTitle", true, false)
	if header_title is Label:
		header_title.text = slide_data.get("header", "LECTURE SLIDE")

	var header_icon = placeholder.find_child("HeaderIcon", true, false)
	if header_icon is Label:
		header_icon.text = slide_data.get("header_icon", "🎓")

	var ref_lbl = placeholder.find_child("ReferenceLabel", true, false)
	if ref_lbl is Label:
		var ref_text = slide_data.get("reference", "")
		ref_lbl.text = ref_text
		ref_lbl.visible = ref_text != ""

	# Hide the legacy Text label
	var legacy = placeholder.find_child("Text", true, false)
	if legacy is Label:
		legacy.visible = false

	placeholder.visible = true
	_teaching_canvas.visible = true


# ── Dialogue Log Overlay UI ──────────────────────────────────────────

func _create_log_button(parent_canvas: CanvasLayer):
	if parent_canvas.get_node_or_null("LogButton"):
		return
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

	_log_overlay = CanvasLayer.new()
	_log_overlay.layer = 70
	_log_overlay.name = "DialogueLogOverlay"
	get_tree().current_scene.add_child(_log_overlay)

	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_overlay.add_child(backdrop)

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

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

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

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.35, 0.55))
	vbox.add_child(sep)

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

	for child in log_content.get_children():
		child.queue_free()

	var challenge_active = _challenge_ui and is_instance_valid(_challenge_ui) and bool(_challenge_ui.get("_challenge_active"))

	for entry in _dialogue_log:
		var line_label = RichTextLabel.new()
		line_label.bbcode_enabled = true
		line_label.fit_content = true
		line_label.scroll_active = false
		line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_label.add_theme_font_size_override("normal_font_size", 13)

		var speaker = entry.get("name", "???")
		var text = entry.get("text", "")
		var name_color = "#a3c4f3" if speaker == "Professor Markup" else "#c8e6c9"
		if challenge_active and (
			text.find("\n") != -1
			or text.find("<") != -1
			or text.find(">") != -1
			or text.find("{") != -1
			or text.find("}") != -1
			or text.find(":") != -1
		):
			text = "[REDACTED - solve the challenge first!]"

		line_label.text = "[color=" + name_color + "][b]" + speaker + ":[/b][/color] [color=#d4d4d8]" + text + "[/color]"
		log_content.add_child(line_label)

	var scroll = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll")
	if scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# ─── Glossary ────────────────────────────────────────────────────────────────
# Called when a student clicks a [url=term]word[/url] on a teaching slide bullet.

func _on_slide_glossary_clicked(meta) -> void:
	var term = str(meta).strip_edges().to_lower()
	var popup = GLOSSARY_POPUP_SCENE.new()
	# Add to root so layer=100 puts it above slides (50) and dialogue (60)
	get_tree().root.add_child(popup)
	popup.show_definition(term)
