# autoload as "MonsterDB"
extends Node

var monsters: Dictionary = {}  # monster_id -> MonsterData
var loot_tables: Dictionary = {}  # table_name -> LootTable

class MonsterData:
	var id: String
	var name: String
	var type: String
	var family: String
	var is_boss: bool = false
	var min_level: int
	var max_level: int
	var base_stats: Dictionary
	var scaling: Dictionary
	var scene_path: String
	var ai_type: String
	var abilities: Array
	var xp_reward_base: int
	var xp_scaling: float
	var loot_table_id: String
	var respawn_time: float
	var resistances: Dictionary = {}
	var phases: Array = []
	
	func get_stats_for_level(level: int) -> Dictionary:
		"""Calculate monster stats at specific level"""
		var stats = {}
		for stat in base_stats.keys():
			var base = base_stats[stat]
			var scaling_key = stat + "_per_level"
			if scaling.has(scaling_key):
				stats[stat] = base + (scaling[scaling_key] * (level - min_level))
			else:
				stats[stat] = base
		return stats
	
	func get_xp_reward(level: int) -> int:
		"""Calculate XP reward at specific level"""
		return int(xp_reward_base * pow(xp_scaling, level - min_level))

class LootTable:
	var id: String
	var guaranteed_drops: Array = []
	var drop_pools: Array = []
	var rare_drops: Array = []
	
	func roll_loot(monster_level: int) -> Array:
		"""Roll for loot drops"""
		var loot: Array = []
		
		# Guaranteed drops
		for drop in guaranteed_drops:
			var item_id = drop["item_id"]
			var min_amt = drop.get("min_amount", 1)
			var max_amt = drop.get("max_amount", 1)
			var chance = drop.get("chance", 1.0)
			
			if randf() <= chance:
				var amount = randi_range(min_amt, max_amt)
				loot.append({"item_id": item_id, "amount": amount})
		
		# Drop pools
		for pool in drop_pools:
			var rolls = pool.get("rolls", 1)
			var pool_chance = pool.get("chance", 1.0)
			
			if randf() <= pool_chance:
				for i in range(rolls):
					var item = _roll_from_pool(pool["items"], monster_level)
					if item:
						loot.append(item)
		
		# Rare drops
		for drop in rare_drops:
			if randf() <= drop["chance"]:
				loot.append({"item_id": drop["item_id"], "amount": 1})
		
		return loot
	
	func _roll_from_pool(items: Array, monster_level: int) -> Dictionary:
		"""Roll a single item from weighted pool"""
		var valid_items = []
		var total_weight = 0.0
		
		# Filter by level
		for item_data in items:
			var min_lvl = item_data.get("min_level", 0)
			var max_lvl = item_data.get("max_level", 999)
			
			if monster_level >= min_lvl and monster_level <= max_lvl:
				valid_items.append(item_data)
				total_weight += item_data["weight"]
		
		if valid_items.size() == 0:
			return {}
		
		# Weighted random selection
		var roll = randf() * total_weight
		var cumulative = 0.0
		
		for item_data in valid_items:
			cumulative += item_data["weight"]
			if roll <= cumulative:
				return {
					"item_id": item_data["item_id"],
					"amount": item_data.get("amount", 1)
				}
		
		return {}

func _ready() -> void:
	load_monster_database()
	load_loot_tables()

func load_monster_database() -> void:
	var file = FileAccess.open("res://data/monsters/monsters.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load monsters.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse monsters.json")
		return
	
	var data = json.data
	for monster_dict in data["monsters"]:
		var monster = MonsterData.new()
		monster.id = monster_dict.get("id", "")
		monster.name = monster_dict.get("name", "Unknown")
		monster.type = monster_dict.get("type", "")
		monster.family = monster_dict.get("family", "")
		monster.is_boss = monster_dict.get("boss", false)
		monster.min_level = monster_dict.get("min_level", 1)
		monster.max_level = monster_dict.get("max_level", 1)
		monster.base_stats = monster_dict.get("base_stats", {})
		monster.scaling = monster_dict.get("scaling", {})
		monster.scene_path = monster_dict.get("scene", "")
		monster.ai_type = monster_dict.get("ai_type", "")
		monster.abilities = monster_dict.get("abilities", [])
		monster.xp_reward_base = monster_dict.get("xp_reward_base", 0)
		monster.xp_scaling = monster_dict.get("xp_scaling", 1.0)
		monster.loot_table_id = monster_dict.get("loot_table", "")
		monster.respawn_time = monster_dict.get("respawn_time", 60.0)
		monster.resistances = monster_dict.get("resistances", {})
		monster.phases = monster_dict.get("phases", [])
		
		monsters[monster.id] = monster
	
	print("Loaded %d monsters" % monsters.size())

func load_loot_tables() -> void:
	var file = FileAccess.open("res://data/monsters/loot_tables.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load loot_tables.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse loot_tables.json")
		return
	
	var data = json.data["loot_tables"]
	for table_id in data.keys():
		var table_dict = data[table_id]
		var table = LootTable.new()
		table.id = table_id
		table.guaranteed_drops = table_dict.get("guaranteed_drops", [])
		table.drop_pools = table_dict.get("drop_pools", [])
		table.rare_drops = table_dict.get("rare_drops", [])
		
		loot_tables[table_id] = table
	
	print("Loaded %d loot tables" % loot_tables.size())

func get_monster(monster_id: String) -> MonsterData:
	"""Get monster data by ID"""
	return monsters.get(monster_id, null)

func get_monsters_by_level_range(min_level: int, max_level: int) -> Array:
	"""Get monsters within level range"""
	var result = []
	for monster in monsters.values():
		if monster.min_level <= max_level and monster.max_level >= min_level:
			result.append(monster)
	return result

func get_loot_table(table_id: String) -> LootTable:
	"""Get loot table by ID"""
	return loot_tables.get(table_id, null)

func roll_monster_loot(monster_id: String, monster_level: int) -> Array:
	"""Roll loot for a specific monster"""
	var monster = get_monster(monster_id)
	if not monster:
		return []
	
	var loot_table = get_loot_table(monster.loot_table_id)
	if not loot_table:
		return []
	
	return loot_table.roll_loot(monster_level)
