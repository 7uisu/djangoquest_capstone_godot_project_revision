# ch2_professor_query_controller.gd — Year 2 Semester 2 Professor Controller
# Manages the teach-code-teach-code flow for Professor Query (Models, ORM & Databases)
# Wired to NPCMaleCollegeProf03 via college_map_manager.gd
#
# Flow:
#   Player interacts with NPCMaleCollegeProf03 → gate check (Y1S1+Y1S2+Y2S1 required) →
#   lecture prompt → 4 modules of (Teaching slides + dialogue) then IDE coding
#   challenges → Mark ch2_y2s2_teaching_done = true
#
# Semester 2 Modules:
#   Module 1 — Models & Migrations
#   Module 2 — Django ORM (QuerySets)
#   Module 3 — Admin Panel
#   Module 4 — MVT Flow (Review)
extends Node

const CODING_UI_SCENE = preload("res://Scenes/Games/coding_challenge_ui.tscn")
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")

@onready var character_data = get_node("/root/CharacterData")

var player: Node2D = null
var professor_npc: Area2D = null
var dialogue_box = null

var _cutscene_running: bool = false
var _teaching_canvas: CanvasLayer = null
var _dialogue_log: Array = []
var _log_overlay: CanvasLayer = null

var _challenge_canvas: CanvasLayer = null
var _challenge_ui: Node = null
var _original_dialogue_layer: int = 10

# ── Interaction Handler ───────────────────────────────────────────────

func _on_professor_interacted():
	print("ProfQueryController: _on_professor_interacted() called!")
	if _cutscene_running:
		return
	
	# Find player
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	dialogue_box = _get_dialogue_box()
	
	# ── Gate: Must complete Y1S1, Y1S2, AND Y2S1 first ────────
	var has_markup = character_data and character_data.ch2_y1s1_teaching_done
	var has_syntax = character_data and character_data.ch2_y1s2_teaching_done
	var has_view = character_data and character_data.ch2_y2s1_teaching_done
	
	if not (has_markup and has_syntax and has_view):
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Query", "text": "You're not ready for my class yet." },
				{ "name": "Professor Query", "text": "You need to finish [color=#f0c674]Professor Markup[/color], [color=#f0c674]Professor Syntax[/color], and [color=#f0c674]Professor View[/color] first." },
				{ "name": "Professor Query", "text": "Come back when you've completed all three." }
			])
		return
	
	# ── Post-completion dialogue ──────────────────────────────────
	if character_data and character_data.ch2_y2s2_teaching_done:
		if dialogue_box:
			dialogue_box.start([
				{ "name": "Professor Query", "text": "You've completed all my lessons for this semester." },
				{ "name": "Professor Query", "text": "[color=#f0c674]Models[/color], [color=#f0c674]ORM[/color], [color=#f0c674]Admin Panel[/color], [color=#f0c674]MVT Flow[/color]. The database layer is yours." },
				{ "name": "Professor Query", "text": "Do not let your data corrupt. Move forward." }
			])
		return
	
	# ── Lecture prompt ────────────────────────────────────────────
	if dialogue_box:
		var current_mod = 0
		if character_data:
			current_mod = character_data.ch2_y2s2_current_module
		
		var mod_names = ["Models & Migrations", "Django ORM", "Admin Panel", "MVT Flow"]
		var mod_label = mod_names[current_mod] if current_mod < mod_names.size() else "the lesson"
		
		var lines = [{
			"name": "Professor Query",
			"text": "Ready for the lecture on " + mod_label + "?",
			"choices": ["Yes", "Not yet"]
		}]
		
		dialogue_box.choice_selected.connect(_on_lecture_choice, CONNECT_ONE_SHOT)
		dialogue_box.start(lines)

func _on_lecture_choice(choice_index: int):
	print("ProfQueryController: choice_index = ", choice_index)
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
		current_module = character_data.ch2_y2s2_current_module
	
	# ─── DEBUG SKIP IDE ────────────────────────────────────────────
	# @TODO: CHANGE THIS TO false WHEN DONE TESTING
	var DEBUG_SKIP_IDE = false
	# ─── END OF DEBUG SKIP IDE ────────────────────────────────────
	
	_challenge_canvas = null
	_challenge_ui = null
	
	# ─── Run modules from current progress ────────────────────────
	
	if current_module <= 0:
		await _play_module_1_models(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s2_current_module = 1
	
	if current_module <= 1:
		await _play_module_2_orm(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s2_current_module = 2
	
	if current_module <= 2:
		await _play_module_3_admin(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s2_current_module = 3
	
	if current_module <= 3:
		await _play_module_4_mvt(DEBUG_SKIP_IDE)
		if character_data:
			character_data.ch2_y2s2_current_module = 4
	
	# ─── All modules done ─────────────────────────────────────────
	
	if dialogue_box and dialogue_box is CanvasLayer and not DEBUG_SKIP_IDE:
		dialogue_box.layer = _original_dialogue_layer
	
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.queue_free()
	_challenge_canvas = null
	_challenge_ui = null
	
	await get_tree().create_timer(0.3).timeout
	
	# Completion dialogue
	dialogue_box = _get_dialogue_box()
	if dialogue_box:
		dialogue_box.start([
			{ "name": "Professor Query", "text": "Database migrations applied. Models normalized." },
			{ "name": "Professor Query", "text": "You now understand [color=#f0c674]models[/color], [color=#f0c674]ORM queries[/color], [color=#f0c674]admin registration[/color], and the [color=#f0c674]MVT flow[/color]." },
			{ "name": "Professor Query", "text": "These aren't just topics. They're the data backbone of every Django application." },
			{ "name": "Professor Query", "text": "Year 2 complete. Do not let your data corrupt." }
		])
		await dialogue_box.dialogue_finished
	
	# Mark complete
	if character_data:
		character_data.ch2_y2s2_teaching_done = true
	
	# Unfreeze player
	if player:
		player.can_move = true
		player.can_interact = true
		player.set_physics_process(true)
		player.block_ui_input = false
	
	_cutscene_running = false

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
	# Keep canvas hidden — it will be shown AFTER load_challenge() populates it
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.visible = false
	_hide_fullscreen_image()

func _show_challenge_canvas() -> void:
	if _challenge_canvas and is_instance_valid(_challenge_canvas):
		_challenge_canvas.visible = true

func _await_challenge_done(ui) -> void:
	while not ui.is_completed:
		await get_tree().create_timer(0.1).timeout
	while not ui.results_overlay.visible:
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(1.5).timeout
	ui.results_overlay.visible = false
	ui.lock_typing(true)

func _ensure_challenge_ui() -> Node:
	if _challenge_ui and is_instance_valid(_challenge_ui):
		dialogue_box = _get_dialogue_box()
		if dialogue_box and dialogue_box is CanvasLayer:
			_original_dialogue_layer = dialogue_box.layer if dialogue_box.layer != 60 else _original_dialogue_layer
			dialogue_box.layer = 60
		return _challenge_ui
	_challenge_canvas = CanvasLayer.new()
	_challenge_canvas.layer = 50
	_challenge_canvas.name = "ChallengeCanvasLayer"
	get_tree().current_scene.add_child(_challenge_canvas)
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
#  MODULE 1 — Models & Migrations
# ══════════════════════════════════════════════════════════════════════

func _play_module_1_models(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 1: What are Models ─────────────────────────
	_show_teaching_slide({
		"icon": "🗄️",
		"title": "Django Models",
		"subtitle": "Your database, defined in Python",
		"bullets": [
			"[b]Models[/b] define your database structure using Python classes.",
			"Each model class = One database table.",
			"Each class attribute = One database column.",
			"Django auto-generates SQL from your Models."
		],
		"code": "class Student(models.Model):\n    name = models.CharField(max_length=100)\n    grade = models.CharField(max_length=2)",
		"header": "MODULE 1 — MODELS & MIGRATIONS",
		"header_icon": "🗃️",
		"slide_num": "1 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Welcome. This semester, we deal with data." },
			{ "name": "Professor Query", "text": "Every application needs a way to store and organize information." },
			{ "name": "Student", "text": "So we write SQL?" },
			{ "name": "Professor Query", "text": "No. That's the old way." },
			{ "name": "Professor Query", "text": "In Django, we use [color=#f0c674]Models[/color] to define database tables using Python classes." },
			{ "name": "Professor Query", "text": "One class equals one table. Each attribute is a column. Clean and simple." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 2: Migrations ─────────────────────────
	_show_teaching_slide({
		"icon": "🔄",
		"title": "Migrations",
		"subtitle": "Version control for your database",
		"bullets": [
			"[b]python manage.py makemigrations[/b]",
			"→ Creates instructions for database changes.",
			"[b]python manage.py migrate[/b]",
			"→ Applies those instructions to the actual database."
		],
		"code": "python manage.py makemigrations\npython manage.py migrate",
		"header": "MODULE 1 — MODELS & MIGRATIONS",
		"header_icon": "🗃️",
		"slide_num": "2 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Writing the Python class isn't enough. You need to tell the database to actually create the table." },
			{ "name": "Student", "text": "How do we do that?" },
			{ "name": "Professor Query", "text": "Two commands. [color=#f0c674]makemigrations[/color] prepares the changes. [color=#f0c674]migrate[/color] applies them." },
			{ "name": "Professor Query", "text": "Think of migrations like version control for your database." },
			{ "name": "Professor Query", "text": "Now let's see if you can define a model field." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	# ─── Coding Challenge ─────────────────────────────────────────
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"query_model", "Define a Model Field", "python", "models.py",
		["from django.db import models", "", "class Student(models.Model):", "    # Define a name field using a CharField with max_length=100", "    "],
		["Define the 'name' field using models.CharField(max_length=100)"],
		"Type the field definition here...",
		[
			"name = models.CharField(max_length=100)",
			"name=models.CharField(max_length=100)"
		],
		"✅ Success! Table column 'name' defined.\n  Column type: VARCHAR(100)\n  Nullable: False",
		"Error: Invalid Field Definition. Did you use models.CharField?",
		[
			"You need to define the class variable: name",
			"Set it equal to models.CharField(max_length=100)"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Define the [color=#f0c674]name[/color] field for our Student model." },
			{ "name": "Professor Query", "text": "It should be a CharField that can hold up to 100 characters." },
			{ "name": "Professor Query", "text": "Type: [color=#f0c674]name = models.CharField(max_length=100)[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Good. That column can now hold up to 100 characters of text." },
			{ "name": "Professor Query", "text": "Now we need to learn how to actually [color=#f0c674]get data out[/color] of these tables." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 2 — Django ORM
# ══════════════════════════════════════════════════════════════════════

func _play_module_2_orm(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 3: ORM Basics ─────────────────────────
	_show_teaching_slide({
		"icon": "🤖",
		"title": "Django ORM",
		"subtitle": "Object Relational Mapper",
		"bullets": [
			"You don't write SQL. Django writes it for you.",
			"Django translates Python into optimized SQL queries.",
			"[b]Model.objects.all()[/b] → Retrieves every row.",
			"[b]Model.objects.get(id=1)[/b] → Retrieves one specific row."
		],
		"code": "# Get ALL students\nstudents = Student.objects.all()\n\n# Get ONE student by ID\nstudent = Student.objects.get(id=1)",
		"header": "MODULE 2 — THE ORM",
		"header_icon": "🔎",
		"slide_num": "3 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Storing data is only half the job. You also need to retrieve it." },
			{ "name": "Professor Query", "text": "Django has a built-in system called the [color=#f0c674]ORM[/color] for this." },
			{ "name": "Student", "text": "So we never write SQL at all?" },
			{ "name": "Professor Query", "text": "Correct. Django handles all the SQL behind the scenes." },
			{ "name": "Professor Query", "text": "Every model has a manager called [color=#f0c674]objects[/color]. That's how you access data." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 4: QuerySets ─────────────────────────
	_show_teaching_slide({
		"icon": "🔎",
		"title": "QuerySets & Filtering",
		"subtitle": "Precision data extraction",
		"bullets": [
			"[b]Model.objects.filter()[/b] returns a QuerySet.",
			"A QuerySet is a list of results matching a condition.",
			"You can chain filters for complex lookups.",
			"The database does the heavy lifting, not Python."
		],
		"code": "# Get students with grade 'A'\nhonor_roll = Student.objects.filter(grade='A')\n\n# Chain filters\nseniors = Student.objects.filter(grade='A', year=4)",
		"header": "MODULE 2 — THE ORM",
		"header_icon": "🔎",
		"slide_num": "4 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "What if I only need certain records?" },
			{ "name": "Professor Query", "text": "Then you use [color=#f0c674]filter[/color]." },
			{ "name": "Professor Query", "text": "It tells the database to only return the rows that match your condition." },
			{ "name": "Professor Query", "text": "Don't pull everything into Python and loop through it yourself. That's wasteful." },
			{ "name": "Professor Query", "text": "Let me see if you can write a filter query." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"query_orm", "Extract Specific Data", "python", "views.py",
		["from .models import Student", "", "def get_excellent_students():", "    # Use ORM to get all students whose grade is 'A'", "    return "],
		["Write: Student.objects.filter(grade='A')"],
		"Type the ORM query here...",
		[
			"Student.objects.filter(grade='A')",
			"Student.objects.filter(grade=\"A\")"
		],
		"✅ QuerySet generated successfully!\n  <QuerySet [<Student: Alice>, <Student: Bob>]>\n  2 records matched.",
		"Error: QuerySet invalid. Use the model's objects manager.",
		[
			"Call the default manager: Student.objects",
			"Use the filter method: .filter(grade='A')"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Get all students who earned an [color=#f0c674]A[/color] grade." },
			{ "name": "Professor Query", "text": "Type: [color=#f0c674]Student.objects.filter(grade='A')[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Good. The database filtered the records for you." },
			{ "name": "Professor Query", "text": "Python just received the results. That's the right way to do it." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 3 — Admin Panel
# ══════════════════════════════════════════════════════════════════════

func _play_module_3_admin(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 5: Admin Overview ─────────────────────────
	_show_teaching_slide({
		"icon": "🔑",
		"title": "Django Admin",
		"subtitle": "A free, built-in CMS",
		"bullets": [
			"Django comes with a fully-featured admin GUI out of the box.",
			"You do NOT have to build CRUD interfaces for your staff.",
			"Access it at [b]/admin/[/b] after creating a superuser.",
			"Models are hidden by default — you must [b]register[/b] them."
		],
		"header": "MODULE 3 — ADMIN PANEL",
		"header_icon": "🛠️",
		"slide_num": "5 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "The data is in the database now. But how do I actually see it?" },
			{ "name": "Professor Query", "text": "Django gives you a built-in [color=#f0c674]admin panel[/color]." },
			{ "name": "Professor Query", "text": "It's a full management interface. You get it for free just by using Django." },
			{ "name": "Student", "text": "So my models just show up there?" },
			{ "name": "Professor Query", "text": "Not automatically. You have to [color=#f0c674]register[/color] them first." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 6: Registering Models ─────────────────────
	_show_teaching_slide({
		"icon": "📝",
		"title": "Registering Models",
		"subtitle": "Connecting to the Admin Site",
		"bullets": [
			"Edit [b]admin.py[/b] inside your app folder.",
			"Import your model from [b]models.py[/b].",
			"Use [b]admin.site.register(ModelName)[/b].",
			"The model will now appear in your Admin dashboard."
		],
		"code": "# admin.py\nfrom django.contrib import admin\nfrom .models import Student\n\nadmin.site.register(Student)",
		"header": "MODULE 3 — ADMIN PANEL",
		"header_icon": "🛠️",
		"slide_num": "6 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "To make a model visible in the admin, you edit [color=#f0c674]admin.py[/color]." },
			{ "name": "Professor Query", "text": "Import your model and register it. One line of code." },
			{ "name": "Professor Query", "text": "Go ahead and register the Student model." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"query_admin", "Register to Admin", "python", "admin.py",
		["from django.contrib import admin", "from .models import Student", "", "# Register the Student model below:", ""],
		["Type admin.site.register(Student)"],
		"Type the admin register command...",
		[
			"admin.site.register(Student)"
		],
		"✅ Success! Student Model registered.\n  Admin panel: /admin/blog/student/\n  Actions: Add, Change, Delete, View",
		"Error: Not registered correctly. Did you use admin.site.register?",
		[
			"Invoke the admin site registration: admin.site.register()",
			"Pass 'Student' into it: admin.site.register(Student)"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Register the Student model to the admin panel." },
			{ "name": "Professor Query", "text": "Type: [color=#f0c674]admin.site.register(Student)[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Done. Your staff can now manage Student records through the browser." },
			{ "name": "Professor Query", "text": "One line of code gave you an entire admin dashboard. That's Django." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout

# ══════════════════════════════════════════════════════════════════════
#  MODULE 4 — MVT Flow Review
# ══════════════════════════════════════════════════════════════════════

func _play_module_4_mvt(skip_ide: bool):
	dialogue_box = _get_dialogue_box()
	_before_teaching_slides()
	
	# ─── Teaching Slide 7: MVT Triangle ─────────────────────────
	_show_teaching_slide({
		"icon": "🔄",
		"title": "MVT Convergence",
		"subtitle": "Model → View → Template",
		"bullets": [
			"[b]Model[/b]: Defines and queries the database.",
			"[b]View[/b]: Fetches data from Models, processes logic.",
			"[b]Template[/b]: Receives context from View, renders HTML.",
			"They form the structural triangle of every Django app."
		],
		"header": "MODULE 4 — MVT FLOW",
		"header_icon": "🔁",
		"slide_num": "7 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Student", "text": "So MVT means Model, View, Template?" },
			{ "name": "Professor Query", "text": "Yes. The View sits in the middle. It pulls data from the Model and sends it to the Template." },
			{ "name": "Professor Query", "text": "Without the View passing data, the Template has nothing to show." },
			{ "name": "Student", "text": "So the View connects everything?" },
			{ "name": "Professor Query", "text": "Exactly. It's the glue that holds the whole system together." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.2).timeout
	
	# ─── Teaching Slide 8: The View Bridge ─────────────────────────
	_show_teaching_slide({
		"icon": "🌉",
		"title": "The View Bridge",
		"subtitle": "Extracting and packing context",
		"bullets": [
			"1. Retrieve data: [b]data = Model.objects.all()[/b]",
			"2. Pack context: [b]context = {'items': data}[/b]",
			"3. Pass to render: [b]return render(request, 'page.html', context)[/b]"
		],
		"code": "def student_list(request):\n    students = Student.objects.all()\n    return render(request, 'list.html', {'students': students})",
		"header": "MODULE 4 — MVT FLOW",
		"header_icon": "🔁",
		"slide_num": "8 / 8"
	})
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Time for the final exercise." },
			{ "name": "Professor Query", "text": "Pull every student record from the database and pass it to the template." },
			{ "name": "Professor Query", "text": "This brings together everything you learned this semester." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout
	
	await _transition_from_teaching_to_ide(skip_ide)
	
	if skip_ide:
		return
	
	var ui = await _ensure_challenge_ui()
	var ch_data = _make_challenge(
		"query_mvt", "Complete the View", "python", "views.py",
		["from django.shortcuts import render", "from .models import Student", "", "def list_students(request):", "    # Retrieve ALL student records to pass to the template", "    students = ", "", "    return render(request, 'list.html', {'students': students})"],
		["Use ORM to extract all records using objects.all()"],
		"Type the extraction query here...",
		[
			"Student.objects.all()"
		],
		"✅ Correct! The View successfully bridges the Database and the Template.\n  Context: {'students': <QuerySet [...]>}\n  Template: list.html",
		"Error: Could not retrieve records. Use objects.all()",
		[
			"Use the Student model provided.",
			"Call: Student.objects.all()"
		]
	)
	
	ui.load_challenge(ch_data)
	_show_challenge_canvas()
	ui.lock_typing(true)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Retrieve all student records from the database." },
			{ "name": "Professor Query", "text": "Type: [color=#f0c674]Student.objects.all()[/color]" }
		])
		await dialogue_box.dialogue_finished
	
	ui.lock_typing(false)
	
	await _await_challenge_done(ui)
	
	if dialogue_box:
		_show_dialogue_with_log(dialogue_box, [
			{ "name": "Professor Query", "text": "Well done." },
			{ "name": "Professor Query", "text": "Model feeds the View. View feeds the Template. That's how Django works." },
			{ "name": "Professor Query", "text": "You've finished everything I have to teach you this semester." },
			{ "name": "Professor Query", "text": "Next up is [color=#f0c674]Year 3[/color]. Forms and security. Good luck." }
		])
		await dialogue_box.dialogue_finished
	await get_tree().create_timer(0.3).timeout


# ══════════════════════════════════════════════════════════════════════
#  HELPERS — Identical to Professor Syntax / Markup pattern
# ══════════════════════════════════════════════════════════════════════

func _make_challenge(id: String, title: String, topic: String, file_name: String,
	code_lines: Array, mission_steps: Array, placeholder: String,
	expected_answers: Array, correct_output: String, error_output: String,
	progressive_hints: Array = []) -> Dictionary:
	
	var base_hint = progressive_hints[0] if progressive_hints.size() > 0 else "Read the professor's instructions carefully."
	var exact_answer = expected_answers[0] if expected_answers.size() > 0 else ""
	var final_hint = base_hint + "\n\n[color=#5c6370]If you're really stuck, here's the exact code:[/color]\n[color=#98c379]" + exact_answer + "[/color]"

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
		"hint": final_hint,
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
	_teaching_canvas.name = "ProfQueryTeachingCanvas"
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

	var outer_vbox = VBoxContainer.new()
	outer_vbox.name = "OuterVBox"
	outer_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(outer_vbox)

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

	var slide_icon = Label.new()
	slide_icon.name = "SlideIcon"
	slide_icon.text = "📖"
	slide_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slide_icon.add_theme_font_size_override("font_size", 44)
	body_vbox.add_child(slide_icon)

	var title_label = Label.new()
	title_label.name = "SlideTitle"
	title_label.text = ""
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	if custom_font:
		title_label.add_theme_font_override("font", custom_font)
	body_vbox.add_child(title_label)

	var subtitle = Label.new()
	subtitle.name = "SlideSubtitle"
	subtitle.text = ""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.70, 0.82))
	body_vbox.add_child(subtitle)

	var bullets = RichTextLabel.new()
	bullets.name = "SlideBullets"
	bullets.bbcode_enabled = true
	bullets.fit_content = true
	bullets.scroll_active = false
	bullets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bullets.add_theme_font_size_override("normal_font_size", 17)
	bullets.add_theme_color_override("default_color", Color(0.82, 0.85, 0.95))
	body_vbox.add_child(bullets)

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

	var text_label = Label.new()
	text_label.name = "Text"
	text_label.visible = false
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	body_vbox.add_child(text_label)

	var footer = Label.new()
	footer.name = "Footer"
	footer.text = "— Professor Query's Lecture —"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.40, 0.45, 0.58, 0.6))
	body_vbox.add_child(footer)

	return center

func _show_teaching_slide(slide_data: Dictionary) -> void:
	_ensure_teaching_canvas()
	var img_rect = _teaching_canvas.get_node_or_null("TextureRect")
	if img_rect:
		img_rect.visible = false

	var placeholder = _teaching_canvas.get_node_or_null("PlaceholderPanel")
	if not placeholder:
		placeholder = _create_placeholder_panel()
		_teaching_canvas.add_child(placeholder)

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
				bb += "[color=#7dacf0]  ●[/color]  " + b + "\n"
			bullets_rtl.text = bb.strip_edges()
			bullets_rtl.visible = true
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

	var legacy = placeholder.find_child("Text", true, false)
	if legacy is Label:
		legacy.visible = false

	placeholder.visible = true
	_teaching_canvas.visible = true
	
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
	panel.custom_minimum_size = Vector2(600, 400)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.5, 0.8, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	_log_overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)

	var title = Label.new()
	title.text = "Conversation Log"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(60, 24)
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

	for entry in _dialogue_log:
		var name_str = entry.get("name", "Unknown")
		var text_str = entry.get("text", "")
		
		var entry_vbox = VBoxContainer.new()
		entry_vbox.add_theme_constant_override("separation", 0)
		
		var name_lbl = Label.new()
		name_lbl.text = name_str
		name_lbl.add_theme_font_size_override("font_size", 12)
		if name_str == "Student" or name_str == "You":
			name_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		else:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		
		var text_lbl = RichTextLabel.new()
		text_lbl.bbcode_enabled = true
		text_lbl.text = "[color=#cccccc]" + text_str + "[/color]"
		text_lbl.fit_content = true
		text_lbl.scroll_active = false
		text_lbl.add_theme_font_size_override("normal_font_size", 14)
		text_lbl.custom_minimum_size = Vector2(500, 0)
		
		entry_vbox.add_child(name_lbl)
		entry_vbox.add_child(text_lbl)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		entry_vbox.add_child(spacer)
		
		log_content.add_child(entry_vbox)

	await get_tree().process_frame
	var scroll = _log_overlay.get_node_or_null("LogPanel/VBox/LogScroll")
	if scroll:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
