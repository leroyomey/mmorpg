# res://systems/entity_pool.gd  (Autoload as "EntityPool")
extends Node

const MAX_POOL_SIZE := 64
var monster_pools: Dictionary = {}  # archetype_id -> Array[Monster]

func get_monster(scene: PackedScene, archetype_id: String) -> Monster:
	var pool: Array = monster_pools.get(archetype_id, [])
	if not monster_pools.has(archetype_id):
		monster_pools[archetype_id] = pool

	if pool.size() > 0:
		var m: Monster = pool.pop_back()
		m.visible = true
		m.set_physics_process(true)
		return m

	return scene.instantiate() as Monster

func return_monster(m: Monster) -> void:
	var id: String = m.archetype_id
	if id == "": id = "default"
	var pool: Array = monster_pools.get(id, [])
	if not monster_pools.has(id):
		monster_pools[id] = pool

	# Reset minimal state
	m.visible = false
	m.set_physics_process(false)
	m.health = m.max_health

	# Detach from scene but keep it
	if m.get_parent(): m.get_parent().remove_child(m)

	if pool.size() < MAX_POOL_SIZE:
		pool.append(m)
	else:
		m.queue_free()
