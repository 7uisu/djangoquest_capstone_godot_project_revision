extends CanvasLayer

signal traceback_acknowledged
signal root_cause_acknowledged
signal migration_requested
signal terminal_continued

@export_group("Incident Text")
@export_multiline var log_traceback_text: String = "django.db.utils.ProgrammingError: column \"enrolled_at\" of relation \"student_enrollment\" does not exist\n\nThe production database schema is behind the application release. The login endpoint is returning HTTP 500."
@export_multiline var git_blame_text: String = "git blame student_portal/models.py | grep enrolled_at\n\ncommit 4f9b1c2 (3 months ago)\nAuthor: Withdrawn Intern <intern.candidate@university.edu>\nAdded enrolled_at to StudentEnrollment and skipped the remote migration.\n\ncommit a8e3d91 (Today)\nAuthor: You\nMerged PR #42 feat(enrollment): Add student enrollment tracking timestamp."
@export_multiline var showmigrations_text: String = "python manage.py showmigrations enrollments\n\n[ ] 0012_add_enrolled_at  (PENDING)"
@export_multiline var migration_success_text: String = "Operations to perform:\n  Apply all migrations: enrollments\nRunning migrations:\n  Applying enrollments.0012_add_enrolled_at... OK\n\nDatabase schema synchronized. Endpoint restored: HTTP 200 OK — latency 42ms."
@export_multiline var migration_authorization_text: String = "ADMIN TOKEN VERIFIED — WRITE ACCESS GRANTED\nPending migration: 0012_add_enrolled_at"
@export var migrate_command: String = "python manage.py migrate"
@export var command_prompt_text: String = "djq-prod:~$"
@export var diagnostic_prefix_text: String = "console 2 — incident diagnostics"
@export var healthy_prefix_text: String = "console 2 — health check passed"
@export var divino_portrait: Texture2D
@export_multiline var invalid_command_text: String = "Command not executed. Divino instructed: run the documented migration command."
@export var invalid_command_status_text: String = "COMMAND NOT RECOGNIZED"
@export_multiline var retry_hint_text: String = "Check the runbook and enter the exact command shown by Divino."
@export_multiline var success_hint_text: String = "The production endpoint is healthy and its database schema now matches the release."

@export_group("Divino Dialogue — Inspector Editable")
@export var step1_dialogue: Array[Dictionary] = [
	{"name": "Divino Cinaon", "text": "Read the traceback carefully. The login service is not crashing because of traffic; the database schema is rejecting the query. The column enrolled_at is missing in production PostgreSQL."}
]
@export var step2_dialogue: Array[Dictionary] = [
	{"name": "Divino Cinaon", "text": "This Commit & Author History uses git blame, a Git tool that tracks which commit authored each line. Look at line 42: the withdrawn intern drafted this model and skipped the remote migration."},
	{"name": "Divino Cinaon", "text": "When you completed PR #42, you signed off without verifying migrations against production. You could blame the ghost intern, but who owns the code that reached production?"}
]
@export var step3_dialogue: Array[Dictionary] = [
	{"name": "Divino Cinaon", "text": "The commit history is in front of you. In the post-mortem, you could blame the ghost intern and walk away. How do you address the missing migration?"}
]
@export var no_response_dialogue: Array[Dictionary] = [
	{"name": "Divino Cinaon", "text": "Take a moment. When you are ready, choose how you will account for the release."}
]
@export var step4_dialogue: Array[Dictionary] = [
	{"name": "Divino Cinaon", "text": "I have authorized Console 2 with my senior admin token. Never migrate blind in production. Run the verified command to restore service."}
]
@export var migration_complete_dialogue: Array[Dictionary] = [
	{"name": "Divino Cinaon", "text": "Incident resolved. Production is responding again. We will make the migration and verification steps visible in the release checklist next time."}
]
@export var accountability_choices: Array[String] = [
	"It wasn't my fault. Look at Commit & Author History — the previous intern who withdrew wrote this broken schema three months ago. I was just completing their unfinished work.",
	"DevOps automation and QA staging should have caught unmigrated legacy fields before I branched off of them.",
	"The previous intern left the technical debt, but I merged PR #42 and signed off on the deployment checklist without verifying their migration history. In production, whoever ships the code owns the code. It is my responsibility, Divino."
]
@export var no_response_choice_label: String = "No response — give me another moment to decide."
@export var choice_a_failure_dialogue: Array[Dictionary] = [
	{"name": "Divino Cinaon", "text": "I see. Understood. The previous intern broke the schema three months ago, and you were just cleaning up their mess."},
	{"name": "Divino Cinaon", "text": "Let's bring production back up first. We'll run the migration. Management will review the sprint logs."}
]
@export var choice_b_failure_dialogue: Array[Dictionary] = [
	{"name": "Divino Cinaon", "text": "I see. Understood. DevOps automation missed it, QA staging missed it, and you just happened to click Deploy."},
	{"name": "Divino Cinaon", "text": "Let's bring production back up first. We'll run the migration. Management will review the sprint logs."}
]

@export_group("Accountability Failure Cutscene")
@export var hr_cutscene_title: String = "Chapter 12 — CUT_07B: Behind Closed Doors"
@export_multiline var hr_cutscene_visual: String = "Ground Floor HR Office — Late Evening.\nAugust Creed sits alone at his glowing terminal with a coffee cup beside his keyboard. On his monitor is an open draft email:\n\nTo: You\nSubject: DJQ Corp — Official Job Offer: Junior Full-Stack Developer\nAttachment: Employment_Contract_Regular.pdf\n\nAugust reviews the server incident post-mortem on his desk: 'Trainee deflected incident ownership during production outage. Trust compromised.' August sighs quietly and discards the draft contract."
@export var hr_cutscene_dialogue: Array[Dictionary] = [
	{"name": "August Creed", "text": "They completed their OJT hours, but engineering leadership cannot build a team on blame-shifting. I have to discard this contract."}
]
@export var exit_cutscene_title: String = "Chapter 12 — The Exit"
@export_multiline var exit_cutscene_visual: String = "Two weeks later. Ground Floor Lobby Reception. Kendra hands you a crisp white envelope containing your Certificate of OJT Completion. Upstairs, the team gathers for a release celebration without you. No permanent badge is offered."
@export var exit_cutscene_dialogue: Array[Dictionary] = [
	{"name": "You", "text": "I completed all my hours. University gave me full credit. But when regular junior offers came out, my desk was cleared..."},
	{"name": "You", "text": "They never even brought up the 500 error in my exit interview. It was not the broken code that cost me the job; it was dodging accountability when the server went down."}
]
@export var failure_screen_title: String = "OPPORTUNITY LOST"
@export var failure_screen_quote: String = "Bugs can be patched in minutes. Lost trust cannot."
@export_multiline var failure_screen_description: String = "You completed your OJT hours, but failed to earn the team's trust.\nIn software engineering, technical debt is inherited, but accountability is non-negotiable."
@export var failure_screen_retry_label: String = "Retry Server Incident"

@export_group("Tutorial Spotlight Instructions")
@export_multiline var spotlight_traceback_text: String = "Step 1 — Incident diagnosis: read the missing-column error and HTTP 500 response. Press Space to continue."
@export_multiline var spotlight_git_blame_text: String = "Step 2 — Root cause: inspect the author and commit that introduced enrolled_at. Press Space to continue."
@export_multiline var spotlight_migration_status_text: String = "The migration is pending: [ ] means it has not been applied to production. Press Space to continue."
@export_multiline var spotlight_command_text: String = "Step 4 — Console 2 is authorized. Review the command field and the Fill Command helper. After the guide closes, enter and run the command."

@export_group("Terminal Labels")
@export var traceback_status_text: String = "CRITICAL — PRODUCTION DATABASE"
@export var root_cause_status_text: String = "INCIDENT TRIAGE — ROOT CAUSE"
@export var migration_status_text: String = "ADMIN TOKEN VERIFIED — CONSOLE 2 UNLOCKED"
@export var success_status_text: String = "SYSTEM HEALTHY — ALL SERVICES OPERATIONAL"
@export var traceback_title_text: String = "Login API — Migration Failure"
@export var root_cause_title_text: String = "Commit & Author History & Migration Status"
@export var migration_title_text: String = "Production Database Migration (Authorized)"
@export var success_title_text: String = "Migration Complete"
@export var acknowledge_traceback_label: String = "Continue to Commit & Author History"
@export var acknowledge_root_cause_label: String = "Continue to Incident Response Decision"
@export var commit_author_history_heading: String = "Commit & Author History (git blame)"
@export var incident_response_question_text: String = "Incident Response Decision — how do you address the missing migration?"
@export var run_migration_label: String = "Run Migration"
@export var fill_command_label: String = "Fill Command"
@export var continue_label: String = "Continue"

@export_group("Server Rack Prompts")
@export var triage_interaction_prompt: String = "[F] Triage Critical Error!"
@export var migration_interaction_prompt: String = "[F] Run python manage.py migrate"
@export var triage_objective_text: String = "Access the primary console ([F] Triage Critical Error!)."
@export var migration_objective_text: String = "Run python manage.py migrate at the primary console ([F])."

@onready var status_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/TerminalHeader/StatusLabel
@onready var title_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/TitleLabel
@onready var output_label: RichTextLabel = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputContent/OutputLabel
@onready var root_cause_split: HBoxContainer = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputContent/RootCauseSplit
@onready var history_heading: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputContent/RootCauseSplit/GitBlamePanel/GitBlameMargin/GitBlameContent/HistoryHeading
@onready var git_blame_label: RichTextLabel = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputContent/RootCauseSplit/GitBlamePanel/GitBlameMargin/GitBlameContent/GitBlameLabel
@onready var migration_status_label: RichTextLabel = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputContent/RootCauseSplit/MigrationStatusPanel/MigrationStatusMargin/MigrationStatusLabel
@onready var command_prefix_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/CommandRow/CommandMargin/CommandRowContents/CommandPrefixLabel
@onready var command_line_edit: LineEdit = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/CommandRow/CommandMargin/CommandRowContents/CommandLineEdit
@onready var quick_fill_button: Button = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/CommandRow/CommandMargin/CommandRowContents/QuickFillButton
@onready var action_button: Button = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/ActionButton
@onready var hint_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/HintLabel

enum TerminalMode { TRACEBACK, ROOT_CAUSE, AUTHORIZATION, MIGRATION, SUCCESS }
var _mode: TerminalMode = TerminalMode.TRACEBACK
var _status_pulse_tween: Tween


func _ready() -> void:
	output_label.bbcode_enabled = false
	history_heading.text = commit_author_history_heading
	action_button.pressed.connect(_on_action_pressed)
	command_line_edit.text_submitted.connect(_on_command_submitted)
	quick_fill_button.pressed.connect(_fill_command)
	visible = false


func present_traceback() -> void:
	_mode = TerminalMode.TRACEBACK
	status_label.text = traceback_status_text
	status_label.add_theme_color_override("font_color", Color("#ff6b6b"))
	_start_critical_status_pulse()
	title_label.text = traceback_title_text
	output_label.text = log_traceback_text
	output_label.show()
	root_cause_split.hide()
	command_prefix_label.text = diagnostic_prefix_text
	command_line_edit.hide()
	quick_fill_button.hide()
	action_button.show()
	action_button.text = acknowledge_traceback_label
	hint_label.text = spotlight_traceback_text
	action_button.disabled = false
	visible = true


func present_root_cause() -> void:
	_mode = TerminalMode.ROOT_CAUSE
	_stop_status_pulse()
	status_label.text = root_cause_status_text
	status_label.add_theme_color_override("font_color", Color("#e3b341"))
	title_label.text = root_cause_title_text
	output_label.hide()
	git_blame_label.text = git_blame_text
	migration_status_label.text = showmigrations_text
	root_cause_split.show()
	command_prefix_label.text = diagnostic_prefix_text
	command_line_edit.hide()
	quick_fill_button.hide()
	action_button.show()
	action_button.text = acknowledge_root_cause_label
	hint_label.text = spotlight_migration_status_text
	action_button.disabled = false
	visible = true


func present_authorization() -> void:
	_mode = TerminalMode.AUTHORIZATION
	_stop_status_pulse()
	status_label.text = migration_status_text
	status_label.add_theme_color_override("font_color", Color("#6ee7a8"))
	title_label.text = migration_title_text
	output_label.text = "%s\n\n%s" % [migration_authorization_text, showmigrations_text]
	output_label.show()
	root_cause_split.hide()
	command_prefix_label.text = diagnostic_prefix_text
	command_line_edit.hide()
	quick_fill_button.hide()
	action_button.hide()
	hint_label.text = migration_authorization_text
	visible = true


func present_migration_prompt() -> void:
	_mode = TerminalMode.MIGRATION
	status_label.text = migration_status_text
	status_label.add_theme_color_override("font_color", Color("#6ee7a8"))
	title_label.text = migration_title_text
	output_label.text = "%s\n\n%s" % [migration_authorization_text, showmigrations_text]
	output_label.show()
	root_cause_split.hide()
	command_prefix_label.text = command_prompt_text
	command_line_edit.text = ""
	command_line_edit.placeholder_text = migrate_command
	command_line_edit.show()
	quick_fill_button.text = fill_command_label
	quick_fill_button.show()
	action_button.show()
	command_line_edit.call_deferred("grab_focus")
	action_button.text = run_migration_label
	hint_label.text = retry_hint_text
	action_button.disabled = false
	visible = true


func present_success() -> void:
	_mode = TerminalMode.SUCCESS
	_stop_status_pulse()
	status_label.text = success_status_text
	status_label.add_theme_color_override("font_color", Color("#6ee7a8"))
	title_label.text = success_title_text
	output_label.text = migration_success_text
	output_label.show()
	root_cause_split.hide()
	command_prefix_label.text = healthy_prefix_text
	command_line_edit.hide()
	quick_fill_button.hide()
	action_button.text = continue_label
	hint_label.text = success_hint_text
	action_button.disabled = false
	visible = true


func _fill_command() -> void:
	command_line_edit.text = migrate_command
	command_line_edit.grab_focus()


func _start_critical_status_pulse() -> void:
	_stop_status_pulse()
	status_label.modulate.a = 1.0
	_status_pulse_tween = create_tween().set_loops()
	_status_pulse_tween.tween_property(status_label, "modulate:a", 0.55, 0.55)
	_status_pulse_tween.tween_property(status_label, "modulate:a", 1.0, 0.55)


func _stop_status_pulse() -> void:
	if _status_pulse_tween and _status_pulse_tween.is_running():
		_status_pulse_tween.kill()
	status_label.modulate.a = 1.0


func _on_action_pressed() -> void:
	match _mode:
		TerminalMode.TRACEBACK:
			visible = false
			traceback_acknowledged.emit()
		TerminalMode.ROOT_CAUSE:
			visible = false
			root_cause_acknowledged.emit()
		TerminalMode.MIGRATION:
			if command_line_edit.text.strip_edges() != migrate_command:
				status_label.text = invalid_command_status_text
				status_label.add_theme_color_override("font_color", Color("#ffbf69"))
				output_label.text += "\n\n" + invalid_command_text
				hint_label.text = retry_hint_text
				return
			status_label.text = migration_status_text
			status_label.add_theme_color_override("font_color", Color("#6ee7a8"))
			action_button.disabled = true
			migration_requested.emit()
		TerminalMode.SUCCESS:
			visible = false
			terminal_continued.emit()


func _on_command_submitted(_submitted_text: String) -> void:
	_on_action_pressed()
