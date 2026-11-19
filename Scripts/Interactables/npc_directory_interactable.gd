extends Area2D

## Editor-placeable directory that lists the current floor's active staff
## and all department rosters across DJQ Corp.

@export var interaction_text := "[F] View Staff Directory"
@export var directory_title := "DJQ Corp — Staff Directory"

@onready var prompt: Label = $Label

var player_is_inside := false

const STAFF_ROLES: Dictionary = {
	"Kendra Barba": "Receptionist & Front Desk Manager",
	"August Creed": "HR Specialist & OJT Coordinator",
	"Ivana Daniela Gabani": "Engineering Team Lead & Senior Architect",
	"Hanna Luisa Paday": "Senior System Designer & Database Architect",
	"Celestina Balon": "QA Lead",
	"Mario Ellan Cruz": "Client Liaison & Product Owner",
	"Kenna Louisa Arizobal": "Senior Backend Developer",
	"Abel Abendaño": "Lead Frontend Developer",
	"Abel Abendano": "Lead Frontend Developer",
	"Reynalda Patalinghug": "DevOps & Infrastructure Specialist",
	"Nathalie Milo": "Database Analyst",
	"Divino Cinaon": "Server Infrastructure & Network Lead",
	"Julia Roa": "Executive Sponsor & Vice President",
	"Noriela Asahan": "Junior Developer",
	"Alexa Apuyan": "Product & QA Coordinator",
	"Tercio Mateo Ramos": "Technical Support Specialist",
	"Luka Neri": "Backend Trainee",
	"Patricio Mateo": "Junior QA Tester",
}

const CANONICAL_OFFICE_ROSTER: Array = [
	# Ground Floor
	{
		"name": "Kendra Barba",
		"role": "Receptionist & Front Desk Manager",
		"floor": "Ground Floor",
		"room": "Reception Room"
	},
	{
		"name": "August Creed",
		"role": "HR Specialist & OJT Coordinator",
		"floor": "Ground Floor",
		"room": "Sprint / Meeting Room"
	},
	{
		"name": "Celestina Balon",
		"role": "QA Lead",
		"floor": "Ground Floor",
		"room": "QA and Design Room"
	},
	{
		"name": "Alexa Apuyan",
		"role": "Product & QA Coordinator",
		"floor": "Ground Floor",
		"room": "QA and Design Room"
	},
	{
		"name": "Mario Ellan Cruz",
		"role": "Client Liaison & Product Owner",
		"floor": "Ground Floor",
		"room": "Sprint / Meeting Room"
	},
	{
		"name": "Hanna Luisa Paday",
		"role": "Senior System Designer",
		"floor": "Ground Floor",
		"room": "Sprint / Meeting Room"
	},
	# 2nd Floor
	{
		"name": "Abel Abendaño",
		"role": "Lead Frontend Developer",
		"floor": "2nd Floor",
		"room": "Frontend Room"
	},
	{
		"name": "Luka Neri",
		"role": "Backend Trainee",
		"floor": "2nd Floor",
		"room": "Break Room / Pantry"
	},
	{
		"name": "Kenna Louisa Arizobal",
		"role": "Senior Backend Developer",
		"floor": "2nd Floor",
		"room": "Backend Room"
	},
	{
		"name": "Nathalie Milo",
		"role": "Database Analyst",
		"floor": "2nd Floor",
		"room": "Backend Room"
	},
	{
		"name": "Patricio Mateo",
		"role": "Junior QA Tester",
		"floor": "2nd Floor",
		"room": "Break Room / Hallway"
	},
	{
		"name": "Reynalda Patalinghug",
		"role": "DevOps & Infrastructure Specialist",
		"floor": "2nd Floor",
		"room": "DevOps Room"
	},
	{
		"name": "Noriela Asahan",
		"role": "Junior Developer",
		"floor": "2nd Floor",
		"room": "Break Room / Hallway"
	},
	# 3rd Floor
	{
		"name": "Julia Roa",
		"role": "Executive Sponsor & Vice President",
		"floor": "3rd Floor",
		"room": "Executive Meeting Room"
	},
	{
		"name": "Ivana Daniela Gabani",
		"role": "Engineering Team Lead & Senior Architect",
		"floor": "3rd Floor",
		"room": "Lead's Office"
	},
	{
		"name": "Divino Cinaon",
		"role": "Server Infrastructure & Network Lead",
		"floor": "3rd Floor",
		"room": "Server Room"
	},
	{
		"name": "Tercio Mateo Ramos",
		"role": "Technical Support Specialist",
		"floor": "3rd Floor",
		"room": "IT Storage"
	}
]


func _ready() -> void:
	if prompt:
		prompt.text = interaction_text
		prompt.visible = false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = true
		if prompt:
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_inside = false
		if prompt:
			prompt.visible = false


func interact() -> void:
	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null or bool(dialogue_box.get("is_active")):
		return
	var entries := _build_directory_entries()
	if entries.is_empty():
		entries.append({"name": directory_title, "text": "No staff are currently listed in the directory."})
	dialogue_box.start(entries)


func _build_directory_entries() -> Array:
	var result: Array = []
	var scene := get_tree().current_scene
	if scene == null:
		return result

	var room_indicator := scene.find_child("RoomIndicator", true, false)
	var current_floor := str(room_indicator.get("floor_name")) if room_indicator and "floor_name" in room_indicator else "Office"

	# 1. Gather all live NPCs present in this scene
	var live_npcs := _gather_scene_npcs(scene)
	var listed_names: Dictionary = {}

	result.append({
		"name": directory_title,
		"text": "%s Staff Directory\nActive personnel and workstations on this floor." % current_floor
	})

	for npc in live_npcs:
		var raw_name := _get_npc_display_name(npc)
		listed_names[raw_name] = true
		var role := _get_npc_role(raw_name, npc)
		var location := _get_npc_room(npc, room_indicator)

		result.append({
			"name": directory_title,
			"text": "%s — %s\nLocation: %s, %s" % [raw_name, role, current_floor, location]
		})

	# If scene NPCs were fewer than canonical floor members (e.g. story hidden), include remaining scheduled staff
	var canonical_floor_members := _get_canonical_members_for_floor(current_floor)
	for member in canonical_floor_members:
		var m_name: String = member["name"]
		var already_listed := false
		for k in listed_names:
			if k.to_lower() == m_name.to_lower() or k.replace("ñ", "n").to_lower() == m_name.replace("ñ", "n").to_lower():
				already_listed = true
				break
		if not already_listed:
			result.append({
				"name": directory_title,
				"text": "%s — %s\nLocation: %s, %s (Assigned)" % [member["name"], member["role"], member["floor"], member["room"]]
			})

	# 2. Add other office floors so all NPCs in the office are reflected
	var floor_order := ["Ground Floor", "2nd Floor", "3rd Floor"]
	for fl in floor_order:
		if _is_same_floor(fl, current_floor):
			continue
		var floor_members := _get_canonical_members_for_floor(fl)
		if floor_members.is_empty():
			continue
		var lines: Array[String] = []
		lines.append("DJQ Corp — %s Staff:" % fl)
		for member in floor_members:
			lines.append("• %s — %s (%s)" % [member["name"], member["role"], member["room"]])
		result.append({
			"name": directory_title,
			"text": "\n".join(lines)
		})

	return result


func _gather_scene_npcs(scene: Node) -> Array[Node2D]:
	var list: Array[Node2D] = []
	var seen: Dictionary = {}

	# Check group "office_npcs"
	for node in get_tree().get_nodes_in_group("office_npcs"):
		if _is_valid_npc(node) and not seen.has(node):
			seen[node] = true
			list.append(node as Node2D)

	# Check group "npcs"
	for node in get_tree().get_nodes_in_group("npcs"):
		if _is_valid_npc(node) and not seen.has(node):
			seen[node] = true
			list.append(node as Node2D)

	# Search scene children
	if scene:
		for child in scene.find_children("*", "Node2D", true, false):
			if _is_valid_npc(child) and not seen.has(child):
				seen[child] = true
				list.append(child as Node2D)

	list.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return _get_npc_display_name(a) < _get_npc_display_name(b)
	)
	return list


func _is_valid_npc(node: Node) -> bool:
	if not is_instance_valid(node) or not (node is Node2D):
		return false
	if node == self or node.is_ancestor_of(self) or self.is_ancestor_of(node):
		return false
	if node.is_in_group("player") or node.name == "Player":
		return false

	var n_name := str(node.name)
	if n_name.begins_with("NPCDirectory") or n_name.begins_with("NPCBulletin"):
		return false
	if "Directory" in n_name or "Door" in n_name or "Elevator" in n_name:
		return false

	var is_npc := node.is_in_group("office_npcs") or node.is_in_group("npcs") or "speaker_name" in node or n_name.begins_with("NPC")
	if not is_npc:
		return false

	if not node.is_visible_in_tree() and not node.visible:
		return false

	return true


func _get_npc_display_name(npc: Node2D) -> String:
	if "speaker_name" in npc:
		var s_name = str(npc.get("speaker_name")).strip_edges()
		if not s_name.is_empty():
			return s_name

	var raw := str(npc.name)
	if raw.begins_with("NPC"):
		raw = raw.substr(3)

	var reg := RegEx.create_from_string("(?<=[a-z])(?=[A-Z])")
	if reg:
		raw = reg.sub(raw, " ", true)
	return raw


func _get_npc_role(npc_name: String, npc: Node2D) -> String:
	if STAFF_ROLES.has(npc_name):
		return STAFF_ROLES[npc_name]

	var norm_name := npc_name.replace("ñ", "n").to_lower()
	for key in STAFF_ROLES:
		if key.to_lower() == npc_name.to_lower() or key.replace("ñ", "n").to_lower() == norm_name:
			return STAFF_ROLES[key]

	if npc.has_meta("role"):
		return str(npc.get_meta("role"))
	if npc.has_meta("ch3_narrative_role"):
		var nr := str(npc.get_meta("ch3_narrative_role")).to_lower()
		for key in STAFF_ROLES:
			if nr in key.to_lower():
				return STAFF_ROLES[key]

	return "Staff Member"


func _get_npc_room(npc: Node2D, room_indicator: Node) -> String:
	if room_indicator:
		for zone in room_indicator.get_children():
			if zone.has_method("contains_point") and zone.contains_point(npc.global_position):
				return str(zone.get("room_name"))
	return "Hallway"


func _is_same_floor(a: String, b: String) -> bool:
	var a_low := a.to_lower()
	var b_low := b.to_lower()
	if a_low in b_low or b_low in a_low:
		return true
	if (a_low.contains("ground") or a_low.contains("1st") or a_low.contains("floor 1")) and (b_low.contains("ground") or b_low.contains("1st") or b_low.contains("floor 1")):
		return true
	if a_low.contains("2") and b_low.contains("2"):
		return true
	if a_low.contains("3") and b_low.contains("3"):
		return true
	return false


func _get_canonical_members_for_floor(floor_name: String) -> Array:
	var members: Array = []
	for entry in CANONICAL_OFFICE_ROSTER:
		if _is_same_floor(str(entry["floor"]), floor_name):
			members.append(entry)
	return members


func _get_dialogue_box() -> CanvasLayer:
	for node in get_tree().get_nodes_in_group("dialogue_box"):
		if node is CanvasLayer:
			return node
	var scene := get_tree().current_scene
	return scene.get_node_or_null("DialogueBox") as CanvasLayer if scene else null
