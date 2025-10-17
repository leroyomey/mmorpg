extends Node3D

func _ready() -> void:
	# Set spawn parent
	Net.set_spawn_parent(self)
	print("🌍 World ready")
	
	# Wait a few frames for everything to settle
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check if we have pending character data from login
	if Net.pending_character_data.size() > 0:
		print("📦 Found pending character data, spawning player...")
		Net.spawn_local_player(Net.pending_character_data)
		Net.pending_character_data = {}  # Clear it
	else:
		print("⚠️ No pending character data found")
