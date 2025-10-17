# autoload as "ItemDB"
extends Node

var items: Dictionary = {}  # item_id -> ItemData
var item_types: Dictionary = {}

class ItemData:
	var id: String
	var name: String
	var type: String
	var subtype: String
	var rarity: String
	var level_requirement: int
	var base_stats: Dictionary
	var scaling: Dictionary
	var icon_path: String
	var mesh_path: String
	var stack_size: int
	var sell_price: int
	var effects: Array = []
	var slot: String = ""
	
	func get_stat(stat_name: String, character_level: int = 0, character_stats: Dictionary = {}) -> float:
		"""Calculate stat value based on scaling"""
		var base = base_stats.get(stat_name, 0.0)
		
		# Level scaling
		var level_key = stat_name + "_per_level"
		if scaling.has(level_key):
			base += scaling[level_key] * character_level
		
		# Stat scaling (e.g., strength_scaling for damage)
		for stat in character_stats.keys():
			var scaling_key = stat + "_scaling"
			if scaling.has(scaling_key):
				base += character_stats[stat] * scaling[scaling_key]
		
		return base

func _ready() -> void:
	load_item_database()
	load_item_types()

func load_item_database() -> void:
	var file = FileAccess.open("res://data/items/items.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load items.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse items.json")
		return
	
	var data = json.data
	for item_dict in data["items"]:
		var item = ItemData.new()
		item.id = item_dict.get("id", "")
		item.name = item_dict.get("name", "Unknown")
		item.type = item_dict.get("type", "")
		item.subtype = item_dict.get("subtype", "")
		item.rarity = item_dict.get("rarity", "common")
		item.level_requirement = item_dict.get("level_requirement", 1)
		item.base_stats = item_dict.get("base_stats", {})
		item.scaling = item_dict.get("scaling", {})
		item.icon_path = item_dict.get("icon", "")
		item.mesh_path = item_dict.get("mesh", "")
		item.stack_size = item_dict.get("stack_size", 1)
		item.sell_price = item_dict.get("sell_price", 0)
		item.effects = item_dict.get("effects", [])
		item.slot = item_dict.get("slot", "")
		
		items[item.id] = item
	
	print("Loaded %d items" % items.size())

func load_item_types() -> void:
	var file = FileAccess.open("res://data/items/item_types.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load item_types.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse item_types.json")
		return
	
	item_types = json.data["types"]
	print("Loaded %d item types" % item_types.size())

func get_item(item_id: String) -> ItemData:
	"""Get item data by ID"""
	return items.get(item_id, null)

func get_items_by_type(type: String, subtype: String = "") -> Array[ItemData]:
	"""Get all items of a specific type"""
	var result: Array[ItemData] = []
	for item in items.values():
		if item.type == type:
			if subtype == "" or item.subtype == subtype:
				result.append(item)
	return result

func get_items_by_level_range(min_level: int, max_level: int) -> Array[ItemData]:
	"""Get items within a level range"""
	var result: Array[ItemData] = []
	for item in items.values():
		if item.level_requirement >= min_level and item.level_requirement <= max_level:
			result.append(item)
	return result
