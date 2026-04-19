# coding_items.gd — Central registry of buff items for coding challenges
# Contains item definitions, texture paths, and helper functions
extends RefCounted
class_name CodingItems

# ─── Item IDs ────────────────────────────────────────────────────────────────

const RUBBER_DUCK = "rubber_duck"
const WANSTER_ENERGY = "wanster_energy"
const SYNTAX_GLASSES = "syntax_glasses"
const OS_PREMIUM = "os_premium"
const ENCRYPTED_DRIVE = "encrypted_drive"

# ─── Item Definitions ────────────────────────────────────────────────────────

const ITEMS = {
	RUBBER_DUCK: {
		"id": RUBBER_DUCK,
		"name": "Rubber Duck",
		"description": "A tiny yellow rubber duck. Programmers swear that talking to it helps you find bugs.",
		"buff_description": "🦆 DEBUG BUFF: Highlights the exact bug line in yellow during Debug challenges. Unlimited use!",
		"icon_path": "res://Textures/School Textures/Items/Interactable/Rubber-Duck-32x32.png",
		"usable_on": ["debug"],
		"consumable": false,
		"pickup_quantity": 1,
		"price": 50,
	},
	WANSTER_ENERGY: {
		"id": WANSTER_ENERGY,
		"name": "Wanster Energy",
		"description": "An extremely caffeinated energy drink. The label says 'MAXIMUM OVERDRIVE'. Probably not safe.",
		"buff_description": "☕ TIMER BUFF: Adds +15 seconds to the countdown during timed challenges. 3 uses per pickup.",
		"icon_path": "res://Textures/School Textures/Items/Interactable/Wanster-Energy-32x32.png",
		"usable_on": ["predict_output"],
		"consumable": true,
		"pickup_quantity": 3,
		"price": 75,
	},
	SYNTAX_GLASSES: {
		"id": SYNTAX_GLASSES,
		"name": "Syntax Glasses",
		"description": "Thick-rimmed hacker glasses. They make everything look like The Matrix... and wrong answers glow red.",
		"buff_description": "👓 50/50 BUFF: Removes one incorrect option from multiple-choice challenges. 3 uses per pickup.",
		"icon_path": "res://Textures/School Textures/Items/Interactable/Hacker-Eyeglasses-32x32.png",
		"usable_on": ["debug", "follow_steps", "predict_output"],
		"consumable": true,
		"pickup_quantity": 3,
		"price": 100,
	},
	OS_PREMIUM: {
		"id": OS_PREMIUM,
		"name": "OS Premium",
		"description": "A shiny credit card for 'Overflow Stack Premium™'. Comes with ad-free browsing and... auto-complete?!",
		"buff_description": "💳 AUTO-TYPE BUFF: Automatically fills in the first half of the correct answer for Free-Type and Terminal challenges. 3 uses per pickup.",
		"icon_path": "res://Textures/School Textures/Items/Interactable/CreditCard-32x32.png",
		"usable_on": ["free_type", "terminal"],
		"consumable": true,
		"pickup_quantity": 3,
		"price": 150,
	},
	ENCRYPTED_DRIVE: {
		"id": ENCRYPTED_DRIVE,
		"name": "Encrypted Drive",
		"description": "A mysterious USB drive found behind a locker. Someone scratched 'SOLUTIONS' on the back. Suspicious...",
		"buff_description": "💾 INSTANT SOLVE: Automatically completes ANY challenge instantly. Single use — gone after activation!",
		"icon_path": "res://Textures/School Textures/Items/Interactable/Encrypted Drive-32x32.png",
		"usable_on": ["debug", "follow_steps", "predict_output", "free_type", "terminal"],
		"consumable": true,
		"pickup_quantity": 1,
		"price": 500,
	},
}

# ─── Helper Functions ────────────────────────────────────────────────────────

## Get all items the player currently has that can be used on this challenge type
static func get_usable_items(challenge_type: String) -> Array:
	var inv = Engine.get_singleton("InventoryManager") if Engine.has_singleton("InventoryManager") else null
	if inv == null:
		# Fallback: try node path
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			inv = tree.root.get_node_or_null("/root/InventoryManager")
	if inv == null:
		return []

	var usable: Array = []
	for item_id in ITEMS:
		var item_def = ITEMS[item_id]
		if challenge_type in item_def["usable_on"] and inv.has_item(item_id):
			usable.append(item_def)
	return usable

## Get an item definition by ID
static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

## Load the icon texture for an item
static func get_icon(item_id: String) -> Texture2D:
	var item = ITEMS.get(item_id, {})
	var path = item.get("icon_path", "")
	if path != "":
		return load(path)
	return null
