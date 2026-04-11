# learning_professor_select_controller.gd — Professor Selection UI Controller
# Manages the professor selection interface for learning mode
extends Control

signal professor_selected(professor_name: String)
signal back_pressed

@onready var markup_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/MarkupButton
@onready var syntax_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/SyntaxButton
@onready var view_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/ViewButton
@onready var query_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/QueryButton
@onready var auth_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/AuthButton
@onready var token_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/TokenButton
@onready var rest_button: Button = $CenterContainer/VBoxContainer/ProfessorGrid/RESTButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/ButtonContainer/BackButton

@onready var character_data = get_node("/root/CharacterData")

func _ready():
	# Connect button signals
	markup_button.pressed.connect(_on_markup_pressed)
	syntax_button.pressed.connect(_on_syntax_pressed)
	view_button.pressed.connect(_on_view_pressed)
	query_button.pressed.connect(_on_query_pressed)
	auth_button.pressed.connect(_on_auth_pressed)
	token_button.pressed.connect(_on_token_pressed)
	rest_button.pressed.connect(_on_rest_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Update button states based on progress
	_update_button_states()

func _update_button_states():
	# For now, make all buttons unlocked already as requested by the user
	pass

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

func _on_auth_pressed():
	if not auth_button.disabled:
		professor_selected.emit("auth")

func _on_token_pressed():
	if not token_button.disabled:
		professor_selected.emit("token")

func _on_rest_pressed():
	if not rest_button.disabled:
		professor_selected.emit("rest")

func _on_back_pressed():
	back_pressed.emit()
