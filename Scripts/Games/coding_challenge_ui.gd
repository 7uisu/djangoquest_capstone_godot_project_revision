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
var _challenge_hints_used: int = 0  # hints used for current challenge (max 4 before Overflow Stack)
const MAX_HINTS: int = 5             # 4 progressive + 1 Overflow Stack = 5 total

# Global session hint counter — shared across ALL challenges in one session
# Allows the adviser's rule: "only 5 hints total per session"
var global_hints_used: int = 0
const GLOBAL_MAX_HINTS: int = 5

# ─── Node References ─────────────────────────────────────────────────────────
# Screens
@onready var ide_screen: Control = $IDEScreen
@onready var browser_screen: Control = $BrowserScreen
var _is_browser_visible: bool = false

@onready var title_label: Label = $IDEScreen/TitleBar/TitleLabel
@onready var timer_label: Label = $IDEScreen/TitleBar/TimerLabel
@onready var close_button: Button = $IDEScreen/TitleBar/CloseButton
@onready var gear_button: Button = $IDEScreen/TitleBar/GearButton

# Mission Panel
@onready var mission_title: Label = $IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/MissionTitle
@onready var steps_container: VBoxContainer = $IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/StepsContainer
@onready var hint_button: Button = $IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/HintButton
@onready var hint_label: RichTextLabel = $IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/HintLabel
@onready var overflow_stack_button: Button = $IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/OverflowStackButton
@onready var alt_tab_button: Button = $IDEScreen/MainContent/MissionPanel/MissionScroll/MissionVBox/AltTabButton

# Code Panel
@onready var file_tabs_container: HBoxContainer = $IDEScreen/MainContent/CodePanel/CodeVBox/FileTabs
@onready var file_tab_label: Label = $IDEScreen/MainContent/CodePanel/CodeVBox/FileTabs/FileTab
@onready var code_display: RichTextLabel = $IDEScreen/MainContent/CodePanel/CodeVBox/CodeScroll/CodeDisplay
@onready var code_edit: CodeEdit = $IDEScreen/MainContent/CodePanel/CodeVBox/CodeEditor
@onready var code_scroll: ScrollContainer = $IDEScreen/MainContent/CodePanel/CodeVBox/CodeScroll
@onready var options_label: Label = $IDEScreen/MainContent/CodePanel/CodeVBox/OptionsLabel
@onready var options_container: VBoxContainer = $IDEScreen/MainContent/CodePanel/CodeVBox/OptionsContainer
@onready var free_type_edit: TextEdit = $IDEScreen/MainContent/CodePanel/CodeVBox/FreeTypeEdit
@onready var linter_label: RichTextLabel = $IDEScreen/MainContent/CodePanel/CodeVBox/LinterLabel

# Terminal Strip (bottom of code panel)
@onready var terminal_strip: PanelContainer = $IDEScreen/MainContent/CodePanel/CodeVBox/TerminalStrip
@onready var terminal_header: Label = $IDEScreen/MainContent/CodePanel/CodeVBox/TerminalStrip/TerminalVBox/TerminalHeader
@onready var terminal_output: RichTextLabel = $IDEScreen/MainContent/CodePanel/CodeVBox/TerminalStrip/TerminalVBox/TerminalScroll/TerminalOutput

# Browser Screen
@onready var browser_back_btn: Button = $BrowserScreen/BrowserToolbar/BackToIDEButton
@onready var browser_address: Label = $BrowserScreen/BrowserToolbar/AddressBar
@onready var reload_button: Button = $BrowserScreen/BrowserToolbar/ReloadButton
@onready var browser_preview: RichTextLabel = $BrowserScreen/BrowserMargin/BrowserPreview

# Bottom Bar
@onready var run_button: Button = $IDEScreen/BottomBar/RunButton
@onready var progress_label: Label = $IDEScreen/BottomBar/ProgressLabel
@onready var feedback_label: Label = $IDEScreen/BottomBar/FeedbackLabel

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

# Overflow Stack (overlay on top of everything)
@onready var overflow_overlay: PanelContainer = $OverflowStackOverlay
@onready var stack_question: Label = $OverflowStackOverlay/StackVBox/StackQuestion
@onready var stack_votes: Label = $OverflowStackOverlay/StackVBox/StackVotes
@onready var stack_answer: RichTextLabel = $OverflowStackOverlay/StackVBox/StackAnswer
@onready var stack_user: Label = $OverflowStackOverlay/StackVBox/StackUser
@onready var stack_logo: Label = $OverflowStackOverlay/StackVBox/StackHeader/StackLogo
@onready var stack_close_button: Button = $OverflowStackOverlay/StackVBox/StackHeader/StackCloseButton

# Item Buff System
@onready var item_button: Button = $IDEScreen/TitleBar/ItemButton
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
	
	# IDE Code Monospace Fonts
	var code_font = preload("res://Textures/Fonts/JetBrainsMono/JetBrainsMono-Regular.ttf")
	code_display.add_theme_font_override("normal_font", code_font)
	code_display.add_theme_font_size_override("normal_font_size", 14)
	terminal_output.add_theme_font_override("normal_font", code_font)
	terminal_output.add_theme_font_size_override("normal_font_size", 14)
	free_type_edit.add_theme_font_override("font", code_font)
	free_type_edit.add_theme_font_size_override("font_size", 14)
	stack_answer.add_theme_font_override("normal_font", code_font)
	stack_answer.add_theme_font_size_override("normal_font_size", 13)

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
	free_type_edit.text_changed.connect(_on_free_type_changed)
	gear_button.pressed.connect(_on_gear_pressed)
	stack_close_button.pressed.connect(func(): overflow_overlay.visible = false)
	troll_dialogue.gui_input.connect(_on_troll_panel_clicked)
	troll_dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
	item_button.pressed.connect(_on_item_button_pressed)
	item_popup_close.pressed.connect(func(): item_popup.visible = false)

	# New screen-switching buttons
	alt_tab_button.pressed.connect(_switch_to_browser)
	browser_back_btn.pressed.connect(_switch_to_ide)
	overflow_stack_button.pressed.connect(_on_overflow_stack_btn_pressed)

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
	browser_screen.visible = false

	# Style new UI elements
	_style_terminal_strip()
	_style_browser_screen()
	_style_action_buttons()

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
	_challenge_hints_used = 0  # Reset per-challenge hint counter
	is_free_type = challenge.get("type", "") == "free_type"
	is_terminal = challenge.get("type", "") == "terminal"

	_setup_title()
	_setup_mission_panel()
	_setup_code_panel()
	_setup_terminal()
	_setup_timer()
	_setup_bottom_bar()

	results_overlay.visible = false
	feedback_label.visible = false

	if is_free_type or is_terminal:
		run_button.disabled = true  # enabled when they type something
	else:
		run_button.disabled = true

	linter_label.visible = false
	overflow_overlay.visible = false

	# Reset browser and terminal
	_switch_to_ide_instant()
	_setup_terminal()
	_setup_file_tabs()

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
	var code_font = preload("res://Textures/Fonts/JetBrainsMono/JetBrainsMono-Regular.ttf")
	var steps = current_challenge.get("mission_steps", [])
	for i in range(steps.size()):
		var step_label = Label.new()
		step_label.text = str(i + 1) + ". " + steps[i]
		step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step_label.add_theme_color_override("font_color", Color("abb2bf"))
		step_label.add_theme_font_override("font", code_font)
		step_label.add_theme_font_size_override("font_size", 12)
		steps_container.add_child(step_label)

	# Hint button — label updates with remaining count
	hint_label.visible = false
	hint_label.text = current_challenge.get("hint", "")
	var has_hint = current_challenge.get("hint", "") != "" or current_challenge.get("hints", []).size() > 0
	hint_button.visible = has_hint
	if has_hint:
		_update_hint_button_label()

func _setup_code_panel():
	# File tab
	file_tab_label.text = "  📄 " + current_challenge.get("file_name", "code.py")

	var code_lines = current_challenge.get("code_lines", [])
	var bug_line = current_challenge.get("bug_line", -1)
	var topic = current_challenge.get("topic", "python")
	var ctype = current_challenge.get("type", "debug")

	# ── CodeEdit mode: free_type and terminal challenges ──
	if is_free_type or is_terminal:
		# Hide the old RichTextLabel display and TextEdit
		code_scroll.visible = false
		free_type_edit.visible = false
		options_label.visible = false
		options_container.visible = false
		for child in options_container.get_children():
			child.queue_free()

		# Show CodeEdit
		code_edit.visible = true

		# Build the full code content: existing code + starter area
		var starter = current_challenge.get("starter_code", "")
		var full_code = ""
		if code_lines.size() > 0:
			full_code = "\n".join(code_lines)
			if starter != "":
				full_code += "\n" + starter
		else:
			full_code = starter

		code_edit.text = full_code
		code_edit.editable = true

		# Apply syntax highlighting
		_setup_code_highlighter(topic)

		# Style CodeEdit
		var code_font = preload("res://Textures/Fonts/JetBrainsMono/JetBrainsMono-Regular.ttf")
		code_edit.add_theme_font_override("font", code_font)
		code_edit.add_theme_font_size_override("font_size", 14)

		if is_terminal:
			# Terminal green-on-black style
			code_edit.add_theme_color_override("font_color", Color("00ff41"))
			var term_style = StyleBoxFlat.new()
			term_style.bg_color = Color("0d0d0d")
			term_style.border_color = Color("333333")
			term_style.set_border_width_all(1)
			term_style.set_corner_radius_all(4)
			term_style.set_content_margin_all(8)
			code_edit.add_theme_stylebox_override("normal", term_style)
			code_edit.add_theme_stylebox_override("focus", term_style)
		else:
			# IDE dark theme
			code_edit.add_theme_color_override("font_color", Color("abb2bf"))
			var ide_style = StyleBoxFlat.new()
			ide_style.bg_color = Color("1e1e2e")
			ide_style.border_color = Color("3d3d5c")
			ide_style.set_border_width_all(1)
			ide_style.set_corner_radius_all(0)
			ide_style.set_content_margin_all(8)
			code_edit.add_theme_stylebox_override("normal", ide_style)
			code_edit.add_theme_stylebox_override("focus", ide_style)

		# Place cursor at the end
		code_edit.set_caret_line(code_edit.get_line_count() - 1)
		code_edit.set_caret_column(code_edit.get_line(code_edit.get_line_count() - 1).length())

		# Connect text changed
		if not code_edit.text_changed.is_connected(_on_code_edit_changed):
			code_edit.text_changed.connect(_on_code_edit_changed)
		return

	# ── RichTextLabel mode: multiple-choice challenges ──
	code_edit.visible = false
	code_scroll.visible = true
	free_type_edit.visible = false
	options_label.visible = true

	# Syntax-highlighted code (BBCode)
	var bbcode = ""
	for i in range(code_lines.size()):
		var line_num = str(i + 1).lpad(3, " ")
		var line_color = COLOR_LINE_NUM

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

	# Multiple-choice mode
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

# ─── CodeEdit Syntax Highlighter ────────────────────────────────────────────

func _setup_code_highlighter(topic: String):
	var highlighter = CodeHighlighter.new()

	# Base colors
	highlighter.number_color = Color("d19a66")       # orange
	highlighter.symbol_color = Color("abb2bf")        # light grey
	highlighter.function_color = Color("61afef")      # blue
	highlighter.member_variable_color = Color("e06c75")  # red

	match topic:
		"python":
			highlighter.keyword_colors = {
				"def": Color("c678dd"), "return": Color("c678dd"),
				"if": Color("c678dd"), "else": Color("c678dd"),
				"elif": Color("c678dd"), "for": Color("c678dd"),
				"while": Color("c678dd"), "in": Color("c678dd"),
				"import": Color("c678dd"), "from": Color("c678dd"),
				"class": Color("c678dd"), "and": Color("c678dd"),
				"or": Color("c678dd"), "not": Color("c678dd"),
				"True": Color("d19a66"), "False": Color("d19a66"),
				"None": Color("d19a66"), "print": Color("61afef"),
				"range": Color("61afef"), "len": Color("61afef"),
				"str": Color("61afef"), "int": Color("61afef"),
				"float": Color("61afef"), "list": Color("61afef"),
				"dict": Color("61afef"), "self": Color("e06c75"),
				"pass": Color("c678dd"), "break": Color("c678dd"),
				"continue": Color("c678dd"), "with": Color("c678dd"),
				"as": Color("c678dd"), "try": Color("c678dd"),
				"except": Color("c678dd"), "finally": Color("c678dd"),
				"raise": Color("c678dd"), "yield": Color("c678dd"),
				"lambda": Color("c678dd"), "global": Color("c678dd"),
			}
			highlighter.color_regions = {
				"\"": Color("98c379"),    # double-quote strings
				"'": Color("98c379"),     # single-quote strings
				"#": Color("5c6370"),     # comments
			}
		"html":
			highlighter.keyword_colors = {
				"html": Color("e06c75"), "head": Color("e06c75"),
				"body": Color("e06c75"), "div": Color("e06c75"),
				"h1": Color("e06c75"), "h2": Color("e06c75"),
				"h3": Color("e06c75"), "p": Color("e06c75"),
				"a": Color("e06c75"), "img": Color("e06c75"),
				"form": Color("e06c75"), "input": Color("e06c75"),
				"button": Color("e06c75"), "span": Color("e06c75"),
				"ul": Color("e06c75"), "ol": Color("e06c75"),
				"li": Color("e06c75"), "table": Color("e06c75"),
				"tr": Color("e06c75"), "td": Color("e06c75"),
				"link": Color("e06c75"), "meta": Color("e06c75"),
				"title": Color("e06c75"), "script": Color("e06c75"),
				"style": Color("e06c75"),
			}
			highlighter.color_regions = {
				"\"": Color("98c379"),
				"'": Color("98c379"),
				"<!--": Color("5c6370"),
			}
		"css":
			highlighter.keyword_colors = {
				"color": Color("61afef"), "background-color": Color("61afef"),
				"font-size": Color("61afef"), "text-align": Color("61afef"),
				"margin": Color("61afef"), "padding": Color("61afef"),
				"border": Color("61afef"), "display": Color("61afef"),
				"position": Color("61afef"), "width": Color("61afef"),
				"height": Color("61afef"), "flex": Color("61afef"),
				"grid": Color("61afef"),
			}
			highlighter.color_regions = {
				"\"": Color("98c379"),
				"'": Color("98c379"),
				"/*": Color("5c6370"),
			}

	code_edit.syntax_highlighter = highlighter

# Helper to detect output_type — auto-detects from topic if not explicitly set
func _get_output_type() -> String:
	var output_type = current_challenge.get("output_type", "")
	if output_type == "":
		var topic = current_challenge.get("topic", "python")
		if topic in ["html", "css", "django"]:
			output_type = "browser"
		else:
			output_type = "terminal"
	return output_type

func _setup_terminal():
	# Always-visible terminal strip at the bottom of the code panel
	terminal_output.bbcode_enabled = true
	var ctype = current_challenge.get("type", "debug")
	if ctype == "predict_output":
		terminal_output.text = "[color=#5c6370][i]Run the code to see the output...[/i][/color]"
	elif current_challenge.get("error_output", "") != "":
		terminal_output.text = "[color=#e06c75]" + current_challenge["error_output"] + "[/color]"
	else:
		terminal_output.text = "[color=#5c6370][i]Click ▶ Run to execute...[/i][/color]"

	# Set browser preview initial state
	var output_type = _get_output_type()
	if output_type == "browser":
		browser_address.text = " 🔒 http://127.0.0.1:8000/"
		var error_out = current_challenge.get("error_output", "")
		if error_out != "":
			browser_preview.text = "[color=#cc3333][font_size=14]" + error_out + "[/font_size][/color]"
		else:
			browser_preview.text = "[color=#888888][i]Press ▶ Run in the IDE, then Alt-Tab here to see the result.[/i][/color]"

func _setup_file_tabs():
	# Clear old dynamic tab buttons (keep the static FileTab label as fallback)
	for child in file_tabs_container.get_children():
		if child != file_tab_label:
			child.queue_free()

	var files = current_challenge.get("files", {})
	if files.is_empty():
		# Single-file challenge: show the simple label
		file_tab_label.visible = true
		file_tab_label.text = "  📄 " + current_challenge.get("file_name", "code.py")
		return

	# Multi-file challenge: hide the simple label and create tab buttons
	file_tab_label.visible = false
	var active_file = current_challenge.get("active_file", "")
	var first_file = true
	for file_name in files.keys():
		var tab_btn = Button.new()
		tab_btn.text = "  📄 " + file_name
		tab_btn.custom_minimum_size = Vector2(0, 28)
		tab_btn.add_theme_font_size_override("font_size", 12)

		var is_active = (file_name == active_file) or (active_file == "" and first_file)
		var style = StyleBoxFlat.new()
		if is_active:
			style.bg_color = Color("1e1e2e")
			style.border_color = Color("007acc")
			style.set_border_width_all(0)
			style.border_width_top = 2
			tab_btn.add_theme_color_override("font_color", Color("ffffff"))
		else:
			style.bg_color = Color("2d2d3d")
			style.border_color = Color("3e3e42")
			style.set_border_width_all(0)
			tab_btn.add_theme_color_override("font_color", Color("888888"))

		style.set_corner_radius_all(0)
		style.set_content_margin_all(6)
		tab_btn.add_theme_stylebox_override("normal", style)
		tab_btn.add_theme_stylebox_override("hover", style)
		tab_btn.add_theme_stylebox_override("pressed", style)

		# Connect press to switch file content
		var captured_name = file_name
		tab_btn.pressed.connect(func(): _on_file_tab_pressed(captured_name))
		file_tabs_container.add_child(tab_btn)
		first_file = false

func _on_file_tab_pressed(file_name: String):
	_play_click()
	var files = current_challenge.get("files", {})
	var content = files.get(file_name, "")
	var topic = current_challenge.get("topic", "python")

	# Determine file topic from extension
	if file_name.ends_with(".html"):
		topic = "html"
	elif file_name.ends_with(".css"):
		topic = "css"
	elif file_name.ends_with(".py"):
		topic = "python"

	# Re-render the code display with the file's content
	var lines = content.split("\n")
	var bbcode = ""
	for i in range(lines.size()):
		var line_num = str(i + 1).lpad(3, " ")
		bbcode += "[color=" + COLOR_LINE_NUM + "]" + line_num + " [/color]"
		bbcode += _syntax_highlight(lines[i], topic)
		if i < lines.size() - 1:
			bbcode += "\n"
	code_display.text = bbcode

	# Update tab highlighting
	var active_file = current_challenge.get("active_file", "")
	var is_editable = (file_name == active_file)
	if is_editable:
		free_type_edit.visible = is_free_type or is_terminal
	else:
		free_type_edit.visible = false

	# Restyle all tabs
	for child in file_tabs_container.get_children():
		if child is Button:
			var is_active = child.text.strip_edges().ends_with(file_name)
			var style = StyleBoxFlat.new()
			if is_active:
				style.bg_color = Color("1e1e2e")
				style.border_color = Color("007acc")
				style.set_border_width_all(0)
				style.border_width_top = 2
				child.add_theme_color_override("font_color", Color("ffffff"))
			else:
				style.bg_color = Color("2d2d3d")
				style.border_color = Color("3e3e42")
				style.set_border_width_all(0)
				child.add_theme_color_override("font_color", Color("888888"))
			style.set_corner_radius_all(0)
			style.set_content_margin_all(6)
			child.add_theme_stylebox_override("normal", style)
			child.add_theme_stylebox_override("hover", style)
			child.add_theme_stylebox_override("pressed", style)

# Generate fake rendered website content for the browser preview
func _get_browser_preview_content(challenge_id: String, correct_output: String) -> String:
	# Map challenge IDs to fake website previews
	match challenge_id:
		# ── Professor Markup (HTML/CSS) ────────────────
		"markup_web_basics":
			return "[font_size=16][b]200 OK[/b][/font_size]\n\n[font_size=13][color=#555555]HTTP/1.1 200 OK\nContent-Type: text/html\nServer: Django/4.2[/color][/font_size]\n\n[font_size=14]Request successful — page loaded.[/font_size]"
		"markup_html":
			return "[font_size=24][b]Hello[/b][/font_size]\n\n[font_size=14]World[/font_size]\n\n[font_size=11][color=#888888]Page rendered with proper body, heading, and paragraph tags.[/color][/font_size]"
		"markup_css":
			return "[font_size=18][b]Styled Box[/b][/font_size]\n\n[font_size=14]  ┌─────────────────────┐\n  │                     │\n  │   margin: 20px      │\n  │   padding: 10px     │\n  │                     │\n  └─────────────────────┘[/font_size]\n\n[font_size=11][color=#888888]Box model applied correctly.[/color][/font_size]"
		"markup_flexbox":
			return "[font_size=18][b]Centered Layout[/b][/font_size]\n\n[font_size=14]      ┌───┐  ┌───┐  ┌───┐\n      │ A │  │ B │  │ C │\n      └───┘  └───┘  └───┘[/font_size]\n\n[font_size=11][color=#888888]Items centered with flexbox.[/color][/font_size]"
		"markup_responsive":
			return "[font_size=18][b]Responsive Preview[/b][/font_size]\n\n[font_size=13][color=#2266cc]Desktop (> 600px):[/color]  ║ A ║ B ║ C ║\n[color=#cc6622]Mobile  (≤ 600px):[/color]  ║ A ║\n                       ║ B ║\n                       ║ C ║[/font_size]\n\n[font_size=11][color=#888888]Media query active at 600px.[/color][/font_size]"
		# ── Professor Token (CSRF form)  ────────────────
		"token_csrf":
			return "[font_size=18][b]Student Form[/b][/font_size]\n[color=#aaaaaa]──────────────────────────[/color]\n\nName: [color=#cccccc][███████████][/color]\nGrade: [color=#cccccc][███████████][/color]\n\n[color=#3a8f3a][█ Save █][/color]\n\n[font_size=11][color=#4a9e4a]🔒 CSRF token verified — form is protected[/color][/font_size]"
		_:
			# Fallback: render the correct_output as fake page content
			return "[font_size=14]" + correct_output + "[/font_size]"

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

	# Update terminal + browser output
	terminal_output.bbcode_enabled = true
	if is_correct:
		var correct_output = current_challenge.get("correct_output", "Success!")
		var challenge_id = current_challenge.get("id", "")
		terminal_output.text = "[color=#98c379]" + correct_output + "[/color]"
		if _get_output_type() == "browser":
			browser_preview.text = _get_browser_preview_content(challenge_id, correct_output)

		feedback_label.text = "✅ Correct!"
		feedback_label.add_theme_color_override("font_color", Color("98c379"))
		if correct_sfx.stream:
			correct_sfx.play()
	else:
		var error_output = current_challenge.get("error_output", "Error!")
		terminal_output.text = "[color=#e06c75]" + error_output + "[/color]"
		if _get_output_type() == "browser":
			browser_preview.text = "[color=#cc3333]" + error_output + "[/color]"

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

# (Old guilt-trip _on_hint_pressed removed — replaced by new system above)

func _update_hint_button_label():
	var remaining = GLOBAL_MAX_HINTS - global_hints_used
	if remaining <= 0:
		hint_button.text = "📚 No Hints Remaining"
		hint_button.disabled = true
	else:
		hint_button.text = "📚 Hint (%d / %d)" % [global_hints_used, GLOBAL_MAX_HINTS]
		hint_button.disabled = false

func _on_hint_pressed():
	_play_click()

	# Hard cap — no more hints this session
	if global_hints_used >= GLOBAL_MAX_HINTS:
		_update_hint_button_label()
		return

	global_hints_used += 1
	_challenge_hints_used += 1
	_update_hint_button_label()

	# On the 5th hint (global), open Overflow Stack with conceptual help only
	if global_hints_used >= GLOBAL_MAX_HINTS:
		_show_overflow_stack()
		return

	# Otherwise show a progressive in-panel hint (hints 1–4)
	# Support both a single "hint" string and a "hints" array for multi-level clues
	var hints_array: Array = current_challenge.get("hints", [])
	if hints_array.is_empty():
		var single = current_challenge.get("hint", "")
		if single != "":
			hints_array = [single]

	var hint_index = clamp(_challenge_hints_used - 1, 0, hints_array.size() - 1)
	var hint_text = hints_array[hint_index] if hints_array.size() > 0 else "Think carefully about the syntax."

	hint_label.bbcode_enabled = true
	hint_label.text = "[color=#e0c675]💡 Hint %d:[/color] [color=#abb2bf]%s[/color]" % [_challenge_hints_used, hint_text]
	hint_label.visible = true

	# Animate hint label in
	hint_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(hint_label, "modulate:a", 1.0, 0.25)

func _on_reload_pressed():
	# Re-show the initial output state
	_setup_terminal()

func _on_overflow_stack_btn_pressed():
	_play_click()
	_on_hint_pressed()

func _on_free_type_changed():
	# Enable run button when player has typed something (legacy TextEdit)
	if (is_free_type or is_terminal) and not is_completed:
		run_button.disabled = free_type_edit.text.strip_edges() == ""

func _on_code_edit_changed():
	# Enable run button when player has typed something (CodeEdit)
	if (is_free_type or is_terminal) and not is_completed:
		run_button.disabled = code_edit.text.strip_edges() == ""

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
	# ── Extract what the player typed ──
	var full_text = ""
	var player_typed_only = ""

	if code_edit.visible:
		full_text = code_edit.text
		# Extract only the portion after pre-filled code_lines
		var code_lines_arr = current_challenge.get("code_lines", [])
		var all_lines = full_text.split("\n")
		if code_lines_arr.size() > 0 and all_lines.size() > code_lines_arr.size():
			var player_lines = []
			for i in range(code_lines_arr.size(), all_lines.size()):
				player_lines.append(all_lines[i])
			player_typed_only = "\n".join(player_lines).strip_edges()
		else:
			player_typed_only = full_text.strip_edges()
	else:
		full_text = free_type_edit.text
		player_typed_only = full_text.strip_edges()

	var expected_answers = current_challenge.get("expected_answers", [])

	# ── Try server-side validation first (Judge0 + Gemini) ──
	# Show a "compiling" state while we wait
	terminal_output.bbcode_enabled = true
	terminal_output.text = "[color=#61afef]⏳ Compiling...[/color]"
	feedback_label.text = "Running your code..."
	feedback_label.add_theme_color_override("font_color", Color("61afef"))
	feedback_label.visible = true
	run_button.disabled = true

	# Determine language from challenge data (topic field)
	var topic = current_challenge.get("topic", "python")
	var language = "python"  # default
	match topic:
		"html", "css", "http":
			language = "html"
		"django":
			language = "django"
		"python", "oop", "variables", "functions", "loops":
			language = "python"
	
	var challenge_id = current_challenge.get("id", "")
	var expected_output = current_challenge.get("correct_output", "Success!")

	# Call the Django backend via ApiManager
	ApiManager.check_code(player_typed_only, language, challenge_id, expected_answers, expected_output)

	# Wait for the response signal
	var result = await ApiManager.code_checked

	run_button.disabled = false

	if result.get("offline", false):
		# ── Server offline: fall back to local validation ──
		print("coding_challenge_ui: Server offline, using local validation")
		_run_free_type_local(full_text, player_typed_only, expected_answers)
	else:
		# ── Server responded: use its result ──
		_handle_server_result(result)


func _handle_server_result(result: Dictionary):
	"""Handle the response from Django GameCheckCodeView."""
	terminal_output.bbcode_enabled = true
	var is_correct = result.get("success", false)
	var output = result.get("output", "")
	var ai_hint = result.get("ai_hint", "")

	if is_correct:
		is_completed = true
		timer_running = false
		free_type_edit.editable = false
		code_edit.editable = false

		var challenge_id = current_challenge.get("id", "")
		terminal_output.text = "[color=#98c379]" + output + "[/color]"
		if _get_output_type() == "browser":
			browser_preview.text = _get_browser_preview_content(challenge_id, output)

		feedback_label.text = "✅ Correct! Your code works!"
		feedback_label.add_theme_color_override("font_color", Color("98c379"))
		feedback_label.visible = true
		run_button.disabled = true
		if correct_sfx.stream:
			correct_sfx.play()

		await get_tree().create_timer(2.0).timeout
		_show_results(true)
	else:
		_attempts += 1

		# Build error display with AI hint if available
		var error_text = "[color=#e06c75]" + output + "[/color]"

		if ai_hint != "":
			error_text += "\n\n[color=#d19a66]🤖 AI HINT: " + ai_hint + "[/color]"
		else:
			# Fall back to progressive hints from challenge data
			var hints = current_challenge.get("progressive_hints", [])
			var expected_answers_list = current_challenge.get("expected_answers", [])
			var answer_text = expected_answers_list[0] if expected_answers_list.size() > 0 else ""
			
			if hints.size() > 0:
				if _attempts <= hints.size():
					var hint = hints[_attempts - 1]
					error_text += "\n\n[color=#d19a66]HINT " + str(_attempts) + ": " + hint + "[/color]"
				else:
					error_text += "\n\n[color=#98c379]ANSWER: Just type exactly: " + answer_text + "[/color]"

		terminal_output.text = error_text
		
		if _get_output_type() == "browser":
			browser_preview.text = "[color=#cc3333]" + output + "[/color]"

		feedback_label.text = "❌ Not quite — check the terminal for hints!"
		feedback_label.add_theme_color_override("font_color", Color("e06c75"))
		feedback_label.visible = true
		if wrong_sfx.stream:
			wrong_sfx.play()


func _run_free_type_local(full_text: String, player_typed_only: String, expected_answers: Array):
	"""Offline fallback: local multi-pass validation (no server needed)."""
	# ── Multi-pass validation ──
	var is_correct = false

	for answer in expected_answers:
		var ans = answer.strip_edges()

		# Pass 1: Exact match of just what the player typed after pre-filled lines
		if player_typed_only == ans:
			is_correct = true
			break

		# Pass 2: Exact match of the full CodeEdit content
		if full_text.strip_edges() == ans:
			is_correct = true
			break

		# Pass 3: The expected answer appears as a substring within the full text
		if full_text.find(ans) != -1:
			is_correct = true
			break

		# Pass 4: Normalized whitespace comparison
		if _normalize_whitespace(player_typed_only) == _normalize_whitespace(ans):
			is_correct = true
			break
		if _normalize_whitespace(full_text.strip_edges()) == _normalize_whitespace(ans):
			is_correct = true
			break

	terminal_output.bbcode_enabled = true

	if is_correct:
		# ── Correct: lock everything and show results ──
		is_completed = true
		timer_running = false
		free_type_edit.editable = false
		code_edit.editable = false

		var correct_output = current_challenge.get("correct_output", "Success!")
		var challenge_id = current_challenge.get("id", "")
		terminal_output.text = "[color=#98c379]" + correct_output + "[/color]"
		if _get_output_type() == "browser":
			browser_preview.text = _get_browser_preview_content(challenge_id, correct_output)

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
		
		var hints = current_challenge.get("progressive_hints", [])
		var expected_answers_list = current_challenge.get("expected_answers", [])
		var answer_text = expected_answers_list[0] if expected_answers_list.size() > 0 else ""
		
		var error_output = current_challenge.get("error_output", "Error!")
		
		if hints.size() > 0:
			if _attempts <= hints.size():
				var hint = hints[_attempts - 1]
				terminal_output.text = "[color=#e06c75]" + error_output + "[/color]\n\n[color=#d19a66]HINT " + str(_attempts) + ": " + hint + "[/color]"
				feedback_label.text = "❌ Not quite — read the hint in the terminal!"
			else:
				terminal_output.text = "[color=#e06c75]" + error_output + "[/color]\n\n[color=#98c379]ANSWER: Just type exactly: " + answer_text + "[/color]"
				feedback_label.text = "❌ Still stuck? I put the answer in the terminal!"
		else:
			terminal_output.text = "[color=#e06c75]" + error_output + "[/color]"
			feedback_label.text = "❌ Not quite — check your code and try again!"

		# Also update browser preview for browser-type challenges
		if _get_output_type() == "browser":
			browser_preview.text = "[color=#cc3333]" + error_output + "[/color]"

		feedback_label.add_theme_color_override("font_color", Color("e06c75"))
		feedback_label.visible = true
		if wrong_sfx.stream:
			wrong_sfx.play()

		# Keep editor editable so they can fix and retry
		free_type_edit.editable = true
		code_edit.editable = true
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
	if (is_free_type or is_terminal) and (free_type_edit.has_focus() or code_edit.has_focus()):
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
	# Find the deepest conceptual clue available (never the raw answer)
	var hints_array: Array = current_challenge.get("hints", [])
	if hints_array.is_empty():
		var single = current_challenge.get("hint", "")
		if single != "":
			hints_array = [single]

	# Use the last hint in the array as the "deepest" clue
	var deep_clue = hints_array.back() if hints_array.size() > 0 else "Review the topic material and try again."
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
	stack_question.text = "Q: I'm really stuck on \"" + title + "\". Final hint please!"
	stack_question.add_theme_color_override("font_color", Color("3b4045"))
	stack_question.add_theme_font_size_override("font_size", 13)

	# Votes
	var vote_count = randi_range(12, 247)
	stack_votes.text = "▲ " + str(vote_count) + " votes  •  📣 Community Hint (No answers!)"
	stack_votes.add_theme_color_override("font_color", Color("6a9955"))
	stack_votes.add_theme_font_size_override("font_size", 12)

	# Deep conceptual clue — NOT the answer
	var intro = OVERFLOW_INTROS[randi() % OVERFLOW_INTROS.size()]
	stack_answer.bbcode_enabled = true
	stack_answer.text = (
		"[color=#3b4045]" + intro + deep_clue + "\n\n" +
		"[color=#e06c75][b]⚠️ You have used all 5 hints for this session.[/b]\n" +
		"The answer will not be shown. Review the lesson material and try again.[/color][/color]"
	)
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
	if code_edit.visible:
		code_edit.text = half
	else:
		free_type_edit.text = half
		free_type_edit.visible = true
	run_button.disabled = false

func _buff_encrypted_drive():
	# Instantly solve the challenge
	is_completed = true

	# Show correct output
	var correct_output = current_challenge.get("correct_output", "✓ Correct!")
	var challenge_id = current_challenge.get("id", "")
	terminal_output.text = "[color=#98c379]" + correct_output + "[/color]"
	if _get_output_type() == "browser":
		browser_preview.text = _get_browser_preview_content(challenge_id, correct_output)

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
		code_edit.editable = not _locked
		if _locked:
			run_button.disabled = true
		else:
			# only enable run if there's text
			var current_text = code_edit.text if code_edit.visible else free_type_edit.text
			run_button.disabled = current_text.strip_edges() == ""

# ─── Screen Switching (IDE ↔ Browser) ────────────────────────────────────────

func _switch_to_browser():
	if _is_browser_visible:
		return
	_play_click()
	_is_browser_visible = true
	browser_screen.visible = true

	var vp_width = get_viewport_rect().size.x
	# Slide IDE left, Browser in from the right
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ide_screen, "position:x", -vp_width, 0.35)
	browser_screen.position.x = vp_width
	tween.tween_property(browser_screen, "position:x", 0.0, 0.35)

func _switch_to_ide():
	if not _is_browser_visible:
		return
	_play_click()
	_is_browser_visible = false

	var vp_width = get_viewport_rect().size.x
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ide_screen, "position:x", 0.0, 0.35)
	tween.tween_property(browser_screen, "position:x", vp_width, 0.35)
	tween.chain().tween_callback(func(): browser_screen.visible = false)

func _switch_to_ide_instant():
	# Instantly reset to IDE view (no animation, used during load_challenge)
	_is_browser_visible = false
	ide_screen.position.x = 0
	browser_screen.position.x = get_viewport_rect().size.x
	browser_screen.visible = false

# ─── Styling for New UI Elements ─────────────────────────────────────────────

func _style_terminal_strip():
	# Dark terminal-style background
	var term_style = StyleBoxFlat.new()
	term_style.bg_color = Color("0d0d0d")
	term_style.border_color = Color("333333")
	term_style.set_border_width_all(1)
	term_style.set_corner_radius_all(0)
	term_style.set_content_margin_all(6)
	terminal_strip.add_theme_stylebox_override("panel", term_style)

	# Terminal header label
	terminal_header.add_theme_color_override("font_color", Color("888888"))
	terminal_header.add_theme_font_size_override("font_size", 11)

	# Terminal output text
	var code_font = preload("res://Textures/Fonts/JetBrainsMono/JetBrainsMono-Regular.ttf")
	terminal_output.add_theme_font_override("normal_font", code_font)
	terminal_output.add_theme_font_size_override("normal_font_size", 12)
	terminal_output.add_theme_color_override("default_color", Color("00ff41"))  # Matrix green

func _style_browser_screen():
	# Browser toolbar styling
	var toolbar_style = StyleBoxFlat.new()
	toolbar_style.bg_color = Color("e0e0e0")
	toolbar_style.set_content_margin_all(6)

	# Address bar
	browser_address.add_theme_color_override("font_color", Color("333333"))
	browser_address.add_theme_font_size_override("font_size", 13)

	# Back button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("d0d0d0")
	btn_style.border_color = Color("aaaaaa")
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(6)
	browser_back_btn.add_theme_stylebox_override("normal", btn_style)
	browser_back_btn.add_theme_color_override("font_color", Color("333333"))
	browser_back_btn.add_theme_font_size_override("font_size", 12)

	# Browser preview text
	browser_preview.add_theme_color_override("default_color", Color("222222"))
	browser_preview.add_theme_font_size_override("normal_font_size", 14)

func _style_action_buttons():
	# Overflow Stack button — orange themed
	var os_style = StyleBoxFlat.new()
	os_style.bg_color = Color("b05c00")
	os_style.set_corner_radius_all(4)
	os_style.set_content_margin_all(6)
	overflow_stack_button.add_theme_stylebox_override("normal", os_style)
	overflow_stack_button.add_theme_color_override("font_color", Color("ffffff"))
	overflow_stack_button.add_theme_font_size_override("font_size", 12)

	var os_hover = os_style.duplicate()
	os_hover.bg_color = Color("d16d00")
	overflow_stack_button.add_theme_stylebox_override("hover", os_hover)

	# Alt-tab button — blue themed
	var at_style = StyleBoxFlat.new()
	at_style.bg_color = Color("2d2d3d")
	at_style.border_color = Color("007acc")
	at_style.set_border_width_all(1)
	at_style.set_corner_radius_all(4)
	at_style.set_content_margin_all(6)
	alt_tab_button.add_theme_stylebox_override("normal", at_style)
	alt_tab_button.add_theme_color_override("font_color", Color("ffffff"))
	alt_tab_button.add_theme_font_size_override("font_size", 12)

	var at_hover = at_style.duplicate()
	at_hover.bg_color = Color("3e3e52")
	alt_tab_button.add_theme_stylebox_override("hover", at_hover)
