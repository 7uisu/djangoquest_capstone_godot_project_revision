# loading_overlay.gd — Reusable loading screen overlay
# DjangoQuest logo centered with an animated spinner ring, semi-transparent BG.
#
# Usage:
#   var LoadingOverlay = load("res://Scripts/UI/loading_overlay.gd")
#   var overlay = LoadingOverlay.create(get_tree())                              # generic
#   var overlay = LoadingOverlay.create(get_tree(), "Auto Saving, please wait...") # with subtitle
#   ...do work...
#   await overlay.dismiss()
extends CanvasLayer

signal dismissed

var _subtitle_text: String = ""
var _bg: ColorRect = null
var _logo: TextureRect = null
var _spinner: Control = null
var _subtitle_label: Label = null
var _spin_angle: float = 0.0

## Factory — instantiate the overlay and add it to the scene tree
static func create(tree: SceneTree, subtitle: String = "") -> Node:
	var overlay = CanvasLayer.new()
	overlay.set_script(load("res://Scripts/UI/loading_overlay.gd"))
	overlay.layer = 120
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay._subtitle_text = subtitle
	tree.current_scene.add_child(overlay)
	return overlay

func _ready():
	# ── Semi-transparent dark background ──────────────────────────────
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.0)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# ── Center container for logo + spinner ───────────────────────────
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	# ── Logo container (logo sits on top of spinner ring) ─────────────
	var logo_holder = Control.new()
	logo_holder.custom_minimum_size = Vector2(140, 140)
	logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(logo_holder)

	# Spinner ring (uses its own _draw callback)
	_spinner = _SpinnerRing.new()
	_spinner.overlay = self
	_spinner.custom_minimum_size = Vector2(140, 140)
	_spinner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_holder.add_child(_spinner)

	# Logo image
	var logo_tex = load("res://DQUESTLOGO.svg")
	if logo_tex:
		_logo = TextureRect.new()
		_logo.texture = logo_tex
		_logo.custom_minimum_size = Vector2(100, 100)
		_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_logo.position -= Vector2(50, 50)
		_logo.size = Vector2(100, 100)
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo_holder.add_child(_logo)

	# ── Subtitle label (optional) ─────────────────────────────────────
	if _subtitle_text != "":
		_subtitle_label = Label.new()
		_subtitle_label.text = _subtitle_text
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_subtitle_label.add_theme_font_size_override("font_size", 20)
		_subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))
		
		var font_res = load("res://Textures/Fonts/Pixelify_Sans/PixelifySans-VariableFont_wght.ttf")
		if font_res:
			_subtitle_label.add_theme_font_override("font", font_res)
			
		_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(_subtitle_label)

	# ── Fade in ───────────────────────────────────────────────────────
	var tween = create_tween()
	tween.tween_property(_bg, "color:a", 0.75, 0.3).set_ease(Tween.EASE_OUT)

func _process(delta):
	if _spinner and is_instance_valid(_spinner):
		_spin_angle += delta * 3.0
		_spinner.queue_redraw()

## Fade out and free
func dismiss():
	var tween = create_tween()
	tween.tween_property(_bg, "color:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	if _logo:
		tween.parallel().tween_property(_logo, "modulate:a", 0.0, 0.3)
	if _subtitle_label:
		tween.parallel().tween_property(_subtitle_label, "modulate:a", 0.0, 0.3)
	if _spinner:
		tween.parallel().tween_property(_spinner, "modulate:a", 0.0, 0.3)
	await tween.finished
	dismissed.emit()
	queue_free()


# ─── Inner class: draws the spinner ring via _draw() ─────────────────────────
class _SpinnerRing extends Control:
	var overlay  # reference to parent LoadingOverlay

	func _draw():
		if not overlay:
			return

		var center_pos = size / 2.0
		var radius = 62.0
		var arc_color = Color(0.94, 0.78, 0.42, 0.9)  # Warm gold
		var bg_ring_color = Color(1, 1, 1, 0.1)
		var line_width = 4.0
		var segments = 32

		# Background ring (full circle)
		for i in range(segments):
			var a1 = (float(i) / segments) * TAU
			var a2 = (float(i + 1) / segments) * TAU
			var p1 = center_pos + Vector2(cos(a1), sin(a1)) * radius
			var p2 = center_pos + Vector2(cos(a2), sin(a2)) * radius
			draw_line(p1, p2, bg_ring_color, line_width, true)

		# Animated arc (120-degree sweep that rotates)
		var arc_segments = 16
		var sweep = TAU * 0.33
		for i in range(arc_segments):
			var a1 = overlay._spin_angle + (float(i) / arc_segments) * sweep
			var a2 = overlay._spin_angle + (float(i + 1) / arc_segments) * sweep
			var p1 = center_pos + Vector2(cos(a1), sin(a1)) * radius
			var p2 = center_pos + Vector2(cos(a2), sin(a2)) * radius
			draw_line(p1, p2, arc_color, line_width, true)
