# learning_mode_controller.gd — Direct Learning Mode Controller
# Bypasses top-down game, goes straight to professor teaching content
# Shows intro explanation, then professor selection, then launches professor lessons
extends Control

const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialogue_box.tscn")
const PROFESSOR_SELECT_SCENE = preload("res://Scenes/UI/learning_professor_select.tscn")

@onready var character_data = get_node("/root/CharacterData")

var dialogue_box = null

func _ready():
	# Show intro explanation when learning mode starts
	_show_learning_intro()

func _show_learning_intro():
	if character_data and character_data.has_seen_learning_mode_intro:
		_show_professor_selection()
		return
		
	if character_data:
		character_data.has_seen_learning_mode_intro = true

	dialogue_box = _get_dialogue_box()
	
	var intro_lines = [
		{"name": "DjangoQuest", "text": "Welcome to [color=#f0c674]Learning Mode[/color]!"},
		{"name": "DjangoQuest", "text": "This is where you'll master web development through structured lessons."},
		{"name": "DjangoQuest", "text": "Each professor specializes in different areas:"},
		{"name": "DjangoQuest", "text": "[color=#f0c674]Professor Markup[/color] teaches HTML, CSS & web fundamentals"},
		{"name": "DjangoQuest", "text": "[color=#f0c674]Professor Syntax[/color] teaches Python programming & OOP"},
		{"name": "DjangoQuest", "text": "[color=#f0c674]Professor View[/color] teaches Django setup & views"},
		{"name": "DjangoQuest", "text": "[color=#f0c674]Professor Query[/color] teaches databases & ORM"},
		{"name": "DjangoQuest", "text": "[color=#f0c674]Professor Auth[/color] teaches authentication permissions"},
		{"name": "DjangoQuest", "text": "[color=#f0c674]Professor Token[/color] teaches Django forms & security"},
		{"name": "DjangoQuest", "text": "[color=#f0c674]Professor REST[/color] teaches JSON APIs & tokens"},
		{"name": "DjangoQuest", "text": "Each lesson includes teaching slides and hands-on coding challenges."},
		{"name": "DjangoQuest", "text": "Ready to start learning? Choose your professor!"}
	]
	
	if dialogue_box:
		dialogue_box.start(intro_lines)
		await dialogue_box.dialogue_finished
	
	# After intro, show professor selection
	_show_professor_selection()

func _show_professor_selection():
	var professor_select = PROFESSOR_SELECT_SCENE.instantiate()
	add_child(professor_select)
	
	# Connect signals from professor selection
	professor_select.professor_selected.connect(_on_professor_selected)
	professor_select.back_pressed.connect(_on_back_pressed)

func _on_professor_selected(professor_name: String):
	print("LearningModeController: Professor selected: ", professor_name)
	
	# Remove professor selection UI
	if has_node("LearningProfessorSelect"):
		get_node("LearningProfessorSelect").queue_free()
	
	# Launch the appropriate professor controller
	_launch_professor_lessons(professor_name)

func _on_back_pressed():
	# Return to main menu
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

func _launch_professor_lessons(professor_name: String):
	match professor_name:
		"markup":
			_launch_markup_lessons()
		"syntax":
			_launch_syntax_lessons()
		"view":
			_launch_view_lessons()
		"query":
			_launch_query_lessons()
		"auth":
			_launch_auth_lessons()
		"token":
			_launch_token_lessons()
		"rest":
			_launch_rest_lessons()
		_:
			print("LearningModeController: Unknown professor: ", professor_name)
			_show_professor_selection()  # Show selection again

func _launch_markup_lessons():
	# Create and configure Professor Markup controller
	const ProfMarkupController = preload("res://Scripts/Ch2/ch2_professor_markup_controller.gd")
	var controller = ProfMarkupController.new()
	controller.is_learning_mode = true
	add_child(controller)
	
	# Simulate professor interaction to start lessons
	controller._on_professor_interacted()

func _launch_syntax_lessons():
	# Create and configure Professor Syntax controller
	const ProfSyntaxController = preload("res://Scripts/Ch2/ch2_professor_syntax_controller.gd")
	var controller = ProfSyntaxController.new()
	controller.is_learning_mode = true
	add_child(controller)
	
	# Simulate professor interaction to start lessons
	controller._on_professor_interacted()

func _launch_view_lessons():
	# Create and configure Professor View controller
	const ProfViewController = preload("res://Scripts/Ch2/ch2_professor_view_controller.gd")
	var controller = ProfViewController.new()
	controller.is_learning_mode = true
	add_child(controller)
	
	# Simulate professor interaction to start lessons
	controller._on_professor_interacted()

func _launch_query_lessons():
	# Create and configure Professor Query controller
	const ProfQueryController = preload("res://Scripts/Ch2/ch2_professor_query_controller.gd")
	var controller = ProfQueryController.new()
	controller.is_learning_mode = true
	add_child(controller)
	
	# Simulate professor interaction to start lessons
	controller._on_professor_interacted()

func _launch_auth_lessons():
	const ProfAuthController = preload("res://Scripts/Ch2/ch2_professor_auth_controller.gd")
	var controller = ProfAuthController.new()
	controller.is_learning_mode = true
	add_child(controller)
	controller._on_professor_interacted()

func _launch_token_lessons():
	const ProfTokenController = preload("res://Scripts/Ch2/ch2_professor_token_controller.gd")
	var controller = ProfTokenController.new()
	controller.is_learning_mode = true
	add_child(controller)
	controller._on_professor_interacted()

func _launch_rest_lessons():
	const ProfRestController = preload("res://Scripts/Ch2/ch2_professor_rest_controller.gd")
	var controller = ProfRestController.new()
	controller.is_learning_mode = true
	add_child(controller)
	controller._on_professor_interacted()

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
