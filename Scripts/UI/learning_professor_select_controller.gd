# learning_professor_select_controller.gd — Professor Selection UI Controller
# Manages the professor selection interface for learning mode
extends Control

signal professor_selected(professor_name: String)
signal back_pressed

@onready var markup_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/MarkupButton
@onready var syntax_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/SyntaxButton
@onready var view_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/ViewButton
@onready var query_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/QueryButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/ButtonContainer/BackButton

@onready var character_data = get_node("/root/CharacterData")

func _ready():
	# Connect button signals
	markup_button.pressed.connect(_on_markup_pressed)
	syntax_button.pressed.connect(_on_syntax_pressed)
	view_button.pressed.connect(_on_view_pressed)
	query_button.pressed.connect(_on_query_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Update button states based on progress
	_update_button_states()

func _update_button_states():
	# Disable buttons for professors that haven't unlocked prerequisites
	if character_data:
	# Professor Syntax requires Professor Markup completion
		if not character_data.ch2_y1s1_teaching_done:
			syntax_button.disabled = true
			syntax_button.text = "Professor Syntax\nPython & OOP\n\n(Complete Professor Markup first)"
		
		# Professor View requires both Year 1 completion
		if not (character_data.ch2_y1s1_teaching_done and character_data.ch2_y1s2_teaching_done):
			view_button.disabled = true
			view_button.text = "Professor View\nDjango Setup\n\n(Complete Year 1 first)"
		
		# Professor Query requires Year 1 + Year 2 Semester 1
		if not (character_data.ch2_y1s1_teaching_done and character_data.ch2_y1s2_teaching_done and character_data.ch2_y2s1_teaching_done):
			query_button.disabled = true
			query_button.text = "Professor Query\nDatabases\n\n(Complete previous semesters first)"

func _on_markup_pressed():
	professor_selected.emit("markup")

func _on_syntax_pressed():
	if not syntax_button.disabled:
		professor_selected.emit("syntax")

func _on_view_pressed():
	if not view_button.disabled:
		professor_selected.emit("view")

func _on_query_pressed():
	if not query_button.disabled:
		professor_selected.emit("query")

func _on_back_pressed():
	back_pressed.emit()
