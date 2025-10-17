# hud.gd
extends Control

@onready var health_bar: ProgressBar = $TopBar/HealthBar
@onready var health_label: Label = $TopBar/HealthBar/HealthLabel
@onready var mana_bar: ProgressBar = $TopBar/ManaBar
@onready var mana_label: Label = $TopBar/ManaBar/ManaLabel
@onready var energy_bar: ProgressBar = $TopBar/EnergyBar
@onready var energy_label: Label = $TopBar/EnergyBar/EnergyLabel
@onready var xp_bar: ProgressBar = $TopBar/XPBar
@onready var xp_label: Label = $TopBar/XPBar/XPLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var character_stats: PanelContainer = $CharacterStats

var local_player: Player = null

# Display options - can be changed via settings menu
enum DisplayMode {
	NUMERIC,      # 100/150
	PERCENTAGE,   # 66%
	BOTH,         # 100/150 (66%)
	NONE          # No text
}

var health_display_mode: DisplayMode = DisplayMode.NUMERIC
var mana_display_mode: DisplayMode = DisplayMode.NUMERIC
var energy_display_mode: DisplayMode = DisplayMode.NUMERIC
var xp_display_mode: DisplayMode = DisplayMode.PERCENTAGE

func _ready() -> void:
	setup_progress_bars()
	_find_and_connect_player()

func setup_progress_bars() -> void:
	# Health - Red
	var health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color(220.0/255.0, 20.0/255.0, 20.0/255.0)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	
	var health_bg = StyleBoxFlat.new()
	health_bg.bg_color = Color(40.0/255.0, 40.0/255.0, 40.0/255.0)
	health_bar.add_theme_stylebox_override("background", health_bg)
	
	# Mana - Blue
	var mana_fill = StyleBoxFlat.new()
	mana_fill.bg_color = Color(33.0/255.0, 150.0/255.0, 243.0/255.0)
	mana_bar.add_theme_stylebox_override("fill", mana_fill)
	
	var mana_bg = StyleBoxFlat.new()
	mana_bg.bg_color = Color(40.0/255.0, 40.0/255.0, 40.0/255.0)
	mana_bar.add_theme_stylebox_override("background", mana_bg)
	
	# Energy - Yellow
	var energy_fill = StyleBoxFlat.new()
	energy_fill.bg_color = Color(255.0/255.0, 214.0/255.0, 0.0/255.0)
	energy_bar.add_theme_stylebox_override("fill", energy_fill)
	
	var energy_bg = StyleBoxFlat.new()
	energy_bg.bg_color = Color(40.0/255.0, 40.0/255.0, 40.0/255.0)
	energy_bar.add_theme_stylebox_override("background", energy_bg)
	
	# XP - Purple
	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(153.0/255.0, 51.0/255.0, 204.0/255.0)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	
	var xp_bg = StyleBoxFlat.new()
	xp_bg.bg_color = Color(40.0/255.0, 40.0/255.0, 40.0/255.0)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	
	# Setup label styling (outline for readability)
	for label in [health_label, mana_label, energy_label, xp_label]:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)

func _find_and_connect_player() -> void:
	var attempts = 0
	var max_attempts = 300  # 5 seconds at 60fps
	
	while local_player == null and attempts < max_attempts:
		await get_tree().process_frame
		local_player = get_tree().get_first_node_in_group("local_player")
		attempts += 1
	
	if local_player == null:
		push_error("HUD: Failed to find local player after 5 seconds!")
		# Show error message to user
		_show_error_message("Failed to connect to game. Please restart.")
		return
	
	# Player found! Connect signals
	print("Local player found! Connecting HUD...")
	local_player.health_changed.connect(_on_health_changed)
	local_player.mana_changed.connect(_on_mana_changed)
	local_player.energy_changed.connect(_on_energy_changed)
	local_player.level_changed.connect(_on_level_changed)
	local_player.experience_changed.connect(_on_experience_changed)
	local_player.stats_changed.connect(_on_stats_changed)
	
	# Initialize UI with current values
	_on_health_changed(local_player.health, local_player.max_health)
	_on_mana_changed(local_player.mana, local_player.max_mana)
	_on_energy_changed(local_player.energy, local_player.max_energy)
	_on_level_changed(local_player.level)
	_on_experience_changed(local_player.experience, local_player.get_required_xp_for_level(local_player.level))

func _show_error_message(message: String) -> void:
	# You can create a Label node for errors
	# For now, just print
	push_error(message)
	# TODO: Show this in UI

# Helper function to format bar text based on display mode
func format_bar_text(current: float, maximum: float, mode: DisplayMode) -> String:
	match mode:
		DisplayMode.NUMERIC:
			return "%d/%d" % [int(current), int(maximum)]
		DisplayMode.PERCENTAGE:
			var percent = (current / maximum * 100.0) if maximum > 0 else 0.0  # Changed to 0.0
			return "%d%%" % int(percent)
		DisplayMode.BOTH:
			var percent = (current / maximum * 100.0) if maximum > 0 else 0.0  # Changed to 0.0
			return "%d/%d (%d%%)" % [int(current), int(maximum), int(percent)]
		DisplayMode.NONE:
			return ""
	return ""

# Signal callbacks
func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current
	health_label.text = format_bar_text(current, max_hp, health_display_mode)

func _on_mana_changed(current: float, max_mp: float) -> void:
	mana_bar.max_value = max_mp
	mana_bar.value = current
	mana_label.text = format_bar_text(current, max_mp, mana_display_mode)

func _on_energy_changed(current: float, max_ep: float) -> void:
	energy_bar.max_value = max_ep
	energy_bar.value = current
	energy_label.text = format_bar_text(current, max_ep, energy_display_mode)

func _on_level_changed(new_level: int) -> void:
	level_label.text = "Level %d" % new_level

func _on_experience_changed(current: int, required: int) -> void:
	xp_bar.max_value = required
	xp_bar.value = current
	xp_label.text = format_bar_text(current, required, xp_display_mode)

func _on_stats_changed() -> void:
	if local_player:
		health_bar.max_value = local_player.max_health
		mana_bar.max_value = local_player.max_mana
		energy_bar.max_value = local_player.max_energy

# Public functions to change display modes (call from settings menu)
func set_health_display_mode(mode: DisplayMode) -> void:
	health_display_mode = mode
	if local_player:
		_on_health_changed(local_player.health, local_player.max_health)

func set_mana_display_mode(mode: DisplayMode) -> void:
	mana_display_mode = mode
	if local_player:
		_on_mana_changed(local_player.mana, local_player.max_mana)

func set_energy_display_mode(mode: DisplayMode) -> void:
	energy_display_mode = mode
	if local_player:
		_on_energy_changed(local_player.energy, local_player.max_energy)

func set_xp_display_mode(mode: DisplayMode) -> void:
	xp_display_mode = mode
	if local_player:
		_on_experience_changed(local_player.experience, local_player.get_required_xp_for_level(local_player.level))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"):  # Tab key
		if character_stats:
			character_stats.toggle()
