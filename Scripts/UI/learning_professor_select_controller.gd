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

var sis_overlay: Control
var sis_panel: PanelContainer
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
	
	sis_overlay = Control.new()
	sis_overlay.visible = false
	sis_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sis_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dimmer = ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.58)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sis_overlay.add_child(dimmer)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sis_overlay.add_child(center)

	sis_panel = PanelContainer.new()
	sis_panel.custom_minimum_size = Vector2(640, 460)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.095, 0.135, 0.98)
	style.border_color = Color(0.28, 0.38, 0.55, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	sis_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	sis_panel.add_child(vbox)
	
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	var title = Label.new()
	title.text = "Learning Mode Transcript"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	title_box.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Best grades recorded from professor practice sessions"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.64, 0.74))
	title_box.add_child(subtitle)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(86, 34)
	close_btn.pressed.connect(func(): sis_overlay.visible = false)
	header.add_child(close_btn)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	sis_label = RichTextLabel.new()
	sis_label.bbcode_enabled = true
	sis_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sis_label.fit_content = false
	sis_label.scroll_active = true
	sis_label.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(sis_label)

	center.add_child(sis_panel)
	add_child(sis_overlay)

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
	sis_overlay.visible = true
	_update_sis_display()

func _update_sis_display():
	if not character_data:
		sis_label.text = "No character data found."
		return
		
	var grades = character_data.learning_mode_grades
	if grades.is_empty():
		sis_label.text = "\n\n[center][color=#9aa4b8]No professor modules completed in Learning Mode yet.[/color]\n[color=#657086]Finish a practice professor to record your best grade here.[/color][/center]"
		return
		
	var text = "[color=#6b7890]PROFESSOR RECORDS[/color]\n\n"
	text += "[table=3]\n"
	text += "[cell][color=#8fa2c2][b]Module[/b][/color][/cell]"
	text += "[cell][color=#8fa2c2][b]Best Grade[/b][/color][/cell]"
	text += "[cell][color=#8fa2c2][b]Standing[/b][/color][/cell]\n"
	
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
		text += "[cell][color=#e7ecf7]%s[/color][/cell]" % prof_name
		text += "[cell][color=%s][b]%.2f[/b][/color][/cell]" % [grade_class[1], raw]
		text += "[cell][color=%s]%s[/color][/cell]\n" % [grade_class[1], grade_class[0]]
		
	text += "[/table]\n\n"
	
	var gwa = total / float(count)
	var gwa_class = _get_grade_class(gwa)
	text += "[center][color=#8fa2c2]OVERALL LEARNING MODE GWA[/color]\n"
	text += "[font_size=30][color=%s][b]%.2f[/b][/color][/font_size]\n" % [gwa_class[1], gwa]
	text += "[color=%s]%s[/color][/center]" % [gwa_class[1], gwa_class[0]]
	
	sis_label.text = text

func _get_grade_class(raw: float) -> Array:
	if raw <= 1.25: return ["Excellent", "#4ade80"]
	if raw <= 1.75: return ["Very Good", "#a3e635"]
	if raw <= 2.25: return ["Good", "#facc15"]
	if raw <= 2.75: return ["Satisfactory", "#fb923c"]
	if raw <= 3.00: return ["Passing", "#f87171"]
	if raw <= 4.00: return ["Incomplete", "#a78bfa"]
	return ["Failed", "#ef4444"]
