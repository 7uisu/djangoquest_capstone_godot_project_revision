# laptop_ui.gd — In-game laptop overlay with 4 apps
# Attach to a CanvasLayer. Toggle with "toggle_laptop" input (X key).
extends CanvasLayer

var is_open: bool = false
var current_app: String = ""  # "" = desktop, "retro_browser", "notes", "messages", "settings"

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
var messages_content: Control
var settings_content: Control

func _ready():
	layer = 90
	visible = false
	_build_ui()

func open():
	is_open = true
	visible = true
	current_app = ""
	_show_desktop()
	_set_player_can_move(false)

func close():
	is_open = false
	visible = false
	current_app = ""
	_set_player_can_move(true)

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

# ─── Desktop (4 App Icons) ───────────────────────────────────────────────────

func _create_desktop() -> Control:
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Center the grid
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(center)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 30)
	center.add_child(grid)

	# App icons
	var apps = [
		{"id": "retro_browser", "name": "RetroBrowser", "icon": "🌐", "color": Color(0.2, 0.5, 0.9), "desc": "Replay unlocked challenges"},
		{"id": "notes", "name": "Notes", "icon": "📝", "color": Color(0.85, 0.75, 0.2), "desc": "Your knowledge base"},
		{"id": "messages", "name": "Messages", "icon": "📨", "color": Color(0.3, 0.75, 0.4), "desc": "Quest messages"},
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
	messages_content = _build_messages()
	settings_content = _build_settings()

	app_content.add_child(retro_browser_content)
	app_content.add_child(notes_content)
	app_content.add_child(messages_content)
	app_content.add_child(settings_content)

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

# ─── Messages App ────────────────────────────────────────────────────────────

func _build_messages() -> ScrollContainer:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.visible = false

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "📨 Messages — Quest Log"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.3, 0.75, 0.4))
	vbox.add_child(header)

	# Sample messages (placeholder)
	var messages = [
		{
			"sender": "👨‍🏫 Professor",
			"subject": "Welcome to DjangoQuest!",
			"preview": "Your coding journey begins now. Talk to NPCs around campus to start learning!",
			"time": "Just now",
			"unread": true,
		},
		{
			"sender": "📦 System",
			"subject": "Laptop Setup Complete",
			"preview": "Your DjangoQuest laptop is ready. Press X anytime to open it.",
			"time": "Earlier",
			"unread": false,
		},
	]

	for msg in messages:
		var msg_card = _create_message_card(msg)
		vbox.add_child(msg_card)

	return scroll

func _create_message_card(msg: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16) if not msg.get("unread", false) else Color(0.1, 0.14, 0.22)
	style.border_color = Color(0.2, 0.3, 0.45) if msg.get("unread", false) else Color(0.15, 0.18, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Top row: sender + time
	var top = HBoxContainer.new()
	vbox.add_child(top)

	var sender = Label.new()
	sender.text = msg.get("sender", "Unknown")
	sender.add_theme_font_size_override("font_size", 12)
	sender.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5) if msg.get("unread") else Color(0.6, 0.65, 0.7))
	sender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sender)

	var time_label = Label.new()
	time_label.text = msg.get("time", "")
	time_label.add_theme_font_size_override("font_size", 9)
	time_label.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
	top.add_child(time_label)

	# Subject
	var subject = Label.new()
	subject.text = msg.get("subject", "")
	subject.add_theme_font_size_override("font_size", 13)
	subject.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	vbox.add_child(subject)

	# Preview
	var preview = Label.new()
	preview.text = msg.get("preview", "")
	preview.add_theme_font_size_override("font_size", 10)
	preview.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(preview)

	# Unread dot
	if msg.get("unread", false):
		var dot = Label.new()
		dot.text = "● NEW"
		dot.add_theme_font_size_override("font_size", 9)
		dot.add_theme_color_override("font_color", Color(0.3, 0.8, 0.5))
		vbox.add_child(dot)

	return card

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

	# Status icons
	var status = Label.new()
	status.text = "🔋 98%  |  📶  |  [X] Close"
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	hbox.add_child(status)

	return bar

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
	messages_content.visible = false
	settings_content.visible = false

	# Show the selected app
	match app_id:
		"retro_browser":
			app_title_label.text = "🌐 RetroBrowser"
			retro_browser_content.visible = true
		"notes":
			app_title_label.text = "📝 Notes"
			notes_content.visible = true
		"messages":
			app_title_label.text = "📨 Messages"
			messages_content.visible = true
		"settings":
			app_title_label.text = "⚙️ Settings"
			settings_content.visible = true

func _back_to_desktop():
	current_app = ""
	_show_desktop()

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _set_player_can_move(value: bool):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = value
