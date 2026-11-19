extends CanvasLayer

@export var reference_manual_rules: Array[Dictionary] = [{"id": "RUN-02", "title": "Check schema migrations before restarting", "badge": "DEVOPS", "description": "When logs report a missing database column, inspect migration status and apply pending migrations before restarting services.", "bad_code": "systemctl restart gunicorn", "good_code": "python manage.py showmigrations"}]

signal migration_applied(command: String)
signal command_completed(command: String, succeeded: bool)

@export_multiline var initial_welcome_text: String = "[color=#7ee787]DJQ Production Console[/color]\nRunbook mode is active. Use a quick command, type a command, or press Tab for completion."
@export var command_registry: Dictionary = {
	"python manage.py showmigrations": "[color=#ff7b72][ ] 0012_add_enrolled_at[/color]\nMigration is pending.",
	"python manage.py migrate": "[color=#7ee787]Applying enrollments.0012_add_enrolled_at... OK[/color]\nDatabase schema is up to date. Production login endpoint restored: HTTP 200.",
	"git status": "On branch main\nYour branch is up to date with 'origin/main'.\n\nnothing to commit, working tree clean",
	"git log --oneline -n 3": "a8e3d91 Merge enrollment timestamp feature\n4f9b1c2 Add enrolled_at to StudentEnrollment\n19c5b72 Add student enrollment endpoint",
	"help": "Supported commands:\npython manage.py showmigrations\npython manage.py migrate\ngit status\ngit log --oneline -n 3\nclear\n\nTip: press Tab to complete a command. Use the arrow keys to browse command history.",
	"clear": ""
}
@export var required_completion_command: String = "python manage.py migrate"
@export var quick_command_shortcuts: PackedStringArray = [
	"git status",
	"python manage.py showmigrations",
	"python manage.py migrate",
	"clear"
]
@export var quick_command_labels: PackedStringArray = ["git status", "showmigrations", "migrate", "clear"]
@export_multiline var runbook_hint_text: String = "Helping hand: inspect the pending migration first, then run the migration command. Use ↑/↓ for history and Tab to complete commands."

@onready var output_view: RichTextLabel = $Screen/CenterContainer/TerminalWindow/WindowMargin/MainVBox/OutputPanel/OutputMargin/OutputView
@onready var command_input: LineEdit = $Screen/CenterContainer/TerminalWindow/WindowMargin/MainVBox/CommandRow/CommandMargin/CommandRowContents/CommandInput
@onready var hint_label: Label = $Screen/CenterContainer/TerminalWindow/WindowMargin/MainVBox/HintLabel
@onready var quick_buttons: HBoxContainer = $Screen/CenterContainer/TerminalWindow/WindowMargin/MainVBox/QuickCommandBar

var command_history: PackedStringArray = []
var history_cursor: int = 0
var quick_button_nodes: Array[Button] = []


func _ready() -> void:
	var manual: ReferenceManualDockPrototype = $Screen/ManualDockHost/ReferenceManualDockPrototype
	manual.load_ruleset(manual.manual_title, reference_manual_rules)
	$Screen/CenterContainer/TerminalWindow/WindowMargin/MainVBox/Header/ReferenceButton.pressed.connect(manual.toggle_manual)
	hint_label.text = runbook_hint_text
	command_input.text_submitted.connect(_on_command_submitted)
	command_input.gui_input.connect(_on_command_gui_input)
	_setup_quick_buttons()
	_append_output(initial_welcome_text)


func _setup_quick_buttons() -> void:
	for child in quick_buttons.get_children():
		child.queue_free()
	quick_button_nodes.clear()
	for i in range(quick_command_shortcuts.size()):
		var chip := Button.new()
		var chip_label := quick_command_labels[i] if i < quick_command_labels.size() else quick_command_shortcuts[i]
		chip.text = "[ " + chip_label + " ]"
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_run_quick_command.bind(quick_command_shortcuts[i]))
		quick_buttons.add_child(chip)
		quick_button_nodes.append(chip)


func _run_quick_command(command: String) -> void:
	if command == "clear":
		_append_output("[color=#8b949e]$ clear[/color]")
		output_view.clear()
		return
	command_input.text = command
	_execute_command(command)


func _on_command_submitted(command: String) -> void:
	_execute_command(command.strip_edges())


func _execute_command(command: String) -> void:
	if command.is_empty():
		return
	command_history.append(command)
	history_cursor = command_history.size()
	if command == "clear":
		output_view.clear()
		return

	_append_output("[color=#7ee787]$ %s[/color]" % command)
	var known := command_registry.has(command)
	var response := str(command_registry.get(command, command_registry.get("help", runbook_hint_text)))
	_append_output(response)
	var succeeded := known and not response.is_empty()
	if command == required_completion_command and succeeded:
		migration_applied.emit(command)
	command_completed.emit(command, succeeded)


func _append_output(text: String) -> void:
	output_view.append_text(text + "\n\n")
	output_view.scroll_to_line(output_view.get_line_count())


func _on_command_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP:
			_browse_history(-1)
			command_input.accept_event()
		KEY_DOWN:
			_browse_history(1)
			command_input.accept_event()
		KEY_TAB:
			_autocomplete_command()
			command_input.accept_event()


func _browse_history(direction: int) -> void:
	if command_history.is_empty():
		return
	history_cursor = clampi(history_cursor + direction, 0, command_history.size())
	command_input.text = "" if history_cursor == command_history.size() else command_history[history_cursor]
	command_input.caret_column = command_input.text.length()


func _autocomplete_command() -> void:
	var prefix := command_input.text.strip_edges()
	if prefix.is_empty():
		return
	var matches: Array[String] = []
	for key in command_registry.keys():
		var candidate := str(key)
		if candidate.begins_with(prefix):
			matches.append(candidate)
	matches.sort()
	if matches.size() == 1:
		command_input.text = matches[0]
		command_input.caret_column = command_input.text.length()
	elif matches.size() > 1:
		_append_output("[color=#8b949e]Matches: %s[/color]" % ", ".join(matches))