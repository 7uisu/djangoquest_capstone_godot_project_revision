# quest_hud.gd — On-screen quest objective + edge arrow toward target (CanvasLayer)
extends CanvasLayer

@onready var _body: RichTextLabel = $Root/QuestPanel/Margin/VBox/QuestBody
@onready var _distance: Label = $Root/QuestPanel/Margin/VBox/DistanceLabel


func _ready() -> void:
	layer = 8
	sync_from_manager()
	var qm := get_node_or_null("/root/QuestManager")
	if qm and not qm.quest_changed.is_connected(_on_quest_changed):
		qm.quest_changed.connect(_on_quest_changed)
	if qm and not qm.quest_visibility_changed.is_connected(_on_quest_visibility_changed):
		qm.quest_visibility_changed.connect(_on_quest_visibility_changed)


func _on_quest_changed(_id: String, _text: String) -> void:
	sync_from_manager()


func _on_quest_visibility_changed(_v: bool) -> void:
	sync_from_manager()


func _process(_delta: float) -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.is_quest_content_visible() and not qm.target_node_names.is_empty():
		var player := _find_player()
		if player:
			var target: Vector2 = qm.get_arrow_target_global_position()
			if target != Vector2.ZERO:
				var dist_m: int = int(round(player.global_position.distance_to(target) / 32.0))
				_distance.text = str(dist_m) + " m"


func sync_from_manager() -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if qm == null:
		visible = false
		return
	var show_ui: bool = qm.is_quest_content_visible()
	visible = show_ui
	if not show_ui:
		return
	_body.text = "[center]" + qm.current_quest_text + "[/center]"
	_distance.visible = not qm.target_node_names.is_empty()
	if _distance.visible and qm.target_node_names.size() > 0:
		_process(0.0)


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D
