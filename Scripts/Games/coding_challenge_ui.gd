# coding_challenge_ui.gd — DjangoQuest IDE: VSCode-style coding minigame controller
# Attach to the root Control of coding_challenge_ui.tscn
extends Control

signal challenge_completed(success: bool, challenge_id: String)

# ─── Challenge Data ──────────────────────────────────────────────────────────
var current_challenge: Dictionary = {}
var selected_option: int = -1
var is_completed: bool = false
var timer_running: bool = false
var time_remaining: float = 0.0
var is_free_type: bool = false  # true when challenge uses free typing instead of options
var is_terminal: bool = false   # true for terminal command challenges
var is_dark_theme: bool = true  # light theme troll toggle
var hide_close_button: bool = false  # when true, prevent closing (NPC challenges)

var _attempts: int = 0  # tracks incorrect submissions for progressive hints

# ─── Node References ─────────────────────────────────────────────────────────
@onready var title_label: Label = $TitleBar/TitleLabel
@onready var timer_label: Label = $TitleBar/TimerLabel
@onready var close_button: Button = $TitleBar/CloseButton
@onready var gear_button: Button = $TitleBar/GearButton

# Mission Panel
@onready var mission_title: Label = $MainContent/MissionPanel/MissionScroll/MissionVBox/MissionTitle
@onready var steps_container: VBoxContainer = $MainContent/MissionPanel/MissionScroll/MissionVBox/StepsContainer
@onready var hint_button: Button = $MainContent/MissionPanel/MissionScroll/MissionVBox/HintButton
@onready var hint_label: RichTextLabel = $MainContent/MissionPanel/MissionScroll/MissionVBox/HintLabel

# Code Panel
@onready var file_tab_label: Label = $MainContent/CodePanel/CodeVBox/FileTab
@onready var code_display: RichTextLabel = $MainContent/CodePanel/CodeVBox/CodeScroll/CodeDisplay
@onready var options_label: Label = $MainContent/CodePanel/CodeVBox/OptionsLabel
@onready var options_container: VBoxContainer = $MainContent/CodePanel/CodeVBox/OptionsContainer
@onready var free_type_edit: TextEdit = $MainContent/CodePanel/CodeVBox/FreeTypeEdit
@onready var linter_label: RichTextLabel = $MainContent/CodePanel/CodeVBox/LinterLabel

# Output Panel
@onready var output_panel: PanelContainer = $MainContent/OutputPanel
@onready var output_title: Label = $MainContent/OutputPanel/OutputVBox/OutputTitleBar/OutputTitle
@onready var output_display: RichTextLabel = $MainContent/OutputPanel/OutputVBox/OutputScroll/OutputDisplay
@onready var reload_button: Button = $MainContent/OutputPanel/OutputVBox/OutputTitleBar/ReloadButton
@onready var toggle_output_button: Button = $BottomBar/ToggleOutputButton

# Bottom Bar
@onready var run_button: Button = $BottomBar/RunButton
@onready var progress_label: Label = $BottomBar/ProgressLabel
@onready var feedback_label: Label = $BottomBar/FeedbackLabel

# Results Overlay
@onready var results_overlay: PanelContainer = $ResultsOverlay
@onready var results_title: Label = $ResultsOverlay/ResultsVBox/ResultsTitle
@onready var results_text: Label = $ResultsOverlay/ResultsVBox/ResultsText
@onready var continue_button: Button = $ResultsOverlay/ResultsVBox/ContinueButton

# Audio
@onready var correct_sfx: AudioStreamPlayer = $CorrectSFX
@onready var wrong_sfx: AudioStreamPlayer = $WrongSFX
@onready var keypad_sfx: AudioStreamPlayer = $KeypadSFX
@onready var mouse_click_sfx: AudioStreamPlayer = $MouseClickSFX
var _keypad_cooldown: float = 0.0
const KEYPAD_COOLDOWN_TIME: float = 0.15  # seconds between keypad clicks

# Light Theme Troll
@onready var light_flash: ColorRect = $LightFlash
@onready var troll_dialogue: PanelContainer = $TrollDialogue
@onready var troll_name: Label = $TrollDialogue/TrollMargin/TrollVBox/TrollName
@onready var troll_text: RichTextLabel = $TrollDialogue/TrollMargin/TrollVBox/TrollText
@onready var troll_continue: Label = $TrollDialogue/TrollMargin/TrollVBox/TrollContinue
var _troll_tween: Tween = null
var _troll_lines: Array = []
var _troll_line_index: int = 0
var _troll_typing: bool = false

# Overflow Stack
@onready var overflow_overlay: PanelContainer = $OverflowStackOverlay
@onready var stack_question: Label = $OverflowStackOverlay/StackVBox/StackQuestion
@onready var stack_votes: Label = $OverflowStackOverlay/StackVBox/StackVotes
@onready var stack_answer: RichTextLabel = $OverflowStackOverlay/StackVBox/StackAnswer
@onready var stack_user: Label = $OverflowStackOverlay/StackVBox/StackUser
@onready var stack_logo: Label = $OverflowStackOverlay/StackVBox/StackHeader/StackLogo
@onready var stack_close_button: Button = $OverflowStackOverlay/StackVBox/StackHeader/StackCloseButton

# Item Buff System
@onready var item_button: Button = $TitleBar/ItemButton
@onready var item_popup: PanelContainer = $ItemPopup
@onready var item_popup_title: Label = $ItemPopup/ItemPopupVBox/ItemPopupTitle
@onready var item_list: VBoxContainer = $ItemPopup/ItemPopupVBox/ItemPopupScroll/ItemList
@onready var item_popup_close: Button = $ItemPopup/ItemPopupVBox/ItemPopupClose

# ─── Syntax Colors ───────────────────────────────────────────────────────────
const COLOR_KEYWORD = "#c678dd"    # purple
const COLOR_STRING = "#98c379"     # green
const COLOR_FUNCTION = "#61afef"   # blue
const COLOR_COMMENT = "#5c6370"    # grey
const COLOR_NUMBER = "#d19a66"     # orange
const COLOR_NORMAL = "#abb2bf"     # light grey
const COLOR_TAG = "#e06c75"        # red (for HTML tags)
const COLOR_ATTR = "#d19a66"       # orange (for HTML attributes)
const COLOR_BUG_BG = "#3e2020"     # dark red background for bug line
const COLOR_LINE_NUM = "#636d83"   # dim line numbers

# Python keywords for syntax highlighting
const PYTHON_KEYWORDS = ["def", "return", "if", "else", "elif", "for", "while",
	"in", "import", "from", "class", "True", "False", "None", "and", "or", "not",
	"print", "range", "len", "str", "int", "float", "list", "dict"]

const HTML_TAGS = ["html", "head", "body", "h1", "h2", "h3", "h4", "p", "div",
	"span", "ul", "ol", "li", "a", "img", "form", "input", "button", "DOCTYPE",
	"link", "script", "style", "meta", "title", "br", "hr", "table", "tr", "td", "th"]

const CSS_PROPERTIES = ["color", "background-color", "font-size", "text-align",
	"margin", "padding", "border", "display", "position", "width", "height",
	"font-weight", "text-decoration", "flex", "grid"]

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready():
	# Apply custom pixel font
	var custom_font = preload("res://Textures/Fonts/Pixelify_Sans/static/PixelifySans-Regular.ttf")
	var custom_theme = Theme.new()
	custom_theme.default_font = custom_font
	theme = custom_theme

	# RichTextLabels need the font enforced explicitly sometimes
	hint_label.add_theme_font_override("normal_font", custom_font)
	code_display.add_theme_font_override("normal_font", custom_font)
	output_display.add_theme_font_override("normal_font", custom_font)

	# Ensure SFX streams are loaded
	keypad_sfx.stream = preload("res://Sounds/UI SFX/UIClick_BLEEOOP_Keypad_Click.wav")
	mouse_click_sfx.stream = preload("res://Sounds/UI SFX/UIClick_BLEEOOP_Mouse_Click.wav")
	mouse_click_sfx.volume_db = -6.0
	keypad_sfx.volume_db = -8.0

	# Connect signals
	close_button.pressed.connect(_on_close_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	run_button.pressed.connect(_on_run_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	toggle_output_button.pressed.connect(_on_toggle_output_pressed)
	free_type_edit.text_changed.connect(_on_free_type_changed)
	gear_button.pressed.connect(_on_gear_pressed)
	stack_close_button.pressed.connect(func(): overflow_overlay.visible = false)
	troll_dialogue.gui_input.connect(_on_troll_panel_clicked)
	troll_dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
	item_button.pressed.connect(_on_item_button_pressed)
	item_popup_close.pressed.connect(func(): item_popup.visible = false)

	# Initial state
	results_overlay.visible = false
	hint_label.visible = false
	timer_label.visible = false
	feedback_label.visible = false
	run_button.disabled = true
	free_type_edit.visible = false
	linter_label.visible = false
	overflow_overlay.visible = false
	light_flash.visible = false
	troll_dialogue.visible = false
	item_popup.visible = false

	# Style the free-type editor
	_style_free_type_edit()

	# Load a default challenge if none set (for testing)
	if current_challenge.is_empty():
		var ChallengeData = preload("res://Scripts/Games/coding_challenge_data.gd")
		load_challenge(ChallengeData.python_challenges[0])

func _process(delta):
	# Keypad cooldown timer
	if _keypad_cooldown > 0:
		_keypad_cooldown -= delta

	if timer_running and time_remaining > 0:
		time_remaining -= delta
		_update_timer_display()
		if time_remaining <= 0:
			time_remaining = 0
			timer_running = false
			_on_time_up()

# ─── Public API ──────────────────────────────────────────────────────────────

func load_challenge(challenge: Dictionary) -> void:
	current_challenge = challenge
	is_completed = false
	selected_option = -1
	_attempts = 0
	is_free_type = challenge.get("type", "") == "free_type"
	is_terminal = challenge.get("type", "") == "terminal"

	_setup_title()
	_setup_mission_panel()
	_setup_code_panel()
	_setup_output_panel()
	_setup_timer()
	_setup_bottom_bar()

	results_overlay.visible = false
	feedback_label.visible = false

	# Show/hide output panel based on challenge setting
	var show_output = challenge.get("show_output", true)
	output_panel.visible = show_output
	toggle_output_button.text = "◀ Hide Output" if show_output else "▶ Show Output"

	if is_free_type or is_terminal:
		run_button.disabled = true  # enabled when they type something
	else:
		run_button.disabled = true

	linter_label.visible = false
	overflow_overlay.visible = false

func load_challenge_set(challenges: Array, index: int = 0) -> void:
	"""Load a set of challenges, showing progress like 'Challenge 1 / 5'."""
	if index < challenges.size():
		load_challenge(challenges[index])
		progress_label.text = "Challenge " + str(index + 1) + " / " + str(challenges.size())

# ─── UI Setup ────────────────────────────────────────────────────────────────

func _setup_title():
	title_label.text = "  DjangoQuest IDE — " + current_challenge.get("title", "Challenge")

func _setup_mission_panel():
	# Title based on type
	var type_label = ""
	match current_challenge.get("type", "debug"):
		"debug": type_label = "🔧 DEBUG"
		"follow_steps": type_label = "📝 FOLLOW STEPS"
		"predict_output": type_label = "🤔 PREDICT OUTPUT"
		"free_type": type_label = "⌨️ CODE IT"
		"terminal": type_label = "💻 TERMINAL"
	mission_title.text = type_label

	# Clear old steps
	for child in steps_container.get_children():
		child.queue_free()

	# Add mission steps
	var steps = current_challenge.get("mission_steps", [])
	for i in range(steps.size()):
		var step_label = Label.new()
		step_label.text = str(i + 1) + ". " + steps[i]
		step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step_label.add_theme_color_override("font_color", Color("abb2bf"))
		step_label.add_theme_font_size_override("font_size", 13)
		steps_container.add_child(step_label)

	# Hint — now opens Overflow Stack popup instead
	hint_label.visible = false
	hint_label.text = current_challenge.get("hint", "")
	var has_hint = current_challenge.get("hint", "") != ""
	hint_button.visible = has_hint
	if has_hint:
		hint_button.text = "📚 Ask Overflow Stack"

func _setup_code_panel():
	# File tab
	file_tab_label.text = "  📄 " + current_challenge.get("file_name", "code.py")

	# Syntax-highlighted code
	var code_lines = current_challenge.get("code_lines", [])
	var bug_line = current_challenge.get("bug_line", -1)
	var topic = current_challenge.get("topic", "python")

	var bbcode = ""
	for i in range(code_lines.size()):
		var line_num = str(i + 1).lpad(3, " ")
		var line_color = COLOR_LINE_NUM

		# Bug line highlight
		if i == bug_line:
			bbcode += "[bgcolor=" + COLOR_BUG_BG + "]"
			bbcode += "[color=" + line_color + "]" + line_num + " [/color]"
			bbcode += _syntax_highlight(code_lines[i], topic)
			bbcode += "[/bgcolor]"
		else:
			bbcode += "[color=" + line_color + "]" + line_num + " [/color]"
			bbcode += _syntax_highlight(code_lines[i], topic)

		if i < code_lines.size() - 1:
			bbcode += "\n"

	code_display.bbcode_enabled = true
	code_display.text = bbcode

	# Determine challenge type
	var ctype = current_challenge.get("type", "debug")

	# Terminal mode: show TextEdit styled as a terminal, hide options
	if is_terminal:
		options_label.text = "Type your command:"
		options_container.visible = false
		free_type_edit.visible = true
		free_type_edit.text = current_challenge.get("starter_code", "")
		free_type_edit.placeholder_text = current_challenge.get("placeholder", "$ ")
		# Style as terminal
		var term_style = StyleBoxFlat.new()
		term_style.bg_color = Color("0d0d0d")
		term_style.border_color = Color("333333")
		term_style.set_border_width_all(1)
		term_style.set_corner_radius_all(4)
		term_style.set_content_margin_all(8)
		free_type_edit.add_theme_stylebox_override("normal", term_style)
		free_type_edit.add_theme_stylebox_override("focus", term_style)
		free_type_edit.add_theme_color_override("font_color", Color("00ff41"))  # Matrix green
		for child in options_container.get_children():
			child.queue_free()
		return

	# Free-type mode: show TextEdit, hide options
	if is_free_type:
		options_label.text = "Type your code below:"
		options_container.visible = false
		free_type_edit.visible = true
		free_type_edit.text = current_challenge.get("starter_code", "")
		free_type_edit.placeholder_text = current_challenge.get("placeholder", "Type your code here...")
		# Clear old option buttons
		for child in options_container.get_children():
			child.queue_free()
		return

	# Multiple-choice mode: show options, hide TextEdit
	free_type_edit.visible = false
	options_container.visible = true
	match ctype:
		"debug": options_label.text = "Select the fix:"
		"follow_steps": options_label.text = "Select the correct code:"
		"predict_output": options_label.text = "What will the output be?"

	# Clear old options
	for child in options_container.get_children():
		child.queue_free()

	# Create option buttons
	var options = current_challenge.get("options", [])
	for i in range(options.size()):
		var btn = Button.new()
		btn.text = options[i].get("text", "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)

		# Style the button
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color("2d2d3d")
		style_normal.border_color = Color("3d3d5c")
		style_normal.set_border_width_all(1)
		style_normal.set_corner_radius_all(4)
		style_normal.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", style_normal)

		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color("3d3d5c")
		style_hover.border_color = Color("5c5c8a")
		btn.add_theme_stylebox_override("hover", style_hover)

		var style_pressed = style_normal.duplicate()
		style_pressed.bg_color = Color("1a3a5c")
		style_pressed.border_color = Color("4a9eff")
		btn.add_theme_stylebox_override("pressed", style_pressed)

		btn.add_theme_color_override("font_color", Color("abb2bf"))
		btn.add_theme_color_override("font_hover_color", Color("e0e0e0"))

		btn.pressed.connect(_on_option_selected.bind(i))
		options_container.add_child(btn)

func _setup_output_panel():
	var output_type = current_challenge.get("output_type", "terminal")
	if output_type == "browser":
		output_title.text = " 🌐 Preview — http://localhost:8000"
	else:
		output_title.text = " 💻 Terminal"

	# Show initial state (error or blank)
	var ctype = current_challenge.get("type", "debug")
	output_display.bbcode_enabled = true
	if ctype == "predict_output":
		output_display.text = "[color=#5c6370][i]Run the code to see the output...[/i][/color]"
	elif current_challenge.get("error_output", "") != "":
		output_display.text = "[color=#e06c75]" + current_challenge["error_output"] + "[/color]"
	else:
		output_display.text = "[color=#5c6370][i]Click ▶ Run to execute...[/i][/color]"

func _setup_timer():
	if current_challenge.get("timed", false):
		time_remaining = float(current_challenge.get("time_limit", 30))
		timer_label.visible = true
		timer_running = true

		# Make timer more prominent
		timer_label.add_theme_font_size_override("font_size", 16)
		timer_label.custom_minimum_size = Vector2(90, 0)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		_update_timer_display()
	else:
		timer_label.visible = false
		timer_running = false

func _setup_bottom_bar():
	progress_label.text = current_challenge.get("topic", "").to_upper() + " — " + current_challenge.get("title", "")

var _timer_pulse_tween: Tween = null

func _update_timer_display():
	var seconds = int(time_remaining)
	var color = "#98c379" # green
	if seconds <= 10:
		color = "#e06c75" # red — danger!
		# Pulse effect when low
		if _timer_pulse_tween == null or not _timer_pulse_tween.is_valid():
			_timer_pulse_tween = create_tween().set_loops()
			_timer_pulse_tween.tween_property(timer_label, "modulate:a", 0.4, 0.4)
			_timer_pulse_tween.tween_property(timer_label, "modulate:a", 1.0, 0.4)
	elif seconds <= 20:
		color = "#d19a66" # orange — warning
		# Stop pulse if it was running
		if _timer_pulse_tween and _timer_pulse_tween.is_valid():
			_timer_pulse_tween.kill()
			_timer_pulse_tween = null
			timer_label.modulate.a = 1.0
	else:
		# Stop pulse if it was running
		if _timer_pulse_tween and _timer_pulse_tween.is_valid():
			_timer_pulse_tween.kill()
			_timer_pulse_tween = null
			timer_label.modulate.a = 1.0

	timer_label.text = "⏱ " + str(seconds) + "s"
	timer_label.add_theme_color_override("font_color", Color(color))

# ─── Syntax Highlighting ────────────────────────────────────────────────────

func _syntax_highlight(line: String, topic: String) -> String:
	if line.strip_edges() == "":
		return " "

	match topic:
		"python": return _highlight_python(line)
		"html": return _highlight_html(line)
		"css": return _highlight_css(line)
		"django": return _highlight_python(line) # Django uses Python syntax
		_: return "[color=" + COLOR_NORMAL + "]" + _escape_bbcode(line) + "[/color]"

func _highlight_python(line: String) -> String:
	var result = ""
	var stripped = line.strip_edges()

	# Comment
	if stripped.begins_with("#"):
		return "[color=" + COLOR_COMMENT + "]" + _escape_bbcode(line) + "[/color]"

	# Leading whitespace
	var indent = ""
	for c in line:
		if c == ' ' or c == '\t':
			indent += c
		else:
			break
	if indent != "":
		result += indent

	var remaining = line.substr(indent.length())

	# Simple token-based highlighting
	var in_string = false
	var string_char = ""
	var current_token = ""
	var i = 0

	while i < remaining.length():
		var ch = remaining[i]

		# String handling
		if not in_string and (ch == "'" or ch == '"'):
			# Flush current token
			if current_token != "":
				result += _colorize_python_token(current_token)
				current_token = ""
			in_string = true
			string_char = ch
			current_token = ch
			i += 1
			continue

		if in_string:
			current_token += ch
			if ch == string_char:
				result += "[color=" + COLOR_STRING + "]" + _escape_bbcode(current_token) + "[/color]"
				current_token = ""
				in_string = false
			i += 1
			continue

		# Token boundaries
		if ch == ' ' or ch == '(' or ch == ')' or ch == ':' or ch == ',' or ch == '=' or ch == '+' or ch == '.':
			if current_token != "":
				result += _colorize_python_token(current_token)
				current_token = ""
			result += "[color=" + COLOR_NORMAL + "]" + _escape_bbcode(str(ch)) + "[/color]"
			i += 1
			continue

		current_token += ch
		i += 1

	# Flush remaining
	if current_token != "":
		if in_string:
			result += "[color=" + COLOR_STRING + "]" + _escape_bbcode(current_token) + "[/color]"
		else:
			result += _colorize_python_token(current_token)

	return result

func _colorize_python_token(token: String) -> String:
	if token in PYTHON_KEYWORDS:
		if token in ["def", "return", "if", "else", "elif", "for", "while", "in",
			"import", "from", "class", "and", "or", "not", "True", "False", "None"]:
			return "[color=" + COLOR_KEYWORD + "]" + _escape_bbcode(token) + "[/color]"
		else:
			return "[color=" + COLOR_FUNCTION + "]" + _escape_bbcode(token) + "[/color]"

	# Numbers
	if token.is_valid_int() or token.is_valid_float():
		return "[color=" + COLOR_NUMBER + "]" + _escape_bbcode(token) + "[/color]"

	return "[color=" + COLOR_NORMAL + "]" + _escape_bbcode(token) + "[/color]"

func _highlight_html(line: String) -> String:
	var result = ""
	var stripped = line.strip_edges()

	# Comment
	if stripped.begins_with("<!--"):
		return "[color=" + COLOR_COMMENT + "]" + _escape_bbcode(line) + "[/color]"

	# Simple approach: color < > and tag names
	var in_tag = false
	var current_token = ""

	for ch in line:
		if ch == '<':
			if current_token != "":
				result += "[color=" + COLOR_NORMAL + "]" + _escape_bbcode(current_token) + "[/color]"
				current_token = ""
			in_tag = true
			current_token = "<"
		elif ch == '>' and in_tag:
			current_token += ">"
			result += "[color=" + COLOR_TAG + "]" + _escape_bbcode(current_token) + "[/color]"
			current_token = ""
			in_tag = false
		else:
			current_token += ch

	if current_token != "":
		var color = COLOR_TAG if in_tag else COLOR_NORMAL
		result += "[color=" + color + "]" + _escape_bbcode(current_token) + "[/color]"

	return result

func _highlight_css(line: String) -> String:
	var stripped = line.strip_edges()

	# Comment
	if stripped.begins_with("/*") or stripped.begins_with("*"):
		return "[color=" + COLOR_COMMENT + "]" + _escape_bbcode(line) + "[/color]"

	# Selector (lines with {)
	if "{" in line or "}" in line:
		return "[color=" + COLOR_TAG + "]" + _escape_bbcode(line) + "[/color]"

	# Property: value;
	if ":" in stripped:
		var parts = line.split(":", true, 1)
		if parts.size() == 2:
			return "[color=" + COLOR_FUNCTION + "]" + _escape_bbcode(parts[0]) + "[/color]" + \
				"[color=" + COLOR_NORMAL + "]:[/color]" + \
				"[color=" + COLOR_STRING + "]" + _escape_bbcode(parts[1]) + "[/color]"

	return "[color=" + COLOR_NORMAL + "]" + _escape_bbcode(line) + "[/color]"

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

# ─── Event Handlers ──────────────────────────────────────────────────────────

func _on_option_selected(index: int):
	if is_completed:
		return

	# Play mouse click
	_play_click()

	selected_option = index
	run_button.disabled = false

	# Highlight selected option, dim others
	var buttons = options_container.get_children()
	for i in range(buttons.size()):
		var btn = buttons[i] as Button
		if i == index:
			var style = StyleBoxFlat.new()
			style.bg_color = Color("1a3a5c")
			style.border_color = Color("4a9eff")
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			style.set_content_margin_all(8)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_color_override("font_color", Color("e0e0e0"))
		else:
			var style = StyleBoxFlat.new()
			style.bg_color = Color("2d2d3d")
			style.border_color = Color("3d3d5c")
			style.set_border_width_all(1)
			style.set_corner_radius_all(4)
			style.set_content_margin_all(8)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_color_override("font_color", Color("6b7280"))

func _on_run_pressed():
	if is_completed:
		return

	# Play mouse click
	_play_click()

	# Handle free-type or terminal mode
	if is_free_type or is_terminal:
		_run_free_type()
		return

	# Handle multiple-choice mode
	if selected_option < 0:
		return

	is_completed = true
	timer_running = false

	var options = current_challenge.get("options", [])
	var is_correct = false
	if selected_option < options.size():
		is_correct = options[selected_option].get("correct", false)

	# Show output panel if hidden
	if not output_panel.visible:
		output_panel.visible = true
		toggle_output_button.text = "◀ Hide Output"

	# Update output panel
	output_display.bbcode_enabled = true
	if is_correct:
		var correct_output = current_challenge.get("correct_output", "Success!")
		if current_challenge.get("output_type", "terminal") == "browser":
			output_display.text = correct_output
		else:
			output_display.text = "[color=#98c379]" + correct_output + "[/color]"

		feedback_label.text = "✅ Correct!"
		feedback_label.add_theme_color_override("font_color", Color("98c379"))
		if correct_sfx.stream:
			correct_sfx.play()
	else:
		var error_output = current_challenge.get("error_output", "Error!")
		output_display.text = "[color=#e06c75]" + error_output + "[/color]"

		feedback_label.text = "❌ Incorrect — try to learn from this!"
		feedback_label.add_theme_color_override("font_color", Color("e06c75"))
		if wrong_sfx.stream:
			wrong_sfx.play()

	feedback_label.visible = true

	# Color the option buttons green/red
	var buttons = options_container.get_children()
	for i in range(buttons.size()):
		var btn = buttons[i] as Button
		btn.disabled = true
		if options[i].get("correct", false):
			var style = StyleBoxFlat.new()
			style.bg_color = Color("1a3a2a")
			style.border_color = Color("98c379")
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			style.set_content_margin_all(8)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("disabled", style)
			btn.add_theme_color_override("font_disabled_color", Color("98c379"))
		elif i == selected_option:
			var style = StyleBoxFlat.new()
			style.bg_color = Color("3a1a1a")
			style.border_color = Color("e06c75")
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			style.set_content_margin_all(8)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("disabled", style)
			btn.add_theme_color_override("font_disabled_color", Color("e06c75"))

	# Disable run button
	run_button.disabled = true

	# Show results after delay
	await get_tree().create_timer(2.0).timeout
	_show_results(is_correct)

func _on_time_up():
	if is_completed:
		return

	is_completed = true
	feedback_label.text = "⏰ Time's up!"
	feedback_label.add_theme_color_override("font_color", Color("e06c75"))
	feedback_label.visible = true
	run_button.disabled = true

	# Disable all option buttons
	for btn in options_container.get_children():
		btn.disabled = true

	if wrong_sfx.stream:
		wrong_sfx.play()

	await get_tree().create_timer(1.5).timeout
	_show_results(false)

func _on_hint_pressed():
	# Play mouse click
	_play_click()
	
	# Create a guilt trip overlay dynamically
	var overlay = ColorRect.new()
	overlay.name = "GuiltTripOverlay"
	overlay.color = Color(0, 0, 0, 0.8) # Dark translucent backdrop
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100 # Put on top of everything
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("1e1e2e")
	style.border_color = Color("e06c75") # Red border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "✨ OVERFLOW STACK PREMIUM ✨"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("e0c675")) # Gold/Yellow
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var text_label = Label.new()
	text_label.text = "Tired of staring at bugs?\nUnlock the exact answer instantly with Overflow Stack Premium!\n\n(Warning: Relying on copy-paste removes critical thinking skills.\nAre you sure you want to give up and skip the learning process?)"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(450, 0)
	text_label.add_theme_color_override("font_color", Color("abb2bf"))
	text_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(text_label)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	var yes_btn = Button.new()
	yes_btn.text = "View Answer (Free Trial)"
	var yes_style = StyleBoxFlat.new()
	yes_style.bg_color = Color("3a2a1a") # Gold-ish dark
	yes_style.border_color = Color("e0c675")
	yes_style.set_border_width_all(1)
	yes_style.set_corner_radius_all(4)
	yes_style.set_content_margin_all(10)
	yes_btn.add_theme_stylebox_override("normal", yes_style)
	
	var yes_hover = yes_style.duplicate()
	yes_hover.bg_color = Color("5a4a2a")
	yes_btn.add_theme_stylebox_override("hover", yes_hover)
	yes_btn.add_theme_color_override("font_color", Color("e0c675"))
	
	var no_btn = Button.new()
	no_btn.text = "Close Ad  [x]"
	var no_style = StyleBoxFlat.new()
	no_style.bg_color = Color("2a2a3a")
	no_style.border_color = Color("5c6370")
	no_style.set_border_width_all(1)
	no_style.set_corner_radius_all(4)
	no_style.set_content_margin_all(10)
	no_btn.add_theme_stylebox_override("normal", no_style)
	
	var no_hover = no_style.duplicate()
	no_hover.bg_color = Color("3a3a4a")
	no_btn.add_theme_stylebox_override("hover", no_hover)
	no_btn.add_theme_color_override("font_color", Color("abb2bf"))
	
	hbox.add_child(yes_btn)
	hbox.add_child(no_btn)
	
	add_child(overlay)
	
	yes_btn.pressed.connect(func():
		_play_click()
		overlay.queue_free()
		_show_overflow_stack()
	)
	
	no_btn.pressed.connect(func():
		_play_click()
		overlay.queue_free()
	)

func _on_reload_pressed():
	# Re-show the initial output state
	_setup_output_panel()

func _on_toggle_output_pressed():
	_play_click()
	output_panel.visible = !output_panel.visible
	toggle_output_button.text = "◀ Hide Output" if output_panel.visible else "▶ Show Output"

func _on_free_type_changed():
	# Enable run button when player has typed something
	if (is_free_type or is_terminal) and not is_completed:
		run_button.disabled = free_type_edit.text.strip_edges() == ""

func _on_close_pressed():
	_play_click()
	emit_signal("challenge_completed", false, current_challenge.get("id", ""))
	queue_free()

# ─── SFX Helper ──────────────────────────────────────────────────────────────

func _play_click():
	# Create a fresh one-shot player to guarantee sound plays
	var player = AudioStreamPlayer.new()
	player.stream = preload("res://Sounds/UI SFX/UIClick_BLEEOOP_Mouse_Click.wav")
	player.volume_db = -6.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _on_continue_pressed():
	var success = results_title.text.contains("Correct") or results_title.text.contains("Solved")
	emit_signal("challenge_completed", success, current_challenge.get("id", ""))
	queue_free()

# ─── Results ─────────────────────────────────────────────────────────────────

func _show_results(success: bool):
	results_overlay.visible = true

	if success:
		results_title.text = "✅ Challenge Solved!"
		results_title.add_theme_color_override("font_color", Color("98c379"))
		results_text.text = "Great job! You got it right."

		# Hide X button on success for NPC challenges so they can't accidentally quit
		if hide_close_button:
			close_button.visible = false
			# Auto-emit success after a short delay
			await get_tree().create_timer(2.0).timeout
			emit_signal("challenge_completed", true, current_challenge.get("id", ""))
	else:
		results_title.text = "❌ Not Quite..."
		results_title.add_theme_color_override("font_color", Color("e06c75"))
		# Show which was correct
		var options = current_challenge.get("options", [])
		var correct_text = ""
		for opt in options:
			if opt.get("correct", false):
				correct_text = opt.get("text", "")
				break
		results_text.text = "The correct answer was:\n" + correct_text

	results_text.add_theme_color_override("font_color", Color("abb2bf"))

	# Animate in
	results_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(results_overlay, "modulate:a", 1.0, 0.3)

# ─── Free-Type Validation ────────────────────────────────────────────────────

func _run_free_type():
	var player_code = free_type_edit.text.strip_edges()
	var expected_answers = current_challenge.get("expected_answers", [])

	# Check if the player's code matches any accepted answer
	var is_correct = false
	for answer in expected_answers:
		if player_code.strip_edges() == answer.strip_edges():
			is_correct = true
			break

	# Also check with normalized whitespace (collapse multiple spaces)
	if not is_correct:
		var normalized_player = _normalize_whitespace(player_code)
		for answer in expected_answers:
			if normalized_player == _normalize_whitespace(answer.strip_edges()):
				is_correct = true
				break

	# Show output panel if hidden
	if not output_panel.visible:
		output_panel.visible = true
		toggle_output_button.text = "◀ Hide Output"

	output_display.bbcode_enabled = true

	if is_correct:
		# ── Correct: lock everything and show results ──
		is_completed = true
		timer_running = false
		free_type_edit.editable = false

		var correct_output = current_challenge.get("correct_output", "Success!")
		if current_challenge.get("output_type", "terminal") == "browser":
			output_display.text = correct_output
		else:
			output_display.text = "[color=#98c379]" + correct_output + "[/color]"

		feedback_label.text = "✅ Correct! Your code works!"
		feedback_label.add_theme_color_override("font_color", Color("98c379"))
		feedback_label.visible = true
		run_button.disabled = true
		if correct_sfx.stream:
			correct_sfx.play()

		await get_tree().create_timer(2.0).timeout
		_show_results(true)
	else:
		# ── Wrong: show progressive hints ──
		_attempts += 1
		
		# Get hints and answer
		var hints = current_challenge.get("progressive_hints", [])
		var expected_answers_list = current_challenge.get("expected_answers", [])
		var answer_text = expected_answers_list[0] if expected_answers_list.size() > 0 else ""
		
		var error_output = current_challenge.get("error_output", "Error!")
		
		if hints.size() > 0:
			# Progressive hint logic
			if _attempts <= hints.size():
				# Show next hint
				var hint = hints[_attempts - 1]
				output_display.text = "[color=#e06c75]" + error_output + "[/color]\n\n[color=#d19a66]HINT " + str(_attempts) + ": " + hint + "[/color]"
				feedback_label.text = "❌ Not quite — read the hint in the output panel!"
			else:
				# Show the answer
				output_display.text = "[color=#e06c75]" + error_output + "[/color]\n\n[color=#98c379]ANSWER: Just type exactly: " + answer_text + "[/color]"
				feedback_label.text = "❌ Still stuck? I put the answer in the output panel!"
		else:
			# Normal error feedback
			output_display.text = "[color=#e06c75]" + error_output + "[/color]"
			feedback_label.text = "❌ Not quite — check your code and try again!"

		feedback_label.add_theme_color_override("font_color", Color("e06c75"))
		feedback_label.visible = true
		if wrong_sfx.stream:
			wrong_sfx.play()

		# Keep editor editable so they can fix and retry
		free_type_edit.editable = true
		run_button.disabled = false

		# Show red squiggle linter
		linter_label.visible = true
		linter_label.bbcode_enabled = true
		linter_label.text = "[color=#e06c75]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~[/color] [color=#5c6370]syntax error[/color]"

func _normalize_whitespace(text: String) -> String:
	# Collapse all whitespace sequences into single spaces
	var result = ""
	var prev_was_space = false
	for c in text:
		if c == ' ' or c == '\t' or c == '\n':
			if not prev_was_space:
				result += " "
				prev_was_space = true
		else:
			result += c
			prev_was_space = false
	return result

func _style_free_type_edit():
	# Dark theme for the code text editor
	var style = StyleBoxFlat.new()
	style.bg_color = Color("1e1e2e")
	style.border_color = Color("3d3d5c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	free_type_edit.add_theme_stylebox_override("normal", style)
	free_type_edit.add_theme_stylebox_override("focus", style)
	free_type_edit.add_theme_color_override("font_color", Color("abb2bf"))
	free_type_edit.add_theme_color_override("caret_color", Color("61afef"))
	free_type_edit.add_theme_font_size_override("font_size", 14)

# ─── Input Override ──────────────────────────────────────────────────────────

func _input(event):
	# When the player is typing in the free-type editor, let ALL keys through
	if (is_free_type or is_terminal) and free_type_edit.has_focus():
		# Play keypad SFX on real key presses only (not held-key echoes)
		if event is InputEventKey and event.pressed and not event.is_echo():
			if keypad_sfx and keypad_sfx.stream:
				keypad_sfx.play()
		return

	# Otherwise block game-specific actions (movement, interact, etc.)
	if event.is_action("interact") or event.is_action("ui_cancel") \
		or event.is_action("up") or event.is_action("down") \
		or event.is_action("left") or event.is_action("right"):
		get_viewport().set_input_as_handled()

# ─── Overflow Stack Popup ───────────────────────────────────────────────────

const OVERFLOW_USERS = [
	"xX_codeMaster69_Xx  •  ⭐ 42,069 rep",
	"django_guru_420  •  ⭐ 1,337 rep",
	"definitely_not_AI  •  ⭐ 99,999 rep",
	"i_hate_css  •  ⭐ 8,008 rep",
	"copy_paste_engineer  •  ⭐ 12,345 rep",
	"stackoverflow_is_life  •  ⭐ 77,777 rep",
]

const OVERFLOW_INTROS = [
	"Smh, this question again... Anyway, ",
	"I literally answered this 5 minutes ago but okay. ",
	"*sigh* Did you even try googling first? ",
	"This is BASIC stuff but I'll help because I'm nice. ",
	"Marking as duplicate but here's the answer anyway: ",
	"Not sure why this has 47 upvotes but fine. ",
]

func _show_overflow_stack():
	var hint_text = current_challenge.get("hint", "No hint available.")
	var title = current_challenge.get("title", "Help")

	# Style the overlay
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("fdf7e2")  # Stack Overflow cream
	panel_style.border_color = Color("e3d5a0")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	overflow_overlay.add_theme_stylebox_override("panel", panel_style)

	# Logo
	stack_logo.add_theme_color_override("font_color", Color("f48024"))  # SO orange
	stack_logo.add_theme_font_size_override("font_size", 16)

	# Question
	stack_question.text = "Q: How do I fix \"" + title + "\"? Please help!!!"
	stack_question.add_theme_color_override("font_color", Color("3b4045"))
	stack_question.add_theme_font_size_override("font_size", 13)

	# Votes
	var vote_count = randi_range(12, 247)
	stack_votes.text = "▲ " + str(vote_count) + " votes  •  ✅ Accepted Answer"
	stack_votes.add_theme_color_override("font_color", Color("6a9955"))
	stack_votes.add_theme_font_size_override("font_size", 12)

	# Answer — grumpy but helpful
	var intro = OVERFLOW_INTROS[randi() % OVERFLOW_INTROS.size()]
	stack_answer.bbcode_enabled = true
	stack_answer.text = "[color=#3b4045]" + intro + hint_text + "[/color]"
	stack_answer.add_theme_font_size_override("normal_font_size", 13)

	# User
	stack_user.text = "answered by " + OVERFLOW_USERS[randi() % OVERFLOW_USERS.size()]
	stack_user.add_theme_color_override("font_color", Color("6a737c"))
	stack_user.add_theme_font_size_override("font_size", 11)

	overflow_overlay.visible = true

	# Animate in
	overflow_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(overflow_overlay, "modulate:a", 1.0, 0.25)

# ─── Light Theme Troll ─────────────────────────────────────────────────────

func _on_gear_pressed():
	if is_dark_theme:
		_troll_light_theme()
	else:
		_restore_dark_theme()

func _troll_light_theme():
	is_dark_theme = false

	# Blinding white flash
	light_flash.visible = true
	light_flash.modulate.a = 1.0

	# Screen shake
	var original_pos = position
	var tween = create_tween()
	for i in range(6):
		var shake_x = randf_range(-8, 8)
		var shake_y = randf_range(-5, 5)
		tween.tween_property(self, "position", original_pos + Vector2(shake_x, shake_y), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)

	# Fade flash down
	var flash_tween = create_tween()
	flash_tween.tween_property(light_flash, "modulate:a", 0.0, 0.8)
	flash_tween.tween_callback(func(): light_flash.visible = false)

	# Visual novel dialogue reaction
	_show_troll_dialogue([
		{"name": "☀️ IDE", "text": "AAAGHHH!!! MY PIXELS ARE BURNING!!!"},
		{"name": "😵 You", "text": "...Why did I click that? WHO uses light theme?!"},
		{"name": "🌙 IDE", "text": "Switching back to dark mode... my eyes thank you."},
	])

func _show_troll_dialogue(lines: Array):
	_troll_lines = lines
	_troll_line_index = 0

	# Style the dialogue box
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("1a1a2e")
	panel_style.border_color = Color("e06c75")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(0)
	troll_dialogue.add_theme_stylebox_override("panel", panel_style)

	troll_dialogue.visible = true
	_advance_troll_dialogue()

func _advance_troll_dialogue():
	if _troll_line_index >= _troll_lines.size():
		# Done — close and restore dark theme
		troll_dialogue.visible = false
		_restore_dark_theme()
		return

	var line = _troll_lines[_troll_line_index]

	# Speaker name
	troll_name.text = line.get("name", "")
	troll_name.add_theme_color_override("font_color", Color("61afef"))
	troll_name.add_theme_font_size_override("font_size", 14)

	# Typewriter effect
	var text = line.get("text", "")
	troll_text.text = text
	troll_text.visible_ratio = 0.0
	troll_text.add_theme_color_override("default_color", Color("e0e0e0"))
	troll_text.add_theme_font_size_override("normal_font_size", 14)

	troll_continue.visible = false
	troll_continue.add_theme_color_override("font_color", Color("abb2bf"))

	_troll_typing = true

	if _troll_tween and _troll_tween.is_valid():
		_troll_tween.kill()

	var duration = text.length() / 40.0  # 40 chars per second
	_troll_tween = create_tween()
	_troll_tween.tween_property(troll_text, "visible_ratio", 1.0, duration)
	_troll_tween.tween_callback(_on_troll_type_done)

func _on_troll_type_done():
	_troll_typing = false
	troll_continue.visible = true

	# Blink the continue indicator
	var blink = create_tween().set_loops()
	blink.tween_property(troll_continue, "modulate:a", 0.3, 0.4)
	blink.tween_property(troll_continue, "modulate:a", 1.0, 0.4)

func _on_troll_panel_clicked(event: InputEvent):
	if not troll_dialogue.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if _troll_typing:
			# Skip typewriter
			if _troll_tween and _troll_tween.is_valid():
				_troll_tween.kill()
			troll_text.visible_ratio = 1.0
			_on_troll_type_done()
		else:
			# Advance to next line
			_troll_line_index += 1
			_advance_troll_dialogue()

func _restore_dark_theme():
	is_dark_theme = true
	light_flash.visible = false
	troll_dialogue.visible = false

# ─── Item Buff System ────────────────────────────────────────────────────────

func _on_item_button_pressed():
	if is_completed:
		return
	_play_click()
	if item_popup.visible:
		item_popup.visible = false
		return
	_populate_item_popup()

func _populate_item_popup():
	# Clear old items
	for child in item_list.get_children():
		child.queue_free()

	# Style the popup
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("1e1e2e")
	panel_style.border_color = Color("4a9eff")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(10)
	item_popup.add_theme_stylebox_override("panel", panel_style)

	item_popup_title.add_theme_color_override("font_color", Color("e0e0e0"))
	item_popup_title.add_theme_font_size_override("font_size", 14)

	# Get usable items for this challenge type
	var challenge_type = current_challenge.get("type", "debug")
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		_show_no_items_message("Inventory not available")
		return

	var usable_items: Array = []
	for item_id in CodingItems.ITEMS:
		var item_def = CodingItems.ITEMS[item_id]
		if challenge_type in item_def["usable_on"] and inv.has_item(item_id):
			usable_items.append(item_def)

	if usable_items.is_empty():
		_show_no_items_message("No usable items for this challenge type")
		return

	# Create a button for each usable item
	for item_def in usable_items:
		var item_btn = Button.new()
		var icon_text = ""
		match item_def["id"]:
			CodingItems.RUBBER_DUCK: icon_text = "🦆"
			CodingItems.WANSTER_ENERGY: icon_text = "☕"
			CodingItems.SYNTAX_GLASSES: icon_text = "👓"
			CodingItems.OS_PREMIUM: icon_text = "💳"
			CodingItems.ENCRYPTED_DRIVE: icon_text = "💾"

		# Show remaining uses
		var qty_text = ""
		if item_def.get("consumable", false):
			var qty = inv.get_item_quantity(item_def["id"])
			qty_text = " (x" + str(qty) + ")"
		else:
			qty_text = " (∞)"

		item_btn.text = icon_text + " " + item_def["name"] + qty_text
		item_btn.tooltip_text = item_def.get("buff_description", item_def["description"])
		item_btn.custom_minimum_size = Vector2(0, 36)
		item_btn.add_theme_font_size_override("font_size", 12)

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color("2a2a3e")
		btn_style.border_color = Color("3d3d5c")
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.set_content_margin_all(6)
		item_btn.add_theme_stylebox_override("normal", btn_style)
		item_btn.add_theme_color_override("font_color", Color("e0e0e0"))

		var hover_style = btn_style.duplicate()
		hover_style.bg_color = Color("3a3a5e")
		hover_style.border_color = Color("4a9eff")
		item_btn.add_theme_stylebox_override("hover", hover_style)

		# Capture item_id for the lambda
		var captured_id = item_def["id"]
		item_btn.pressed.connect(func(): _use_item(captured_id))
		item_list.add_child(item_btn)

	item_popup.visible = true
	# Animate in
	item_popup.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(item_popup, "modulate:a", 1.0, 0.2)

func _show_no_items_message(msg: String):
	var label = Label.new()
	label.text = msg
	label.add_theme_color_override("font_color", Color("6a6a8a"))
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_list.add_child(label)
	item_popup.visible = true

func _use_item(item_id: String):
	item_popup.visible = false

	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return

	var item_def = CodingItems.ITEMS.get(item_id, {})
	var item_name = item_def.get("name", "Item")

	# Consume if consumable
	if item_def.get("consumable", false):
		inv.remove_item(item_id)

	# Apply the buff
	match item_id:
		CodingItems.RUBBER_DUCK:
			_buff_rubber_duck()
		CodingItems.WANSTER_ENERGY:
			_buff_wanster_energy()
		CodingItems.SYNTAX_GLASSES:
			_buff_syntax_glasses()
		CodingItems.OS_PREMIUM:
			_buff_os_premium()
		CodingItems.ENCRYPTED_DRIVE:
			_buff_encrypted_drive()

	# Show usage feedback
	feedback_label.text = "✨ Used: " + item_name + "!"
	feedback_label.add_theme_color_override("font_color", Color("61afef"))
	feedback_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if not is_completed:
		feedback_label.visible = false

# ─── Buff Implementations ────────────────────────────────────────────────────

func _buff_rubber_duck():
	# Highlight the bug line in yellow in the code display
	var bug_line = current_challenge.get("bug_line", -1)
	if bug_line < 0:
		feedback_label.text = "🦆 Quack! ...but there's no bug to find here."
		return

	var code_lines = current_challenge.get("code_lines", [])
	var highlighted_code = ""
	for i in range(code_lines.size()):
		var line_num = str(i + 1).pad_zeros(2) if code_lines.size() > 9 else str(i + 1)
		var line_text = code_lines[i]
		if i == bug_line:
			# Highlight this line with a yellow background marker
			highlighted_code += "[color=#e5c07b][b]→ " + line_num + "  " + line_text + "  ◄ 🦆[/b][/color]\n"
		else:
			highlighted_code += "  " + line_num + "  " + line_text + "\n"
	code_display.text = highlighted_code

func _buff_wanster_energy():
	# Add 15 seconds to the timer
	if timer_running:
		time_remaining += 15.0
		_update_timer_display()
		feedback_label.text = "☕ +15 SECONDS! MAXIMUM ENERGY!"
	else:
		feedback_label.text = "☕ No timer active, but you feel energized!"

func _buff_syntax_glasses():
	# Remove one incorrect option button
	var buttons = options_container.get_children()
	var wrong_buttons: Array = []
	var options = current_challenge.get("options", [])

	for i in range(min(buttons.size(), options.size())):
		if not options[i].get("correct", false) and buttons[i].visible:
			wrong_buttons.append(buttons[i])

	if wrong_buttons.is_empty():
		feedback_label.text = "👓 No wrong options to remove!"
		return

	# Pick a random wrong one and cross it out
	var to_remove = wrong_buttons[randi() % wrong_buttons.size()]
	to_remove.disabled = true
	to_remove.modulate = Color(0.4, 0.4, 0.4, 0.5)
	to_remove.text = "✕ " + to_remove.text

func _buff_os_premium():
	# Auto-type the first half of the expected answer
	var expected = current_challenge.get("expected_answers", [])
	if expected.is_empty():
		feedback_label.text = "💳 No answer to auto-complete!"
		return

	var answer = expected[0]
	var half = answer.substr(0, int(answer.length() * 0.5))
	free_type_edit.text = half
	free_type_edit.visible = true
	run_button.disabled = false

func _buff_encrypted_drive():
	# Instantly solve the challenge
	is_completed = true

	# Show correct output
	var correct_output = current_challenge.get("correct_output", "✓ Correct!")
	output_display.text = correct_output

	# Play correct SFX
	if correct_sfx and correct_sfx.stream:
		correct_sfx.play()

	# Show results
	feedback_label.text = "💾 Encrypted Drive activated! Solution uploaded."
	feedback_label.add_theme_color_override("font_color", Color("98c379"))
	feedback_label.visible = true
	run_button.disabled = true

	await get_tree().create_timer(1.5).timeout
	_show_results(true)

# ─── Programmatic Locks ──────────────────────────────────────────────────────

func lock_typing(_locked: bool):
	if is_free_type or is_terminal:
		free_type_edit.editable = not _locked
		if _locked:
			run_button.disabled = true
		else:
			# only enable run if there's text
			run_button.disabled = free_type_edit.text.strip_edges() == ""
