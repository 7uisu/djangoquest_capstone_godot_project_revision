# intro_slides.gd — Visual novel intro with gender-specific slides + narration
# After all slides, plays bus transition (right-to-left) then loads school map.
extends Control

@onready var character_data = get_node("/root/CharacterData")
@onready var background_image: TextureRect = $BackgroundImage
@onready var slide_label: Label = $SlideIndicator
@onready var narration_panel: PanelContainer = $NarrationPanel
@onready var narration_text: RichTextLabel = $NarrationPanel/MarginContainer/VBoxContainer/NarrationText
@onready var continue_indicator: Label = $NarrationPanel/MarginContainer/VBoxContainer/ContinueIndicator

# Typewriter
@export var chars_per_second: float = 40.0
var _type_tween: Tween = null
var _indicator_tween: Tween = null
var is_typing: bool = false

# Slide data — loading actual introduction backgrounds and text
var male_slides: Array = [
	{ "image": "res://Textures/Introduction Cutscenes/INTRO1.png", "text": "In the bustling city, a young student named Mateo prepares for a new school year..." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO2BOY.png", "text": "He's heard rumors about a special class that teaches web development with Django." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO3BOY.png", "text": "Excited and curious, Mateo packs his bag and gets ready for the journey." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO4.png", "text": "The school is on the other side of town — a long bus ride away." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO5BOY.png", "text": "As the cityscape passes by, Mateo imagines the projects he'll build." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO6.png", "text": "The bus slows down... his new school comes into view." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO7.png", "text": "Taking a deep breath, Mateo prepares to step into a new chapter of his life." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO8BOY.png", "text": "The hallway seems larger, buzzing with students eager to learn." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO9BOY.png", "text": "She finds her classroom, spotting a familiar face among the crowd." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO10BOY.png", "text": "This is it – the beginning of her Django Quest!" },
]

var female_slides: Array = [
	{ "image": "res://Textures/Introduction Cutscenes/INTRO1.png", "text": "In the bustling city, a young student named Solmi prepares for a new school year..." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO2GIRL.png", "text": "She's heard rumors about a special class that teaches web development with Django." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO3GIRL.png", "text": "Excited and curious, Solmi packs her bag and gets ready for the journey." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO4.png", "text": "The school is on the other side of town — a long bus ride away." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO5GIRL.png", "text": "As the cityscape passes by, Solmi imagines the projects she'll build." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO6.png", "text": "The bus slows down... her new school comes into view." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO7.png", "text": "Taking a deep breath, Solmi prepares to step into a new chapter of her life." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO8GIRL.png", "text": "The hallway seems larger, buzzing with students eager to learn." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO9GIRL.png", "text": "She finds her classroom, spotting a familiar face among the crowd." },
	{ "image": "res://Textures/Introduction Cutscenes/INTRO10GIRL.png", "text": "This is it – the beginning of her Django Quest!" },
]

var current_slides: Array = []
var current_slide_index: int = -1
var is_active: bool = false

func _ready():
	# Pick slides based on gender
	if character_data.selected_gender == "female":
		current_slides = female_slides
	else:
		current_slides = male_slides

	continue_indicator.visible = false
	_start_indicator_blink()
	_advance()

func _input(event):
	if not is_active:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			_skip_typing()
		else:
			_advance()
		get_viewport().set_input_as_handled()

func _advance():
	current_slide_index += 1

	if current_slide_index >= current_slides.size():
		# All slides done — transition to school via bus
		_start_bus_transition()
		return

	is_active = true
	var slide = current_slides[current_slide_index]

	# Update slide indicator
	slide_label.text = str(current_slide_index + 1) + " / " + str(current_slides.size())

	# Update background image
	if background_image and slide.has("image"):
		var tex = load(slide["image"])
		if tex:
			background_image.texture = tex
			
	var color_rect = $BackgroundColor
	if color_rect:
		color_rect.visible = false # Hide placeholder color if we have real images

	# Typewriter narration
	continue_indicator.visible = false
	_type_text(slide["text"])

func _type_text(text: String):
	is_typing = true
	narration_text.text = text
	narration_text.visible_ratio = 0.0

	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()

	var duration = text.length() / chars_per_second
	_type_tween = create_tween()
	_type_tween.tween_property(narration_text, "visible_ratio", 1.0, duration)
	_type_tween.tween_callback(_on_typing_finished)

func _skip_typing():
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	narration_text.visible_ratio = 1.0
	_on_typing_finished()

func _on_typing_finished():
	is_typing = false
	continue_indicator.visible = true

func _start_bus_transition():
	is_active = false
	# Use SceneTransition autoload for bus transition to school map
	var scene_transition = get_node("/root/SceneTransition")
	if scene_transition and scene_transition.has_method("transition_to_scene_with_bus"):
		scene_transition.transition_to_scene_with_bus(
			"res://Scenes/Ch1/school_map.tscn",
			false  # goes_right = false → right-to-left
		)
	else:
		# Fallback: simple scene change
		get_tree().change_scene_to_file("res://Scenes/Ch1/school_map.tscn")

func _start_indicator_blink():
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 0.3, 0.5)
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)
