extends CanvasLayer

@export var reference_manual_rules: Array[Dictionary] = [{"id": "REV-01", "title": "Check ownership before trusting an ID", "badge": "SECURITY", "description": "A URL supplied student ID is not proof that the signed-in user owns the requested record.", "bad_code": "StudentEnrollment.objects.filter(student_id=student_id).first()", "good_code": "StudentEnrollment.objects.filter(student_id=student_id, student__user=request.user).first()"}]

signal review_submitted(success: bool, line_index: int)
signal closed

@export var file_path_title: String = "student_portal/views.py"
@export var raw_diff_lines: PackedStringArray = [
	"@@ enrollment view @@",
	"enrollment = StudentEnrollment.objects.filter(student_id=student_id).first()",
	"enrolled_date = enrollment.enrolled_at if enrollment else None",
	"return Response({\"enrolled_at\": enrolled_date})"
]
@export var target_bug_line_index: int = 1
@export_multiline var bug_explanation_hint: String = "The query trusts a student_id supplied by the request without checking that the authenticated user owns that record."
@export var success_action_label: String = "Submit Review"

var selected_line_index := -1
var flagged_lines: Dictionary = {}
var reviewed_lines: Dictionary = {}
var line_buttons: Array[Button] = []

@onready var screen: Control = $Screen
@onready var file_title: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/FileTitle
@onready var line_list: VBoxContainer = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Body/LineScroll/LineList
@onready var line_info: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Body/Side/LineInfo
@onready var annotation: RichTextLabel = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Body/Side/Annotation
@onready var annotation_popup: PopupPanel = $Screen/AnnotationPopup
@onready var popup_annotation_label: RichTextLabel = $Screen/AnnotationPopup/PopupMargin/PopupBox/PopupAnnotationLabel
@onready var result_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ResultLabel
@onready var flag_button: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Body/Side/FlagButton
@onready var reviewed_button: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/Body/Side/ReviewedButton
@onready var submit_button: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/SubmitButton


func _ready() -> void:
	var manual: ReferenceManualDockPrototype = $Screen/ManualDockHost/ReferenceManualDockPrototype
	manual.load_ruleset(manual.manual_title, reference_manual_rules)
	$Screen/CenterContainer/Window/WindowMargin/MainVBox/Header/ReferenceButton.pressed.connect(manual.toggle_manual)
	file_title.text = file_path_title
	flag_button.pressed.connect(_flag_selected)
	reviewed_button.pressed.connect(_mark_reviewed)
	submit_button.pressed.connect(_submit_review)
	$Screen/CenterContainer/Window/WindowMargin/MainVBox/Header/CloseButton.pressed.connect(_on_close_pressed)
	$Screen/AnnotationPopup/PopupMargin/PopupBox/DismissPopup.pressed.connect(annotation_popup.hide)
	submit_button.text = success_action_label
	_render_lines()


func _render_lines() -> void:
	for child in line_list.get_children():
		child.queue_free()
	line_buttons.clear()
	for i in range(raw_diff_lines.size()):
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%04d  %s" % [i + 1, raw_diff_lines[i]]
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color("#c9d1d9"))
		button.add_theme_stylebox_override("normal", _panel_style("#161b22", "#30363d", 2))
		button.add_theme_stylebox_override("hover", _panel_style("#21262d", "#58a6ff", 2))
		button.pressed.connect(_select_line.bind(i))
		line_list.add_child(button)
		line_buttons.append(button)
		_update_line_color(i)


func _select_line(index: int) -> void:
	selected_line_index = index
	line_info.text = "Line %d\n%s" % [index + 1, raw_diff_lines[index]]
	annotation.text = "Inspect this line. Flag suspicious code or mark it reviewed."
	popup_annotation_label.text = "[b]Line %d[/b]\n%s\n\nInspect the code, then choose Flag as Bug or Mark Reviewed." % [index + 1, raw_diff_lines[index]]
	annotation_popup.popup_centered(Vector2i(420, 190))
	_update_line_color(index)


func _flag_selected() -> void:
	if selected_line_index < 0:
		return
	flagged_lines[selected_line_index] = true
	reviewed_lines.erase(selected_line_index)
	annotation.text = "[b]Review annotation[/b]\n" + bug_explanation_hint
	_update_line_color(selected_line_index)


func _mark_reviewed() -> void:
	if selected_line_index < 0:
		return
	reviewed_lines[selected_line_index] = true
	flagged_lines.erase(selected_line_index)
	annotation.text = "Line %d marked reviewed." % (selected_line_index + 1)
	_update_line_color(selected_line_index)


func _update_line_color(index: int) -> void:
	if index < 0 or index >= line_buttons.size():
		return
	var color := "#161b22"
	if flagged_lines.has(index):
		color = "#5b252b"
	elif reviewed_lines.has(index):
		color = "#173b2b"
	elif index == selected_line_index:
		color = "#1f3a5a"
	line_buttons[index].add_theme_stylebox_override("normal", _panel_style(color, "#30363d", 2))


func _submit_review() -> void:
	var success := flagged_lines.has(target_bug_line_index)
	result_label.text = "Correct: the unsafe line is flagged." if success else "Review incomplete. Inspect the diff and flag the line that causes the security issue."
	result_label.add_theme_color_override("font_color", Color("#7ee787") if success else Color("#ff7b72"))
	review_submitted.emit(success, target_bug_line_index if success else selected_line_index)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _panel_style(background: String, border: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style




