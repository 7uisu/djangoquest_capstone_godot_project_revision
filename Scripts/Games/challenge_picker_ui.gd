# challenge_picker_ui.gd — Browse and launch any coding challenge
# Run this scene directly or instantiate it in-game
extends Control

var ChallengeData = preload("res://Scripts/Games/coding_challenge_data.gd")
var ChallengeScene = preload("res://Scenes/Games/coding_challenge_ui.tscn")

var current_topic: String = "python"

@onready var topic_buttons: HBoxContainer = $VBox/TopicBar
@onready var challenge_list: VBoxContainer = $VBox/ScrollContainer/ChallengeList
@onready var title_label: Label = $VBox/TitleBar/Title
@onready var count_label: Label = $VBox/TitleBar/Count
@onready var close_button: Button = $VBox/TitleBar/CloseButton

# Topic button colors
const TOPIC_COLORS = {
	"python": Color("3572A5"),
	"html": Color("e34c26"),
	"css": Color("563d7c"),
	"django": Color("0C4B33"),
}

const TYPE_ICONS = {
	"debug": "🔧",
	"follow_steps": "📝",
	"predict_output": "🤔",
	"free_type": "⌨️",
	"terminal": "💻",
}

func _ready():
	# Apply custom pixel font
	var custom_font = preload("res://Textures/Fonts/Pixelify_Sans/static/PixelifySans-Regular.ttf")
	var custom_theme = Theme.new()
	custom_theme.default_font = custom_font
	theme = custom_theme

	close_button.pressed.connect(func(): queue_free())
	_create_topic_buttons()
	_load_topic("python")

func _create_topic_buttons():
	for child in topic_buttons.get_children():
		if child is Button:
			child.queue_free()

	for topic in ["python", "html", "css", "django"]:
		var btn = Button.new()
		btn.text = "  " + topic.to_upper() + "  "
		btn.add_theme_font_size_override("font_size", 15)

		var style = StyleBoxFlat.new()
		style.bg_color = TOPIC_COLORS.get(topic, Color("333333"))
		style.set_corner_radius_all(6)
		style.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", style)

		var style_hover = style.duplicate()
		style_hover.bg_color = TOPIC_COLORS.get(topic, Color("333333")).lightened(0.2)
		btn.add_theme_stylebox_override("hover", style_hover)

		btn.add_theme_color_override("font_color", Color("ffffff"))
		btn.add_theme_color_override("font_hover_color", Color("ffffff"))

		btn.pressed.connect(_load_topic.bind(topic))
		topic_buttons.add_child(btn)

func _load_topic(topic: String):
	current_topic = topic
	var challenges = ChallengeData.get_challenges_by_topic(topic)

	title_label.text = "  📂 " + topic.to_upper() + " Challenges"
	count_label.text = str(challenges.size()) + " challenges"

	# Clear old buttons
	for child in challenge_list.get_children():
		child.queue_free()

	# Style active topic tab
	var topic_btns = topic_buttons.get_children()
	var topics = ["python", "html", "css", "django"]
	for i in range(min(topic_btns.size(), topics.size())):
		var btn = topic_btns[i] as Button
		if btn == null:
			continue
		var style = StyleBoxFlat.new()
		if topics[i] == topic:
			style.bg_color = TOPIC_COLORS.get(topics[i], Color("333333"))
			style.border_color = Color("ffffff")
			style.set_border_width_all(2)
		else:
			style.bg_color = TOPIC_COLORS.get(topics[i], Color("333333")).darkened(0.3)
			style.border_color = Color("00000000")
			style.set_border_width_all(0)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", style)

	# Create challenge cards
	for i in range(challenges.size()):
		var challenge = challenges[i]
		var card = _create_challenge_card(challenge, i)
		challenge_list.add_child(card)

func _create_challenge_card(challenge: Dictionary, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("2d2d3d")
	style.border_color = Color("3d3d5c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Left: Type icon + Number
	var type_str = challenge.get("type", "debug")
	var icon = TYPE_ICONS.get(type_str, "❓")

	var number_label = Label.new()
	number_label.text = icon + "  #" + str(index + 1)
	number_label.add_theme_font_size_override("font_size", 14)
	number_label.add_theme_color_override("font_color", Color("8b8fa3"))
	number_label.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(number_label)

	# Middle: Title + Type
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title = Label.new()
	title.text = challenge.get("title", "Untitled")
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("e0e0e0"))
	info_vbox.add_child(title)

	var type_label = Label.new()
	var type_name = type_str.replace("_", " ").capitalize()
	var timed_text = "  ⏱ " + str(challenge.get("time_limit", 0)) + "s" if challenge.get("timed", false) else ""
	type_label.text = type_name + timed_text
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color("6b7280"))
	info_vbox.add_child(type_label)

	hbox.add_child(info_vbox)

	# Right: Play button
	var play_btn = Button.new()
	play_btn.text = "▶ Play"
	play_btn.add_theme_font_size_override("font_size", 13)
	play_btn.custom_minimum_size = Vector2(80, 0)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("1a6b35")
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(6)
	play_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color("22884a")
	play_btn.add_theme_stylebox_override("hover", btn_hover)

	play_btn.add_theme_color_override("font_color", Color("ffffff"))
	play_btn.add_theme_color_override("font_hover_color", Color("ffffff"))

	play_btn.pressed.connect(_launch_challenge.bind(challenge))
	hbox.add_child(play_btn)

	return panel

func _launch_challenge(challenge: Dictionary):
	# Hide picker, show IDE
	visible = false
	var ide = ChallengeScene.instantiate()
	ide.challenge_completed.connect(_on_challenge_done)
	get_tree().root.add_child(ide)
	# Must be in tree before load so @onready nodes are ready
	ide.load_challenge(challenge)

func _on_challenge_done(_success: bool, _id: String):
	# Show picker again when challenge ends
	visible = true

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
