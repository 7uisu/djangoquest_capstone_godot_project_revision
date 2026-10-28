@tool
extends Resource
class_name GetHubTicket

@export_category("Issue")
@export var issue_number: int = 101
@export var title: String = "Student portal layout collapses on mobile"
@export var reporter_name: String = "Celestina Balon"
@export var reporter_role: String = "QA Lead"
@export_enum("Low", "Normal", "High", "Critical") var priority: String = "High"
@export_enum("Open", "In Progress", "Closed") var initial_status: String = "Open"
@export var labels: PackedStringArray = ["bug", "frontend", "css", "high-priority"]
@export_multiline var description: String = "The Student Learning Portal dashboard cards overflow the viewport on narrow mobile screens."
@export var reproduction_steps: PackedStringArray = [
	"Open the dashboard at a desktop width.",
	"Resize the preview to 375 px wide.",
	"Observe the cards extend beyond the viewport instead of wrapping."
]
@export var acceptance_criteria: PackedStringArray = [
	"Cards remain inside the mobile viewport.",
	"Desktop layout remains a flexible row.",
	"Use a targeted CSS change; do not rewrite the navbar."
]
@export var attachment_heading: String = "QA attachment · 375 px mobile viewport"
@export_multiline var attachment_caption: String = "Reproduced on a narrow phone viewport. The cards continue horizontally and are clipped at the right edge."

@export_category("IDE Challenge")
@export var challenge_title: String = "Fix the mobile card layout"
@export_enum("css", "python", "django", "javascript", "typescript") var challenge_topic: String = "css"
@export_enum("free_type", "terminal") var challenge_type: String = "free_type"
@export_enum("browser", "terminal") var challenge_output_type: String = "browser"
@export var file_name: String = "responsive.css"
@export_multiline var starter_code: String = ".portal-cards {\n    display: flex;\n    gap: 12px;\n}"
@export_category("IDE Project Explorer")
@export var project_tree: Dictionary = {
	"student_portal": {
		"manage.py": "",
		"portal": {
			"templates": {"dashboard.html": ""},
			"static": {"css": {"responsive.css": "", "navigation.css": ""}}
		}
	}
}
@export var expected_code: String = "flex-wrap: wrap;"
@export_multiline var hint: String = "The container is already a flex row. Which flex property allows its children to move onto another line when there is not enough room?"
@export_multiline var correct_output: String = "PASS  Mobile cards stay within the viewport.\nPASS  Desktop row layout is preserved.\nHTTP 200 OK — ready for QA review."
@export_multiline var error_output: String = "FAIL  Mobile cards still overflow. Check the flex container's wrapping behavior."
@export var mission_steps: PackedStringArray = [
	"Reproduce the 375 px mobile layout issue in the browser preview.",
	"Keep the existing flex layout and make the cards wrap.",
	"Run the checks, then return to GetHub and submit the ticket to QA."
]
@export_multiline var preview_before: String = "[center][b]STUDENT PORTAL · MOBILE 375 PX[/b][/center]\n\n[color=#8b949e]Dashboard cards[/color]\n\n[bgcolor=#3b2028][color=#ff7b72]  Attendance  →  Grades  →  Assignments  →[/color][/bgcolor]\n\n[color=#ff7b72]⚠ Horizontal overflow — content clipped[/color]"
@export_multiline var preview_after: String = "[center][b]STUDENT PORTAL · MOBILE 375 PX[/b][/center]\n\n[color=#8b949e]Dashboard cards[/color]\n\n[bgcolor=#193528][color=#7ee787]  Attendance  ✓[/color][/bgcolor]\n\n[bgcolor=#193528][color=#7ee787]  Grades  ✓[/color][/bgcolor]\n\n[bgcolor=#193528][color=#7ee787]  Assignments  ✓[/color][/bgcolor]\n\n[color=#7ee787]✓ Cards wrap cleanly inside the viewport[/color]"

@export_category("Multi-File Challenge")
@export var is_multi_file: bool = false
@export var active_file: String = ""
@export var multi_files: Dictionary = {}
@export var multi_expected_answers: Dictionary = {}

@export_category("Mentor Guidance")
@export var mentor_name: String = ""
@export_multiline var mentor_hint: String = ""


func build_challenge() -> Dictionary:
	var ticket_id := "office_gethub_%d" % issue_number
	var challenge := {
		"id": ticket_id,
		"topic": challenge_topic,
		"type": challenge_type,
		"title": challenge_title,
		"timed": false,
		"time_limit": 0,
		"file_name": file_name,
		"active_file": file_name,
		"files": {file_name: starter_code},
		"project_tree": project_tree,
		"expected_answers": [expected_code],
		"mission_steps": mission_steps,
		"hint": hint,
		"mentor_name": mentor_name,
		"mentor_hint": mentor_hint,
		"correct_output": correct_output,
		"error_output": error_output,
		"output_type": challenge_output_type,
		"browser_preview_before": preview_before,
		"browser_preview_after": preview_after,
		"preview_required_code": expected_code
	}
	if is_multi_file and not multi_files.is_empty():
		var selected_file := active_file if not active_file.is_empty() else str(multi_files.keys()[0])
		challenge["file_name"] = selected_file
		challenge["active_file"] = selected_file
		challenge["files"] = multi_files
		challenge["expected_answers"] = multi_expected_answers
	return challenge
