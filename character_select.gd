extends Control

const _DOUBLE_CLICK_WINDOW := 0.35

@onready var character_list: VBoxContainer = $CenterContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var create_button: Button = $CenterContainer/VBoxContainer/HBoxContainer/CreateButton
@onready var delete_button: Button = $CenterContainer/VBoxContainer/HBoxContainer/DeleteButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var root_box: VBoxContainer = $CenterContainer/VBoxContainer
@onready var sc: ScrollContainer = $CenterContainer/VBoxContainer/ScrollContainer

var characters: Array = []
var selected_character: Dictionary = {}
var account_data: Dictionary = {}

# Add near top:
var _last_selected_id: String = ""
var _last_click_time := 0.0

const MAX_CHARACTERS: int = 2

func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	delete_button.disabled = true

	# Signals you actually need here
	if not Net.is_connected("character_loaded", Callable(self, "_on_character_loaded")):
		Net.character_loaded.connect(_on_character_loaded)

	# NEW: if your backend can push a fresh list, listen to it here.
	# Rename 'character_list_received' to whatever your Net emits.
	if Net.has_signal("character_list_received"):
		if not Net.is_connected("character_list_received", Callable(self, "_on_character_list_received")):
			Net.character_list_received.connect(_on_character_list_received)

	await get_tree().process_frame

	if Net.account_data.is_empty():
		push_error("No account data available!")
		status_label.text = "❌ Error: No account data"
		return

	# Make containers expand to fill
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal       = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical         = Control.SIZE_EXPAND_FILL
	character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_list.size_flags_vertical   = Control.SIZE_EXPAND_FILL

# CenterContainer sizes children to their *minimum*. Give the inner VBox a sane minimum.
	root_box.custom_minimum_size = Vector2(520, 360)


	setup(Net.account_data)

func setup(account_info: Dictionary) -> void:
	account_data = account_info
	var raw_chars = account_info.get("characters", account_info.get("Chars", account_info.get("Characters", [])))
	if typeof(raw_chars) != TYPE_ARRAY:
		raw_chars = []
	characters = _normalize_chars(raw_chars)

	print("📋 Character selection for: ", str(account_data.get("username", account_data.get("email", "unknown"))))
	print("   Server gave ", raw_chars.size(), " raw entries -> ", characters.size(), " normalized.")
	print("   First entry sample: ", JSON.stringify(characters[0]) if characters.size() > 0 else "[]")

	_populate_character_list()

# Normalize server dictionaries to a stable shape we use everywhere.
func _normalize_chars(raw: Array) -> Array:
	var out: Array = []
	for c in raw:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var id    = str(c.get("id", c.get("character_id", c.get("uuid", ""))))
		var _name  = str(c.get("name", c.get("character_name", "Unknown")))
		var clazz = str(c.get("class", c.get("clazz", c.get("archetype", "warrior"))))
		var level = int(c.get("level", c.get("lvl", 1)))
		out.append({
			"id": id,
			"name": name,
			"class": clazz,
			"level": level,
		})
	return out

func _populate_character_list() -> void:
	# Clear existing buttons
	for child in character_list.get_children():
		child.queue_free()
	
	if characters.size() == 0:
		var label = Label.new()
		label.text = "No characters found. Create one to begin!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		character_list.add_child(label)
		create_button.grab_focus()
		return
	
	# Create button for each character
	for char in characters:
		var button = Button.new()
		button.custom_minimum_size = Vector2(400, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # <-- add this
		
		var char_name = char.get("name", "Unknown")
		var char_class = char.get("class", "warrior")
		var char_level = char.get("level", 1)
		
		button.text = "%s - Level %d %s" % [char_name, char_level, char_class.capitalize()]
		button.pressed.connect(_on_character_selected.bind(char))
		
		character_list.add_child(button)
	
	# Enable/disable create button based on max characters
	create_button.disabled = characters.size() >= MAX_CHARACTERS
	if characters.size() >= MAX_CHARACTERS:
		status_label.text = "Maximum characters reached (%d/%d)" % [characters.size(), MAX_CHARACTERS]

# Single click selects; second click within window enters.
func _on_character_pressed(char: Dictionary) -> void:
	selected_character = char
	delete_button.disabled = false

	var now := Time.get_ticks_msec() / 1000.0
	var this_id := str(char.get("id", ""))
	var is_double := (this_id == _last_selected_id) and (now - _last_click_time <= _DOUBLE_CLICK_WINDOW)
	_last_selected_id = this_id
	_last_click_time = now

	if is_double:
		_enter_world()
	else:
		status_label.text = "Selected: %s — click again to enter, or Delete to remove" % char.get("name", "Unknown")

func _on_character_selected(char: Dictionary) -> void:
	selected_character = char
	delete_button.disabled = false
	
	var char_name = char.get("name", "Unknown")
	status_label.text = "Selected: %s - Click again to enter world or Delete to remove" % char_name
	
	# Double-click to enter world
	if selected_character == char:
		_enter_world()

func _enter_world() -> void:
	if selected_character.is_empty():
		status_label.text = "❌ No character selected"
		return
	var char_id = str(selected_character.get("id", ""))
	if char_id.is_empty():
		status_label.text = "❌ Character has no id (backend bug)"
		push_error("Selected character missing 'id'. Payload: " + JSON.stringify(selected_character))
		return
	status_label.text = "Loading %s..." % selected_character.get("name", "character")
	print("🎮 Entering world with character: ", selected_character.get("name"))
	Net.select_character(char_id)

func _on_character_loaded(character_data: Dictionary) -> void:
	status_label.text = "✅ Entering world..."
	await get_tree().create_timer(0.2).timeout
	Net.pending_character_data = character_data
	get_tree().change_scene_to_file("res://world.tscn")

func _on_create_pressed() -> void:
	var dialog = _create_character_creation_dialog()
	add_child(dialog)
	dialog.popup_centered()

func _on_delete_pressed() -> void:
	if selected_character.is_empty():
		status_label.text = "❌ No character selected"
		return
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Delete %s? This cannot be undone!" % selected_character.get("name", "character")
	dialog.title = "Confirm Delete"
	dialog.confirmed.connect(func():
		_delete_character(str(selected_character.get("id", "")))
	)
	add_child(dialog)
	dialog.popup_centered()

func _create_character_creation_dialog() -> Window:
	var dialog = Window.new()
	dialog.title = "Create New Character"
	dialog.size = Vector2i(400, 300)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(vbox)
	
	# Character name input
	var name_label = Label.new()
	name_label.text = "Character Name:"
	vbox.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.placeholder_text = "Enter name (3-16 characters)"
	name_input.max_length = 16
	vbox.add_child(name_input)
	
	# Class selection
	var class_label = Label.new()
	class_label.text = "Class:"
	vbox.add_child(class_label)
	
	var class_option = OptionButton.new()
	class_option.add_item("Warrior")
	class_option.add_item("Mage")
	class_option.add_item("Rogue")
	class_option.add_item("Priest")
	vbox.add_child(class_option)
	
	# Race selection
	var race_label = Label.new()
	race_label.text = "Race:"
	vbox.add_child(race_label)
	
	var race_option = OptionButton.new()
	race_option.add_item("Human")
	race_option.add_item("Elf")
	race_option.add_item("Orc")
	race_option.add_item("Dwarf")
	vbox.add_child(race_option)
	
	# Buttons
	var button_box = HBoxContainer.new()
	vbox.add_child(button_box)
	
	var create_btn = Button.new()
	create_btn.text = "Create"
	create_btn.pressed.connect(func():
		_create_character(
			name_input.text,
			class_option.get_item_text(class_option.selected).to_lower(),
			race_option.get_item_text(race_option.selected).to_lower()
		)
		dialog.queue_free()
	)
	button_box.add_child(create_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	button_box.add_child(cancel_btn)
	
	return dialog


func _create_character(char_name: String, char_class: String, char_race: String) -> void:
	char_name = char_name.strip_edges()
	if char_name.length() < 3:
		status_label.text = "❌ Name must be at least 3 characters"
		return
	# is_valid_identifier is very strict (first char must be letter/_). If that’s intended, fine;
	# otherwise loosen it: only letters/numbers/underscore and 3–16.
	var name_ok := RegEx.new()
	name_ok.compile("^[A-Za-z0-9_]{3,16}$")
	if not name_ok.search(char_name):
		status_label.text = "❌ Name can only contain letters, numbers, and underscores (3–16)"
		return

	status_label.text = "Creating character..."
	print("🆕 Creating character: ", char_name, " (", char_class, ", ", char_race, ")")

	Net._send_json({
		"t": "create_character",
		"name": char_name,
		"class": char_class,
		"race": char_race
	})

	# Expect the server to answer with a fresh list event.
	if Net.has_signal("character_list_received"):
		status_label.text = "📥 Waiting for server to confirm…"
	else:
		# Fallback: manual refresh if your API supports it.
		if Net.has_method("request_character_list"):
			await get_tree().create_timer(0.2).timeout
			Net.request_character_list()

func _delete_character(char_id: String) -> void:
	if char_id.is_empty():
		status_label.text = "❌ Character missing id"
		return
	status_label.text = "Deleting character..."
	print("🗑️ Deleting character: ", char_id)
	Net._send_json({
		"t": "delete_character",
		"character_id": char_id
	})

	# Expect server to push the updated list; fallback to manual refresh if available.
	if Net.has_signal("character_list_received"):
		status_label.text = "📥 Waiting for server to confirm…"
	else:
		if Net.has_method("request_character_list"):
			await get_tree().create_timer(0.2).timeout
			Net.request_character_list()

# Handler for server-pushed list updates.
func _on_character_list_received(raw_chars: Array) -> void:
	characters = _normalize_chars(raw_chars)
	selected_character = {}
	delete_button.disabled = true
	_populate_character_list()
	status_label.text = "✅ List refreshed (%d)" % characters.size()
