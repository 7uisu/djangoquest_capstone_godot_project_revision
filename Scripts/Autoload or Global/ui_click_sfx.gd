# ui_click_sfx.gd — Global autoload: plays mouse click on EVERY button press
# Added as autoload in project.godot — no changes needed to any other script
extends Node

var click_stream: AudioStream

func _ready():
	click_stream = preload("res://Sounds/UI SFX/UIClick_BLEEOOP_Mouse_Click.wav")
	# Hook into existing buttons
	get_tree().node_added.connect(_on_node_added)
	# Hook buttons already in tree
	_hook_all_buttons(get_tree().root)

func _hook_all_buttons(node: Node):
	if node is Button:
		if not node.pressed.is_connected(_play_click):
			node.pressed.connect(_play_click)
	for child in node.get_children():
		_hook_all_buttons(child)

func _on_node_added(node: Node):
	if node is Button:
		# Defer so the button is fully ready
		node.ready.connect(func():
			if not node.pressed.is_connected(_play_click):
				node.pressed.connect(_play_click)
		)

func _play_click():
	var player = AudioStreamPlayer.new()
	player.stream = click_stream
	player.volume_db = -6.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
