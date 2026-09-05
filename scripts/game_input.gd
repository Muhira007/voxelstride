extends RefCounted

static func setup() -> void:
	_bind("move_forward", [KEY_W], [], JOY_AXIS_LEFT_Y, -1)
	_bind("move_back", [KEY_S], [], JOY_AXIS_LEFT_Y, 1)
	_bind("move_left", [KEY_A], [], JOY_AXIS_LEFT_X, -1)
	_bind("move_right", [KEY_D], [], JOY_AXIS_LEFT_X, 1)
	_bind("look_left", [], [], JOY_AXIS_RIGHT_X, -1)
	_bind("look_right", [], [], JOY_AXIS_RIGHT_X, 1)
	_bind("look_up", [], [], JOY_AXIS_RIGHT_Y, -1)
	_bind("look_down", [], [], JOY_AXIS_RIGHT_Y, 1)
	_bind("jump", [KEY_SPACE], [JOY_BUTTON_A])
	_bind("crouch", [KEY_CTRL], [JOY_BUTTON_B])
	_bind("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK])
	_bind("inventory", [KEY_E], [JOY_BUTTON_Y])
	_bind("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	_bind("next_block", [KEY_BRACKETRIGHT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN])
	_bind("previous_block", [KEY_BRACKETLEFT], [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP])
	_bind("break_block", [], [], JOY_AXIS_TRIGGER_RIGHT, 1)
	_bind("place_block", [], [], JOY_AXIS_TRIGGER_LEFT, 1)
	_bind("save_world", [KEY_F5], [JOY_BUTTON_BACK])
	_bind("fullscreen", [KEY_F11], [])
	_mouse("break_block", MOUSE_BUTTON_LEFT)
	_mouse("place_block", MOUSE_BUTTON_RIGHT)
	_mouse("next_block", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("previous_block", MOUSE_BUTTON_WHEEL_UP)

static func _bind(action: String, keys: Array, buttons: Array, axis: int = -1, axis_value: float = 0) -> void:
	if InputMap.has_action(action): InputMap.erase_action(action)
	InputMap.add_action(action, 0.22 if axis < JOY_AXIS_TRIGGER_LEFT else 0.35)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
	if axis >= 0:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = axis_value
		InputMap.action_add_event(action, event)

static func _mouse(action: String, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
