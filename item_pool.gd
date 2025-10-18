# systems/item_pool.gd (Autoload as "ItemPool")
extends Node

const MAX_POOL_SIZE := 200

var pools: Dictionary = {}  # archetype -> Array[WorldItem]

func get_item(scene: PackedScene, archetype: String) -> Node3D:
	if not pools.has(archetype):
		pools[archetype] = []
	
	var pool = pools[archetype]
	if pool.size() > 0:
		var item = pool.pop_back()
		item.visible = true
		item.set_physics_process(true)
		return item
	
	# Pool empty, create new
	return scene.instantiate()

func return_item(item: Node3D, archetype: String) -> void:
	if not pools.has(archetype):
		pools[archetype] = []
	
	var pool = pools[archetype]
	if pool.size() < MAX_POOL_SIZE:
		item.visible = false
		item.set_physics_process(false)
		if item.get_parent():
			item.get_parent().remove_child(item)
		pool.append(item)
	else:
		item.queue_free()

func clear_all() -> void:
	for archetype in pools.keys():
		for item in pools[archetype]:
			if is_instance_valid(item):
				item.queue_free()
	pools.clear()
