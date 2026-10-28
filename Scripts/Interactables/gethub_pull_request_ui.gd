extends CanvasLayer

signal pr_reviewed(approved: bool, pr_number: int, comment: String)
signal closed

@export var pr_number: int = 42
@export var pr_title: String = "feat(enrollment): Add student enrollment tracking timestamp"
@export var author_name: String = "You"
@export var author_role: String = "Junior Developer"
@export var branch_target: String = "main ← feature/student-enrollment"
@export_multiline var description: String = "Adds enrolled_at timestamp field to track student onboarding time. Staging pipeline tests passed."
@export var checklist: PackedStringArray = ["[x] Unit tests pass in CI pipeline", "[x] Staging API smoke tests pass", "[ ] Database migrations included in release runbook: python manage.py migrate"]
@export_multiline var diff_content: String = "diff --git a/student_portal/models.py b/student_portal/models.py\n@@ StudentEnrollment model @@\n+class StudentEnrollment(models.Model):\n+    student = models.ForeignKey(Student, on_delete=models.CASCADE)\n+    enrolled_at = models.DateTimeField(auto_now_add=True)\ndiff --git a/student_portal/views.py b/student_portal/views.py\n@@ enrollment view @@\n+enrollment = StudentEnrollment.objects.filter(student_id=student_id).first()\n+enrolled_date = enrollment.enrolled_at if enrollment else None"
@export var approve_action_label: String = "Approve & Trigger Deployment"
@export var approve_label: String = "Approve"
@export var request_changes_label: String = "Request Changes"
@export_multiline var default_change_request_comment: String = ""

@onready var repository_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/TopBar/RepositoryLabel
@onready var pr_badge: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/PRHeader/PRTitleRow/OpenBadge
@onready var pr_title_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/PRHeader/PRTitleRow/PRTitle
@onready var author_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/PRHeader/AuthorLabel
@onready var branch_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/PRHeader/BranchLabel
@onready var overview_tab: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/TabRow/OverviewTab
@onready var diff_tab: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/TabRow/DiffTab
@onready var overview_pane: Control = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ReviewContent/OverviewPane
@onready var diff_pane: Control = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ReviewContent/DiffPane
@onready var description_label: Label = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ReviewContent/OverviewPane/OverviewMargin/OverviewVBox/DescriptionLabel
@onready var checklist_container: VBoxContainer = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ReviewContent/OverviewPane/OverviewMargin/OverviewVBox/ChecklistPanel/ChecklistMargin/ChecklistVBox/ChecklistItems
@onready var verdict_option: OptionButton = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ReviewContent/OverviewPane/OverviewMargin/OverviewVBox/ReviewPanel/ReviewMargin/ReviewVBox/VerdictOption
@onready var comment_edit: TextEdit = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ReviewContent/OverviewPane/OverviewMargin/OverviewVBox/ReviewPanel/ReviewMargin/ReviewVBox/CommentEdit
@onready var diff_label: RichTextLabel = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ReviewContent/DiffPane/DiffMargin/DiffLabel
@onready var submit_button: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/ActionRow/SubmitReviewButton
@onready var close_button: Button = $Screen/CenterContainer/Window/WindowMargin/MainVBox/TopBar/CloseButton


func _ready() -> void:
	repository_label.text = "DjangoQuest Product Team  ·  default branch: main"
	pr_badge.text = "  Open  "
	pr_title_label.text = "#%d  %s" % [pr_number, pr_title]
	author_label.text = "◉  %s  (%s)  ·  opened this sprint" % [author_name, author_role]
	branch_label.text = branch_target
	description_label.text = description
	verdict_option.clear()
	verdict_option.add_item(approve_label)
	verdict_option.add_item(request_changes_label)
	verdict_option.select(0)
	verdict_option.item_selected.connect(_on_verdict_selected)
	overview_tab.pressed.connect(_show_overview)
	diff_tab.pressed.connect(_show_diff)
	submit_button.pressed.connect(_on_submit_review)
	close_button.pressed.connect(_on_close_pressed)
	_build_checklist()
	_render_diff()
	_on_verdict_selected(0)
	_show_overview()


func _build_checklist() -> void:
	for child in checklist_container.get_children():
		child.queue_free()
	for checklist_item in checklist:
		var item_text := str(checklist_item)
		var checked := item_text.begins_with("[x]") or item_text.begins_with("[X]")
		if item_text.begins_with("[x]") or item_text.begins_with("[X]") or item_text.begins_with("[ ]"):
			item_text = item_text.substr(3).strip_edges()
		var checkbox := CheckBox.new()
		checkbox.text = item_text
		checkbox.button_pressed = checked
		checkbox.disabled = true
		checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		checkbox.add_theme_font_size_override("font_size", 13)
		checkbox.add_theme_color_override("font_color", Color("#c9d1d9") if checked else Color("#ffbf69"))
		checklist_container.add_child(checkbox)


func _render_diff() -> void:
	diff_label.clear()
	diff_label.add_theme_font_override("normal_font", load("res://Textures/Fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"))
	diff_label.add_theme_font_size_override("normal_font_size", 13)
	var line_number := 1
	for line in diff_content.split("\n"):
		if line.begins_with("+") and not line.begins_with("+++"):
			diff_label.push_bgcolor(Color("#193528"))
			diff_label.push_color(Color("#7ee787"))
		elif line.begins_with("-") and not line.begins_with("---"):
			diff_label.push_bgcolor(Color("#3b2028"))
			diff_label.push_color(Color("#ff9b93"))
		elif line.begins_with("@@"):
			diff_label.push_color(Color("#79c0ff"))
		diff_label.add_text("%04d  %s\n" % [line_number, line])
		if line.begins_with("+") and not line.begins_with("+++") or line.begins_with("-") and not line.begins_with("---"):
			diff_label.pop()
			diff_label.pop()
		elif line.begins_with("@@"):
			diff_label.pop()
		line_number += 1


func _on_verdict_selected(index: int) -> void:
	if index == 0:
		submit_button.text = approve_action_label
	else:
		submit_button.text = "Submit Request Changes"


func _show_overview() -> void:
	overview_pane.show()
	diff_pane.hide()
	overview_tab.add_theme_color_override("font_color", Color("#f0f6fc"))
	diff_tab.add_theme_color_override("font_color", Color("#8b949e"))


func _show_diff() -> void:
	overview_pane.hide()
	diff_pane.show()
	overview_tab.add_theme_color_override("font_color", Color("#8b949e"))
	diff_tab.add_theme_color_override("font_color", Color("#f0f6fc"))


func _on_submit_review() -> void:
	var approved := verdict_option.selected == 0
	var comment := comment_edit.text.strip_edges()
	if not approved and comment.is_empty():
		comment = default_change_request_comment
	pr_reviewed.emit(approved, pr_number, comment)
	queue_free()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
