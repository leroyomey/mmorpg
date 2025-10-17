# autoload/game_state.gd
extends Node

# Account-wide data (persists across characters)
var account_id: String = ""
var premium_currency: int = 0
var unlocked_mounts: Array[String] = []
var achievements: Array[String] = []

# Current character data (loaded from server)
var character_id: String = ""
var character_name: String = ""
var character_class: String = ""
var character_race: String = ""

# Session data
var current_shard_id: int = 0
var current_zone: String = ""
var party_members: Array[int] = []
var guild_id: String = ""

# Save/Load functions
func save_player_data(player: Player) -> Dictionary:
	return {
		"health": player.health,
		"mana": player.mana,
		"energy": player.energy,
		"level": player.level,
		"experience": player.experience,
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},
		"stats": {
			"strength": player.strength,
			"intelligence": player.intelligence,
			"agility": player.agility,
			"stamina": player.stamina
		}
	}

func load_player_data(player: Player, data: Dictionary):
	player.health = data.get("health", 100.0)
	player.mana = data.get("mana", 100.0)
	player.energy = data.get("energy", 100.0)
	player.level = data.get("level", 1)
	player.experience = data.get("experience", 0)
	
	var pos = data.get("position", {})
	player.global_position = Vector3(
		pos.get("x", 0),
		pos.get("y", 0),
		pos.get("z", 0)
	)
	
	var stats = data.get("stats", {})
	player.strength = stats.get("strength", 10)
	player.intelligence = stats.get("intelligence", 10)
	player.agility = stats.get("agility", 10)
	player.stamina = stats.get("stamina", 10)
