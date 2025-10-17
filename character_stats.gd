extends PanelContainer

@onready var level_value: Label = $MarginContainer/VBoxContainer/LevelValue
#@onready var xp_value: Label = $MarginContainer/VBoxContainer/StatsVBox/XPRow/XPValue
#@onready var health_value: Label = $MarginContainer/VBoxContainer/StatsVBox/HealthRow/HealthValue
#@onready var mana_value: Label = $MarginContainer/VBoxContainer/StatsVBox/ManaRow/ManaValue
#@onready var energy_value: Label = $MarginContainer/VBoxContainer/StatsVBox/EnergyRow/EnergyValue
@onready var str_value: Label = $MarginContainer/VBoxContainer/StrValue
@onready var int_value: Label = $MarginContainer/VBoxContainer/IntValue
@onready var agi_value: Label = $MarginContainer/VBoxContainer/AgiValue
@onready var sta_value: Label = $MarginContainer/VBoxContainer/StaValue
#@onready var gear_value: Label = $MarginContainer/VBoxContainer/StatsVBox/GearRow/GearValue
#@onready var damage_value: Label = $MarginContainer/VBoxContainer/StatsVBox/DamageRow/DamageValue
#@onready var power_value: Label = $MarginContainer/VBoxContainer/StatsVBox/PowerRow/PowerValue
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var local_player: Player = null

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false  # Start hidden
	_find_and_connect_player()

func _find_and_connect_player() -> void:
	var attempts = 0
	var max_attempts = 300  # 5 seconds at 60fps
	
	while local_player == null and attempts < max_attempts:
		await get_tree().process_frame
		local_player = get_tree().get_first_node_in_group("local_player")
		attempts += 1
	
	if local_player == null:
		push_error("CharacterStats: Failed to find local player after 5 seconds!")
		return
	
	print("Character Stats connected to player!")
	
	# Connect signals
	local_player.health_changed.connect(_update_display)
	local_player.mana_changed.connect(_update_display)
	local_player.energy_changed.connect(_update_display)
	local_player.level_changed.connect(_update_display)
	local_player.experience_changed.connect(_update_display)
	local_player.stats_changed.connect(_update_display)
	
	# Initial update
	_update_display()

func _update_display(_a = null, _b = null) -> void:
	if not local_player:
		return
	
	level_value.text = "LVL: " + str(local_player.level)  # ← FIXED: Proper formatting
	var _req_xp = local_player.get_required_xp_for_level(local_player.level)
	#xp_value.text = "%d / %d" % [local_player.experience, req_xp]
	
	#health_value.text = "%d / %d" % [int(local_player.health), int(local_player.max_health)]
	#mana_value.text = "%d / %d" % [int(local_player.mana), int(local_player.max_mana)]
	#energy_value.text = "%d / %d" % [int(local_player.energy), int(local_player.max_energy)]
	
	str_value.text = "STR: " + str(local_player.strength)
	int_value.text = "INT: " + str(local_player.intelligence)
	agi_value.text = "AGI: " + str(local_player.agility)
	sta_value.text = "STA: " + str(local_player.stamina)
	
	#gear_value.text = str(local_player.gear_score)
	#damage_value.text = str(int(local_player.calculate_damage()))
	#power_value.text = str(int(local_player.calculate_total_power()))

func _on_close_pressed() -> void:
	visible = false

func toggle() -> void:
	visible = !visible
