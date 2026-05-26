# laptop_ui.gd — In-game laptop overlay with 4 apps
# Attach to a CanvasLayer. Toggle with "toggle_laptop" input (X key).
extends CanvasLayer

const CODING_UI_SCENE = preload("res://Scenes/Games/coding_challenge_ui.tscn")
const GLOSSARY_POPUP_SCENE = preload("res://Scripts/UI/glossary_popup.gd")
const PROFESSOR_NOTES_PATH = "res://Data/professor_notes_slides.json"
const PROFESSOR_CHALLENGES_PATH = "res://Data/professor_challenges.json"
const THESIS_CHALLENGE_DATA = preload("res://Scripts/Ch2/thesis_challenge_data.gd")

var is_open: bool = false
var is_saving: bool = false
var current_app: String = ""  # "" = desktop, "retro_browser", "notes", "quest_log", "settings", "certificates"

# ─── Root Nodes ──────────────────────────────────────────────────────────────
var screen_panel: PanelContainer
var desktop_view: Control
var app_view: Control
var app_title_bar: HBoxContainer
var app_title_label: Label
var app_back_button: Button
var app_content: PanelContainer
var taskbar: PanelContainer

# App content containers
var retro_browser_content: Control
var notes_content: Control
var quest_log_content: Control
var settings_content: Control
var sis_content: Control
var certificates_content: Control
var achievements_content: Control

var _cred_label: Label

# Quest log card references (for updating the tracked indicator)
var _quest_cards: Dictionary = {}  # quest_id -> { card, indicator }
var _retro_challenges_list: VBoxContainer
var _notes_list: VBoxContainer
var _professor_notes_data: Dictionary = {}
var _professor_challenges_data: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	_build_ui()

func open():
	is_open = true
	visible = true
	get_tree().paused = true
	current_app = ""
	var qm = get_node_or_null("/root/QuestManager")
	if qm: qm.hide_quest()
	var cd = get_node_or_null("/root/CharacterData")
	if _cred_label and cd:
		_cred_label.text = str(cd.credits)
	_show_desktop()
	_update_college_locks()

func close():
	if is_saving: return
	is_open = false
	visible = false
	get_tree().paused = false
	current_app = ""
	var qm = get_node_or_null("/root/QuestManager")
	if qm: qm.show_quest()

func _update_college_locks():
	# Find the SIS and Certificate buttons on the desktop grid and enable/disable dynamically
	if not desktop_view:
		return
	var cd = get_node_or_null("/root/CharacterData")
	if not cd:
		return
	var should_lock = not cd.has_reached_college
	for node in _get_all_desktop_buttons():
		if node is Button:
			var icon = node.text.strip_edges()
			if icon == "🎓" or icon == "🏆":
				node.disabled = should_lock

func _get_all_desktop_buttons() -> Array:
	var result = []
	if not desktop_view:
		return result
	for child in desktop_view.get_children():
		_collect_buttons(child, result)
	return result

func _collect_buttons(node: Node, result: Array):
	if node is Button:
		result.append(node)
	for child in node.get_children():
		_collect_buttons(child, result)

# ─── Build Full UI ───────────────────────────────────────────────────────────

func _build_ui():
	# Full screen dimmer
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	# Laptop screen panel (centered, with border)
	screen_panel = PanelContainer.new()
	var screen_style = StyleBoxFlat.new()
	screen_style.bg_color = Color(0.07, 0.09, 0.14, 0.98)
	screen_style.border_color = Color(0.25, 0.3, 0.45, 0.9)
	screen_style.set_border_width_all(3)
	screen_style.set_corner_radius_all(12)
	screen_style.set_content_margin_all(0)
	screen_panel.add_theme_stylebox_override("panel", screen_style)

	screen_panel.set_anchors_preset(Control.PRESET_CENTER)
	screen_panel.anchor_left = 0.1
	screen_panel.anchor_top = 0.08
	screen_panel.anchor_right = 0.9
	screen_panel.anchor_bottom = 0.92
	screen_panel.offset_left = 0
	screen_panel.offset_top = 0
	screen_panel.offset_right = 0
	screen_panel.offset_bottom = 0
	add_child(screen_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	screen_panel.add_child(main_vbox)

	# ─── Top Bar (laptop chrome) ─────────────────────────────────────────
	var top_bar = _create_top_bar()
	main_vbox.add_child(top_bar)

	# ─── Content Area ────────────────────────────────────────────────────
	var content_area = PanelContainer.new()
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(0.06, 0.07, 0.12)
	content_style.set_content_margin_all(16)
	content_area.add_theme_stylebox_override("panel", content_style)
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_area)

	var content_stack = Control.new()
	content_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(content_stack)

	# Desktop View
	desktop_view = _create_desktop()
	content_stack.add_child(desktop_view)

	# App View (hidden by default)
	app_view = _create_app_view()
	content_stack.add_child(app_view)

	# ─── Taskbar ─────────────────────────────────────────────────────────
	taskbar = _create_taskbar()
	main_vbox.add_child(taskbar)

# ─── Top Bar ─────────────────────────────────────────────────────────────────

func _create_top_bar() -> PanelContainer:
	var bar = HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 32)
	bar.add_theme_constant_override("separation", 8)

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.14, 0.22)
	bar_bg.set_content_margin_all(6)
	bar_bg.corner_radius_top_left = 12
	bar_bg.corner_radius_top_right = 12

	var bar_panel = PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", bar_bg)
	bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	bar_panel.add_child(hbox)

	# Dots
	for color in [Color(0.9, 0.3, 0.3), Color(0.9, 0.7, 0.2), Color(0.3, 0.8, 0.4)]:
		var dot = ColorRect.new()
		dot.color = color
		dot.custom_minimum_size = Vector2(10, 10)
		hbox.add_child(dot)

	# Title
	var title = Label.new()
	title.text = "💻 DjangoQuest Laptop"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(title)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.8, 0.25, 0.25, 0.8)
	close_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(close)
	hbox.add_child(close_btn)

	return bar_panel

# ─── Desktop (App Icons) ─────────────────────────────────────────────────────

func _create_desktop() -> Control:
	var container = ScrollContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	# Center the grid
	var center = CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 520)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(center)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 30)
	center.add_child(grid)

	# App icons
	var apps = [
		{"id": "sis", "name": "Student Information System", "icon": "🎓", "color": Color(0.8, 0.3, 0.3), "desc": "Academic Records"},
		{"id": "retro_browser", "name": "RetroBrowser", "icon": "🌐", "color": Color(0.2, 0.5, 0.9), "desc": "Replay unlocked challenges"},
		{"id": "notes", "name": "Notes", "icon": "📝", "color": Color(0.85, 0.75, 0.2), "desc": "Your knowledge base"},
		{"id": "quest_log", "name": "Quest Log", "icon": "📋", "color": Color(0.3, 0.75, 0.4), "desc": "Track your quests"},
		{"id": "settings", "name": "Settings", "icon": "⚙️", "color": Color(0.6, 0.35, 0.8), "desc": "Audio and IDE options"},
		{"id": "certificates", "name": "Certificates", "icon": "🏆", "color": Color(0.85, 0.65, 0.1), "desc": "View earned ECertificates"},
		{"id": "achievements", "name": "Achievements", "icon": "🏅", "color": Color(0.9, 0.55, 0.1), "desc": "Your earned badges"},
	]

	for app in apps:
		var app_btn = _create_app_icon(app)
		grid.add_child(app_btn)

	return container

func _create_app_icon(app: Dictionary) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size = Vector2(120, 120)

	# Icon button
	var btn = Button.new()
	btn.text = app["icon"]
	btn.custom_minimum_size = Vector2(72, 72)
	btn.add_theme_font_size_override("font_size", 32)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = app["color"].darkened(0.5)
	btn_style.border_color = app["color"]
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(14)
	btn_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style = btn_style.duplicate()
	hover_style.bg_color = app["color"].darkened(0.3)
	hover_style.border_color = app["color"].lightened(0.3)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", Color.WHITE)

	var disabled_style = btn_style.duplicate()
	disabled_style.bg_color = app["color"].darkened(0.7)
	disabled_style.border_color = app["color"].darkened(0.7)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))

	var app_id = app["id"]
	btn.pressed.connect(func(): _open_app(app_id))
	vbox.add_child(btn)

	# Lock SIS and Certificates if still in Ch1
	if app_id == "sis" or app_id == "certificates":
		var cd = get_node_or_null("/root/CharacterData")
		if cd and not cd.has_reached_college:
			btn.disabled = true
			btn.tooltip_text = "Locked until College."

	# Label
	var label = Label.new()
	label.text = app["name"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	vbox.add_child(label)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = app["desc"]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	vbox.add_child(subtitle)

	return vbox

# ─── App View (shared container for all apps) ────────────────────────────────

func _create_app_view() -> Control:
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.visible = false

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	container.add_child(vbox)

	# App title bar
	app_title_bar = HBoxContainer.new()
	app_title_bar.custom_minimum_size = Vector2(0, 36)
	app_title_bar.add_theme_constant_override("separation", 8)

	var title_bg = PanelContainer.new()
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.1, 0.12, 0.2)
	title_style.set_content_margin_all(6)
	title_style.border_color = Color(0.2, 0.25, 0.4)
	title_style.border_width_bottom = 1
	title_bg.add_theme_stylebox_override("panel", title_style)
	title_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	title_bg.add_child(title_hbox)

	# Back button
	app_back_button = Button.new()
	app_back_button.text = "← Back"
	app_back_button.add_theme_font_size_override("font_size", 12)
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.15, 0.18, 0.28)
	back_style.set_corner_radius_all(4)
	back_style.set_content_margin_all(4)
	app_back_button.add_theme_stylebox_override("normal", back_style)
	app_back_button.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	app_back_button.pressed.connect(_back_to_desktop)
	title_hbox.add_child(app_back_button)

	# Title
	app_title_label = Label.new()
	app_title_label.text = "App Name"
	app_title_label.add_theme_font_size_override("font_size", 14)
	app_title_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	app_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(app_title_label)

	vbox.add_child(title_bg)

	# App content area
	app_content = PanelContainer.new()
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(0.05, 0.06, 0.1)
	content_style.set_content_margin_all(12)
	app_content.add_theme_stylebox_override("panel", content_style)
	app_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(app_content)

	# Build each app's content
	retro_browser_content = _build_retro_browser()
	notes_content = _build_notes()
	quest_log_content = _build_quest_log()
	settings_content = _build_settings()
	sis_content = _build_sis()
	certificates_content = _build_certificates()
	achievements_content = _build_achievements()

	app_content.add_child(retro_browser_content)
	app_content.add_child(notes_content)
	app_content.add_child(quest_log_content)
	app_content.add_child(settings_content)
	app_content.add_child(sis_content)
	app_content.add_child(certificates_content)
	app_content.add_child(achievements_content)

	return container

# ─── RetroBrowser App ────────────────────────────────────────────────────────

func _build_retro_browser() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.visible = false

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "🌐 RetroBrowser — Challenge Replay"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(header)

	var desc = Label.new()
	desc.text = "Challenges you've unlocked by helping NPCs will appear here.\nBeat an NPC's challenge to install it on your laptop for practice!"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	_retro_challenges_list = VBoxContainer.new()
	_retro_challenges_list.name = "RetroChallengesList"
	_retro_challenges_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retro_challenges_list.add_theme_constant_override("separation", 10)
	vbox.add_child(_retro_challenges_list)

	_refresh_retro_browser()

	return scroll

func _refresh_retro_browser() -> void:
	if not _retro_challenges_list:
		return

	for child in _retro_challenges_list.get_children():
		child.queue_free()

	var cd = get_node_or_null("/root/CharacterData")
	var unlocked_groups = _get_unlocked_retro_groups(cd)
	if unlocked_groups.is_empty():
		var empty = Label.new()
		empty.text = "No coding challenges unlocked yet. Finish a professor lesson to install their challenge set here."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_retro_challenges_list.add_child(empty)
		return

	for group in unlocked_groups:
		_retro_challenges_list.add_child(_create_retro_group(group))

func _get_unlocked_retro_groups(cd) -> Array:
	var groups = []
	var professor_sets = [
		{"key": "markup", "flag": "ch2_y1s1_teaching_done", "title": "Professor Markup", "topic": "HTML, CSS, and Layout"},
		{"key": "syntax", "flag": "ch2_y1s2_teaching_done", "title": "Professor Syntax", "topic": "Python Core and OOP"},
		{"key": "view", "flag": "ch2_y2s1_teaching_done", "title": "Professor View", "topic": "Django Setup, URLs, Views, Templates"},
		{"key": "query", "flag": "ch2_y2s2_teaching_done", "title": "Professor Query", "topic": "Models, ORM, and Relationships"},
		{"key": "token", "flag": "ch2_y3s1_teaching_done", "title": "Professor Token", "topic": "Forms, Validation, CSRF"},
		{"key": "auth", "flag": "ch2_y3s2_teaching_done", "title": "Professor Auth", "topic": "Authentication and Authorization"},
		{"key": "rest", "flag": "ch2_y3mid_teaching_done", "title": "Professor REST", "topic": "APIs, Serializers, Routers"},
	]

	var challenge_data = _load_professor_challenges_data()
	for info in professor_sets:
		if cd and bool(cd.get(info["flag"])):
			var challenges = challenge_data.get(info["key"], [])
			challenges = _get_replayable_challenges(challenges)
			if challenges is Array and not challenges.is_empty():
				groups.append({
					"title": info["title"],
					"topic": info["topic"],
					"challenges": challenges,
				})

	if cd:
		var panelist_progress = int(cd.get("thesis_panelist_progress"))
		var panelists = [
			{"index": 1, "title": "Panelist Cruz", "topic": "Django project setup defense"},
			{"index": 2, "title": "Panelist Santos", "topic": "Models, ORM, Forms rapid review"},
			{"index": 3, "title": "Panelist Reyes", "topic": "Final debugging defense"},
		]
		for panelist in panelists:
			if panelist_progress >= int(panelist["index"]):
				var panelist_challenges = THESIS_CHALLENGE_DATA.get_challenges(int(panelist["index"]))
				panelist_challenges = _get_replayable_challenges(panelist_challenges)
				if not panelist_challenges.is_empty():
					groups.append({
						"title": panelist["title"],
						"topic": panelist["topic"],
						"challenges": panelist_challenges,
					})

	return groups

func _get_replayable_challenges(challenges: Array) -> Array:
	var replayable = []
	for challenge in challenges:
		if not (challenge is Dictionary):
			continue
		var expected = challenge.get("expected_answers", [])
		var options = challenge.get("options", [])
		if (expected is Array and not expected.is_empty()) or expected is Dictionary or (options is Array and not options.is_empty()):
			replayable.append(challenge)
	return replayable

func _create_retro_group(group: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16)
	style.border_color = Color(0.2, 0.5, 0.9, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title = Label.new()
	title.text = "%s — %s" % [str(group.get("title", "Challenge Set")), str(group.get("topic", "Practice"))]
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	var challenges: Array = group.get("challenges", [])
	for challenge in challenges:
		vbox.add_child(_create_retro_challenge_row(challenge))

	return card

func _create_retro_challenge_row(challenge: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label = Label.new()
	label.text = "%s  [%s]" % [str(challenge.get("title", "Practice Challenge")), str(challenge.get("file_name", "code"))]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var button = Button.new()
	button.text = "Replay"
	button.custom_minimum_size = Vector2(82, 30)
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(_launch_retro_challenge.bind(challenge))
	row.add_child(button)

	return row

func _launch_retro_challenge(challenge: Dictionary) -> void:
	var replay_data = challenge.duplicate(true)
	replay_data["timed"] = false

	visible = false
	is_open = false
	get_tree().paused = false

	var canvas = CanvasLayer.new()
	canvas.layer = 150
	canvas.name = "RetroBrowserChallengeLayer"
	get_tree().root.add_child(canvas)

	var ui = CODING_UI_SCENE.instantiate()
	ui.hide_close_button = false
	canvas.add_child(ui)
	ui.tree_exited.connect(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
		open()
		_open_app("retro_browser")
	)
	ui.load_challenge(replay_data)

func _load_professor_challenges_data() -> Dictionary:
	if not _professor_challenges_data.is_empty():
		return _professor_challenges_data

	if not FileAccess.file_exists(PROFESSOR_CHALLENGES_PATH):
		push_warning("Professor challenge data file is missing: " + PROFESSOR_CHALLENGES_PATH)
		return {}

	var file = FileAccess.open(PROFESSOR_CHALLENGES_PATH, FileAccess.READ)
	if not file:
		push_warning("Unable to open professor challenge data file: " + PROFESSOR_CHALLENGES_PATH)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_professor_challenges_data = parsed
	else:
		push_warning("Professor challenge data file could not be parsed.")

	return _professor_challenges_data

# ─── Notes App ───────────────────────────────────────────────────────────────

func _build_notes() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.visible = false

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "📝 Notes — Knowledge Base"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.85, 0.75, 0.2))
	vbox.add_child(header)

	var desc = Label.new()
	desc.text = "Professor slide decks unlock here after you finish each teaching session.\nUse them to review the lesson before helping students or replaying challenges."
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	_notes_list = VBoxContainer.new()
	_notes_list.name = "NotesList"
	_notes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_list.add_theme_constant_override("separation", 10)
	vbox.add_child(_notes_list)

	_refresh_notes()

	return scroll

func _refresh_notes() -> void:
	if not _notes_list:
		return

	for child in _notes_list.get_children():
		child.queue_free()

	var unlocked_count = 0
	for deck in _get_note_decks():
		var unlocked = _is_note_deck_unlocked(deck)
		if unlocked:
			unlocked_count += 1
		_notes_list.add_child(_create_note_deck_card(deck, unlocked))

	if unlocked_count == 0:
		var hint = Label.new()
		hint.text = "No professor slide decks unlocked yet. Finish a professor's teaching session to save their slides here."
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notes_list.add_child(hint)

func _is_note_deck_unlocked(deck: Dictionary) -> bool:
	var cd = get_node_or_null("/root/CharacterData")
	if not cd:
		return false
	return bool(cd.get(deck.get("flag", "")))

func _create_note_deck_card(deck: Dictionary, unlocked: bool) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18) if unlocked else Color(0.07, 0.08, 0.12)
	style.border_color = Color(0.85, 0.75, 0.2, 0.45) if unlocked else Color(0.2, 0.22, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	var title = Label.new()
	title.text = ("✅ " if unlocked else "🔒 ") + str(deck.get("title", "Untitled Notes"))
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.86, 0.45) if unlocked else Color(0.45, 0.47, 0.55))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	var prev = Label.new()
	prev.text = str(deck.get("preview", "Review deck"))
	prev.add_theme_font_size_override("font_size", 10)
	prev.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7) if unlocked else Color(0.35, 0.37, 0.45))
	prev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(prev)

	var status = Label.new()
	if unlocked:
		status.text = "%d lesson slides available" % _get_note_slides(deck).size()
		status.add_theme_color_override("font_color", Color(0.45, 0.75, 0.45))
	else:
		status.text = "Finish this professor's teaching to unlock"
		status.add_theme_color_override("font_color", Color(0.42, 0.42, 0.48))
	status.add_theme_font_size_override("font_size", 9)
	vbox.add_child(status)

	var view_btn = Button.new()
	view_btn.text = "View Slides" if unlocked else "Locked"
	view_btn.disabled = not unlocked
	view_btn.custom_minimum_size = Vector2(110, 36)
	view_btn.add_theme_font_size_override("font_size", 10)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.18, 0.08)
	btn_style.border_color = Color(0.85, 0.75, 0.2, 0.55)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(5)
	view_btn.add_theme_stylebox_override("normal", btn_style)
	var hover = btn_style.duplicate()
	hover.bg_color = Color(0.3, 0.26, 0.1)
	view_btn.add_theme_stylebox_override("hover", hover)
	var disabled_style = btn_style.duplicate()
	disabled_style.bg_color = Color(0.12, 0.12, 0.15)
	disabled_style.border_color = Color(0.24, 0.24, 0.3)
	view_btn.add_theme_stylebox_override("disabled", disabled_style)
	view_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	view_btn.add_theme_color_override("font_disabled_color", Color(0.42, 0.42, 0.48))
	view_btn.pressed.connect(_show_note_deck.bind(deck))
	hbox.add_child(view_btn)

	return card

func _show_note_deck(deck: Dictionary) -> void:
	var slides: Array = _get_note_slides(deck)
	if slides.is_empty():
		return

	var overlay = Panel.new()
	overlay.name = "NotesSlideViewer"
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.9)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_panel.add_child(overlay)

	var frame = PanelContainer.new()
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.08, 0.09, 0.14)
	frame_style.border_color = Color(0.85, 0.75, 0.2, 0.55)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(8)
	frame_style.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(620, 420)
	frame.size = Vector2(620, 420)
	frame.position = Vector2(-310, -210)
	overlay.add_child(frame)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(layout)

	var title = Label.new()
	title.text = str(deck.get("title", "Notes"))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(title)

	var slide_title = Label.new()
	slide_title.add_theme_font_size_override("font_size", 15)
	slide_title.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	slide_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(slide_title)

	var body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = false
	body.scroll_active = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 12)
	body.add_theme_color_override("default_color", Color(0.72, 0.76, 0.86))
	body.meta_underlined = true
	body.meta_clicked.connect(_on_notes_glossary_clicked)
	layout.add_child(body)

	var nav = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	layout.add_child(nav)

	var prev_btn = Button.new()
	prev_btn.text = "← Previous"
	prev_btn.add_theme_font_size_override("font_size", 11)
	nav.add_child(prev_btn)

	var slide_count = Label.new()
	slide_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slide_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slide_count.add_theme_font_size_override("font_size", 11)
	slide_count.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	nav.add_child(slide_count)

	var next_btn = Button.new()
	next_btn.text = "Next →"
	next_btn.add_theme_font_size_override("font_size", 11)
	nav.add_child(next_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 11)
	nav.add_child(close_btn)

	var state = {"index": 0}
	var render_slide = func():
		var i = int(state["index"])
		var slide: Dictionary = slides[i]
		slide_title.text = str(slide.get("title", "Review Slide"))
		body.text = _format_note_slide_body(slide)
		slide_count.text = "Slide %d of %d" % [i + 1, slides.size()]
		prev_btn.disabled = i <= 0
		next_btn.disabled = i >= slides.size() - 1

	prev_btn.pressed.connect(func():
		state["index"] = max(0, int(state["index"]) - 1)
		render_slide.call()
	)
	next_btn.pressed.connect(func():
		state["index"] = min(slides.size() - 1, int(state["index"]) + 1)
		render_slide.call()
	)
	close_btn.pressed.connect(func(): overlay.queue_free())
	render_slide.call()

func _on_notes_glossary_clicked(meta) -> void:
	var term = str(meta).strip_edges().to_lower()
	if term.is_empty():
		return
	var popup = GLOSSARY_POPUP_SCENE.new()
	get_tree().root.add_child(popup)
	popup.show_definition(term)

func _get_note_slides(deck: Dictionary) -> Array:
	if deck.has("slides"):
		return deck.get("slides", [])

	var deck_key = str(deck.get("deck_key", ""))
	if deck_key.is_empty():
		return []

	var notes_data = _load_professor_notes_data()
	var slides = notes_data.get(deck_key, [])
	return slides if slides is Array else []

func _load_professor_notes_data() -> Dictionary:
	if not _professor_notes_data.is_empty():
		return _professor_notes_data

	if not FileAccess.file_exists(PROFESSOR_NOTES_PATH):
		push_warning("Professor notes data file is missing: " + PROFESSOR_NOTES_PATH)
		return {}

	var file = FileAccess.open(PROFESSOR_NOTES_PATH, FileAccess.READ)
	if not file:
		push_warning("Unable to open professor notes data file: " + PROFESSOR_NOTES_PATH)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_professor_notes_data = parsed
	else:
		push_warning("Professor notes data file could not be parsed.")

	return _professor_notes_data

func _format_note_slide_body(slide: Dictionary) -> String:
	if slide.has("body"):
		return GlossaryData.auto_link(str(slide.get("body", "")))

	var lines: Array[String] = []
	var subtitle = str(slide.get("subtitle", "")).strip_edges()
	if not subtitle.is_empty():
		lines.append("[color=#9fb3d9]" + subtitle + "[/color]")
		lines.append("")

	var bullets: Array = slide.get("bullets", [])
	for bullet in bullets:
		lines.append("[color=#7dacf0]  *[/color]  " + GlossaryData.auto_link(str(bullet)))

	var code = str(slide.get("code", "")).strip_edges()
	if not code.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append("[color=#9fd18b]Code:[/color]")
		lines.append("[code]" + code + "[/code]")

	var reference = str(slide.get("reference", "")).strip_edges()
	if not reference.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append("[color=#6f778a]" + reference + "[/color]")

	return "\n".join(PackedStringArray(lines))

func _get_note_decks() -> Array:
	return [
		{
			"flag": "ch1_teaching_done",
			"title": "SHS Professor — Python History",
			"preview": "Guido van Rossum, Python's origin, the name, readability, Python 3, and modern uses.",
			"slides": [
				{"title": "Python's Creator", "body": "Python was created by Guido van Rossum.\n\n• He began working on Python in 1989.\n• His earlier work on ABC influenced Python's clean structure.\n• The language became known for readability and simplicity."},
				{"title": "Why the Name Python?", "body": "Python was not named after the snake.\n\n• The name came from Monty Python's Flying Circus.\n• Guido wanted the language to feel fun and approachable.\n• This is why Python's culture often values clarity and friendliness."},
				{"title": "Python Today", "body": "Python is now used in many fields.\n\n• Python 3.0 was released in 2008 to fix older language flaws.\n• The Python Software Foundation supports and promotes the language.\n• Python is used by organizations like NASA, Google, and Netflix.\n• Django is one of Python's major web development frameworks."},
			],
		},
		{
			"flag": "ch2_y1s1_teaching_done",
			"title": "Professor Markup — HTML, CSS, and Layout",
			"preview": "HTML structure, CSS styling, DOM thinking, and Flexbox layout.",
			"deck_key": "markup",
		},
		{
			"flag": "ch2_y1s2_teaching_done",
			"title": "Professor Syntax — Python Core and OOP",
			"preview": "Python data types, loops, classes, constructors, and HTTP requests.",
			"deck_key": "syntax",
		},
		{
			"flag": "ch2_y2s1_teaching_done",
			"title": "Professor View — Django Setup, URLs, Views, Templates",
			"preview": "Virtual environments, manage.py, URL routing, view functions, templates, and static files.",
			"deck_key": "view",
		},
		{
			"flag": "ch2_y2s2_teaching_done",
			"title": "Professor Query — Models, ORM, and Relationships",
			"preview": "Django models, database relationships, migrations, and ORM queries.",
			"deck_key": "query",
		},
		{
			"flag": "ch2_y3s1_teaching_done",
			"title": "Professor Token — Forms, Validation, CSRF",
			"preview": "HTML forms, Django forms, validation, CSRF protection, and messages.",
			"deck_key": "token",
		},
		{
			"flag": "ch2_y3s2_teaching_done",
			"title": "Professor Auth — Authentication and Authorization",
			"preview": "Login, identity checks, permissions, and ownership rules.",
			"deck_key": "auth",
		},
		{
			"flag": "ch2_y3mid_teaching_done",
			"title": "Professor REST — APIs, Serializers, Routers",
			"preview": "Django REST Framework, JSON responses, serializers, viewsets, and API routing.",
			"deck_key": "rest",
		},
	]

# ─── Quest Log App ───────────────────────────────────────────────────────────

func _build_quest_log() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.visible = false

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "📋 Quest Log"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.3, 0.75, 0.4))
	vbox.add_child(header)

	var sep = HSeparator.new()
	vbox.add_child(sep)
	var qm = get_node_or_null("/root/QuestManager")
	_add_quest_recovery_controls(vbox, qm)

	# ── Main Quest section ──────────────────────────────────────
	var main_header = Label.new()
	main_header.text = "📌 Main Quest"
	main_header.add_theme_font_size_override("font_size", 13)
	main_header.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(main_header)


	if qm and qm.current_quest_text != "":
		var card = _create_quest_card(qm.current_quest_id, qm.current_quest_text, qm)
		vbox.add_child(card)
	else:
		var empty = Label.new()
		empty.text = "No active main quest."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
		vbox.add_child(empty)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# ── Side Quests section ─────────────────────────────────────
	var side_header = Label.new()
	side_header.text = "📝 Side Quests"
	side_header.add_theme_font_size_override("font_size", 13)
	side_header.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(side_header)

	var side_empty = Label.new()
	side_empty.text = "📭 No side quests available yet.\nCheck back as you progress through the story!"
	side_empty.add_theme_font_size_override("font_size", 11)
	side_empty.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
	side_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(side_empty)

	# Re-build when quest changes (so the card is live)
	if qm and not qm.quest_changed.is_connected(_on_quest_changed_refresh):
		qm.quest_changed.connect(_on_quest_changed_refresh)

	return scroll

func _on_quest_changed_refresh(_id: String, _text: String) -> void:
	if quest_log_content == null:
		return
	var scroll = quest_log_content as ScrollContainer
	if scroll == null:
		return
	var vbox = scroll.get_child(0) as VBoxContainer
	if vbox == null:
		return

	for c in vbox.get_children():
		c.queue_free()
	await get_tree().process_frame

	var header = Label.new()
	header.text = "📋 Quest Log"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.3, 0.75, 0.4))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())
	_add_quest_recovery_controls(vbox, get_node_or_null("/root/QuestManager"))

	var main_header = Label.new()
	main_header.text = "📌 Main Quest"
	main_header.add_theme_font_size_override("font_size", 13)
	main_header.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(main_header)

	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.current_quest_text != "":
		var card = _create_quest_card(qm.current_quest_id, qm.current_quest_text, qm)
		vbox.add_child(card)
	else:
		var empty = Label.new()
		empty.text = "No active main quest."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
		vbox.add_child(empty)

	vbox.add_child(HSeparator.new())

	var side_header = Label.new()
	side_header.text = "📝 Side Quests"
	side_header.add_theme_font_size_override("font_size", 13)
	side_header.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(side_header)

	var side_empty = Label.new()
	side_empty.text = "📭 No side quests available yet.\nCheck back as you progress through the story!"
	side_empty.add_theme_font_size_override("font_size", 11)
	side_empty.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
	side_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(side_empty)

func _create_quest_card(quest_id: String, quest_text: String, qm) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.14, 0.22)
	style.border_color = Color(0.2, 0.5, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Top row: title + tracking indicator
	var top = HBoxContainer.new()
	vbox.add_child(top)

	var title = Label.new()
	title.text = "📌 " + quest_id.to_upper().replace("_", " ")
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var indicator = Label.new()
	indicator.text = "✅ Tracking" if qm.tracked_quest_id == quest_id else ""
	indicator.add_theme_font_size_override("font_size", 10)
	indicator.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	top.add_child(indicator)

	# Quest text
	var body = Label.new()
	body.text = quest_text
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	# Track button
	var track_btn = Button.new()
	track_btn.text = "Track This Quest"
	track_btn.add_theme_font_size_override("font_size", 11)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.22, 0.14)
	btn_style.border_color = Color(0.3, 0.6, 0.35)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(4)
	track_btn.add_theme_stylebox_override("normal", btn_style)
	track_btn.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6))
	track_btn.pressed.connect(func():
		if qm.has_method("recover_visible_quest"):
			qm.recover_visible_quest()
		elif qm.has_method("reset_suppression"):
			qm.reset_suppression()
		qm.set_tracked_quest(quest_id)
		indicator.text = "✅ Tracking"
	)
	vbox.add_child(track_btn)

	# Store reference for later
	_quest_cards[quest_id] = {"card": card, "indicator": indicator}

	return card

func _add_quest_recovery_controls(vbox: VBoxContainer, qm) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var restore_btn = Button.new()
	restore_btn.text = "Restore Quest HUD"
	restore_btn.add_theme_font_size_override("font_size", 11)
	restore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.22, 0.34, 0.95)
	style.border_color = Color(0.25, 0.5, 0.75, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	restore_btn.add_theme_stylebox_override("normal", style)
	restore_btn.add_theme_color_override("font_color", Color(0.68, 0.86, 1.0))
	restore_btn.disabled = qm == null
	restore_btn.pressed.connect(func():
		var qm_live = get_node_or_null("/root/QuestManager")
		if qm_live == null:
			return
		if qm_live.has_method("recover_visible_quest"):
			qm_live.recover_visible_quest()
		elif qm_live.has_method("reset_suppression"):
			qm_live.reset_suppression()
		_on_quest_changed_refresh(qm_live.current_quest_id, qm_live.current_quest_text)
	)
	row.add_child(restore_btn)

# ─── SIS App ─────────────────────────────────────────────────────────────────
# Uses a sticky header (non-scrolling) with a scrollable cards area below.

func _build_sis() -> Control:
	var outer = Control.new()
	outer.name = "SISOuter"
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.visible = false

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	outer.add_child(margin)

	var layout = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header_panel = PanelContainer.new()
	header_panel.name = "SISHeaderPanel"
	var header_panel_style = StyleBoxFlat.new()
	header_panel_style.bg_color = Color(0.09, 0.115, 0.16, 1.0)
	header_panel_style.border_color = Color(0.28, 0.38, 0.55, 0.7)
	header_panel_style.set_border_width_all(1)
	header_panel_style.set_corner_radius_all(8)
	header_panel_style.set_content_margin_all(14)
	header_panel.add_theme_stylebox_override("panel", header_panel_style)
	layout.add_child(header_panel)

	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	header_panel.add_child(header_vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_vbox.add_child(header_hbox)

	var header = Label.new()
	header.name = "SISTitle"
	header.text = "Academic Records"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header)

	var gwa_label = Label.new()
	gwa_label.name = "GWALabel"
	gwa_label.text = "Academic GWA: " + _calculate_gwa()
	gwa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gwa_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gwa_label.custom_minimum_size = Vector2(172, 34)
	gwa_label.add_theme_font_size_override("font_size", 15)
	gwa_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	var gwa_style = StyleBoxFlat.new()
	gwa_style.bg_color = Color(0.18, 0.15, 0.08, 0.95)
	gwa_style.border_color = Color(0.75, 0.55, 0.18, 0.8)
	gwa_style.set_border_width_all(1)
	gwa_style.set_corner_radius_all(6)
	gwa_style.set_content_margin_all(8)
	gwa_label.add_theme_stylebox_override("normal", gwa_style)
	header_hbox.add_child(gwa_label)

	var subtitle = Label.new()
	subtitle.text = "Story professor grades, thesis evaluations, and learning mode records"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.64, 0.74))
	header_vbox.add_child(subtitle)

	var scroll = ScrollContainer.new()
	scroll.name = "SISScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.name = "SISCardVBox"
	vbox.custom_minimum_size = Vector2(660, 0)
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	_populate_sis_cards(vbox)

	return outer

func _refresh_sis():
	if sis_content == null: return

	# Update the sticky GWA label in-place (no rebuild needed)
	var gwa_lbl = sis_content.find_child("GWALabel", true, false)
	if gwa_lbl:
		gwa_lbl.text = "Academic GWA: " + _calculate_gwa()

	# Clear and repopulate only the scrollable cards vbox
	var vbox = sis_content.find_child("SISCardVBox", true, false) as VBoxContainer
	if vbox == null: return

	for c in vbox.get_children():
		c.queue_free()

	await get_tree().process_frame
	_populate_sis_cards(vbox)

func _populate_sis_cards(vbox: VBoxContainer) -> void:
	var cd = get_node_or_null("/root/CharacterData")

	vbox.add_child(_create_sis_section_label("Story Mode"))

	# Prof Markup
	if cd and (cd.get("ch2_y1s1_teaching_done") or float(cd.get("ch2_y1s1_final_grade")) > 0.0):
		vbox.add_child(_create_active_prof_card(
			"Professor Markup — HTML & CSS",
			cd.ch2_y1s1_final_grade,
			cd.ch2_y1s1_retake_count,
			cd.ch2_y1s1_removal_passed,
			cd.ch2_y1s1_removal_passed or cd.ch2_y1s1_final_grade <= 3.0
		))
	else:
		vbox.add_child(_create_locked_prof_card("Professor Markup — HTML & CSS"))

	# Prof Syntax
	if cd and (cd.get("ch2_y1s2_teaching_done") or float(cd.get("ch2_y1s2_final_grade")) > 0.0):
		vbox.add_child(_create_active_prof_card(
			"Professor Syntax — Python",
			float(cd.ch2_y1s2_final_grade),
			int(cd.ch2_y1s2_retake_count),
			bool(cd.ch2_y1s2_removal_passed),
			bool(cd.ch2_y1s2_removal_passed) or float(cd.ch2_y1s2_final_grade) <= 3.0
		))
	else:
		vbox.add_child(_create_locked_prof_card("Professor Syntax — Python"))

	# Prof View
	if cd and (cd.get("ch2_y2s1_teaching_done") or float(cd.get("ch2_y2s1_final_grade")) > 0.0):
		vbox.add_child(_create_active_prof_card(
			"Professor View — Django Setup & Views",
			float(cd.ch2_y2s1_final_grade),
			int(cd.ch2_y2s1_retake_count),
			bool(cd.ch2_y2s1_removal_passed),
			bool(cd.ch2_y2s1_removal_passed) or float(cd.ch2_y2s1_final_grade) <= 3.0
		))
	else:
		vbox.add_child(_create_locked_prof_card("Professor View — Django Setup & Views"))

	# Prof Query (with AI minigame monitoring)
	if cd and (cd.get("ch2_y2s2_teaching_done") or float(cd.get("ch2_y2s2_final_grade")) > 0.0):
		vbox.add_child(_create_active_prof_card(
			"Professor Query — Models, ORM & Databases",
			float(cd.ch2_y2s2_final_grade),
			int(cd.ch2_y2s2_retake_count),
			bool(cd.ch2_y2s2_removal_passed),
			bool(cd.ch2_y2s2_removal_passed) or float(cd.ch2_y2s2_final_grade) <= 3.0,
			{
				"ai_oto_skipped": bool(cd.ch2_y2s2_ai_oto_skipped),
				"ai_otm_skipped": bool(cd.ch2_y2s2_ai_otm_skipped),
				"ai_mtm_skipped": bool(cd.ch2_y2s2_ai_mtm_skipped),
				"ai_fully_offline": bool(cd.ch2_y2s2_ai_fully_offline),
			}
		))
	else:
		vbox.add_child(_create_locked_prof_card("Professor Query — Models, ORM & Databases"))

	if cd and (cd.get("ch2_y3s1_teaching_done") or float(cd.get("ch2_y3s1_final_grade")) > 0.0):
		vbox.add_child(_create_active_prof_card(
			"Professor Token — Forms & Security",
			float(cd.ch2_y3s1_final_grade),
			int(cd.ch2_y3s1_retake_count),
			bool(cd.ch2_y3s1_removal_passed),
			bool(cd.ch2_y3s1_removal_passed) or float(cd.ch2_y3s1_final_grade) <= 3.0
		))
	else:
		vbox.add_child(_create_locked_prof_card("Professor Token — Forms & Security"))
	if cd and (cd.get("ch2_y3s2_teaching_done") or float(cd.get("ch2_y3s2_final_grade")) > 0.0):
		vbox.add_child(_create_active_prof_card(
			"Professor Auth — Authentication & CRUD",
			float(cd.ch2_y3s2_final_grade),
			int(cd.ch2_y3s2_retake_count),
			bool(cd.ch2_y3s2_removal_passed),
			bool(cd.ch2_y3s2_removal_passed) or float(cd.ch2_y3s2_final_grade) <= 3.0
		))
	else:
		vbox.add_child(_create_locked_prof_card("Professor Auth — Authentication & CRUD"))
	if cd and (cd.get("ch2_y3mid_teaching_done") or float(cd.get("ch2_y3mid_final_grade")) > 0.0):
		vbox.add_child(_create_active_prof_card(
			"Professor REST — APIs & Modern Systems",
			float(cd.ch2_y3mid_final_grade),
			int(cd.ch2_y3mid_retake_count),
			bool(cd.ch2_y3mid_removal_passed),
			bool(cd.ch2_y3mid_removal_passed) or float(cd.ch2_y3mid_final_grade) <= 3.0
		))
	else:
		vbox.add_child(_create_locked_prof_card("Professor REST — APIs & Modern Systems"))

	# ─── Thesis Defense ───────────────────────────────────────────────────────
	if cd and cd.thesis_panelist_progress > 0:
		vbox.add_child(_create_sis_section_label("Thesis Defense Panelist Grades"))

		# Panelist 1
		if cd.thesis_panelist_progress >= 1:
			vbox.add_child(_create_active_prof_card(
				"Panelist Cruz — Django Project Setup",
				cd.thesis_panelist_1_grade,
				cd.thesis_panelist_1_retakes,
				false,
				float(cd.thesis_panelist_1_grade) <= 3.0,
				{},
				false
			))
		else:
			vbox.add_child(_create_locked_prof_card("Panelist Cruz — Django Project Setup"))

		# Panelist 2
		if cd.thesis_panelist_progress >= 2:
			vbox.add_child(_create_active_prof_card(
				"Panelist Santos — Data & Models",
				cd.thesis_panelist_2_grade,
				cd.thesis_panelist_2_retakes,
				false,
				float(cd.thesis_panelist_2_grade) <= 3.0,
				{},
				false
			))
		else:
			vbox.add_child(_create_locked_prof_card("Panelist Santos — Data & Models"))

		# Panelist 3
		if cd.thesis_panelist_progress >= 3:
			vbox.add_child(_create_active_prof_card(
				"Panelist Reyes — System Debugging (Final Boss)",
				cd.thesis_panelist_3_grade,
				cd.thesis_panelist_3_retakes,
				false,
				float(cd.thesis_panelist_3_grade) <= 3.0,
				{},
				false
			))
		else:
			vbox.add_child(_create_locked_prof_card("Panelist Reyes — System Debugging (Final Boss)"))

		if cd.thesis_completed:
			vbox.add_child(_create_sis_section_label("Academic GWA Subject"))
			var combined = (cd.thesis_panelist_1_grade + cd.thesis_panelist_2_grade + cd.thesis_panelist_3_grade) / 3.0
			var combined_snap = _snap_thesis_grade(combined)
			var combined_card = _create_active_prof_card(
				"Thesis — Final Subject Grade",
				combined_snap,
				0,
				false,
				combined_snap <= 3.0,
				{},
				false,
				false
			)
			vbox.add_child(combined_card)
	elif cd and cd.student_seq_progress.get("y3mid", 0) >= 5:
		vbox.add_child(_create_locked_prof_card("🎓 Thesis Defense — Locked (complete all professors first)"))

	# ─── Learning Mode Grades ──────────────────────────────────────────────────
	if cd and cd.get("learning_mode_grades") and not cd.learning_mode_grades.is_empty():
		vbox.add_child(_create_sis_section_label("Learning Mode"))

		for prof_key in cd.learning_mode_grades.keys():
			var grade = float(cd.learning_mode_grades[prof_key])
			var is_passing = grade <= 3.0
			var prof_display = prof_key.capitalize()
			
			var card = _create_active_prof_card(
				"Professor " + prof_display + " (Learning Mode)",
				grade,
				0,
				false,
				is_passing,
				{},
				false,
				false
			)
			vbox.add_child(card)

func _calculate_gwa() -> String:
	var cd = get_node_or_null("/root/CharacterData")
	if not cd: return "N/A"

	var total_grades = 0.0
	var count = 0

	if cd.get("ch2_y1s1_teaching_done"):
		total_grades += float(cd.ch2_y1s1_final_grade)
		count += 1

	if cd.get("ch2_y1s2_teaching_done"):
		total_grades += float(cd.ch2_y1s2_final_grade)
		count += 1

	if cd.get("ch2_y2s1_teaching_done"):
		total_grades += float(cd.ch2_y2s1_final_grade)
		count += 1

	if cd.get("ch2_y2s2_teaching_done"):
		total_grades += float(cd.ch2_y2s2_final_grade)
		count += 1

	if cd.get("ch2_y3s1_teaching_done"):
		total_grades += float(cd.ch2_y3s1_final_grade)
		count += 1

	if cd.get("ch2_y3s2_teaching_done"):
		total_grades += float(cd.ch2_y3s2_final_grade)
		count += 1

	if cd.get("ch2_y3mid_teaching_done"):
		total_grades += float(cd.ch2_y3mid_final_grade)
		count += 1

	# Thesis is counted as one completed subject after the three panelist grades are combined.
	if cd.thesis_completed:
		var combined = (cd.thesis_panelist_1_grade + cd.thesis_panelist_2_grade + cd.thesis_panelist_3_grade) / 3.0
		total_grades += _snap_thesis_grade(combined)
		count += 1

	if count == 0:
		return "N/A"

	var gwa = total_grades / count
	return "%.2f" % gwa

func _snap_thesis_grade(avg: float) -> float:
	if avg <= 1.125: return 1.0
	elif avg <= 1.375: return 1.25
	elif avg <= 1.75: return 1.5
	elif avg <= 2.25: return 2.0
	elif avg <= 2.75: return 2.5
	else: return 3.0

func _create_sis_section_label(text: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.09, 0.13, 0.95)
	style.border_color = Color(0.22, 0.29, 0.42, 0.75)
	style.border_width_bottom = 1
	style.set_content_margin(SIDE_LEFT, 12)
	style.set_content_margin(SIDE_RIGHT, 12)
	style.set_content_margin(SIDE_TOP, 8)
	style.set_content_margin(SIDE_BOTTOM, 8)
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.9))
	panel.add_child(label)
	return panel

func _create_active_prof_card(prof_name: String, grade: float, retakes: int, removal_passed: bool, is_passing: bool, ai_data: Dictionary = {}, show_inc: bool = true, show_retakes: bool = true) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.13, 0.18, 1.0)
	style.border_color = Color(0.28, 0.36, 0.5, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vbox.add_child(top)

	var title = Label.new()
	title.text = prof_name
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var grade_badge = Label.new()
	grade_badge.text = _format_sis_grade(grade)
	grade_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grade_badge.custom_minimum_size = Vector2(72, 30)
	grade_badge.add_theme_font_size_override("font_size", 15)
	grade_badge.add_theme_color_override("font_color", Color(0.08, 0.1, 0.12) if is_passing else Color(1.0, 0.92, 0.92))
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.55, 0.9, 0.62, 1.0) if is_passing else Color(0.72, 0.22, 0.25, 1.0)
	badge_style.set_corner_radius_all(6)
	badge_style.set_content_margin_all(6)
	grade_badge.add_theme_stylebox_override("normal", badge_style)
	top.add_child(grade_badge)

	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	_add_grid_row(grid, "Status", "Passed" if is_passing else "Needs Work", Color(0.45, 0.9, 0.55) if is_passing else Color(0.95, 0.45, 0.45))
	if show_retakes:
		_add_grid_row(grid, "Retakes", str(retakes), Color(0.78, 0.82, 0.9))
	if show_inc:
		_add_grid_row(grid, "Removal", "Passed" if removal_passed else ("Failed" if grade == 5.0 and retakes > 0 else "N/A"), Color(0.78, 0.82, 0.9))

	# ─── AI Minigame Monitoring Section ───────────────────────────────────────
	# Only shown when ai_data is provided (currently: Prof Query — Relationship Architecture)
	if not ai_data.is_empty():
		var ai_sep = HSeparator.new()
		var ai_sep_style = StyleBoxLine.new()
		ai_sep_style.color = Color(0.25, 0.3, 0.45, 0.5)
		ai_sep_style.thickness = 1
		ai_sep.add_theme_stylebox_override("separator", ai_sep_style)
		vbox.add_child(ai_sep)

		var ai_header = Label.new()
		ai_header.text = "AI Minigame - Relationship Architecture"
		ai_header.add_theme_font_size_override("font_size", 13)
		ai_header.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
		vbox.add_child(ai_header)

		var ai_grid = GridContainer.new()
		ai_grid.columns = 4
		ai_grid.add_theme_constant_override("h_separation", 12)
		ai_grid.add_theme_constant_override("v_separation", 6)
		vbox.add_child(ai_grid)

		var oto_skipped: bool = ai_data.get("ai_oto_skipped", false)
		var otm_skipped: bool = ai_data.get("ai_otm_skipped", false)
		var mtm_skipped: bool = ai_data.get("ai_mtm_skipped", false)
		var fully_offline: bool = ai_data.get("ai_fully_offline", false)

		_add_grid_row(ai_grid, "One-to-One:", "⚠️ Auto-skipped" if oto_skipped else "✅ Completed",
			Color(0.95, 0.65, 0.15) if oto_skipped else Color(0.4, 0.9, 0.5))
		_add_grid_row(ai_grid, "One-to-Many:", "⚠️ Auto-skipped" if otm_skipped else "✅ Completed",
			Color(0.95, 0.65, 0.15) if otm_skipped else Color(0.4, 0.9, 0.5))
		_add_grid_row(ai_grid, "Many-to-Many:", "⚠️ Auto-skipped" if mtm_skipped else "✅ Completed",
			Color(0.95, 0.65, 0.15) if mtm_skipped else Color(0.4, 0.9, 0.5))

		var skip_count = (1 if oto_skipped else 0) + (1 if otm_skipped else 0) + (1 if mtm_skipped else 0)
		if fully_offline:
			_add_grid_row(ai_grid, "Server Status:", "❌ Fully Offline (all 3 skipped)", Color(0.9, 0.35, 0.35))
		elif skip_count > 0:
			_add_grid_row(ai_grid, "Server Status:", "⚠️ Partial (%d/3 skipped)" % skip_count, Color(0.95, 0.65, 0.15))
		else:
			_add_grid_row(ai_grid, "Server Status:", "✅ Online — all completed", Color(0.4, 0.9, 0.5))

	return card

func _create_locked_prof_card(prof_name: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.085, 0.12, 0.92)
	style.border_color = Color(0.18, 0.22, 0.31, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var title = Label.new()
	title.text = prof_name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.52, 0.57, 0.67))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(title)

	var badge = Label.new()
	badge.text = "Locked"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(76, 28)
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.58, 0.62, 0.7))
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.11, 0.125, 0.16, 1.0)
	badge_style.border_color = Color(0.22, 0.25, 0.33, 0.9)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(6)
	badge_style.set_content_margin_all(5)
	badge.add_theme_stylebox_override("normal", badge_style)
	hbox.add_child(badge)

	return card

func _add_grid_row(grid: GridContainer, label_text: String, val_text: String, val_color: Color):
	var lbl1 = Label.new()
	lbl1.text = label_text
	lbl1.add_theme_font_size_override("font_size", 11)
	lbl1.add_theme_color_override("font_color", Color(0.55, 0.61, 0.72))
	grid.add_child(lbl1)

	var lbl2 = Label.new()
	lbl2.text = val_text
	lbl2.add_theme_font_size_override("font_size", 12)
	lbl2.add_theme_color_override("font_color", val_color)
	grid.add_child(lbl2)

func _format_sis_grade(grade: float) -> String:
	if is_equal_approx(grade, 0.0):
		return "--"
	return "%.2f" % grade

# ─── Settings App ────────────────────────────────────────────────────────────

func _build_settings() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.visible = false

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "⚙️ Settings — Audio & IDE"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.6, 0.35, 0.8))
	vbox.add_child(header)

	var audio_card = _create_settings_card()
	vbox.add_child(audio_card)

	var audio_vbox = VBoxContainer.new()
	audio_vbox.add_theme_constant_override("separation", 8)
	audio_card.add_child(audio_vbox)

	var audio_header = _create_settings_section_header("🔊 Audio")
	audio_vbox.add_child(audio_header)

	var audio_desc = Label.new()
	audio_desc.text = "Tune the background music and the sound effects without leaving the game."
	audio_desc.add_theme_font_size_override("font_size", 10)
	audio_desc.add_theme_color_override("font_color", Color(0.48, 0.54, 0.65))
	audio_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	audio_vbox.add_child(audio_desc)

	var audio_manager = get_node_or_null("/root/AudioManager")
	var music_volume = 0.75
	var sfx_volume = 0.85
	if audio_manager:
		music_volume = audio_manager.get_music_volume()
		sfx_volume = audio_manager.get_sfx_volume()

	audio_vbox.add_child(_create_audio_slider_row("Background Music", music_volume, _on_laptop_music_changed))
	audio_vbox.add_child(_create_audio_slider_row("Sound Effects", sfx_volume, _on_laptop_sfx_changed))

	var ide_card = _create_settings_card()
	vbox.add_child(ide_card)

	var ide_vbox = VBoxContainer.new()
	ide_vbox.add_theme_constant_override("separation", 10)
	ide_card.add_child(ide_vbox)

	# Theme section
	var theme_header = _create_settings_section_header("🎨 IDE Themes")
	ide_vbox.add_child(theme_header)

	var theme_desc = Label.new()
	theme_desc.text = "Unlock new themes by completing challenges!"
	theme_desc.add_theme_font_size_override("font_size", 10)
	theme_desc.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	ide_vbox.add_child(theme_desc)

	# Theme grid
	var theme_grid = GridContainer.new()
	theme_grid.columns = 3
	theme_grid.add_theme_constant_override("h_separation", 10)
	theme_grid.add_theme_constant_override("v_separation", 10)
	ide_vbox.add_child(theme_grid)

	var themes = [
		{"name": "Default Dark", "color": Color(0.16, 0.18, 0.24), "unlocked": true},
		{"name": "Matrix Green", "color": Color(0.0, 0.2, 0.0), "unlocked": false},
		{"name": "Hacker Red", "color": Color(0.2, 0.0, 0.0), "unlocked": false},
		{"name": "Ocean Blue", "color": Color(0.0, 0.1, 0.25), "unlocked": false},
		{"name": "Sunset", "color": Color(0.25, 0.1, 0.05), "unlocked": false},
		{"name": "Synthwave", "color": Color(0.15, 0.0, 0.2), "unlocked": false},
	]

	for theme in themes:
		var theme_btn = _create_theme_card(theme)
		theme_grid.add_child(theme_btn)

	return scroll

func _create_settings_card() -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 1.0)
	style.border_color = Color(0.19, 0.23, 0.34, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	return card

func _create_settings_section_header(text_value: String) -> Label:
	var label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	return label

func _create_audio_slider_row(label_text: String, current_value: float, changed_handler: Callable) -> VBoxContainer:
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)

	var title = Label.new()
	title.text = label_text
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98))
	block.add_child(title)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	block.add_child(row)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = roundi(current_value * 100.0)
	row.add_child(slider)

	var value_label = Label.new()
	value_label.custom_minimum_size = Vector2(44, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.8))
	value_label.text = "%d%%" % int(slider.value)
	row.add_child(value_label)

	slider.value_changed.connect(changed_handler.bind(value_label))
	return block

func _on_laptop_music_changed(value: float, value_label: Label) -> void:
	value_label.text = "%d%%" % int(round(value))
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.set_music_volume(value / 100.0)

func _on_laptop_sfx_changed(value: float, value_label: Label) -> void:
	value_label.text = "%d%%" % int(round(value))
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.set_sfx_volume(value / 100.0)

func _create_theme_card(theme_data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 70)
	var style = StyleBoxFlat.new()
	style.bg_color = theme_data["color"]
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)

	if theme_data.get("unlocked", false):
		style.border_color = Color(0.4, 0.8, 0.4)
		style.set_border_width_all(2)
	else:
		style.border_color = Color(0.3, 0.3, 0.3, 0.5)
		style.set_border_width_all(1)

	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = theme_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)

	if theme_data.get("unlocked", false):
		name_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	else:
		name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	vbox.add_child(name_label)

	if not theme_data.get("unlocked", false):
		var lock = Label.new()
		lock.text = "🔒"
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 16)
		vbox.add_child(lock)
	else:
		var check = Label.new()
		check.text = "✅ Equipped"
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_font_size_override("font_size", 9)
		check.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		vbox.add_child(check)

	return card

# ─── Taskbar ─────────────────────────────────────────────────────────────────

func _create_taskbar() -> PanelContainer:
	var bar = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18)
	style.set_content_margin_all(6)
	style.border_color = Color(0.2, 0.22, 0.3)
	style.border_width_top = 1
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	bar.add_theme_stylebox_override("panel", style)
	bar.custom_minimum_size = Vector2(0, 28)

	var hbox = HBoxContainer.new()
	bar.add_child(hbox)

	# OS name
	var os_label = Label.new()
	os_label.text = "  DjangoOS v1.0"
	os_label.add_theme_font_size_override("font_size", 10)
	os_label.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	os_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(os_label)

	# Credit display
	var credit_hbox = HBoxContainer.new()
	credit_hbox.name = "CreditDisplay"
	credit_hbox.add_theme_constant_override("separation", 4)
	hbox.add_child(credit_hbox)

	var credit_icon = TextureRect.new()
	credit_icon.custom_minimum_size = Vector2(14, 14)
	credit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	credit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var cred_tex = load("res://Textures/School Textures/Items/Interactable/Credit-32x32.png")
	if cred_tex:
		credit_icon.texture = cred_tex
	credit_hbox.add_child(credit_icon)

	_cred_label = Label.new()
	var cd = get_node_or_null("/root/CharacterData")
	_cred_label.text = str(cd.credits) if cd else "0"
	_cred_label.add_theme_font_size_override("font_size", 10)
	_cred_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	credit_hbox.add_child(_cred_label)

	# Spacer
	var cred_spacer = Label.new()
	cred_spacer.text = "  |  "
	cred_spacer.add_theme_font_size_override("font_size", 10)
	cred_spacer.add_theme_color_override("font_color", Color(0.35, 0.38, 0.45))
	hbox.add_child(cred_spacer)

	# Status icons
	var status = Label.new()
	status.text = "🔋 98%  |  📶  |  "
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	hbox.add_child(status)

	# Save button
	var save_btn = Button.new()
	save_btn.name = "SaveButton"
	save_btn.text = "💾 Save"
	save_btn.add_theme_font_size_override("font_size", 11)
	var save_style = StyleBoxFlat.new()
	save_style.bg_color = Color(0.15, 0.35, 0.25, 0.9)
	save_style.set_corner_radius_all(4)
	save_style.set_content_margin_all(4)
	save_btn.add_theme_stylebox_override("normal", save_style)
	var save_hover = save_style.duplicate()
	save_hover.bg_color = Color(0.2, 0.45, 0.3, 0.95)
	save_btn.add_theme_stylebox_override("hover", save_hover)
	save_btn.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	var exit_btn = Button.new()
	exit_btn.name = "ExitGameButton"
	exit_btn.text = "Exit Game"

	save_btn.pressed.connect(_on_save_pressed.bind(save_btn, exit_btn))
	hbox.add_child(save_btn)

	# Small spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	hbox.add_child(spacer)

	exit_btn.add_theme_font_size_override("font_size", 11)
	var exit_style = StyleBoxFlat.new()
	exit_style.bg_color = Color(0.6, 0.2, 0.2, 0.8)
	exit_style.set_corner_radius_all(4)
	exit_btn.add_theme_stylebox_override("normal", exit_style)
	exit_btn.add_theme_color_override("font_color", Color.WHITE)
	exit_btn.pressed.connect(_on_main_menu_pressed)
	hbox.add_child(exit_btn)

	return bar

func _on_save_pressed(btn: Button, exit_btn: Button = null):
	if is_saving: return
	is_saving = true
	btn.text = "⏳ Saving..."
	btn.disabled = true
	if exit_btn:
		exit_btn.disabled = true

	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		var LoadingOverlay = load("res://Scripts/UI/loading_overlay.gd")
		var overlay_text = "Saving and syncing progress..." if ApiManager.is_logged_in() else "Saving progress..."
		var overlay = LoadingOverlay.create(get_tree(), overlay_text)

		var save_result: Dictionary = await _run_manual_save_and_wait(sm)

		if is_instance_valid(overlay):
			await overlay.dismiss()

		if bool(save_result.get("success", false)):
			btn.text = "✅ Saved!"
			btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			btn.text = "⚠️ Save Failed"
			btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			push_warning("LaptopUI: Manual save failed: " + str(save_result.get("message", "Unknown save error.")))

		await get_tree().create_timer(1.5, true, false, true).timeout
		btn.text = "💾 Save"
		btn.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		btn.disabled = false
		if exit_btn:
			exit_btn.disabled = false
		is_saving = false
	else:
		btn.text = "❌ Error"
		await get_tree().create_timer(2.0, true, false, true).timeout
		btn.text = "💾 Save"
		btn.disabled = false
		if exit_btn:
			exit_btn.disabled = false
		is_saving = false

func _run_manual_save_and_wait(sm: Node) -> Dictionary:
	if not ApiManager.is_logged_in():
		sm.save_game()
		return {
			"success": true,
			"message": "Game saved!",
		}

	sm.save_game()

	while true:
		var result = await sm.save_completed
		var message = str(result[1])
		if message != "Saving...":
			return {
				"success": bool(result[0]),
				"message": message,
			}

	return {
		"success": false,
		"message": "Save did not finish.",
	}

func _on_main_menu_pressed():
	if is_saving:
		return
	CustomConfirm.prompt(
		"Exit to Main Menu",
		"Are you sure you want to exit game?",
		func():
			_prompt_exit_save_choice()
	)

func _prompt_exit_save_choice() -> void:
	CustomConfirm.prompt(
		"Save Before Exiting?",
		"Do you want to save your progress before going back to the main menu?\n\nYes = save first\nNo = exit without saving",
		Callable(self, "_exit_to_main_menu").bind(true),
		Callable(self, "_exit_to_main_menu").bind(false)
	)

func _exit_to_main_menu(save_first: bool) -> void:
	if is_saving:
		return
	is_saving = true

	var sm = get_node_or_null("/root/SaveManager")
	if save_first and sm:
		var LoadingOverlay = load("res://Scripts/UI/loading_overlay.gd")
		var overlay_text = "Saving progress before exiting..."
		var overlay = LoadingOverlay.create(get_tree(), overlay_text)
		var save_result: Dictionary = await _run_manual_save_and_wait(sm)
		if is_instance_valid(overlay):
			await overlay.dismiss()
		if not bool(save_result.get("success", false)):
			push_warning("LaptopUI: Exit save failed: " + str(save_result.get("message", "Unknown save error.")))
			is_saving = false
			return

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.clear_quest()
	is_saving = false
	close()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

# ─── Navigation ──────────────────────────────────────────────────────────────

# ─── Certificates App ────────────────────────────────────────────────────────

func _build_certificates() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.visible = false

	var vbox = VBoxContainer.new()
	vbox.name = "CertsVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	_populate_certificates(vbox)
	return scroll

func _refresh_certificates():
	if certificates_content == null: return
	var scroll = certificates_content as ScrollContainer
	if scroll == null: return
	var vbox = scroll.get_child(0) as VBoxContainer
	if vbox == null: return

	for c in vbox.get_children():
		c.queue_free()
	await get_tree().process_frame
	_populate_certificates(vbox)

func _populate_certificates(vbox: VBoxContainer) -> void:
	var cd = get_node_or_null("/root/CharacterData")

	# Header
	var header = Label.new()
	header.text = "🏆 ECertificates"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
	vbox.add_child(header)

	var desc = Label.new()
	desc.text = "Certificates earned by completing each topic's coursework.\nDownload PDFs at djangoquest.com/profile"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	# Topic certificate data
	var topics = [
		{"key": "y1s1", "topic": "HTML Basics"},
		{"key": "y1s2", "topic": "Python Data Types"},
		{"key": "y2s1", "topic": "Django Views & URL Routing"},
		{"key": "y2s2", "topic": "Django ORM & Relationships"},
		{"key": "y3s1", "topic": "Forms & Security"},
		{"key": "y3s2", "topic": "Authentication & CRUD"},
		{"key": "y3mid", "topic": "RESTful API Design"},
	]

	var all_done = true

	for t in topics:
		var done_flag = "ch2_%s_teaching_done" % t["key"]
		var done_at_flag = "ch2_%s_teaching_done_at" % t["key"]
		var is_done = cd and cd.get(done_flag)
		if not is_done: all_done = false

		var completed_at = ""
		if is_done and cd.get(done_at_flag):
			completed_at = str(cd.get(done_at_flag))

		vbox.add_child(_create_cert_card(t["topic"], is_done, completed_at, false))

	# Grand completion certificate
	var grand_at = ""
	if all_done and cd and cd.get("ch2_y3mid_teaching_done_at"):
		grand_at = str(cd.get("ch2_y3mid_teaching_done_at"))
	vbox.add_child(_create_cert_card("Full Completion — Mastery of Full-Stack Django", all_done, grand_at, true))

func _create_cert_card(topic: String, completed: bool, completed_at: String, is_grand: bool) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()

	if completed:
		if is_grand:
			style.bg_color = Color(0.2, 0.16, 0.05)
			style.border_color = Color(0.85, 0.65, 0.1)
		else:
			style.bg_color = Color(0.08, 0.14, 0.12)
			style.border_color = Color(0.2, 0.6, 0.3)
	else:
		style.bg_color = Color(0.08, 0.08, 0.1)
		style.border_color = Color(0.2, 0.2, 0.25)

	style.set_border_width_all(2 if completed else 1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	# Icon + Topic row
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	card_vbox.add_child(top)

	var icon_label = Label.new()
	icon_label.text = "🏆" if (completed and is_grand) else ("✅" if completed else "🔒")
	icon_label.add_theme_font_size_override("font_size", 18 if is_grand else 14)
	top.add_child(icon_label)

	var topic_label = Label.new()
	topic_label.text = topic
	topic_label.add_theme_font_size_override("font_size", 15 if is_grand else 13)
	topic_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if (completed and is_grand) else (Color(0.8, 0.9, 0.8) if completed else Color(0.4, 0.4, 0.45)))
	topic_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(topic_label)

	if completed and completed_at != "":
		var date_label = Label.new()
		date_label.text = "Completed: " + completed_at
		date_label.add_theme_font_size_override("font_size", 10)
		date_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.4))
		card_vbox.add_child(date_label)
	elif not completed:
		var lock_label = Label.new()
		if is_grand:
			lock_label.text = "Complete all 7 topics to unlock"
		else:
			lock_label.text = "Complete " + topic + " to unlock"
		lock_label.add_theme_font_size_override("font_size", 10)
		lock_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
		card_vbox.add_child(lock_label)

	# Action row for completed certs
	if completed:
		var actions = HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		card_vbox.add_child(actions)

		# View Certificate button
		var view_btn = Button.new()
		view_btn.text = "📜 View Certificate"
		view_btn.add_theme_font_size_override("font_size", 10)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.25, 0.35)
		btn_style.border_color = Color(0.3, 0.5, 0.7)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.set_content_margin_all(4)
		view_btn.add_theme_stylebox_override("normal", btn_style)
		var hover = btn_style.duplicate()
		hover.bg_color = Color(0.2, 0.35, 0.5)
		view_btn.add_theme_stylebox_override("hover", hover)
		view_btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		var cert_topic = topic
		var cert_date = completed_at
		var cert_grand = is_grand
		view_btn.pressed.connect(func(): _show_certificate_viewer(cert_topic, cert_date, cert_grand))
		actions.add_child(view_btn)

		var dl_label = Label.new()
		dl_label.text = "📥 Download PDF at djangoquest.com"
		dl_label.add_theme_font_size_override("font_size", 9)
		dl_label.add_theme_color_override("font_color", Color(0.3, 0.55, 0.9))
		actions.add_child(dl_label)

	return card

# ── Certificate Viewer Popup ─────────────────────────────────────────────────

func _show_certificate_viewer(topic: String, completed_at: String, is_grand: bool) -> void:
	# Create a full-screen overlay inside the laptop
	var overlay = Panel.new()
	overlay.name = "CertViewer"
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.88)
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_panel.add_child(overlay)

	# --- Outer border frame ---
	var outer_frame = PanelContainer.new()
	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = Color(0.98, 0.96, 0.90)
	outer_style.set_corner_radius_all(6)
	outer_style.set_content_margin_all(8)
	outer_frame.add_theme_stylebox_override("panel", outer_style)
	outer_frame.set_anchors_preset(Control.PRESET_CENTER)
	outer_frame.custom_minimum_size = Vector2(520, 370)
	outer_frame.size = Vector2(520, 370)
	outer_frame.position = Vector2(-260, -185)
	overlay.add_child(outer_frame)

	# --- Inner border frame ---
	var inner_frame = PanelContainer.new()
	var inner_style = StyleBoxFlat.new()
	inner_style.bg_color = Color(0.98, 0.96, 0.90)
	if is_grand:
		inner_style.border_color = Color(0.72, 0.53, 0.04)
	else:
		inner_style.border_color = Color(0.1, 0.32, 0.46)
	inner_style.set_border_width_all(3)
	inner_style.set_corner_radius_all(4)
	inner_style.set_content_margin_all(20)
	inner_frame.add_theme_stylebox_override("panel", inner_style)
	inner_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_frame.add_child(inner_frame)

	# --- Corner ornaments ---
	var ornament_color = Color(0.72, 0.53, 0.04) if is_grand else Color(0.1, 0.32, 0.46)
	for pos in [Vector2(14, 10), Vector2(496, 10), Vector2(14, 346), Vector2(496, 346)]:
		var orn = Label.new()
		orn.text = "✦"
		orn.add_theme_font_size_override("font_size", 16)
		orn.add_theme_color_override("font_color", Color(ornament_color.r, ornament_color.g, ornament_color.b, 0.5))
		orn.position = pos
		outer_frame.add_child(orn)

	# --- Certificate content ---
	var content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 5)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_frame.add_child(content)

	# Logo
	var logo_tex = load("res://icon.svg") as Texture2D
	if logo_tex:
		var logo = TextureRect.new()
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.custom_minimum_size = Vector2(160, 40)
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(logo)

	# Branding
	var brand = Label.new()
	brand.text = "D J A N G O Q U E S T"
	brand.add_theme_font_size_override("font_size", 10)
	var accent = Color(0.1, 0.45, 0.72) if not is_grand else Color(0.54, 0.4, 0.08)
	brand.add_theme_color_override("font_color", accent)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(brand)

	# Title
	var title = Label.new()
	title.text = "Certificate of Completion" if not is_grand else "Grand Certificate of Mastery"
	title.add_theme_font_size_override("font_size", 20)
	var title_color = Color(0.08, 0.26, 0.38) if not is_grand else Color(0.42, 0.31, 0.07)
	title.add_theme_color_override("font_color", title_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "DjangoQuest Educational Platform" if not is_grand else "Full-Stack Django Development"
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(sub)

	# Spacer
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 6)
	content.add_child(sp1)

	# "This certifies that"
	var cert_text = Label.new()
	cert_text.text = "T H I S   C E R T I F I E S   T H A T"
	cert_text.add_theme_font_size_override("font_size", 8)
	cert_text.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	cert_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cert_text)

	# Player name
	var cd = get_node_or_null("/root/CharacterData")
	var pname = "Student"
	if cd and cd.player_name != "":
		pname = cd.player_name

	var name_lbl = Label.new()
	name_lbl.text = pname
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_lbl)

	# Underline separator
	var sep1 = HSeparator.new()
	sep1.custom_minimum_size = Vector2(280, 0)
	sep1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(sep1)

	# "has successfully completed the coursework for"
	var mid_text = Label.new()
	mid_text.text = "has successfully completed the coursework for"
	mid_text.add_theme_font_size_override("font_size", 9)
	mid_text.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	mid_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(mid_text)

	# Topic (the star of the show)
	var topic_lbl = Label.new()
	topic_lbl.text = topic
	topic_lbl.add_theme_font_size_override("font_size", 16)
	topic_lbl.add_theme_color_override("font_color", accent)
	topic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	topic_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(topic_lbl)

	# Spacer
	var sp2 = Control.new()
	sp2.custom_minimum_size = Vector2(0, 4)
	content.add_child(sp2)

	# Decorative divider
	var sep2 = HSeparator.new()
	sep2.custom_minimum_size = Vector2(100, 0)
	sep2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(sep2)

	# Date
	if completed_at != "":
		var date_lbl = Label.new()
		# Format date to MM/DD/YYYY if in YYYY-MM-DD format
		var display_date = completed_at
		if completed_at.length() >= 10 and completed_at[4] == "-":
			var parts = completed_at.substr(0, 10).split("-")
			if parts.size() == 3:
				display_date = parts[1] + "/" + parts[2] + "/" + parts[0]
		date_lbl.text = "Completed on " + display_date
		date_lbl.add_theme_font_size_override("font_size", 9)
		date_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(date_lbl)

	# Grand trophy
	if is_grand:
		var trophy = Label.new()
		trophy.text = "🏆"
		trophy.add_theme_font_size_override("font_size", 24)
		trophy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(trophy)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕ Close"
	close_btn.add_theme_font_size_override("font_size", 11)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.15, 0.15, 0.18)
	close_style.border_color = Color(0.35, 0.35, 0.4)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(6)
	close_style.set_content_margin_all(8)
	close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover = close_style.duplicate()
	close_hover.bg_color = Color(0.25, 0.22, 0.28)
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	close_btn.pressed.connect(func(): overlay.queue_free())
	overlay.add_child(close_btn)
	close_btn.anchor_left = 0.5
	close_btn.anchor_right = 0.5
	close_btn.anchor_top = 1.0
	close_btn.anchor_bottom = 1.0
	close_btn.position = Vector2(-35, -45)

# ─── Navigation ──────────────────────────────────────────────────────────────

func _show_desktop():
	desktop_view.visible = true
	app_view.visible = false

# ─── Achievements App ────────────────────────────────────────────────────────

# Master list of all achievements (same order as server)
const ALL_ACHIEVEMENTS = [
	{"key": "ch1_complete", "name": "📜 Origin Story", "desc": "Completed Chapter 1", "unlock": "Complete the SHS Python history lesson and Chapter 1 story."},
	{"key": "ch1_perfect", "name": "🧠 History Buff", "desc": "Perfect Ch1 quiz score", "unlock": "Get a perfect score on the Chapter 1 Python history quiz."},
	{"key": "first_professor", "name": "🎓 Freshman Year", "desc": "Beat your first professor", "unlock": "Complete any one college professor course."},
	{"key": "all_professors", "name": "👨‍🎓 Dean's Lister", "desc": "Conquered all 7 professors", "unlock": "Complete all seven professor courses."},
	{"key": "honor_roll", "name": "🏅 Honor Roll", "desc": "Story GWA ≤ 1.75", "unlock": "Finish the professor storyline with a GWA of 1.75 or better."},
	{"key": "no_retakes", "name": "⚡ First Try", "desc": "Beat a professor with 0 retakes", "unlock": "Pass a professor course without needing a retake."},
	{"key": "comeback_kid", "name": "💪 Comeback Kid", "desc": "Passed a removal exam", "unlock": "Trigger an INC and pass the removal exam."},
	{"key": "thesis_started", "name": "📋 Panel Ready", "desc": "Beat your first panelist", "unlock": "Pass the first thesis panelist evaluation."},
	{"key": "thesis_defended", "name": "🎓 Thesis Defended", "desc": "Defended your thesis", "unlock": "Pass all thesis panelist evaluations."},
	{"key": "thesis_magna", "name": "🌟 Magna Cum Laude", "desc": "Thesis GWA ≤ 1.5", "unlock": "Defend the thesis with a thesis GWA of 1.5 or better."},
	{"key": "item_shopper", "name": "🛒 Shopaholic", "desc": "Used a shop item", "unlock": "Buy or use a shop item during eligible gameplay."},
	{"key": "challenge_10", "name": "🔥 Code Warrior", "desc": "10+ challenges completed", "unlock": "Complete at least 10 coding challenges."},
	{"key": "challenge_25", "name": "💎 Code Legend", "desc": "25+ challenges completed", "unlock": "Complete at least 25 coding challenges."},
	{"key": "community_helper", "name": "🤝 Community Helper", "desc": "Helped 15+ students", "unlock": "Help at least 15 student NPCs."},
	{"key": "full_clear", "name": "🏆 100% Complete", "desc": "100% story progress", "unlock": "Complete the main story, professor courses, students, thesis, and major progress goals."},
]

var _achievements_grid: GridContainer

func _build_achievements() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.visible = false
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "🏅 Your Achievements"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Counter label
	var counter = Label.new()
	counter.name = "AchievementCounter"
	counter.text = "0 / 15 Unlocked"
	counter.add_theme_font_size_override("font_size", 12)
	counter.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(counter)

	# Grid
	_achievements_grid = GridContainer.new()
	_achievements_grid.columns = 3
	_achievements_grid.add_theme_constant_override("h_separation", 10)
	_achievements_grid.add_theme_constant_override("v_separation", 10)
	_achievements_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_achievements_grid)

	return scroll

func _refresh_achievements():
	if not _achievements_grid:
		return

	# Clear old cards
	for c in _achievements_grid.get_children():
		c.queue_free()

	var cd = get_node_or_null("/root/CharacterData")
	var unlocked_keys: Array = cd.unlocked_achievements if cd else []
	var count = 0

	for ach in ALL_ACHIEVEMENTS:
		var is_unlocked = ach["key"] in unlocked_keys
		if is_unlocked:
			count += 1

		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 80)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var card_style = StyleBoxFlat.new()
		card_style.set_corner_radius_all(8)
		card_style.set_content_margin_all(8)
		if is_unlocked:
			card_style.bg_color = Color(0.18, 0.15, 0.05)
			card_style.border_color = Color(0.9, 0.7, 0.1, 0.6)
			card_style.set_border_width_all(2)
		else:
			card_style.bg_color = Color(0.08, 0.08, 0.12)
			card_style.border_color = Color(0.2, 0.2, 0.25)
			card_style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", card_style)

		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 2)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(card_vbox)

		# Icon / Name
		var name_label = Label.new()
		if is_unlocked:
			name_label.text = ach["name"]
			name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
		else:
			name_label.text = "🔒 " + str(ach["name"])
			name_label.add_theme_color_override("font_color", Color(0.48, 0.48, 0.56))
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(name_label)

		# Description
		var desc_label = Label.new()
		if is_unlocked:
			desc_label.text = ach["desc"]
			desc_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		else:
			desc_label.text = str(ach.get("unlock", ach["desc"]))
			desc_label.add_theme_color_override("font_color", Color(0.42, 0.43, 0.5))
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(desc_label)

		_achievements_grid.add_child(card)

	# Update counter
	var counter = achievements_content.find_child("AchievementCounter", true, false)
	if counter:
		counter.text = "%d / %d Unlocked" % [count, ALL_ACHIEVEMENTS.size()]


func _open_app(app_id: String):
	current_app = app_id
	desktop_view.visible = false
	app_view.visible = true

	# Hide all app contents
	retro_browser_content.visible = false
	notes_content.visible = false
	quest_log_content.visible = false
	settings_content.visible = false
	sis_content.visible = false
	certificates_content.visible = false
	achievements_content.visible = false

	# Show the selected app
	match app_id:
		"sis":
			app_title_label.text = "🎓 Student Information System"
			_refresh_sis()
			sis_content.visible = true
		"retro_browser":
			app_title_label.text = "🌐 RetroBrowser"
			_refresh_retro_browser()
			retro_browser_content.visible = true
		"notes":
			app_title_label.text = "📝 Notes"
			_refresh_notes()
			notes_content.visible = true
		"quest_log":
			app_title_label.text = "📋 Quest Log"
			quest_log_content.visible = true
		"settings":
			app_title_label.text = "⚙️ Settings"
			settings_content.visible = true
		"certificates":
			app_title_label.text = "🏆 ECertificates"
			_refresh_certificates()
			certificates_content.visible = true
		"achievements":
			app_title_label.text = "🏅 Achievements"
			_refresh_achievements()
			achievements_content.visible = true

func _back_to_desktop():
	current_app = ""
	_show_desktop()

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		# Don't toggle if a tutorial overlay is currently active
		for node in get_tree().get_nodes_in_group("tutorial_overlay_active"):
			if node.has_method("is_running") and node.is_running():
				return

		var current_scene = get_tree().current_scene
		if current_scene and (current_scene.name == "MainMenu" or current_scene.name == "IntroSlides" or current_scene.name == "LoginScreen"):
			return

		var is_story_mode = false
		if current_scene and (current_scene.name.contains("School") or current_scene.name.contains("Dorm") or current_scene.name.contains("Chapter") or get_tree().get_nodes_in_group("player").size() > 0):
			is_story_mode = true

		# Don't try to open Laptop UI if we are in Learning or Challenge Mode natively
		if not is_story_mode:
			return

		if not is_open:
			# Check if player is allowed to open it
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				var p = players[0]
				if p.get("block_ui_input") or not p.get("can_move"):
					return
				if p.get("inventory_ui") and p.inventory_ui.is_open:
					return
			open()
		else:
			# Don't close if player is in a tutorial (block_ui_input = true)
			var players2 = get_tree().get_nodes_in_group("player")
			if players2.size() > 0:
				var p2 = players2[0]
				if p2.get("block_ui_input"):
					return
			close()
