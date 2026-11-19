extends Control

@export_file("*.tscn") var diff_inspector_scene: String = "res://Scenes/UI/diff_inspector_ui_prototype.tscn"
@export_file("*.tscn") var terminal_shell_scene: String = "res://Scenes/UI/terminal_shell_ui_prototype.tscn"
@export_file("*.tscn") var api_tester_scene: String = "res://Scenes/UI/api_tester_ui_prototype.tscn"
@export_file("*.tscn") var pipeline_sequencer_scene: String = "res://Scenes/UI/pipeline_sequencer_ui_prototype.tscn"

@onready var container_host: Control = $Screen/PreviewArea
@onready var status_lbl: Label = $Screen/TopBar/BarMargin/BarHBox/StatusLabel

var current_instance: Node = null

func _ready() -> void:
	$Screen/TopBar/BarMargin/BarHBox/MenuBtn1.pressed.connect(func(): _load_prototype(diff_inspector_scene, "1. Code Diff Inspector"))
	$Screen/TopBar/BarMargin/BarHBox/MenuBtn2.pressed.connect(func(): _load_prototype(terminal_shell_scene, "2. Live Terminal Shell"))
	$Screen/TopBar/BarMargin/BarHBox/MenuBtn3.pressed.connect(func(): _load_prototype(api_tester_scene, "3. API Tester"))
	$Screen/TopBar/BarMargin/BarHBox/MenuBtn4.pressed.connect(func(): _load_prototype(pipeline_sequencer_scene, "4. Architecture Sequencer"))
	_load_prototype(diff_inspector_scene, "1. Code Diff Inspector")

func _load_prototype(scene_path: String, title: String) -> void:
	if current_instance:
		current_instance.queue_free()
		current_instance = null
	var scene_res := load(scene_path) as PackedScene
	if not scene_res:
		status_lbl.text = "Error: Could not load " + scene_path
		return
	current_instance = scene_res.instantiate()
	if current_instance is CanvasLayer:
		current_instance.layer = 1
	container_host.add_child(current_instance)
	status_lbl.text = title