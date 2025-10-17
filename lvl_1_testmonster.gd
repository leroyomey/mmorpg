# res://actors/monster.gd
extends CharacterBody3D
class_name Monster

var monster_id: String
var archetype_id: String
var level: int = 1

var max_health: float = 100.0
var health: float = 100.0

var server_position: Vector3 = Vector3.ZERO
var server_yaw: float = 0.0
var interpolation_speed: float = 10.0
var max_snap_distance: float = 5.0

@onready var visual_mesh: Node3D = null

func set_from_data(data: MonsterData, instance_mesh: bool = true) -> void:
	archetype_id = data.archetype_id
	level       = max(level, data.base_level)
	max_health  = data.max_health
	health      = max_health

	# Optional: swap mesh from data
	if instance_mesh and data.mesh_scene:
		if visual_mesh and visual_mesh.get_parent(): remove_child(visual_mesh)
		visual_mesh = data.mesh_scene.instantiate()
		add_child(visual_mesh)

func _ready() -> void:
	add_to_group("Monster")
	# fallback mesh auto-detect
	if not visual_mesh:
		for c in get_children():
			if c is MeshInstance3D:
				visual_mesh = c; break

func _physics_process(delta: float) -> void:
	var d := global_position.distance_to(server_position)
	if d > max_snap_distance:
		global_position = server_position
		rotation.y = server_yaw
	else:
		global_position = global_position.lerp(server_position, interpolation_speed * delta)
		rotation.y = lerp_angle(rotation.y, server_yaw, interpolation_speed * delta)

func update_from_server(pos: Vector3, new_yaw: float) -> void:
	server_position = pos
	server_yaw = new_yaw

func reset_interpolation(pos: Vector3, new_yaw: float) -> void:
	global_position = pos
	rotation.y = new_yaw
	server_position = pos
	server_yaw = new_yaw

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	# Return to pool instead of freeing
	EntityPool.return_monster(self)
