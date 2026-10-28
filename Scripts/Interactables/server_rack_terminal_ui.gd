extends CanvasLayer

signal traceback_acknowledged
signal migration_requested
signal terminal_continued

@export_multiline var traceback_text: String = "django.db.utils.ProgrammingError: column \"enrolled_at\" of relation \"student_enrollment\" does not exist\n\nThe production database schema is behind the application release. The login endpoint is returning HTTP 500."
@export var migrate_command: String = "python manage.py migrate"
@export_multiline var success_text: String = "Applying migrations...\n  Applying enrollments.0012_add_enrolled_at... OK\n\nHTTP 200 OK — Production login endpoint restored."

@onready var window_panel: PanelContainer = $Screen/CenterContainer/TerminalWindow
@onready var status_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/TerminalHeader/StatusLabel
@onready var title_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/TitleLabel
@onready var output_label: RichTextLabel = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/OutputPanel/OutputMargin/OutputLabel
@onready var command_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/CommandRow/CommandMargin/CommandRowContents/CommandPrefixLabel
@onready var command_line_edit: LineEdit = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/CommandRow/CommandMargin/CommandRowContents/CommandLineEdit
@onready var action_button: Button = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/ActionButton
@onready var hint_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/WindowVBox/HintLabel

enum TerminalMode { TRACEBACK, MIGRATION, SUCCESS }
var _mode: TerminalMode = TerminalMode.TRACEBACK


func _ready() -> void:
	action_button.pressed.connect(_on_action_pressed)
	command_line_edit.text_submitted.connect(_on_command_submitted)
	visible = false


func present_traceback() -> void:
	_mode = TerminalMode.TRACEBACK
	status_label.text = "●  CRITICAL · PRODUCTION DATABASE"
	status_label.add_theme_color_override("font_color", Color("#ff6b6b"))
	title_label.text = "Login API · Migration Failure"
	output_label.text = "[color=#ff7b72]$ tail -f /var/log/django/production.log[/color]\n\n[color=#f0f3f6]%s[/color]" % traceback_text
	command_label.text = "console 2  ·  incident diagnostics"
	command_line_edit.hide()
	action_button.text = "Acknowledge Traceback"
	hint_label.text = "Review the failing column, then answer Divino's accountability question."
	action_button.disabled = false
	visible = true


func present_migration_prompt() -> void:
	_mode = TerminalMode.MIGRATION
	status_label.text = "●  INCIDENT ACKNOWLEDGED · CONSOLE 2 READY"
	status_label.add_theme_color_override("font_color", Color("#ffbf69"))
	title_label.text = "Run the production database migration"
	output_label.text = "[color=#ff7b72]django.db.utils.ProgrammingError[/color]\ncolumn \"enrolled_at\" of relation \"student_enrollment\" does not exist\n\nThe migration has been reviewed. Apply the pending schema change to restore the login service."
	command_label.text = "djq-prod:~$"
	command_line_edit.text = ""
	command_line_edit.placeholder_text = "Type the migration command..."
	command_line_edit.show()
	command_line_edit.call_deferred("grab_focus")
	action_button.text = "▶  Run Migration"
	hint_label.text = "This runs the documented release command on the production database."
	action_button.disabled = false
	visible = true


func present_success() -> void:
	_mode = TerminalMode.SUCCESS
	status_label.text = "●  SYSTEM HEALTHY · ALL SERVICES OPERATIONAL"
	status_label.add_theme_color_override("font_color", Color("#6ee7a8"))
	title_label.text = "Migration complete"
	output_label.text = "[color=#7ee787]%s[/color]" % success_text
	command_label.text = "console 2  ·  health check passed"
	command_line_edit.hide()
	action_button.text = "Continue"
	hint_label.text = "The red emergency alarm is cleared and production is responding again."
	action_button.disabled = false
	visible = true


func _on_action_pressed() -> void:
	match _mode:
		TerminalMode.TRACEBACK:
			visible = false
			traceback_acknowledged.emit()
		TerminalMode.MIGRATION:
			if command_line_edit.text.strip_edges() != migrate_command:
				status_label.text = "●  COMMAND NOT RECOGNIZED · CHECK THE RUNBOOK"
				status_label.add_theme_color_override("font_color", Color("#ffbf69"))
				output_label.text += "\n\n[color=#ff7b72]Command not executed. Type exactly: %s[/color]" % migrate_command
				return
			action_button.disabled = true
			migration_requested.emit()
		TerminalMode.SUCCESS:
			visible = false
			terminal_continued.emit()


func _on_command_submitted(_submitted_text: String) -> void:
	_on_action_pressed()
