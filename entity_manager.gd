extends Node

# LOD only - server controls visibility
const LOD_CLOSE: float = 20.0
const LOD_MEDIUM: float = 50.0
const LOD_FAR: float = 100.0

const UPDATE_INTERVAL: float = 0.1

var _distance_check_timer: float = 0.0
var local_player: Node = null

func _process(delta: float) -> void:
	_distance_check_timer += delta
	
	if _distance_check_timer < UPDATE_INTERVAL:
		return
	
	_distance_check_timer = 0.0
	
	if not local_player:
		local_player = get_tree().get_first_node_in_group("local_player")
		return
	
	apply_lod()

func apply_lod() -> void:
	var player_pos = local_player.global_position
	
	# Apply LOD to monsters
	for monster in get_tree().get_nodes_in_group("Monster"):
		var distance = monster.global_position.distance_to(player_pos)
		set_monster_lod(monster, distance)
	
	# Apply LOD to remote players
	for player in get_tree().get_nodes_in_group("remote_players"):
		var distance = player.global_position.distance_to(player_pos)
		set_player_lod(player, distance)

func set_monster_lod(monster: Monster, distance: float) -> void:
	"""Adjust monster interpolation speed based on distance"""
	# Always update, but slower for distant monsters
	monster.set_physics_process(true)
	
	if distance < LOD_CLOSE:  # < 20m
		monster.interpolation_speed = 10.0  # Full speed
	elif distance < LOD_MEDIUM:  # 20-50m
		monster.interpolation_speed = 8.0  # Slightly slower
	elif distance < LOD_FAR:  # 50-100m
		monster.interpolation_speed = 5.0  # Noticeably slower
	else:  # > 100m
		monster.interpolation_speed = 3.0  # Very slow (but still smooth)

func set_player_lod(player: Node, distance: float) -> void:
	"""Adjust remote player interpolation speed based on distance"""
	player.set_physics_process(true)
	
	if player.has_method("set_interpolation_speed"):
		if distance < LOD_CLOSE:
			player.interpolation_speed = 10.0
		elif distance < LOD_MEDIUM:
			player.interpolation_speed = 8.0
		elif distance < LOD_FAR:
			player.interpolation_speed = 5.0
		else:
			player.interpolation_speed = 3.0
