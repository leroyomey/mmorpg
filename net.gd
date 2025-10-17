extends Node

var _outbox: Array[String] = []  # queue JSON strings until OPEN
var url: String = ""        # stores the current websocket URL
var pending_character_data: Dictionary = {}
var account_data: Dictionary = {}  # ← ADD THIS LINE
# Signals
signal connection_state_changed(connected: bool)
signal login_success(account_data: Dictionary)
signal login_failed(reason: String)
signal character_loaded(data: Dictionary)
signal snapshot_received(data: Dictionary)

var ws: WebSocketPeer = WebSocketPeer.new()
var connected: bool = false
var seq: int = 0

const SEND_INTERVAL := 0.05
var _accum: float = 0.0

var my_id: String = ""
var entities: Dictionary = {}
var local_player: CharacterBody3D = null
var visible_entities: Dictionary = {}

# Monster system
var monster_scene: PackedScene = preload("res://actors/monsters/lvl_1_zombie/lvl_1_testmonster.tscn")
var monsters: Dictionary = {}
var visible_monsters: Dictionary = {}

var server_url: String = ""
var is_logged_in: bool = false
var _spawn_parent: Node = null

var world_ready := false

# preload your scenes; change paths to match your project
const PLAYER_SCENE := preload("res://actors/players/player.tscn")
const MONSTER_SCENE := preload("res://actors/monsters/lvl_1_zombie/lvl_1_testmonster.tscn")

# ============================================================================
# SPAWN PARENT
# ============================================================================
func set_spawn_parent(parent: Node) -> void:
	"""Set where entities should be spawned"""
	_spawn_parent = parent
	print("📍 Spawn parent set")

# ============================================================================
# SPAWN LOCAL PLAYER
# ============================================================================
func spawn_local_player(data: Dictionary) -> void:
	print("🎮 Spawning local player...")
	
	if get_tree().current_scene == null:
		push_error("❌ No current scene to spawn player into!")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Create player instance
	var player_instance = PLAYER_SCENE.instantiate()
	player_instance.is_local_player = true
	
	# Add to world FIRST
	var spawn_parent = _spawn_parent if _spawn_parent != null else get_tree().current_scene
	spawn_parent.add_child(player_instance)
	
	# Wait for it to enter tree AND _ready() to complete
	if not player_instance.is_inside_tree():
		await player_instance.tree_entered
	
	# Extra frame to let _ready() finish
	await get_tree().process_frame
	
	# NOW set position
	var pos = data.get("position", {})
	player_instance.global_position = Vector3(
		float(pos.get("x", 0.0)),
		float(pos.get("y", 0.0)),
		float(pos.get("z", 0.0))
	)
	player_instance.rotation.y = float(pos.get("yaw", 0.0))
	
	# DEBUG: Show what we're setting
	print("📦 Setting player stats from server:")
	print("   Level from server: ", data.get("level", 1))
	print("   Health from server: ", data.get("health", 100.0))
	
	# Set stats from server (SERVER AUTHORITATIVE)
	# Set level LAST to trigger proper signals
	player_instance.strength = int(data.get("strength", 10))
	player_instance.intelligence = int(data.get("intelligence", 10))
	player_instance.agility = int(data.get("agility", 10))
	player_instance.stamina = int(data.get("stamina", 10))
	player_instance.experience = int(data.get("experience", 0))
	player_instance.level = int(data.get("level", 1))  # ← Set level AFTER base stats
	player_instance.health = float(data.get("health", 100.0))
	player_instance.mana = float(data.get("mana", 100.0))
	player_instance.energy = float(data.get("energy", 100.0))
	player_instance.player_name = str(data.get("name", "Player"))
	
	print("✅ Stats set. Player level is now: ", player_instance.level)
	
	# Store reference
	local_player = player_instance
	is_logged_in = true
	
	print("✅ Local player spawned: ", player_instance.player_name, " at ", player_instance.global_position)

# ---- Public API ----
func connect_to_server(u: String) -> void:
	url = u
	ws = WebSocketPeer.new()
	var err := ws.connect_to_url(url)
	if err != OK:
		push_error("WS connect error: %s" % err)
		connected = false
		emit_signal("connection_state_changed", connected)

func close() -> void:
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.close()

func login(u:String, p:String) -> void:
	_send_json({"t":"login","username":u,"password":p})

func select_character(id:String) -> void:
	_send_json({"t":"select_character","character_id":id})

# ---- Internal helpers ----
func _send_json(payload: Dictionary) -> void:
	var txt := JSON.stringify(payload)
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		ws.send_text(txt)
	elif state == WebSocketPeer.STATE_CONNECTING:
		_outbox.append(txt)                     # queue until OPEN
	else:
		_outbox.append(txt)                     # CLOSED: queue + reconnect
		if url != "":
			connect_to_server(url)

func _process(delta: float) -> void:
	var state := ws.get_ready_state()

	if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN:
		ws.poll()

	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		emit_signal("connection_state_changed", connected)
		for txt in _outbox:
			ws.send_text(txt)
		_outbox.clear()

	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			var txt: String = ws.get_packet().get_string_from_utf8()
			var data = JSON.parse_string(txt)
			if typeof(data) != TYPE_DICTIONARY:
				push_warning("Dropping non-dict packet")
				continue
			_on_message(data)
		
		# Send input regularly
		_accum += delta
		if _accum >= SEND_INTERVAL and local_player != null:
			_accum = 0.0
			_send_input()

	if state == WebSocketPeer.STATE_CLOSED and connected:
		connected = false
		emit_signal("connection_state_changed", connected)

func _state_str(state: int) -> String:
	match state:
		WebSocketPeer.STATE_CONNECTING: return "CONNECTING"
		WebSocketPeer.STATE_OPEN: return "OPEN"
		WebSocketPeer.STATE_CLOSING: return "CLOSING"
		WebSocketPeer.STATE_CLOSED: return "CLOSED"
		_: return str(state)

# Wait until the WS is OPEN (or timeout)
func _await_open(timeout: float = 5.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := ws.get_ready_state()
		if s == WebSocketPeer.STATE_OPEN:
			return true
		if s == WebSocketPeer.STATE_CLOSING or s == WebSocketPeer.STATE_CLOSED:
			return false
		await get_tree().process_frame
		t += get_process_delta_time()
	return ws.get_ready_state() == WebSocketPeer.STATE_OPEN

func _send_input() -> void:
	if local_player == null:
		return
	
	seq += 1
	
	var payload: Dictionary = {
		"t": "input",
		"seq": seq,
		"input": {
			"x": local_player.global_position.x,
			"y": local_player.global_position.y,
			"z": local_player.global_position.z,
			"yaw": local_player.rotation.y,
			"health": local_player.health,
			"mana": local_player.mana,
			"energy": local_player.energy
		}
	}
	_send_json(payload)

func wait_world_ready(timeout := 3.0) -> bool:
	world_ready = false
	var world := get_tree().current_scene
	if world:
		# if the scene is already ready, we can proceed
		world_ready = true
		return true
	var t := 0.0
	while t < timeout and not world_ready:
		await get_tree().process_frame
		t += get_process_delta_time()
		world = get_tree().current_scene
		if world:
			world_ready = true
			return true
	return world_ready

func on_world_ready() -> void:
	world_ready = true

# ---- Message router ----
func _on_message(msg: Dictionary) -> void:
	var msg_type = msg.get("t")
	
	match msg_type:
		"login_success":
			login_success.emit(msg)
		
		"login_failed":
			login_failed.emit(msg.get("reason", "Unknown error"))
		
		"character_loaded":
			character_loaded.emit(msg.get("character", {}))
		
		"kicked":
			print("🚨 KICKED FROM SERVER: ", msg.get("reason"))
			
			var kick_reason = msg.get("reason", "Disconnected from server")
			
			# CRITICAL: Clean up ALL entities before disconnect
			_cleanup_all_entities()
			
			# Disconnect
			ws.close()
			connected = false
			local_player = null
			is_logged_in = false
			my_id = ""
			
			# Return to login
			get_tree().change_scene_to_file("res://login.tscn")
			
			# Wait for scene to load
			await get_tree().create_timer(0.5).timeout
			
			# Set status message on login screen
			var login_screen = get_tree().current_scene
			if login_screen and login_screen.has_method("set_status"):
				login_screen.set_status("⚠️ " + kick_reason, Color.ORANGE_RED)
		
		"snap":
			my_id = msg.get("me", "")
			_handle_snapshot(msg)

func _cleanup_all_entities() -> void:
	print("🧹 Cleaning up all entities...")
	
	# Clean up remote players
	for id in entities.keys():
		var entity = entities[id]
		if is_instance_valid(entity):
			entity.queue_free()
	entities.clear()
	visible_entities.clear()
	
	# Clean up monsters
	for id in monsters.keys():
		var monster = monsters[id]
		if is_instance_valid(monster):
			monster.queue_free()
	monsters.clear()
	visible_monsters.clear()
	
	print("✅ All entities cleaned up")

func _show_kick_message(reason: String) -> void:
	# Create a simple popup
	var popup = AcceptDialog.new()
	popup.dialog_text = reason
	popup.title = "Disconnected"
	popup.ok_button_text = "OK"
	
	# Add to current scene
	get_tree().current_scene.add_child(popup)
	popup.popup_centered()
	
	# Auto-close after 2 seconds
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(popup):
		popup.queue_free()

func _handle_snapshot(msg: Dictionary) -> void:
	var players_arr = msg.get("players", [])
	var monsters_arr = msg.get("monsters", [])
	
	var seen_players: Dictionary = {}
	var seen_monsters: Dictionary = {}
	
	# DEBUG: Show snapshot info
	if players_arr.size() > 0:
		print("📸 Snapshot: ", players_arr.size(), " players, ", monsters_arr.size(), " monsters")
	
	# Handle remote players
	for p in players_arr:
		var id: String = str(p.get("id"))
		
		# Skip if this is us
		if id == my_id:
			print("   Skipping self: ", id.substr(0, 8))
			continue
		
		var pos: Vector3 = Vector3(float(p.get("x")), float(p.get("y")), float(p.get("z")))
		var yaw: float = float(p.get("yaw"))
		
		print("   Remote player ", id.substr(0, 8), " at ", pos)
		
		# Create or update remote player
		var node: CharacterBody3D = await _ensure_entity(id, "player")
		
		if node == null:
			print("   ⚠️ Failed to create/get remote player node")
			continue
		
		if node.has_method("update_from_server"):
			node.update_from_server(pos, yaw)
			print("   ✅ Updated remote player position")
		else:
			print("   ⚠️ Remote player missing update_from_server method")
		
		seen_players[id] = true
		visible_entities[id] = true
	
	# Handle monsters
	for m in monsters_arr:
		var id: String = str(m.get("id"))
		var pos: Vector3 = Vector3(float(m.get("x")), float(m.get("y")), float(m.get("z")))
		var yaw: float = float(m.get("yaw"))
		var type: String = m.get("type", "goblin")
		var level: int = m.get("level", 1)
		
		var monster = _ensure_monster(id, type, level)
		
		if monster and monster.has_method("update_from_server"):
			monster.update_from_server(pos, yaw)
		
		seen_monsters[id] = true
		visible_monsters[id] = true
	
	# Remove disconnected players
	for id in entities.keys():
		if not seen_players.has(id):
			if entities[id] != null:
				print("🗑️ Removing disconnected player: ", id.substr(0, 8))
				entities[id].queue_free()
			entities.erase(id)
			visible_entities.erase(id)
	
	# Remove despawned monsters
	for id in monsters.keys():
		if not seen_monsters.has(id):
			if monsters[id] != null:
				monsters[id].queue_free()
			monsters.erase(id)
			visible_monsters.erase(id)

func _instantiate_entity(eid: String, kind: String) -> Node:
	var world := get_tree().current_scene
	if world == null or not world.is_inside_tree():
		push_warning("World not ready for " + kind + " " + eid.substr(0, 8))
		return null

	var node: Node3D

	match kind:
		"player":
			node = PLAYER_SCENE.instantiate()
			node.name = "Player_%s" % eid.substr(0, 8)
			node.is_local_player = false
			node.add_to_group("remote_players")
			print("   👤 Created remote player node")
		"monster":
			node = MONSTER_SCENE.instantiate()
			node.name = "Monster_%s" % eid.substr(0, 8)
			print("   🧟 Created monster node")
		_:
			node = Node3D.new()
			node.name = "Entity_%s" % eid.substr(0, 8)

	world.add_child(node, true)
	print("   📌 Added ", kind, " to world tree")
	
	# Wait for tree entry
	if not node.is_inside_tree():
		print("   ⏳ Waiting for tree entry...")
		await node.tree_entered
	
	print("   ✅ ", kind, " ", eid.substr(0, 8), " fully spawned at ", node.global_position)
	
	return node

func _ensure_entity(eid: String, kind: String) -> Node:
	# Check if entity exists and is still valid
	if entities.has(eid):
		var existing = entities[eid]
		if is_instance_valid(existing):
			return existing
		else:
			# Entity was freed, remove from dict
			print("⚠️ Entity ", eid.substr(0, 8), " was freed, recreating...")
			entities.erase(eid)
	
	# Create new entity
	print("🆕 Creating new ", kind, " entity: ", eid.substr(0, 8))
	var node = await _instantiate_entity(eid, kind)
	
	if node == null:
		push_error("❌ Failed to create entity ", eid.substr(0, 8))
		return null
	
	entities[eid] = node
	
	# Auto-cleanup when entity is removed from tree
	node.tree_exited.connect(func():
		if entities.get(eid) == node:
			print("🗑️ Entity removed from tree: ", eid.substr(0, 8))
			entities.erase(eid)
	)
	
	print("✅ Entity created successfully: ", kind, " ", eid.substr(0, 8))
	return node

func _ensure_monster(id: String, type: String, level: int) -> Node:
	# Check if monster exists and is still valid
	if monsters.has(id):
		var existing = monsters[id]
		if is_instance_valid(existing):
			return existing
		else:
			# Monster was freed, remove from dict
			monsters.erase(id)
	
	# Create new monster
	var monster = monster_scene.instantiate()
	monster.monster_id = id
	monster.monster_type = type
	monster.level = level
	
	var parent: Node = _spawn_parent if _spawn_parent != null else get_tree().current_scene
	
	# Make sure parent is valid
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		push_error("❌ Cannot spawn monster - invalid parent")
		return null
	
	parent.add_child(monster)
	
	monsters[id] = monster
	print("🧟 Spawned monster: ", type, " Lv.", level)
	
	return monster

func set_player_waypoints(path: PackedVector3Array) -> void:
	if local_player == null or path.size() == 0:
		return
	# For now, just send current position/yaw; server doesn’t consume paths yet
	_send_json({
		"t": "input",
		"seq": seq + 1,
		"input": {
			"x": local_player.global_position.x,
			"y": local_player.global_position.y,
			"z": local_player.global_position.z,
			"yaw": local_player.rotation.y
		}
	})
