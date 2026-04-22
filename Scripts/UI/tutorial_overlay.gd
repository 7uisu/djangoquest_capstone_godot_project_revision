# tutorial_overlay.gd — Contextual Spotlight Tutorial System
# Instantiate via code. Shows a dark overlay with a spotlight hole on a target node.
# Each step can wait for a specific player action before advancing.
extends CanvasLayer

signal tutorial_finished

var steps: Array = []
var current_step: int = -1
var _target_node: Control = null
var _watching_action: String = ""
var _waiting_for_advance: bool = false
var _is_running: bool = false

# Typewriter
var _typewriter_active: bool = false
var _typewriter_total: int = 0
var _typewriter_speed: float = 40.0  # characters per second
var _typewriter_elapsed: float = 0.0

# UI nodes (created in _ready)
var spotlight_rect: ColorRect = null
var tooltip_panel: PanelContainer = null
var instruction_label: RichTextLabel = null
var shader_mat: ShaderMaterial = null
var _arrow_label: Label = null

func _ready():
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _build_ui():
	# Full-screen spotlight rect with shader
	spotlight_rect = ColorRect.new()
	spotlight_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spotlight_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var shader = load("res://Shaders/spotlight_overlay.gdshader")
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("spotlight_pos", Vector2(0.5, 0.5))
	shader_mat.set_shader_parameter("spotlight_size", Vector2(0.0, 0.0))
	spotlight_rect.material = shader_mat
	add_child(spotlight_rect)

	# Tooltip panel
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "TooltipPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.14, 0.95)
	style.border_color = Color(0.4, 0.6, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	tooltip_panel.add_theme_stylebox_override("panel", style)
	tooltip_panel.custom_minimum_size = Vector2(280, 0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	tooltip_panel.add_child(vbox)

	# Arrow indicator
	_arrow_label = Label.new()
	_arrow_label.text = "▼"
	_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_label.add_theme_font_size_override("font_size", 20)
	_arrow_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(_arrow_label)

	# Instruction text
	instruction_label = RichTextLabel.new()
	instruction_label.bbcode_enabled = true
	instruction_label.fit_content = true
	instruction_label.scroll_active = false
	instruction_label.add_theme_font_size_override("normal_font_size", 14)
	instruction_label.add_theme_color_override("default_color", Color(0.9, 0.92, 1.0))
	var font = load("res://Textures/Fonts/Pixelify_Sans/static/PixelifySans-Regular.ttf")
	if font:
		instruction_label.add_theme_font_override("normal_font", font)
	vbox.add_child(instruction_label)

	# Continue hint
	var continue_hint = Label.new()
	continue_hint.name = "ContinueHint"
	continue_hint.text = ""
	continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_hint.add_theme_font_size_override("font_size", 10)
	continue_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	vbox.add_child(continue_hint)

	add_child(tooltip_panel)
	tooltip_panel.visible = false

# ── Public API ───────────────────────────────────────────────────────────────

func start_tutorial(tutorial_steps: Array) -> void:
	if tutorial_steps.is_empty():
		tutorial_finished.emit()
		return
	steps = tutorial_steps
	current_step = -1
	_is_running = true
	visible = true
	add_to_group("tutorial_overlay_active")
	_next_step()

func notify_action(action: String) -> void:
	if not _is_running:
		return
	if action == _watching_action:
		_watching_action = ""
		_next_step()

func is_running() -> bool:
	return _is_running

# ── Typewriter _process ──────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _typewriter_active:
		return
	_typewriter_elapsed += delta
	var chars_to_show = int(_typewriter_elapsed * _typewriter_speed)
	if chars_to_show >= _typewriter_total:
		instruction_label.visible_characters = -1
		_typewriter_active = false
	else:
		instruction_label.visible_characters = chars_to_show

# ── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent):
	if not _is_running:
		return

	# Block Esc and E while tutorial is active to prevent closing laptop/inventory
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_inventory"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()

		# If typewriter is still typing, complete it instantly
		if _typewriter_active:
			instruction_label.visible_characters = -1
			_typewriter_active = false
			return

		# If waiting for spacebar advance, go to next step
		if _waiting_for_advance:
			_waiting_for_advance = false
			_next_step()

# ── Step Logic ───────────────────────────────────────────────────────────────

func _next_step() -> void:
	current_step += 1
	if current_step >= steps.size():
		_end_tutorial()
		return
	_apply_step(steps[current_step])

func _apply_step(step: Dictionary) -> void:
	var text = step.get("text", "")
	instruction_label.text = text
	_watching_action = step.get("wait_for", "")
	_waiting_for_advance = false
	_target_node = null

	# Start typewriter effect
	instruction_label.visible_characters = 0
	_typewriter_active = true
	_typewriter_elapsed = 0.0
	# Get character count after setting text (works with BBCode)
	_typewriter_total = instruction_label.get_total_character_count()
	if _typewriter_total <= 0:
		_typewriter_total = text.length()

	# Spotlight target
	var node_ref = step.get("highlight_node", null)
	if node_ref is Control and is_instance_valid(node_ref):
		_target_node = node_ref
		_point_spotlight_at(_target_node)
	elif node_ref is String and node_ref != "":
		var found = _find_node_by_name(node_ref)
		if found is Control:
			_target_node = found
			_point_spotlight_at(_target_node)
		else:
			_clear_spotlight()
	else:
		_clear_spotlight()

	# Move tooltip off-screen but keep visible so Godot computes its real size
	tooltip_panel.position = Vector2(-5000, -5000)
	tooltip_panel.visible = true

	# Update continue hint and arrow (synchronously, before positioning)
	var hint_label = tooltip_panel.find_child("ContinueHint", true, false)
	if _watching_action != "":
		var action_hints = {
			"move": "[ Use WASD or Arrow Keys ]",
			"press_f": "[ Press F ]",
			"press_e": "[ Press E ]",
			"press_esc": "[ Press Esc ]",
			"click": "[ Click the highlighted element ]"
		}
		if hint_label:
			hint_label.text = action_hints.get(_watching_action, "[ Perform the action ]")
	else:
		_waiting_for_advance = true
		if hint_label:
			hint_label.text = "[ Press Space to continue ]"

	# Arrow direction
	var side = step.get("tooltip_side", "bottom")
	match side:
		"top": _arrow_label.text = "▲"
		"bottom": _arrow_label.text = "▼"
		"left": _arrow_label.text = "◄"
		"right": _arrow_label.text = "►"
		_: _arrow_label.text = "▼"

	# Fire-and-forget: wait 2 frames for layout, then position correctly
	_do_position_after_layout(side)

func _do_position_after_layout(side: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _is_running:
		return
	_position_tooltip_sync(side)

func _point_spotlight_at(node: Control) -> void:
	var rect = node.get_global_rect()
	var center = rect.get_center()
	var screen_size = get_viewport().get_visible_rect().size

	var norm_pos = center / screen_size
	shader_mat.set_shader_parameter("spotlight_pos", norm_pos)

	# Elliptical size with padding
	var pad = Vector2(20, 20)
	var size_norm = (rect.size + pad) / screen_size * 0.5
	shader_mat.set_shader_parameter("spotlight_size", size_norm)

func _clear_spotlight() -> void:
	shader_mat.set_shader_parameter("spotlight_size", Vector2(0.0, 0.0))

func _position_tooltip_sync(side: String) -> void:
	var screen = get_viewport().get_visible_rect().size
	if not _target_node or not is_instance_valid(_target_node):
		tooltip_panel.position = Vector2(screen.x / 2 - 140, screen.y / 2 - 40)
		return

	var rect = _target_node.get_global_rect()
	var tp_size = tooltip_panel.size
	var pos = Vector2.ZERO

	match side:
		"bottom":
			pos = Vector2(rect.get_center().x - tp_size.x / 2, rect.end.y + 16)
		"top":
			pos = Vector2(rect.get_center().x - tp_size.x / 2, rect.position.y - tp_size.y - 16)
		"right":
			pos = Vector2(rect.end.x + 16, rect.get_center().y - tp_size.y / 2)
		"left":
			pos = Vector2(rect.position.x - tp_size.x - 16, rect.get_center().y - tp_size.y / 2)

	# Clamp to screen
	pos.x = clamp(pos.x, 8, screen.x - tp_size.x - 8)
	pos.y = clamp(pos.y, 8, screen.y - tp_size.y - 8)
	tooltip_panel.position = pos

func _end_tutorial() -> void:
	_is_running = false
	_watching_action = ""
	_waiting_for_advance = false
	_typewriter_active = false
	tooltip_panel.visible = false
	instruction_label.visible_characters = -1
	_clear_spotlight()
	visible = false
	if is_in_group("tutorial_overlay_active"):
		remove_from_group("tutorial_overlay_active")
	tutorial_finished.emit()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _find_node_by_name(node_name: String) -> Node:
	var scene = get_tree().current_scene
	if scene:
		return scene.find_child(node_name, true, false)
	return null
