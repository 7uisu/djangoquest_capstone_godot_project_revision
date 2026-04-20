# laptop_ui.gd — In-game laptop overlay with 4 apps
# Attach to a CanvasLayer. Toggle with "toggle_laptop" input (X key).
extends CanvasLayer

var is_open: bool = false
var is_saving: bool = false
var current_app: String = ""  # "" = desktop, "retro_browser", "notes", "quest_log", "settings"

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

var _cred_label: Label

# Quest log card references (for updating the tracked indicator)
var _quest_cards: Dictionary = {}  # quest_id -> { card, indicator }

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

func close():
	if is_saving: return
	is_open = false
	visible = false
	get_tree().paused = false
	current_app = ""
	var qm = get_node_or_null("/root/QuestManager")
	if qm: qm.show_quest()

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
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Center the grid
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		{"id": "settings", "name": "Settings", "icon": "⚙️", "color": Color(0.6, 0.35, 0.8), "desc": "Customize your IDE"},
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

	var app_id = app["id"]
	btn.pressed.connect(func(): _open_app(app_id))
	vbox.add_child(btn)

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

	app_content.add_child(retro_browser_content)
	app_content.add_child(notes_content)
	app_content.add_child(quest_log_content)
	app_content.add_child(settings_content)
	app_content.add_child(sis_content)

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

	# Empty state
	var empty = Label.new()
	empty.text = "📭 No challenges unlocked yet.\nTalk to NPCs around the world to unlock challenges!"
	empty.add_theme_font_size_override("font_size", 12)
	empty.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(empty)

	return scroll

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
	desc.text = "Concepts and lessons you've learned from NPCs will be saved here.\nUse these notes when you get stuck on a challenge!"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Placeholder notes
	var topics = [
		{"title": "📗 What is Python?", "preview": "A beginner-friendly programming language..."},
		{"title": "📘 HTML Basics", "preview": "The skeleton of every webpage..."},
		{"title": "📙 CSS Styling", "preview": "Making things look pretty..."},
		{"title": "📕 Django Framework", "preview": "The web framework for perfectionists..."},
	]

	for topic in topics:
		var note_card = _create_note_card(topic["title"], topic["preview"])
		vbox.add_child(note_card)

	return scroll

func _create_note_card(title_text: String, preview: String) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18)
	style.border_color = Color(0.2, 0.25, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.8, 0.83, 0.92))
	vbox.add_child(title)

	var prev = Label.new()
	prev.text = preview
	prev.add_theme_font_size_override("font_size", 10)
	prev.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	prev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(prev)

	return card

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

	# ── Main Quest section ──────────────────────────────────────
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
		qm.set_tracked_quest(quest_id)
		indicator.text = "✅ Tracking"
	)
	vbox.add_child(track_btn)

	# Store reference for later
	_quest_cards[quest_id] = {"card": card, "indicator": indicator}

	return card

# ─── SIS App ─────────────────────────────────────────────────────────────────
# Uses a sticky header (non-scrolling) with a scrollable cards area below.

func _build_sis() -> Control:
	# Outer wrapper — fills the app content area, never scrolls
	var outer = VBoxContainer.new()
	outer.name = "SISOuter"
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	outer.visible = false

	# ── Sticky header panel ───────────────────────────────────────────────────
	var header_panel = PanelContainer.new()
	header_panel.name = "SISHeaderPanel"
	var header_panel_style = StyleBoxFlat.new()
	header_panel_style.bg_color = Color(0.08, 0.10, 0.16, 1.0)
	header_panel_style.border_color = Color(0.2, 0.25, 0.4, 0.7)
	header_panel_style.border_width_bottom = 1
	header_panel_style.set_content_margin_all(12)
	header_panel.add_theme_stylebox_override("panel", header_panel_style)
	outer.add_child(header_panel)

	var header_hbox = HBoxContainer.new()
	header_panel.add_child(header_hbox)

	var header = Label.new()
	header.name = "SISTitle"
	header.text = "📋 Academic Records"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header)

	var gwa_label = Label.new()
	gwa_label.name = "GWALabel"
	gwa_label.text = "GWA: " + _calculate_gwa()
	gwa_label.add_theme_font_size_override("font_size", 14)
	gwa_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	header_hbox.add_child(gwa_label)

	# ── Scrollable cards area ─────────────────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.name = "SISScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.name = "SISCardVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# Generate initial cards
	_populate_sis_cards(vbox)

	return outer

func _refresh_sis():
	if sis_content == null: return

	# Update the sticky GWA label in-place (no rebuild needed)
	var gwa_lbl = sis_content.find_child("GWALabel", true, false)
	if gwa_lbl:
		gwa_lbl.text = "GWA: " + _calculate_gwa()

	# Clear and repopulate only the scrollable cards vbox
	var vbox = sis_content.find_child("SISCardVBox", true, false) as VBoxContainer
	if vbox == null: return

	for c in vbox.get_children():
		c.queue_free()

	await get_tree().process_frame
	_populate_sis_cards(vbox)

func _populate_sis_cards(vbox: VBoxContainer) -> void:
	var cd = get_node_or_null("/root/CharacterData")

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

	# ─── Learning Mode Sandbox Grades ──────────────────────────────────────────
	if cd and cd.get("learning_mode_grades") and not cd.learning_mode_grades.is_empty():
		var lm_sep = HSeparator.new()
		var lm_sep_style = StyleBoxLine.new()
		lm_sep_style.color = Color(0.25, 0.45, 0.65, 0.5)
		lm_sep_style.thickness = 2
		lm_sep.add_theme_stylebox_override("separator", lm_sep_style)
		vbox.add_child(lm_sep)

		var lm_header = Label.new()
		lm_header.text = "📚 Learning Mode Sandbox Grades"
		lm_header.add_theme_font_size_override("font_size", 16)
		lm_header.add_theme_color_override("font_color", Color(0.3, 0.75, 0.9))
		vbox.add_child(lm_header)

		for prof_key in cd.learning_mode_grades.keys():
			var grade = float(cd.learning_mode_grades[prof_key])
			var is_passing = grade <= 3.0
			var prof_display = prof_key.capitalize()
			
			var card = _create_active_prof_card(
				"Professor " + prof_display + " (Sandbox)",
				grade,
				0,			# Sandbox doesn't track retakes over time
				false,		# No removal exams in sandbox
				is_passing
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

	if count == 0:
		return "N/A"

	var gwa = total_grades / count
	return "%.2f" % gwa

func _create_active_prof_card(prof_name: String, grade: float, retakes: int, removal_passed: bool, is_passing: bool, ai_data: Dictionary = {}) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.22, 1.0)
	style.border_color = Color(0.4, 0.6, 0.9, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title = Label.new()
	title.text = "▼ " + prof_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	_add_grid_row(grid, "Final Grade:", "%.2f" % grade, Color(0.4, 0.9, 0.5) if is_passing else Color(0.9, 0.4, 0.4))
	_add_grid_row(grid, "Retakes:", str(retakes), Color(0.8, 0.8, 0.8))
	_add_grid_row(grid, "INC (Removal Exam):", "Passed" if removal_passed else ("Failed" if grade == 5.0 and retakes > 0 else "N/A"), Color(0.8, 0.8, 0.8))

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
		ai_header.text = "🤖 AI Minigame — Relationship Architecture"
		ai_header.add_theme_font_size_override("font_size", 13)
		ai_header.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
		vbox.add_child(ai_header)

		var ai_grid = GridContainer.new()
		ai_grid.columns = 2
		ai_grid.add_theme_constant_override("h_separation", 40)
		ai_grid.add_theme_constant_override("v_separation", 4)
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
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.8)
	style.border_color = Color(0.2, 0.25, 0.35, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	var title = Label.new()
	title.text = "▶ " + prof_name + " (Locked)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
	card.add_child(title)

	return card

func _add_grid_row(grid: GridContainer, label_text: String, val_text: String, val_color: Color):
	var lbl1 = Label.new()
	lbl1.text = "  " + label_text
	lbl1.add_theme_font_size_override("font_size", 14)
	lbl1.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	grid.add_child(lbl1)

	var lbl2 = Label.new()
	lbl2.text = val_text
	lbl2.add_theme_font_size_override("font_size", 14)
	lbl2.add_theme_color_override("font_color", val_color)
	grid.add_child(lbl2)

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
	header.text = "⚙️ Settings — IDE Customization"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.6, 0.35, 0.8))
	vbox.add_child(header)

	# Theme section
	var theme_header = Label.new()
	theme_header.text = "🎨 IDE Themes"
	theme_header.add_theme_font_size_override("font_size", 13)
	theme_header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(theme_header)

	var theme_desc = Label.new()
	theme_desc.text = "Unlock new themes by completing challenges!"
	theme_desc.add_theme_font_size_override("font_size", 10)
	theme_desc.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	vbox.add_child(theme_desc)

	# Theme grid
	var theme_grid = GridContainer.new()
	theme_grid.columns = 3
	theme_grid.add_theme_constant_override("h_separation", 10)
	theme_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(theme_grid)

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
	credit_hbox.add_theme_constant_override("separation", 4)
	hbox.add_child(credit_hbox)

	var credit_icon = TextureRect.new()
	credit_icon.custom_minimum_size = Vector2(14, 14)
	credit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	credit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var cred_tex = load("res://Textures/School Textures/Items/Interactable/CreditCard-32x32.png")
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
		sm.save_game()
		await get_tree().create_timer(2.0).timeout
		btn.text = "✅ Saved!"
		btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		await get_tree().create_timer(1.5).timeout
		btn.text = "💾 Save"
		btn.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		btn.disabled = false
		if exit_btn:
			exit_btn.disabled = false
		is_saving = false
	else:
		btn.text = "❌ Error"
		await get_tree().create_timer(2.0).timeout
		btn.text = "💾 Save"
		btn.disabled = false
		if exit_btn:
			exit_btn.disabled = false
		is_saving = false

func _on_main_menu_pressed():
	CustomConfirm.prompt(
		"Exit to Main Menu",
		"Are you sure you want to exit game?",
		func():
			var qm = get_node_or_null("/root/QuestManager")
			if qm:
				qm.clear_quest()
			close()
			get_tree().paused = false
			get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
	)

# ─── Navigation ──────────────────────────────────────────────────────────────

func _show_desktop():
	desktop_view.visible = true
	app_view.visible = false

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

	# Show the selected app
	match app_id:
		"sis":
			app_title_label.text = "🎓 Student Information System"
			_refresh_sis()
			sis_content.visible = true
		"retro_browser":
			app_title_label.text = "🌐 RetroBrowser"
			retro_browser_content.visible = true
		"notes":
			app_title_label.text = "📝 Notes"
			notes_content.visible = true
		"quest_log":
			app_title_label.text = "📋 Quest Log"
			quest_log_content.visible = true
		"settings":
			app_title_label.text = "⚙️ Settings"
			settings_content.visible = true

func _back_to_desktop():
	current_app = ""
	_show_desktop()

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
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
			close()
