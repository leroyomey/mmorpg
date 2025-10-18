# systems/monster_database.gd (Autoload as "MonsterDB")
extends Node

var templates: Dictionary = {}  # monster_id -> MonsterTemplate
var scenes: Dictionary = {}      # archetype -> PackedScene

class MonsterTemplate:
	var id: String
	var name: String
	var archetype: String
	var min_level: int
	var max_level: int
	var base_stats: Dictionary
	var scaling_per_level: Dictionary
	var xp_base: int
	var loot_table: String
	var abilities: Array
	var ai_type: String
	var respawn_time: float
	
	func get_stats_for_level(level: int) -> Dictionary:
		var stats = {}
		for stat_name in base_stats.keys():
			var base = base_stats[stat_name]
			var scale = scaling_per_level.get(stat_name, 0.0)
			stats[stat_name] = base + (scale * (level - min_level))
		return stats

func _ready() -> void:
	_load_definitions()
	_preload_scenes()

func _load_definitions() -> void:
	var file = FileAccess.open("res://data/monsters/monster_definitions.json", FileAccess.READ)
	if not file:
		push_error("Failed to load monster_definitions.json")
		return
	
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	for data in json["monsters"]:
		var template = MonsterTemplate.new()
		template.id = data["id"]
		template.name = data["name"]
		template.archetype = data["archetype"]
		template.min_level = data["min_level"]
		template.max_level = data["max_level"]
		template.base_stats = data["base_stats"]
		template.scaling_per_level = data["scaling_per_level"]
		template.xp_base = data["xp_base"]
		template.loot_table = data.get("loot_table", "")
		template.abilities = data.get("abilities", [])
		template.ai_type = data.get("ai_type", "melee_aggro")
		template.respawn_time = data.get("respawn_time", 60.0)
		
		templates[template.id] = template
	
	print("✅ Loaded ", templates.size(), " monster templates")

func _preload_scenes() -> void:
	var archetypes_set = {}
	for template in templates.values():
		archetypes_set[template.archetype] = true
	
	for archetype in archetypes_set.keys():
		# Handle both simple and nested paths
		var path = ""
		if archetype.begins_with("res://"):
			path = archetype  # Full path provided
		else:
			path = "res://data/monsters/archetypes/%s.tscn" % archetype
		
		print("  🔎 Looking for: ", path)
		
		if ResourceLoader.exists(path):
			scenes[archetype] = load(path)
			print("    ✅ Loaded archetype: ", archetype)
		else:
			push_error("    ❌ Missing scene: ", path)
	
	print("✅ Preloaded ", scenes.size(), " monster archetypes")

func get_template(monster_id: String) -> MonsterTemplate:
	return templates.get(monster_id)

func spawn_monster(monster_id: String, level: int) -> Monster:
	var template = get_template(monster_id)
	if not template:
		push_error("Unknown monster: ", monster_id)
		return null
	
	# Get from pool
	var monster = EntityPool.get_monster(scenes[template.archetype], template.archetype)
	
	# Apply template data
	monster.monster_id = monster_id
	monster.archetype_id = template.archetype
	monster.level = clamp(level, template.min_level, template.max_level)
	monster.monster_name = template.name
	
	# Calculate stats for this level
	var stats = template.get_stats_for_level(level)
	monster.max_health = stats["health"]
	monster.health = monster.max_health
	monster.damage = stats.get("damage", 10.0)
	monster.armor = stats.get("armor", 0.0)
	monster.speed = stats.get("speed", 2.0)
	
	return monster
