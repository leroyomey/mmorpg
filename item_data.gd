extends Resource
class_name ItemData

@export var item_id: String
@export var display_name: String
@export var description: String
@export var rarity: String = "common"
@export var mesh_scene: PackedScene
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
@export var base_value: int = 1
