# ch2_professor_syntax_controller.gd — Year 1 Semester 2 Professor Controller
# Manages the teach-code-teach-code flow for Professor Syntax (Python Core & OOP)
# Wired to NPCFemaleCollegeProf01 via college_map_manager.gd
#
# Flow:
#   Player interacts with NPCFemaleCollegeProf01 → gate check (Sem 1 required) →
#   lecture prompt → 3 modules of (Teaching slides + dialogue) then IDE coding
#   challenges → Mark ch2_y1s2_teaching_done = true
#
# Semester 2 Modules:
#   Module 1 — Python Syntax Mastery (Loops, conditionals)
#   Module 2 — Object-Oriented Programming (Classes, objects, methods)
#   Module 3 — HTTP & Requests (requests library, GET/POST)
extends Node

const CODING_UI_SCENE = preload("res://Scenes/Games/coding_challenge_ui.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")
const GLOSSARY_POPUP_SCENE = preload("res://Scripts/UI/glossary_popup.gd")
const REMOVAL_QUIZ_SCENE = preload("res://Scenes/Games/removal_quiz_game.tscn")

var _session_wrong_attempts: int = 0
var _session_hints_used: int = 0

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

var reward_credits_retake_0: int = 100
var reward_credits_retake_1: int = 90
var reward_credits_retake_2: int = 80
var reward_credits_retake_3: int = 60
var reward_credits_retake_4_plus: int = 50

# ── Interaction Handler ───────────────────────────────────────────────

func _on_professor_interacted():
	print("ProfSyntaxController: _on_professor_interacted() called!")
	if _cutscene_running:
		return
	
	# Find player
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	dialogue_box = _get_dialogue_box()
	
	if is_learning_mode:
		_cutscene_running = true
		_start_lesson_sequence()
		return
	
		# ── Retake Interception ───────────────────────────────────────
	if character_data and not character_data.ch2_y1s2_teaching_done and character_data.ch2_y1s2_retake_count > 0:
		if dialogue_box:
			var retakes = character_data.ch2_y1s2_retake_count
			var lines = []
			if retakes == 1:
				lines.append({ "name": "Professor Syntax", "text": "A 5.0. You failed." })
				lines.append({ "name": "Professor Syntax", "text": "Do not pretend you understand. We go back to the beginning." })
			else:
				lines.append({ "name": "Professor Syntax", "text": "Failed again. A 5.0." })
				lines.append({ "name": "Professor Syntax", "text": "Programming requires precision. Try again from Module 1." })
				
			lines.append({
				"name": "Professor Syntax",
				"text": "Ready to restart the lecture sequence for Year 1 Semester 2?",
				"choices": ["Yes", "Not yet"]
			})
			dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
			dialogue_box.start(lines)
		return

	# ── Gate: Must complete Semester 1 first ──────────────────────
	if character_data and not character_data.ch2_y1s1_teaching_done:
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Syntax", "text": "Hmm. You look eager. But you're not ready." },
				{ "name": "Professor Syntax", "text": "Finish [color=#f0c674]Professor Markup's[/color] course first. Then come back." },
				{ "name": "Professor Syntax", "text": "I don't teach students who skip prerequisites." }
			])
		return
	
	# ── Post-completion dialogue ──────────────────────────────────
	if character_data and character_data.ch2_y1s2_teaching_done:
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Syntax", "text": "You've completed all my lessons for this semester." },
				{ "name": "Professor Syntax", "text": "[color=#f0c674]Loops[/color], [color=#f0c674]OOP[/color], [color=#f0c674]HTTP requests[/color]. You know the foundations now." },
				{ "name": "Professor Syntax", "text": "Don't forget them. Everything ahead builds on this." }
			])
		return
	
	# ── Lecture prompt ────────────────────────────────────────────
	if dialogue_box:
		var current_mod = 0
		if character_data:
			current_mod = character_data.ch2_y1s2_current_module
		
		var mod_names = ["Python Syntax Mastery", "Object-Oriented Programming", "HTTP & Requests"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var lines = [{
			"name": "Professor Syntax",
			"text": "Ready for the lecture on " + mod_label + "?",
			"choices": ["Yes", "Not yet"]
		}]
		
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	print("ProfSyntaxController: choice_index = ", choice_index)
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
		current_module = character_data.ch2_y1s2_current_module
	
	if is_learning_mode:
		current_module = 0
	
	# ─── DEBUG SKIP IDE ────────────────────────────────────────────
	# @TODO: CHANGE THIS TO false WHEN DONE TESTING
	var DEBUG_SKIP_IDE = false
	# ─── END OF DEBUG SKIP IDE ────────────────────────────────────
	
	_challenge_canvas = null
	_challenge_ui = null
	_session_wrong_attempts = 0
	_session_hints_used = 0
	
	# ─── Run modules from current progress ────────────────────────
	
	if current_module <= 0:
		await _play_module_1_python_basics(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y1s2_current_module = 1
	
	if current_module <= 1:
		await _play_module_2_oop(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y1s2_current_module = 2
	
	if current_module <= 2:
		await _play_module_3_http_requests(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y1s2_current_module = 3
	
	# ─── All modules done ─────────────────────────────────────────
	
	if dialogue_box and dialogue_box is CanvasLayer and not DEBUG_SKIP_IDE:
		dialogue_box.layer = _original_dialogue_layer
	
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.queue_free()
	_challenge_canvas = null
	_challenge_ui = null
	
	if is_learning_mode:
		var parent_node = get_parent()
		if parent_node and parent_node.has_method("show_professor_selector_disabled"):
			parent_node.show_professor_selector_disabled()
	
		# ─── Grade Evaluation (normal mode, IDE was used) ────────────
	if not DEBUG_SKIP_IDE:
		character_data.ch2_y1s2_wrong_attempts = _session_wrong_attempts
		character_data.ch2_y1s2_hints_used = _session_hints_used
		var grade_result = await _evaluate_and_finalize_grade()
		if grade_result == "fail" or grade_result == "inc_fail":
			if player:
				player.can_move = true
				player.can_interact = true
				player.set_physics_process(true)
				player.block_ui_input = false
			_cutscene_running = false
			return
	
	await get_tree().create_timer(0.3).timeout
	
	if is_learning_mode or DEBUG_SKIP_IDE:
		# Dummy completion for learning mode
		dialogue_box = _get_dialogue_box()
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Syntax", "text": "You made it through." },
				{ "name": "Professor Syntax", "text": "Semester complete." }
			])
			await dialogue_box.dialogue_finished

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
	if not _challenge_ui.challenge_failed.is_connected(_on_challenge_failed):
		_challenge_ui.challenge_failed.connect(_on_challenge_failed)
	if not _challenge_ui.hint_used.is_connected(_on_hint_used):
		_challenge_ui.hint_used.connect(_on_hint_used)
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
#  MODULE 1 — Python Syntax Mastery (Loops & Conditionals)
# ══════════════════════════════════════════════════════════════════════

func _play_module_1_python_basics(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 1: For Loops ─────────────────────────────
	_show_teaching_slide({
		"icon": "🔁",
		"title": "For Loops",
		"subtitle": "Repeat actions over collections",
		"bullets": [
			"A [b]for loop[/b] iterates over a collection",
			"[b]range(n)[/b] generates numbers from 0 to n-1",
			"Each pass through the loop is called an [b]iteration[/b]",
			"Loops eliminate repetitive code"
		],
		"code": "for i in range(5):\n    print(i)\n# Output: 0, 1, 2, 3, 4",
		"header": "MODULE 1 — PYTHON BASICS",
		"slide_num": "1 / 6",
		"reference": "Source: Python Crash Course (Matthes, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "You've written [color=#f0c674]Python[/color] before." },
			{ "name": "Professor Syntax", "text": "Let's see if you actually understood it." },
			{ "name": "Student", "text": "...that sounds like a trap." },
			{ "name": "Professor Syntax", "text": "It is." },
			{ "name": "Professor Syntax", "text": "What does a [color=#f0c674]for loop[/color] do?" },
			{ "name": "Student", "text": "It repeats something?" },
			{ "name": "Professor Syntax", "text": "Correct… but incomplete." },
			{ "name": "Professor Syntax", "text": "A [color=#f0c674]for loop[/color] iterates over a [color=#f0c674]collection[/color]. A list. A range. A string." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	# ─── Teaching Slide 2: Conditionals ──────────────────────────
	_show_teaching_slide({
		"icon": "🔀",
		"title": "Conditionals",
		"subtitle": "Making decisions in code",
		"bullets": [
			"[b]if[/b] checks a condition — runs code if True",
			"[b]elif[/b] checks another condition if the first was False",
			"[b]else[/b] runs when nothing matched",
			"Conditions use [b]comparison operators[/b]: ==, !=, <, >"
		],
		"code": "if score >= 90:\n    print('A')\nelif score >= 80:\n    print('B')\nelse:\n    print('C')",
		"header": "MODULE 1 — PYTHON BASICS",
		"slide_num": "2 / 6",
		"reference": "Source: Python Crash Course (Matthes, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "So like… going through a list?" },
			{ "name": "Professor Syntax", "text": "Exactly. And when you combine loops with [color=#f0c674]conditionals[/color]…" },
			{ "name": "Professor Syntax", "text": "You get decision-making inside repetition." },
			{ "name": "Professor Syntax", "text": "[color=#f0c674]if[/color], [color=#f0c674]elif[/color], [color=#f0c674]else[/color]. These are the building blocks of logic." },
			{ "name": "Professor Syntax", "text": "Without them, your code is a straight line. No branching. No intelligence." },
			{ "name": "Professor Syntax", "text": "Now prove you understand. Write a loop." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"syntax_loops", "Write a For Loop", "python", "loops.py",
		["# Write a for loop that prints 0 to 4", "# Use range() to generate the numbers"],
		["Write a for loop using range(5) that prints each number", "Why: Loops automate repetitive tasks, allowing you to process lists or run code multiple times instantly."],
		"Type your code here...",
		[
			"for i in range(5):\n    print(i)",
			"for i in range(5):\n\tprint(i)",
			"for i in range(5): print(i)"
		],
		"0\n1\n2\n3\n4",
		"SyntaxError: invalid syntax — check your for loop structure!",
		[
			"The syntax is: for variable in range(number):",
			"Don't forget the colon at the end! Then indent the next line.",
			"Type: for i in range(5):\\n    print(i)"
		]
	)
	
	ch_data["project_tree"] = {"loops.py": "file", "student.py": "file", "api_call.py": "file"}
	ui.load_challenge(ch_data)
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Write a [color=#f0c674]for loop[/color] that prints numbers 0 through 4." },
			{ "name": "Professor Syntax", "text": "Use [color=#f0c674]range(5)[/color] to generate the numbers." },
			{ "name": "Professor Syntax", "text": "Type: [color=#f0c674]for i in range(5):[/color] then on the next line: [color=#f0c674]print(i)[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Good. You understand [color=#f0c674]iteration[/color]." },
			{ "name": "Professor Syntax", "text": "Every list, every database query, every file — you'll loop through them." },
			{ "name": "Professor Syntax", "text": "Now we stop writing random code. We start [color=#f0c674]designing systems[/color]." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

	# ─── AI Minigame: Data Type Detective ─────────────────────────
	_show_teaching_slide({
		"icon": "📦",
		"title": "Data Types",
		"subtitle": "The building blocks of every variable",
		"bullets": [
			"[b]String[/b] — stores text (names, messages, addresses)",
			"[b]Integer[/b] — stores whole numbers (age, score, quantity)",
			"[b]Boolean[/b] — stores True/False (yes/no questions)",
			"[b]List[/b] — stores multiple items together (shopping list, student names)"
		],
		"code": "name = 'Alice'       # String\nage = 20             # Integer\nis_enrolled = True   # Boolean\ngrades = [90, 85]    # List",
		"header": "MODULE 1 — PYTHON BASICS",
		"slide_num": "★ AI GAME",
		"reference": "Source: Python Crash Course (Matthes, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Before we move on… let me test your intuition." },
			{ "name": "Professor Syntax", "text": "Python stores everything in [color=#f0c674]data types[/color]. Think of them as different kinds of boxes." },
			{ "name": "Professor Syntax", "text": "Here are two examples:" },
			{ "name": "Professor Syntax", "text": "[color=#f0c674]'My exact age'[/color] → That's a number. So it goes in an [color=#f0c674]Integer[/color] box." },
			{ "name": "Professor Syntax", "text": "[color=#f0c674]'My middle name'[/color] → That's text. It belongs in a [color=#f0c674]String[/color] box." },
			{ "name": "Professor Syntax", "text": "Now it's your turn. Give me [color=#f0c674]4 real-world things[/color] and tell me which box they belong in." },
			{ "name": "Professor Syntax", "text": "One for [color=#f0c674]String[/color], one for [color=#f0c674]Integer[/color], one for [color=#f0c674]Boolean[/color], and one for [color=#f0c674]List[/color]." },
			{ "name": "Professor Syntax", "text": "And no — you cannot use my examples." }
		])
		await dialogue_box.dialogue_finished

	await _transition_from_teaching_to_ide(skip_ide)

	if not skip_ide:
		ui = await _ensure_challenge_ui()
		var ai_data = _make_challenge(
			"syntax_ai_data_types", "Data Type Detective", "ai_evaluator", "brainstorming.txt",
			[
				"🎯 GOAL: Classify 4 real-world things into Python data types.",
				"",
				"📦 The 4 Data Types:",
				"  • String   — text (names, messages, addresses)",
				"  • Integer  — whole numbers (age, score, quantity)",
				"  • Boolean  — True or False (yes/no questions)",
				"  • List     — multiple items (shopping list, top 3 songs)",
				"",
				"✅ EXAMPLE (how your answer should look):",
				"  String:   My home address",
				"  Integer:  The number of pets I own",
				"  Boolean:  Did I eat breakfast today?",
				"  List:     My favorite movies",
				"",
				"🚫 BANNED (do NOT use these):",
				"  • 'My exact age' → Integer",
				"  • 'My middle name' → String",
				"",
				"📝 YOUR TURN — supply one for each type:",
				"  String:   # your answer",
				"  Integer:  # your answer",
				"  Boolean:  # your answer",
				"  List:     # your answer"
			],
			[
				"Classify 4 real-world things into: String, Integer, Boolean, List.",
				"One example per type. Cannot reuse the tutorial examples."
			],
			"Type your 4 real-world examples here...",
			[],
			"System is evaluating...",
			"Evaluation failed.",
			["Think of everyday things — what type of 'box' would they fit in?"]
		)
		ai_data["files"] = {"brainstorming.txt": ""}
		ai_data["active_file"] = "brainstorming.txt"
		ai_data["topic"] = "ai_evaluator"
		ai_data["challenge_type"] = "data_types"
		ai_data["project_tree"] = {"loops.py": "file", "student.py": "file", "brainstorming.txt": "file"}
		ai_data["instructions"] = ["data_types", "Classify 4 real-world things into Python data types: String, Integer, Boolean, List. Provide one example for each type."]

		ui.load_challenge(ai_data)
		_show_challenge_canvas()
		ui.lock_typing(false)
		await _await_challenge_done(ui)

		if dialogue_box:
			_show_dialogue_with_log(dialogue_box, [
				{ "name": "Professor Syntax", "text": "Good. You can see the types behind real-world data." },
				{ "name": "Professor Syntax", "text": "That instinct matters. Every variable you create in Django has a type." }
			])
			await dialogue_box.dialogue_finished
		await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 2 — Object-Oriented Programming (Classes & Objects)
# ══════════════════════════════════════════════════════════════════════

func _play_module_2_oop(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 3: Classes & Objects ──────────────────────
	_show_teaching_slide({
		"icon": "🏗️",
		"title": "Classes & Objects",
		"subtitle": "Blueprints for building systems",
		"bullets": [
			"A [b]class[/b] is a blueprint — a template for creating things",
			"An [b]object[/b] is an instance built from that blueprint",
			"Class = plan, Object = result",
			"[b]Django is built entirely on classes[/b]"
		],
		"code": "class Student:\n    def __init__(self, name):\n        self.name = name\n\nstudent1 = Student('Alice')",
		"header": "MODULE 2 — OOP",
		"slide_num": "3 / 6",
		"reference": "Source: Python Crash Course (Matthes, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Now we stop writing random code." },
			{ "name": "Professor Syntax", "text": "We start [color=#f0c674]designing systems[/color]." },
			{ "name": "Student", "text": "That sounds harder." },
			{ "name": "Professor Syntax", "text": "It is. But it [color=#f0c674]scales[/color]." },
			{ "name": "Professor Syntax", "text": "A [color=#f0c674]class[/color] is a blueprint." },
			{ "name": "Student", "text": "And an [color=#f0c674]object[/color]?" },
			{ "name": "Professor Syntax", "text": "The actual thing built from it." },
			{ "name": "Student", "text": "So like… [color=#f0c674]class[/color] = plan, [color=#f0c674]object[/color] = result?" },
			{ "name": "Professor Syntax", "text": "Yes." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 4: Methods & __init__ ────────────────────
	_show_teaching_slide({
		"icon": "⚙️",
		"title": "Methods & __init__",
		"subtitle": "Giving objects behavior and identity",
		"bullets": [
			"[b]__init__[/b] is the constructor — runs when an object is created",
			"[b]self[/b] refers to the current object instance",
			"[b]Methods[/b] are functions that belong to a class",
			"Every method's first parameter must be [b]self[/b]"
		],
		"code": "class Student:\n    def __init__(self, name, grade):\n        self.name = name\n        self.grade = grade\n    \n    def introduce(self):\n        print(f'I am {self.name}')",
		"header": "MODULE 2 — OOP",
		"slide_num": "4 / 6",
		"reference": "Source: Python Crash Course (Matthes, 2023)"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "When you create an object, Python calls [color=#f0c674]__init__[/color] automatically." },
			{ "name": "Professor Syntax", "text": "That's the [color=#f0c674]constructor[/color]. It sets up the object's initial state." },
			{ "name": "Professor Syntax", "text": "And [color=#f0c674]self[/color]? It refers to the specific object being created." },
			{ "name": "Student", "text": "Why do we always write self?" },
			{ "name": "Professor Syntax", "text": "Because every method needs to know which object it belongs to." },
			{ "name": "Professor Syntax", "text": "If you understand this… you understand how [color=#f0c674]large systems[/color] are built." },
			{ "name": "Professor Syntax", "text": "Now build one." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"syntax_oop", "Create a Class", "python", "student.py",
		["# Create a Student class with a constructor", "# The constructor should accept 'name' as a parameter"],
		["Define class Student with __init__(self, name) that stores self.name", "Why: Classes act as blueprints. They let you create objects that bundle data and behavior, which is how Django builds its structures."],
		"Type your code here...",
		[
			"class Student:\n    def __init__(self, name):\n        self.name = name",
			"class Student:\n\tdef __init__(self, name):\n\t\tself.name = name",
			"class Student:\n    def __init__(self,name):\n        self.name = name",
			"class Student:\n    def __init__(self, name):\n        self.name=name"
		],
		"✅ Class Student created with constructor!",
		"SyntaxError: invalid class definition — check your indentation and colons!",
		[
			"Start with: class Student:",
			"Inside the class, define: def __init__(self, name):",
			"Inside __init__, store: self.name = name"
		]
	)
	
	ch_data["project_tree"] = {"loops.py": "file", "student.py": "file", "api_call.py": "file"}
	ui.load_challenge(ch_data)
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Create a [color=#f0c674]class[/color] called [color=#f0c674]Student[/color]." },
			{ "name": "Professor Syntax", "text": "Give it an [color=#f0c674]__init__[/color] method that accepts [color=#f0c674]name[/color]." },
			{ "name": "Professor Syntax", "text": "Store it as [color=#f0c674]self.name[/color]. Three lines. No excuses." }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Good. You just defined a [color=#f0c674]blueprint[/color]." },
			{ "name": "Professor Syntax", "text": "Every [color=#f0c674]Django model[/color], every [color=#f0c674]view[/color], every form you'll write — they're all classes." },
			{ "name": "Professor Syntax", "text": "One more topic. The most practical one." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 3 — HTTP & Requests
# ══════════════════════════════════════════════════════════════════════

func _play_module_3_http_requests(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 5: HTTP & the Web ─────────────────────────
	_show_teaching_slide({
		"icon": "🌐",
		"title": "HTTP & the Web (Revisited)",
		"subtitle": "Now we talk to servers using Python",
		"bullets": [
			"You learned [b]HTTP[/b] in Semester 1 — now we use it",
			"[b]GET[/b] = request data from a server",
			"[b]POST[/b] = send data to a server",
			"Every [b]web app[/b] is just requests and responses"
		],
		"header": "MODULE 3 — HTTP & REQUESTS",
		"slide_num": "5 / 6",
		"reference": "Source: Official Python Documentation"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Last semester, you learned what [color=#f0c674]HTTP[/color] is." },
			{ "name": "Professor Syntax", "text": "This semester, you learn to [color=#f0c674]use it[/color]." },
			{ "name": "Professor Syntax", "text": "Every [color=#f0c674]web app[/color] is just [color=#f0c674]requests[/color] and [color=#f0c674]responses[/color]. Understand this." },
			{ "name": "Student", "text": "So we can talk to servers with Python?" },
			{ "name": "Professor Syntax", "text": "Exactly." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 6: The requests Library ───────────────────
	_show_teaching_slide({
		"icon": "📡",
		"title": "The requests Library",
		"subtitle": "Python's way of talking to the web",
		"bullets": [
			"[b]requests[/b] is a Python library for making HTTP calls",
			"[b]requests.get(url)[/b] sends a GET request",
			"The response has a [b]status_code[/b] (200 = success)",
			"And [b].text[/b] or [b].json()[/b] for the response body"
		],
		"code": "import requests\n\nresponse = requests.get('https://api.example.com/data')\nprint(response.status_code)  # 200\nprint(response.json())",
		"header": "MODULE 3 — HTTP & REQUESTS",
		"slide_num": "6 / 6",
		"reference": "Source: requests.readthedocs.io"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Python has a library called [color=#f0c674]requests[/color]. It does exactly what the name says." },
			{ "name": "Professor Syntax", "text": "[color=#f0c674]requests.get()[/color] sends a GET request to any URL." },
			{ "name": "Professor Syntax", "text": "The response comes back with a [color=#f0c674]status code[/color] — 200 means success." },
			{ "name": "Professor Syntax", "text": "You can read the data with [color=#f0c674].json()[/color] or [color=#f0c674].text[/color]." },
			{ "name": "Professor Syntax", "text": "Now write one." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"syntax_requests", "Make an HTTP Request", "python", "api_call.py",
		["import requests", "", "# Make a GET request to the URL below", "# URL: 'https://api.example.com/data'"],
		["Write a GET request using requests.get() with the given URL", "Why: Making HTTP requests allows your code to talk to APIs and other servers to retrieve live data over the web."],
		"Type your code here...",
		[
			"response = requests.get('https://api.example.com/data')",
			"response = requests.get(\"https://api.example.com/data\")",
			"response=requests.get('https://api.example.com/data')",
			"response=requests.get(\"https://api.example.com/data\")"
		],
		"200 OK — Data received successfully!",
		"ConnectionError: Could not reach the server — check your URL and method!",
		[
			"Use the requests library: requests.get(url)",
			"Store the result in a variable: response = requests.get('...')",
			"Type: response = requests.get('https://api.example.com/data')"
		]
	)
	
	ch_data["project_tree"] = {"loops.py": "file", "student.py": "file", "api_call.py": "file"}
	ui.load_challenge(ch_data)
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "Write a [color=#f0c674]GET request[/color] using the [color=#f0c674]requests[/color] library." },
			{ "name": "Professor Syntax", "text": "The URL is: [color=#f0c674]'https://api.example.com/data'[/color]" },
			{ "name": "Professor Syntax", "text": "Store the result in a variable called [color=#f0c674]response[/color]." }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Syntax", "text": "You just made your first [color=#f0c674]API call[/color] in Python." },
			{ "name": "Professor Syntax", "text": "This is how modern applications communicate. [color=#f0c674]APIs[/color] are everywhere." },
			{ "name": "Professor Syntax", "text": "And with that… the fundamentals are complete." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout


# ══════════════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════════════

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
	_teaching_canvas.layer = 5
	_teaching_canvas.name = "ProfSyntaxTeachingCanvas"
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

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var body_vbox = VBoxContainer.new()
	body_vbox.name = "BodyVBox"
	body_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(body_vbox)

	# ── Header bar ──
	var header_panel = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.12, 0.16, 0.28, 0.95)
	header_style.set_corner_radius_all(0)
	header_style.corner_radius_top_left = 14
	header_style.corner_radius_top_right = 14
	header_style.set_content_margin_all(8)
	header_panel.add_theme_stylebox_override("panel", header_style)
	body_vbox.add_child(header_panel)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	header_panel.add_child(header_hbox)

	var header_icon = Label.new()
	header_icon.name = "HeaderIcon"
	header_icon.text = "🐍"
	header_icon.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(header_icon)

	var header_title = Label.new()
	header_title.name = "HeaderTitle"
	header_title.text = "LECTURE SLIDE"
	header_title.add_theme_font_size_override("font_size", 13)
	header_title.add_theme_color_override("font_color", Color(0.50, 0.65, 0.90))
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_title)

	var slide_num = Label.new()
	slide_num.name = "SlideNum"
	slide_num.text = ""
	slide_num.add_theme_font_size_override("font_size", 12)
	slide_num.add_theme_color_override("font_color", Color(0.45, 0.55, 0.75, 0.7))
	header_hbox.add_child(slide_num)

	# ── Slide icon ──
	var icon_label = Label.new()
	icon_label.name = "SlideIcon"
	icon_label.text = "📖"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 40)
	body_vbox.add_child(icon_label)

	# ── Title ──
	var font_res = load("res://Textures/Fonts/Pixelify_Sans/static/PixelifySans-Regular.ttf")

	var title_label = Label.new()
	title_label.name = "SlideTitle"
	title_label.text = ""
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	if font_res:
		title_label.add_theme_font_override("font", font_res)
	body_vbox.add_child(title_label)

	# ── Subtitle ──
	var subtitle_label = Label.new()
	subtitle_label.name = "SlideSubtitle"
	subtitle_label.text = ""
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(0.55, 0.60, 0.75))
	subtitle_label.visible = false
	body_vbox.add_child(subtitle_label)

	# ── Spacer ──
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	body_vbox.add_child(spacer)

	# ── Bullets ──
	var bullets_rtl = RichTextLabel.new()
	bullets_rtl.name = "SlideBullets"
	bullets_rtl.bbcode_enabled = true
	bullets_rtl.fit_content = true
	bullets_rtl.scroll_active = false
	bullets_rtl.add_theme_font_size_override("normal_font_size", 15)
	bullets_rtl.add_theme_color_override("default_color", Color(0.80, 0.82, 0.90))
	bullets_rtl.visible = false
	body_vbox.add_child(bullets_rtl)

	# ── Code panel ──
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
	footer.text = "— Professor Syntax's Lecture —"
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
#   slide_num  : String                 — e.g. "1 / 6" shown in header

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
		header_icon.text = slide_data.get("header_icon", "🐍")

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
		var name_color = "#a3c4f3" if speaker == "Professor Syntax" else "#c8e6c9"
		if challenge_active and (
			text.find("\n") != -1
			or text.find("def ") != -1
			or text.find("return ") != -1
			or text.find("print(") != -1
			or text.find("=") != -1
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
func _on_slide_glossary_clicked(meta) -> void:
	var term = str(meta).strip_edges().to_lower()
	var popup = GLOSSARY_POPUP_SCENE.new()
	get_tree().root.add_child(popup)
	popup.show_definition(term)


# ─── Grade System Extensions ──────────────────────────────────────────

func _on_challenge_failed() -> void:
	_session_wrong_attempts += 1
	print("ProfSyntax: wrong_attempts = ", _session_wrong_attempts)

func _on_hint_used() -> void:
	_session_hints_used += 1
	print("ProfSyntax: hints_used = ", _session_hints_used)

func _evaluate_and_finalize_grade() -> String:
	if not character_data: return "pass"

	var GradeCalculator = load("res://Scripts/Autoload or Global/grade_calculator.gd")
	var raw = GradeCalculator.compute_grade(_session_wrong_attempts, _session_hints_used, deduction_wrong_attempt, deduction_hint_used)
	
	if is_learning_mode:
		character_data.update_learning_mode_grade("syntax", raw)
		await _autosave_progress()
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Syntax", "text": "Learning mode session complete. Grade is %s." % GradeCalculator.grade_to_label(raw) }
			])
			await dialogue_box.dialogue_finished
		return "learning"
	
	character_data.ch2_y1s2_wrong_attempts += _session_wrong_attempts
	character_data.ch2_y1s2_hints_used += _session_hints_used
	character_data.ch2_y1s2_final_grade = raw

	print("ProfSyntax Final Grade Computed: ", raw)

	dialogue_box = _get_dialogue_box()

	if GradeCalculator.is_passing(raw):
		var qm = get_node_or_null("/root/QuestManager")
		character_data.ch2_y1s2_teaching_done = true
		_dispatch_rewards()
		
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Syntax", "text": "You passed. Grade: " + GradeCalculator.grade_to_label(raw) + "." },
				{ "name": "Professor Syntax", "text": "You understand the foundations of Python, OOP, and HTTP." },
				{ "name": "Professor Syntax", "text": "Prepare yourself for Django. It won't be easy." }
			])
			await dialogue_box.dialogue_finished
		if qm:
			qm.show_quest()
			if qm.has_method("refresh_college_quest"):
				qm.refresh_college_quest()
		await _autosave_progress()
		return "pass"

	elif GradeCalculator.is_inc(raw):
		character_data.ch2_y1s2_inc_triggered = true
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Syntax", "text": "Your code works, but it's sloppy." },
				{ "name": "Professor Syntax", "text": "You accumulated too many errors and hints. You are receiving an INC (4.0)." },
				{ "name": "Professor Syntax", "text": "Take the removal exam now. Pass it, or fail completely." }
			])
			await dialogue_box.dialogue_finished
			
		var passed = await _launch_removal_exam()
		if passed:
			character_data.ch2_y1s2_removal_passed = true
			character_data.ch2_y1s2_final_grade = 3.0
			character_data.ch2_y1s2_teaching_done = true
			_dispatch_rewards()
			if dialogue_box:
				dialogue_box.start([
					{ "name": "Professor Syntax", "text": "You passed the removal exam. Grade updated to 3.0." },
					{ "name": "Professor Syntax", "text": "Barely acceptable, but you may proceed." }
				])
				await dialogue_box.dialogue_finished
			character_data.ch2_y1s2_teaching_done = true
			await _autosave_progress()
			return "inc_pass"
		else:
			character_data.ch2_y1s2_retake_count += 1
			character_data.ch2_y1s2_current_module = 0
			character_data.ch2_y1s2_final_grade = 5.0
			character_data.ch2_y1s2_removal_passed = false
			if dialogue_box:
				dialogue_box.start([
					{ "name": "Professor Syntax", "text": "You failed the removal exam." },
					{ "name": "Professor Syntax", "text": "You will retake this semester. Goodbye." }
				])
				await dialogue_box.dialogue_finished
			await _autosave_progress()
			return "inc_fail"

	else:
		character_data.ch2_y1s2_retake_count += 1
		character_data.ch2_y1s2_current_module = 0
		character_data.ch2_y1s2_final_grade = 5.0
		
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Syntax", "text": "A 5.0? Ridiculous." },
				{ "name": "Professor Syntax", "text": "Your errors reflect a lack of discipline." },
				{ "name": "Professor Syntax", "text": "You have failed Semester 2. You will have to retake these lessons." }
			])
			await dialogue_box.dialogue_finished
		await _autosave_progress()
		return "fail"

func _launch_removal_exam() -> bool:
	var canvas = CanvasLayer.new()
	canvas.layer = 75
	get_tree().current_scene.add_child(canvas)

	var quiz_instance = REMOVAL_QUIZ_SCENE.instantiate()
	quiz_instance.pass_score = removal_pass_score
	quiz_instance.quiz_count = 5
	
	quiz_instance.all_questions = [
		{
			"question": "Which construct allows repeating code a specific number of times?",
			"options": ["A) A map function", "B) An if statement", "C) A for loop", "D) A switch statement"],
			"correct": 2
		},
		{
			"question": "What is the primary keyword used to define a class in Python?",
			"options": ["A) def", "B) object", "C) class", "D) struct"],
			"correct": 2
		},
		{
			"question": "Which requests method is used to retrieve data from a server?",
			"options": ["A) requests.post()", "B) requests.get()", "C) requests.fetch()", "D) requests.read()"],
			"correct": 1
		},
		{
			"question": "Which Python data structure stores data in key-value pairs?",
			"options": ["A) List", "B) Tuple", "C) Dictionary", "D) Set"],
			"correct": 2
		},
		{
			"question": "What is the correct syntax for defining a function in Python?",
			"options": ["A) function my_func():", "B) void my_func():", "C) def my_func():", "D) create my_func():"],
			"correct": 2
		}
	]
	
	canvas.add_child(quiz_instance)
	var score = await quiz_instance.quiz_completed
	var passed = score >= removal_pass_score
	
	canvas.queue_free()
	return passed

func _dispatch_rewards():
	var retakes = character_data.ch2_y1s2_retake_count
	var credits_earned = 0
	if retakes == 0:
		credits_earned = reward_credits_retake_0
	elif retakes == 1:
		credits_earned = reward_credits_retake_1
	elif retakes == 2:
		credits_earned = reward_credits_retake_2
	elif retakes == 3:
		credits_earned = reward_credits_retake_3
	else:
		credits_earned = reward_credits_retake_4_plus
		
	if credits_earned > 0:
		character_data.add_credits(credits_earned)
		print("ProfSyntax: Dispatched ", credits_earned, " credits for retake count: ", retakes)
	else:
		print("ProfSyntax: No credits dispatched (retakes >= 3)")

func _autosave_progress():
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.save_game()

	if player:
		player.can_move = false
		player.block_ui_input = true
		player.set_physics_process(false)

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lbl = Label.new()
	lbl.text = "⏳ Syncing grades to DjangoQuest SIS..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 28)
	canvas.add_child(bg)
	canvas.add_child(lbl)
	get_tree().current_scene.add_child(canvas)

	await get_tree().create_timer(2.5).timeout

	if is_instance_valid(canvas):
		canvas.queue_free()

	if player:
		player.can_move = true
		player.block_ui_input = false
		player.set_physics_process(true)
