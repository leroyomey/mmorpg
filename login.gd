extends Control

@onready var username_input: LineEdit = $CenterContainer/VBoxContainer/VBoxContainer/usernameInput
@onready var password_input: LineEdit = $CenterContainer/VBoxContainer/VBoxContainer/passwordInput
@onready var login_button: Button   = $CenterContainer/VBoxContainer/loginButton
@onready var status_label: Label    = $CenterContainer/VBoxContainer/statusLabel

func _ready() -> void:
	# Wire UI events
	login_button.pressed.connect(_on_login_button_pressed)
	password_input.text_submitted.connect(_on_password_submitted)

	# Wire Net signals (these MUST be connected or your handlers won’t run)
	Net.connection_state_changed.connect(_on_net_state)
	Net.login_success.connect(_on_login_success)
	Net.login_failed.connect(_on_login_failed)
	Net.character_loaded.connect(_on_character_loaded)

	# Connect and gate UI
	login_button.disabled = true
	status_label.text = "🔌 Connecting..."
	Net.connect_to_server("ws://127.0.0.1:8000/ws")

func _on_net_state(_is_connected: bool) -> void:
	if is_connected:
		status_label.text = "✅ Connected. Please log in."
		login_button.disabled = false
	else:
		status_label.text = "❌ Disconnected. Reconnecting..."
		login_button.disabled = true

func _on_login_button_pressed() -> void:
	if not Net.connected:
		status_label.text = "⏳ Still connecting..."
		return
	status_label.text = "Logging in..."
	login_button.disabled = true
	Net.login(username_input.text.strip_edges(), password_input.text)

func _on_password_submitted(_text: String) -> void:
	_attempt_login()

func _attempt_login() -> void:
	var username = username_input.text.strip_edges()
	var password = password_input.text

	if username.is_empty():
		status_label.text = "❌ Please enter a username"
		return
	if password.is_empty():
		status_label.text = "❌ Please enter a password"
		return

	# Don’t fire if socket isn’t open yet
	if not Net.connected:
		status_label.text = "⏳ Still connecting... try again in a sec."
		return

	login_button.disabled = true
	status_label.text = "Logging in..."
	Net.login(username, password)  # uses the Net singleton

func _on_login_success(account_data: Dictionary) -> void:
	status_label.text = "✅ Login successful!"
	
	var _characters = account_data.get("characters", [])
	
	# Store account data in Net for the character selection screen
	Net.account_data = account_data
	
	# Change to character selection screen
	get_tree().change_scene_to_file("res://character_select.tscn")

func _on_login_failed(reason: String) -> void:
	status_label.text = "❌ Login failed: " + reason
	login_button.disabled = false
	password_input.text = ""
	password_input.grab_focus()

func _on_character_loaded(character_data: Dictionary) -> void:
	status_label.text = "✅ Character loaded! Entering world..."
	
	# Store character data in Net for after scene change
	Net.pending_character_data = character_data
	
	# Change scene (this will remove login.gd from tree)
	get_tree().change_scene_to_file("res://world.tscn")

func _await_net_open(timeout: float = 5.0) -> void:
	var t := 0.0
	while t < timeout and not Net.connected:
		await get_tree().process_frame
		t += get_process_delta_time()

func set_status(message: String, color: Color = Color.YELLOW) -> void:
	status_label.text = message
	status_label.modulate = color
