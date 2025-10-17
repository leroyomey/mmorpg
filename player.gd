extends CharacterBody3D
class_name Player
# ============================================================================
# SIGNALS - For UI to listen to
# ============================================================================
signal health_changed(current: float, max: float)
signal mana_changed(current: float, max: float)
signal energy_changed(current: float, max: float)
signal level_changed(new_level: int)
signal experience_changed(current: int, required: int)
signal stats_changed()

# ============================================================================
# NETWORK SYNC
# ============================================================================
@export var player_id: int = 0
@export var player_name: String = "Player"

# ============================================================================
# COMBAT STATS
# ============================================================================
var max_health: float = 100.0
var max_mana: float = 100.0
var max_energy: float = 100.0

# ---- HEALTH ----
var _health: float = 100.0
var health: float:
	set(value):
		_health = clampf(value, 0.0, max_health)
		health_changed.emit(_health, max_health)
		if _health <= 0.0:
			die()
	get:
		return _health

# ---- MANA ----
var _mana: float = 100.0
var mana: float:
	set(value):
		_mana = clampf(value, 0.0, max_mana)
		mana_changed.emit(_mana, max_mana)
	get:
		return _mana

# ---- ENERGY ----
var _energy: float = 100.0
var energy: float:
	set(value):
		_energy = clampf(value, 0.0, max_energy)
		energy_changed.emit(_energy, max_energy)
	get:
		return _energy

# ---- LEVEL ----
var _level: int = 1
var level: int:
	set(value):
		_level = clamp(value, 1, 80)
		level_changed.emit(_level)
		calculate_max_stats()
	get:
		return _level

# ---- EXPERIENCE ----
var _experience: int = 0
var experience: int:
	set(value):
		_experience = value
		var required_xp := get_required_xp_for_level(level)
		experience_changed.emit(_experience, required_xp)
		check_level_up()
	get:
		return _experience

# Base stats (affect max health, damage, etc.)
# These scale with level automatically
var strength: int = 10
var intelligence: int = 10
var agility: int = 10
var stamina: int = 10

# ============================================================================
# GEAR SYSTEM
# ============================================================================
var gear_score: int = 0  # Range: 0-5000 (max achievable in ~1 year)

# ============================================================================
# REGENERATION SETTINGS
# ============================================================================
@export var health_regen_percent: float = 0.01  # 1% per second
@export var mana_regen_percent: float = 0.02    # 2% per second
@export var energy_regen_percent: float = 0.05  # 5% per second

# ============================================================================
# MOVEMENT / NAVIGATION
# ============================================================================
@export var move_speed: float = 2.5
@export var turn_speed: float = 7.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var agent: NavigationAgent3D = $Agent

# ============================================================================
# CAMERA SETTINGS (RMB orbit; NO auto-rotate)
# ============================================================================
@export var mouse_sens: float = 0.002
@export var orbit_sens: float = 0.006
@export var min_pitch := deg_to_rad(-20)
@export var max_pitch := deg_to_rad(60)
@export var cam_follow_smooth := 0.0  # 0 = snap; >0 seconds = smooth follow

@export var zoom_speed: float = 1.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 15.0
@export var zoom_smooth: float = 10.0

var current_zoom: float = 12.0
var target_zoom: float = 12.0

@onready var cam_rig: Node3D = $CameraRig
@onready var cam_pivot: Node3D = $CameraRig/CameraPivot
@onready var spring_arm: SpringArm3D = $CameraRig/CameraPivot/SpringArm3D
@onready var cam: Camera3D = $CameraRig/CameraPivot/SpringArm3D/Camera3D

# ============================================================================
# NETWORK INTERPOLATION
# ============================================================================
var server_position: Vector3 = Vector3.ZERO
var server_yaw: float = 0.0
var interpolation_speed: float = 10.0
var is_local_player: bool = false
var max_snap_distance: float = 5.0  # NEW: Snap if farther than this

# ============================================================================
# CAMERA STATE
# ============================================================================
var yaw: float = 0.0
var pitch: float = 0.0

var _has_target := false
var character_data: Dictionary = {}  # now it exists

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	add_to_group("Player")
	# Calculate initial max stats based on starting level
	calculate_max_stats()
	
	# Initialize current values to max
	health = max_health
	mana = max_mana
	energy = max_energy
	
	# Add to group for easy UI reference
	if is_local_player:
		add_to_group("local_player")
		print("Added to local_player group!")  # DEBUG
		
		cam.current = true
		spring_arm.spring_length = current_zoom
		
		# --- Nav setup ---
		agent.path_desired_distance = 0.8
		agent.target_desired_distance = 0.8
		agent.avoidance_enabled = true
		agent.navigation_finished.connect(_on_navigation_finished)

		# --- Camera detachment: keep in this scene but stop inheriting Player transform ---
		cam_rig.set_as_top_level(true)
		cam_rig.global_position = global_position

		# Capture initial cam orientation from the editor
		yaw = cam_rig.rotation.y
		pitch = cam_pivot.rotation.x
	else:
		cam.current = false

# ============================================================================
# STAT CALCULATIONS (Hardcore 1-Year System)
# ============================================================================
func calculate_max_stats() -> void:
	"""Recalculate max health/mana/energy based on level and base stats"""
	# Stats scale up to level 80 (1-year max progression)
	var level_health_bonus = level * 50.0
	var stamina_bonus = stamina * 20.0
	max_health = 100.0 + level_health_bonus + stamina_bonus
	
	var level_mana_bonus = level * 30.0
	var int_bonus = intelligence * 15.0
	max_mana = 100.0 + level_mana_bonus + int_bonus
	
	var level_energy_bonus = level * 20.0
	var agi_bonus = agility * 10.0
	max_energy = 100.0 + level_energy_bonus + agi_bonus
	
	stats_changed.emit()
	
	# Examples at different progression points:
	# Level 1, Stats 10 each: 350 HP, 250 MP, 200 EP
	# Level 40, Stats 50 each: 3,100 HP, 1,950 MP, 1,600 EP
	# Level 80, Stats 100 each: 6,100 HP, 3,900 MP, 3,100 EP

func calculate_damage() -> float:
	"""Calculate base damage output"""
	var base = 50.0 + (level * 10.0)
	var stat_bonus = strength * 5.0
	var gear_bonus = gear_score * 0.2
	return base + stat_bonus + gear_bonus
	
	# Examples:
	# Level 1, Str 10, GS 0: 110 damage
	# Level 40, Str 50, GS 2000: 1,140 damage (10.4x)
	# Level 80, Str 100, GS 5000: 2,350 damage (21.4x)

func calculate_total_power() -> float:
	"""Calculate overall character power (for matchmaking/balancing)"""
	var base = 1000.0
	var level_power = level * 100.0
	var gear_power = gear_score * 2.0
	return base + level_power + gear_power
	
	# Power progression:
	# Level 1, GS 0: 1,100 power
	# Level 40, GS 2000: 9,000 power (8.2x)
	# Level 80, GS 5000: 19,000 power (17.3x from start)

func get_required_xp_for_level(lvl: int) -> int:
	"""Calculate XP required for next level (1-year progression curve)"""
	# Aggressive but achievable curve
	if lvl <= 20:
		return int(100 * pow(1.4, lvl - 1))  # Fast start (~20 hours total)
	elif lvl <= 50:
		return int(5000 * pow(1.5, lvl - 20))  # Mid game (~200 hours total)
	else:
		return int(500000 * pow(1.6, lvl - 50))  # Endgame (~1000 hours total)
	
	# Total time to level 80: ~1000-1200 hours (1 year of regular play)

func check_level_up() -> void:
	"""Check if player has enough XP to level up"""
	if level >= 80:
		return  # Max level reached
	
	var required_xp = get_required_xp_for_level(level)
	while experience >= required_xp and level < 80:
		experience -= required_xp
		level += 1
		# Full heal on level up
		health = max_health
		mana = max_mana
		energy = max_energy
		required_xp = get_required_xp_for_level(level)
		
		print("%s leveled up to %d!" % [player_name, level])

# ============================================================================
# COMBAT FUNCTIONS
# ============================================================================
func take_damage(amount: float, _attacker: Node = null) -> void:
	"""Apply damage to player"""
	health -= amount
	# TODO: Spawn damage number in world space UI
	# WorldSpaceUI.spawn_damage_number(global_position, amount)

func heal(amount: float) -> void:
	"""Restore health"""
	health += amount

func use_mana(amount: float) -> bool:
	"""Attempt to use mana. Returns true if successful"""
	if mana >= amount:
		mana -= amount
		return true
	return false

func use_energy(amount: float) -> bool:
	"""Attempt to use energy. Returns true if successful"""
	if energy >= amount:
		energy -= amount
		return true
	return false

func restore_mana(amount: float) -> void:
	"""Restore mana"""
	mana += amount

func restore_energy(amount: float) -> void:
	"""Restore energy"""
	energy += amount

func add_experience(amount: int) -> void:
	"""Add experience points"""
	if level >= 80:
		return  # No XP gain at max level
	experience += amount

func die() -> void:
	"""Handle player death"""
	print("%s has died!" % player_name)
	# TODO: Implement death logic
	# - Disable input
	# - Play death animation
	# - Show respawn UI
	# - Drop items?
	# - Respawn after delay

# ============================================================================
# NAVIGATION CALLBACKS
# ============================================================================
func _on_navigation_finished() -> void:
	_has_target = false
	velocity.x = 0.0
	velocity.z = 0.0

# ============================================================================
# INPUT HANDLING
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player:
		return

	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)
	
	# Click-to-move raycast from the current camera
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos: Vector2 = event.position
		var from: Vector3 = cam.project_ray_origin(click_pos)
		var dir: Vector3 = cam.project_ray_normal(click_pos)
		var to: Vector3 = from + dir * 2000.0

		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(query)

		if hit:
			var target: Vector3 = hit.position
			agent.target_position = target
			_has_target = true
			
			# Wait for NavigationAgent to calculate the path
			await get_tree().process_frame
			
			# Get the calculated path and send to server
			var path = agent.get_current_navigation_path()
			if path.size() > 0:
				Net.set_player_waypoints(path)

	# RMB orbit: only rotate camera while RMB is held
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * mouse_sens
		pitch = clamp(pitch - event.relative.y * orbit_sens, min_pitch, max_pitch)
		_apply_camera_rot()

# ============================================================================
# PHYSICS & MOVEMENT
# ============================================================================
func _physics_process(delta: float) -> void:
	# Remote player: interpolate to server position
	if not is_local_player:
		# Check if we need to snap vs interpolate
		var distance_to_target = global_position.distance_to(server_position)
		
		if distance_to_target > max_snap_distance:
			# Too far - snap instantly (prevents long slides when re-entering view)
			global_position = server_position
			rotation.y = server_yaw
		else:
			# Close enough - smooth interpolation
			global_position = global_position.lerp(server_position, interpolation_speed * delta)
			rotation.y = lerp_angle(rotation.y, server_yaw, interpolation_speed * delta)
		return
	
	# === LOCAL PLAYER ONLY BELOW THIS POINT ===
	
	# Handle passive regeneration
	_handle_regeneration(delta)
	
	# Smooth zoom
	current_zoom = lerp(current_zoom, target_zoom, zoom_smooth * delta)
	spring_arm.spring_length = current_zoom
	
	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = move_toward(velocity.y, 0.0, gravity * delta)

	# --- Path following + facing ---
	if not agent.is_navigation_finished():
		var next_point: Vector3 = agent.get_next_path_position()
		var to_next: Vector3 = next_point - global_transform.origin
		to_next.y = 0.0

		var dist := to_next.length()
		if dist > 0.01:
			var dir: Vector3 = to_next.normalized()
			var desired_vel: Vector3 = dir * move_speed
			velocity.x = desired_vel.x
			velocity.z = desired_vel.z

			# Smoothly face movement direction (PLAYER ONLY)
			var facing := global_transform.basis
			var current_forward := -facing.z
			var target_rot := current_forward.slerp(dir, clamp(turn_speed * delta, 0.0, 1.0))
			look_at(global_transform.origin + target_rot, Vector3.UP)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	# --- Camera follow: position only; never inherit rotation ---
	if cam_follow_smooth > 0.0:
		var t: float = clamp(delta / cam_follow_smooth, 0.0, 1.0)
		cam_rig.global_position = cam_rig.global_position.lerp(global_position, t)
	else:
		cam_rig.global_position = global_position

# ============================================================================
# REGENERATION
# ============================================================================
func _handle_regeneration(delta: float) -> void:
	"""Passive health/mana/energy regeneration (local player only)"""
	if health < max_health:
		health += (max_health * health_regen_percent) * delta
	
	if mana < max_mana:
		mana += (max_mana * mana_regen_percent) * delta
	
	if energy < max_energy:
		energy += (max_energy * energy_regen_percent) * delta

# ============================================================================
# CAMERA CONTROL
# ============================================================================
func _apply_camera_rot() -> void:
	"""Apply yaw and pitch to camera rig"""
	cam_rig.rotation = Vector3(0.0, yaw, 0.0)
	cam_pivot.rotation.x = pitch

# ============================================================================
# NETWORK SYNC
# ============================================================================
func update_from_server(pos: Vector3, new_yaw: float) -> void:
	"""Called by network manager to update remote player position"""
	if is_local_player:
		pass
	else:
		server_position = pos
		server_yaw = new_yaw

func reset_interpolation(pos: Vector3, new_yaw: float) -> void:
	"""Snap to position without interpolation (used when re-entering view)"""
	if not is_local_player:
		global_position = pos
		rotation.y = new_yaw
		server_position = pos
		server_yaw = new_yaw

func setup(data: Dictionary) -> void:
	character_data = data
	# apply spawn position if included
	if data.has("position"):
		var pos = data["position"]
		global_transform.origin = Vector3(pos["x"], pos["y"], pos["z"])
		rotation.y = pos["yaw"]
