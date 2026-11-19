# template_scene_init.gd
# Template scene bootstrap:
#   - Grants both Ch3 badges (CharacterData flags + inventory)
#   - Silences all NPC dialogue so NPCs stand/idle with no interaction
# Attach to a Node child of any template scene root.
extends Node

# Dialogue property names on dialogue_interactable.gd instances
const _DIALOGUE_PROPS := [
	"dialogue_line_1", "dialogue_line_2", "dialogue_line_3",
	"dialogue_line_4", "dialogue_line_5",
	"second_visit_dialogue", "reminder_dialogue",
	"optional_choice_prompt", "optional_choice_reply_a", "optional_choice_reply_b",
	"interaction_text",
]

func _ready() -> void:
	# Badges — CharacterData flags
	var data: Node = get_node_or_null("/root/CharacterData")
	if data != null:
		data.ch3_has_green_badge = true
		data.ch3_has_blue_badge  = true

	# Badges — inventory
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null:
		if not inv.has_item("green_ojt_badge"):
			inv.add_item("green_ojt_badge", "Green OJT Badge",
				"Grants access to the office floors.")
		if not inv.has_item("blue_junior_developer_badge"):
			inv.add_item("blue_junior_developer_badge", "Blue Junior Developer Badge",
				"Grants full access as a junior developer.")

	# Clear NPC dialogue — deferred so all NPC _ready() calls finish first
	call_deferred("_silence_all_npcs")


func _silence_all_npcs() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	_clear_dialogue_recursive(scene_root)


func _clear_dialogue_recursive(node: Node) -> void:
	# Identify dialogue_interactable nodes by the presence of dialogue_line_1
	if "dialogue_line_1" in node:
		for prop in _DIALOGUE_PROPS:
			if prop in node:
				node.set(prop, "")
		# Hide the interaction label so no "(F) to Talk" prompt appears
		if "interaction_text" in node:
			node.interaction_text = ""
		var label: Node = node.get_node_or_null("Label")
		if label != null:
			label.visible = false
	for child in node.get_children():
		_clear_dialogue_recursive(child)
