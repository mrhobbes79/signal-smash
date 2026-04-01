extends Node
## InputManager — Autoload for controller detection and player assignment.
## Detects connected gamepads and assigns them to player slots.
## Supports hot-plug (connect/disconnect during gameplay).

signal controller_connected(device_id: int, player_slot: int)
signal controller_disconnected(device_id: int, player_slot: int)

## Player slots: { slot_index: device_id } — -1 = keyboard, 0+ = gamepad
var player_devices: Dictionary = {
	0: -1,   # P1: keyboard by default
	1: -1,   # P2: keyboard (arrows) by default
	2: -1,   # P3: unassigned
	3: -1,   # P4: unassigned
}

var _connected_joypads: Array[int] = []

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Scan already-connected controllers
	_scan_controllers()
	print("[INPUT] InputManager initialized. Controllers: %d" % _connected_joypads.size())

func _scan_controllers() -> void:
	_connected_joypads.clear()
	for device_id in Input.get_connected_joypads():
		_connected_joypads.append(device_id)
		_auto_assign(device_id)
	_print_assignments()

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		print("[INPUT] Controller connected: device %d — %s" % [device_id, Input.get_joy_name(device_id)])
		if device_id not in _connected_joypads:
			_connected_joypads.append(device_id)
		_auto_assign(device_id)
	else:
		print("[INPUT] Controller disconnected: device %d" % device_id)
		_connected_joypads.erase(device_id)
		_unassign(device_id)
	_print_assignments()

func _auto_assign(device_id: int) -> void:
	# Skip if this device is already assigned to a slot
	for slot in range(4):
		if player_devices[slot] == device_id:
			return
	# Find first empty slot (or keyboard-only slot after P1)
	for slot in range(4):
		if player_devices[slot] == -1 and slot > 0:
			# Assign gamepad to this slot
			player_devices[slot] = device_id
			controller_connected.emit(device_id, slot)
			print("[INPUT] Assigned device %d to P%d" % [device_id, slot + 1])
			return
	# If P1 has no gamepad yet, assign to P1
	if player_devices[0] == -1:
		# Keep P1 on keyboard — gamepads go to P2+
		pass

func _unassign(device_id: int) -> void:
	for slot in range(4):
		if player_devices[slot] == device_id:
			player_devices[slot] = -1
			controller_disconnected.emit(device_id, slot)
			print("[INPUT] Unassigned device %d from P%d" % [device_id, slot + 1])

func assign_device(slot: int, device_id: int) -> void:
	if slot >= 0 and slot < 4:
		player_devices[slot] = device_id
		print("[INPUT] Manual assign: device %d → P%d" % [device_id, slot + 1])

func get_device(slot: int) -> int:
	return player_devices.get(slot, -1)

func get_connected_count() -> int:
	return _connected_joypads.size()

func get_controller_name(device_id: int) -> String:
	if device_id < 0:
		return "Keyboard"
	return Input.get_joy_name(device_id)

func _print_assignments() -> void:
	for slot in range(4):
		var dev: int = player_devices[slot]
		var name: String = "Keyboard" if dev < 0 else Input.get_joy_name(dev)
		print("[INPUT]   P%d → %s (device %d)" % [slot + 1, name, dev])
