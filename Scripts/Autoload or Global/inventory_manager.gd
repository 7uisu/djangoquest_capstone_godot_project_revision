# inventory_manager.gd — Global inventory singleton
# Holds the player's inventory as an array of item dictionaries.
# Register as an autoload in Project Settings.
extends Node

signal inventory_changed

## Each entry: { "id": String, "name": String, "description": String, "icon": Texture2D, "quantity": int }
var items: Array = []

## Add an item (or stack if it already exists).
func add_item(id: String, item_name: String, description: String = "", icon: Texture2D = null, quantity: int = 1):
	for item in items:
		if item["id"] == id:
			item["quantity"] += quantity
			emit_signal("inventory_changed")
			return
	items.append({
		"id": id,
		"name": item_name,
		"description": description,
		"icon": icon,
		"quantity": quantity
	})
	emit_signal("inventory_changed")

## Remove a quantity of an item. Removes the entry entirely if quantity reaches 0.
func remove_item(id: String, quantity: int = 1):
	for i in range(items.size()):
		if items[i]["id"] == id:
			items[i]["quantity"] -= quantity
			if items[i]["quantity"] <= 0:
				items.remove_at(i)
			emit_signal("inventory_changed")
			return

## Check if the player has at least one of this item.
func has_item(id: String) -> bool:
	for item in items:
		if item["id"] == id:
			return true
	return false

## Get the quantity of a specific item (0 if not found).
func get_item_quantity(id: String) -> int:
	for item in items:
		if item["id"] == id:
			return item["quantity"]
	return 0

## Return all items (read-only copy).
func get_items() -> Array:
	return items.duplicate(true)

## Clear the entire inventory.
func clear():
	items.clear()
	emit_signal("inventory_changed")
