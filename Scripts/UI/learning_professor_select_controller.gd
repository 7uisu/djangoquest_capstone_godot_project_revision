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

var sis_panel: Panel
var sis_label: RichTextLabel

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
	
	# ─── Programmatically Add SIS UI ─────────────────────────────
	var sis_btn = Button.new()
	sis_btn.text = "View SIS Grades"
	var btn_container = $CenterContainer/VBoxContainer/ButtonContainer
	if btn_container:
		btn_container.add_child(sis_btn)
	sis_btn.pressed.connect(_on_sis_pressed)
	
	sis_panel = Panel.new()
	sis_panel.visible = false
	sis_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sis_panel.custom_minimum_size = Vector2(600, 450)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.5, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	sis_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 30)
	vbox.add_theme_constant_override("margin_right", 30)
	vbox.add_theme_constant_override("margin_top", 30)
	vbox.add_theme_constant_override("margin_bottom", 30)
	sis_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Django SIS - Learning Mode Transcript"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	sis_label = RichTextLabel.new()
	sis_label.bbcode_enabled = true
	sis_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sis_label)
	
	var close_btn = Button.new()
	close_btn.text = "Close Transcript"
	close_btn.pressed.connect(func(): sis_panel.visible = false)
	vbox.add_child(close_btn)
	
	add_child(sis_panel)

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

# ─── SIS LOGIC ──────────────────────────────────────────────────
func _on_sis_pressed():
	sis_panel.visible = true
	_update_sis_display()

func _update_sis_display():
	if not character_data:
		sis_label.text = "No character data found."
		return
		
	var grades = character_data.learning_mode_grades
	if grades.is_empty():
		sis_label.text = "\n[center][color=#a0a0a0]No Professor modules completed in Learning Mode yet.[/color][/center]"
		return
		
	var text = "\n[center][table=2]\n"
	text += "[cell][b]Professor / Module[/b]          [/cell][cell][b]Highest Grade[/b][/cell]\n"
	
	var total = 0.0
	var count = 0
	
	var name_map = {
		"markup": "Prof. Markup (HTML/CSS)",
		"syntax": "Prof. Syntax (Python OOP)",
		"view": "Prof. View (Django Views)",
		"query": "Prof. Query (DB Models)",
		"auth": "Prof. Auth (Security)",
		"token": "Prof. Token (Forms)",
		"rest": "Prof. REST (JSON API)"
	}
	
	for prof_id in grades:
		var raw = grades[prof_id]
		total += raw
		count += 1
		var prof_name = name_map[prof_id] if name_map.has(prof_id) else prof_id
		
		var grade_class = _get_grade_class(raw)
		text += "[cell]%s[/cell][cell][color=%s]%.1f[/color] ([color=%s]%s[/color])[/cell]\n" % [prof_name, grade_class[1], raw, grade_class[1], grade_class[0]]
		
	text += "[/table][/center]\n\n"
	
	var gwa = total / float(count)
	var gwa_class = _get_grade_class(gwa)
	text += "[center][b]Overall Learning Mode GWA:[/b] [color=%s]%.2f[/color][/center]" % [gwa_class[1], gwa]
	
	sis_label.text = text

func _get_grade_class(raw: float) -> Array:
	if raw <= 1.25: return ["Excellent", "#4ade80"]
	if raw <= 1.75: return ["Very Good", "#a3e635"]
	if raw <= 2.25: return ["Good", "#facc15"]
	if raw <= 2.75: return ["Satisfactory", "#fb923c"]
	if raw <= 3.00: return ["Passing", "#f87171"]
	if raw <= 4.00: return ["Incomplete", "#a78bfa"]
	return ["Failed", "#ef4444"]

