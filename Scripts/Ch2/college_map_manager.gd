# college_map_manager.gd — Manages the college map scene
# Wires up professor NPCs to their lesson controllers.
# Fullscreen teaching placeholders (before the coding UI) are driven by
# ch2_professor_markup_controller.gd on the wired NPC via lesson_controller meta.
extends Node2D

const ProfMarkupController = preload("res://Scripts/Ch2/ch2_professor_markup_controller.gd")
const ProfSyntaxController = preload("res://Scripts/Ch2/ch2_professor_syntax_controller.gd")
const ProfViewController = preload("res://Scripts/Ch2/ch2_professor_view_controller.gd")
const ProfQueryController = preload("res://Scripts/Ch2/ch2_professor_query_controller.gd")

var _professor_markup_controller: Node = null
var _professor_syntax_controller: Node = null
var _professor_view_controller: Node = null
var _professor_query_controller: Node = null

func _ready() -> void:
	print("CollegeMapManager: _ready() called")
	# Wait a frame so all sibling nodes are ready
	await get_tree().process_frame
	print("CollegeMapManager: Frame waited, setting up professors...")
	_setup_professor_markup()
	_setup_professor_syntax()
	_setup_professor_view()
	_setup_professor_query()

func _setup_professor_markup():
	# Find the 1st male professor NPC
	var prof_npc = _find_node_recursive("NPCMaleCollegeProf01")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCMaleCollegeProf01 not found!")
		print("CollegeMapManager: ERROR — NPCMaleCollegeProf01 NOT FOUND")
		# Debug: print all children of Professors node
		var scene_root = get_tree().current_scene
		var profs = scene_root.get_node_or_null("Professors")
		if profs:
			print("CollegeMapManager: Professors node found with children:")
			for child in profs.get_children():
				print("  - ", child.name, " (", child.get_class(), ")")
		else:
			print("CollegeMapManager: No 'Professors' node found under root")
			print("CollegeMapManager: Root children:")
			for child in scene_root.get_children():
				print("  - ", child.name, " (", child.get_class(), ")")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_markup_controller = Node.new()
	_professor_markup_controller.name = "ProfMarkupController"
	_professor_markup_controller.set_script(ProfMarkupController)
	add_child(_professor_markup_controller)
	
	print("CollegeMapManager: Controller created and added as child")
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor Markup"
	
	# Set the controller on the NPC via meta — dialogue_interactable.gd
	# checks for this in interact() and routes to the controller
	prof_npc.set_meta("lesson_controller", _professor_markup_controller)
	
	print("CollegeMapManager: Meta 'lesson_controller' set on NPC")
	print("CollegeMapManager: NPC has_meta check = ", prof_npc.has_meta("lesson_controller"))
	print("CollegeMapManager: Professor Markup wired successfully!")

func _setup_professor_syntax():
	# Find the 1st female professor NPC
	var prof_npc = _find_node_recursive("NPCFemaleCollegeProf01")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCFemaleCollegeProf01 not found!")
		print("CollegeMapManager: ERROR — NPCFemaleCollegeProf01 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_syntax_controller = Node.new()
	_professor_syntax_controller.name = "ProfSyntaxController"
	_professor_syntax_controller.set_script(ProfSyntaxController)
	add_child(_professor_syntax_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor Syntax"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_syntax_controller)
	
	print("CollegeMapManager: Professor Syntax wired to NPCFemaleCollegeProf01 successfully!")

func _setup_professor_view():
	# Find the 2nd male professor NPC
	var prof_npc = _find_node_recursive("NPCMaleCollegeProf02")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCMaleCollegeProf02 not found!")
		print("CollegeMapManager: ERROR — NPCMaleCollegeProf02 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_view_controller = Node.new()
	_professor_view_controller.name = "ProfViewController"
	_professor_view_controller.set_script(ProfViewController)
	add_child(_professor_view_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor View"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_view_controller)
	
	
	print("CollegeMapManager: Professor View wired to NPCMaleCollegeProf02 successfully!")

func _setup_professor_query():
	# Find the 3rd male professor NPC
	var prof_npc = _find_node_recursive("NPCMaleCollegeProf03")
	if not prof_npc:
		push_warning("CollegeMapManager: NPCMaleCollegeProf03 not found!")
		print("CollegeMapManager: ERROR — NPCMaleCollegeProf03 NOT FOUND")
		return
	
	print("CollegeMapManager: Found NPC: ", prof_npc.name, " at ", prof_npc.position)
	
	# Create the controller as a child of this manager
	_professor_query_controller = Node.new()
	_professor_query_controller.name = "ProfQueryController"
	_professor_query_controller.set_script(ProfQueryController)
	add_child(_professor_query_controller)
	
	# Update the NPC speaker name
	if "speaker_name" in prof_npc:
		prof_npc.speaker_name = "Professor Query"
	
	# Set the controller on the NPC via meta
	prof_npc.set_meta("lesson_controller", _professor_query_controller)
	
	print("CollegeMapManager: Professor Query wired to NPCMaleCollegeProf03 successfully!")

func _find_node_recursive(node_name: String) -> Node:
	# Check Professors group first
	var scene_root = get_tree().current_scene
	var profs = scene_root.get_node_or_null("Professors")
	if profs:
		var n = profs.get_node_or_null(node_name)
		if n: return n
	# Fallback: deep search
	return _deep_find(scene_root, node_name)

func _deep_find(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var result = _deep_find(child, target)
		if result:
			return result
	return null
