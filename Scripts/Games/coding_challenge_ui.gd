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

# ─── Node References ─────────────────────────────────────────────────────────
@onready var title_label: Label = $TitleBar/TitleLabel
@onready var timer_label: Label = $TitleBar/TimerLabel
@onready var close_button: Button = $TitleBar/CloseButton

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

	# Connect signals
	close_button.pressed.connect(_on_close_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	run_button.pressed.connect(_on_run_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	toggle_output_button.pressed.connect(_on_toggle_output_pressed)
	free_type_edit.text_changed.connect(_on_free_type_changed)

	# Initial state
	results_overlay.visible = false
	hint_label.visible = false
	timer_label.visible = false
	feedback_label.visible = false
	run_button.disabled = true
	free_type_edit.visible = false

	# Style the free-type editor
	_style_free_type_edit()

	# Load a default challenge if none set (for testing)
	if current_challenge.is_empty():
		var ChallengeData = preload("res://Scripts/Games/coding_challenge_data.gd")
		load_challenge(ChallengeData.python_challenges[0])

func _process(delta):
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
	is_free_type = challenge.get("type", "") == "free_type"

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

	if is_free_type:
		run_button.disabled = true  # enabled when they type something
	else:
		run_button.disabled = true

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

	# Hint
	hint_label.visible = false
	hint_label.text = current_challenge.get("hint", "")
	hint_button.visible = current_challenge.get("hint", "") != ""

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
		_update_timer_display()
	else:
		timer_label.visible = false
		timer_running = false

func _setup_bottom_bar():
	progress_label.text = current_challenge.get("topic", "").to_upper() + " — " + current_challenge.get("title", "")

func _update_timer_display():
	var seconds = int(time_remaining)
	var color = "#98c379" # green
	if seconds <= 10:
		color = "#e06c75" # red
	elif seconds <= 20:
		color = "#d19a66" # orange
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

	# Handle free-type mode
	if is_free_type:
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
	hint_label.visible = !hint_label.visible

func _on_reload_pressed():
	# Re-show the initial output state
	_setup_output_panel()

func _on_toggle_output_pressed():
	output_panel.visible = !output_panel.visible
	toggle_output_button.text = "◀ Hide Output" if output_panel.visible else "▶ Show Output"

func _on_free_type_changed():
	# Enable run button when player has typed something
	if is_free_type and not is_completed:
		run_button.disabled = free_type_edit.text.strip_edges() == ""

func _on_close_pressed():
	emit_signal("challenge_completed", false, current_challenge.get("id", ""))
	queue_free()

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
		# ── Wrong: show feedback but let them try again ──
		var error_output = current_challenge.get("error_output", "Error!")
		output_display.text = "[color=#e06c75]" + error_output + "[/color]"

		feedback_label.text = "❌ Not quite — check your code and try again!"
		feedback_label.add_theme_color_override("font_color", Color("e06c75"))
		feedback_label.visible = true
		if wrong_sfx.stream:
			wrong_sfx.play()

		# Keep editor editable so they can fix and retry
		free_type_edit.editable = true
		run_button.disabled = false

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
	if is_free_type and free_type_edit.has_focus():
		return

	# Otherwise block game-specific actions (movement, interact, etc.)
	if event.is_action("interact") or event.is_action("ui_cancel") \
		or event.is_action("move_up") or event.is_action("move_down") \
		or event.is_action("move_left") or event.is_action("move_right"):
		get_viewport().set_input_as_handled()
