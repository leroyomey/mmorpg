# systems/item_database.gd (Autoload as "ItemDB")
extends Node

var templates: Dictionary = {}  # item_id -> ItemTemplate
var scenes: Dictionary = {}      # archetype -> PackedScene

class ItemTemplate:
	var id: String
	var name: String
	var archetype: String
	var mesh_override: String
	var icon: Texture2D
	var rarity: String
	var level_req: int
	var slot: String
	var item_type: String
	var stats: Dictionary
	var effects: Array
	var stackable: bool
	var max_stack: int
	var sell_value: int
	var weight: float

func _ready() -> void:
	_load_definitions()
	_preload_scenes()

func _load_definitions() -> void:
	var file = FileAccess.open("res://data/items/item_definitions.json", FileAccess.READ)
	if not file:
		push_error("Failed to load item_definitions.json")
		return
	
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	for data in json["items"]:
		var template = ItemTemplate.new()
		template.id = data["id"]
		template.name = data["name"]
		template.archetype = data["archetype"]
		template.mesh_override = data.get("mesh_override", "")
		template.icon = load(data["icon"]) if data.get("icon") else null
		template.rarity = data.get("rarity", "common")
		template.level_req = data.get("level_req", 1)
		template.slot = data.get("slot", "")
		template.item_type = data.get("item_type", "misc")
		template.stats = data.get("stats", {})
		template.effects = data.get("effects", [])
		template.stackable = data.get("stackable", false)
		template.max_stack = data.get("max_stack", 1)
		template.sell_value = data.get("sell_value", 0)
		template.weight = data.get("weight", 1.0)
		
		templates[template.id] = template
	
	print("✅ Loaded ", templates.size(), " item templates")

func _preload_scenes() -> void:
	var archetypes_set = {}
	for template in templates.values():
		archetypes_set[template.archetype] = true
	
	for archetype in archetypes_set.keys():
		var path = "res://data/items/archetypes/%s.tscn" % archetype
		if ResourceLoader.exists(path):
			scenes[archetype] = load(path)
			print("  📦 Loaded item archetype: ", archetype)
		else:
			push_error("Missing scene: ", path)
	
	print("✅ Preloaded ", scenes.size(), " item archetypes")

func get_template(item_id: String) -> ItemTemplate:
	return templates.get(item_id)

func spawn_world_item(item_id: String, stack_count: int = 1) -> Node3D:
	var template = get_template(item_id)
	if not template:
		push_error("Unknown item: ", item_id)
		return null
	
	# Get from pool
	var item = ItemPool.get_item(scenes[template.archetype], template.archetype)
	
	# Apply template data
	item.item_id = item_id
	item.item_name = template.name
	item.stack_count = stack_count
	item.template = template
	
	# Override mesh if specified
	if template.mesh_override and item.has_method("set_mesh"):
		item.set_mesh(load(template.mesh_override))
	
	return item
