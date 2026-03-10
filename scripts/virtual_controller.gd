extends Control

@onready var base: Control = $Base
@onready var stick: Control = $Base/Stick

var touch_index: int = -1
var max_dist: float = 80.0
var dead_zone: float = 20.0
var is_dragging: bool = false

func _input(event: InputEvent) -> void:
	# --- TOUCH ---
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			if get_global_rect().has_point(event.position):
				touch_index = event.index
		elif not event.pressed and event.index == touch_index:
			touch_index = -1
			_reset()

	elif event is InputEventScreenDrag and event.index == touch_index:
		_update(event.position)

	# --- MOUSE (editor/desktop testing) ---
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_global_rect().has_point(event.position):
				is_dragging = true
		else:
			is_dragging = false
			_reset()

	elif event is InputEventMouseMotion and is_dragging:
		_update(event.position)

func _update(pos: Vector2) -> void:
	var center = base.global_position + base.size / 2.0
	var offset = (pos - center).limit_length(max_dist)
	stick.position = base.size / 2.0 - stick.size / 2.0 + offset
	var dir = offset.normalized() if offset.length() > dead_zone else Vector2.ZERO
	_fire("ui_left",  dir.x < -0.3)
	_fire("ui_right", dir.x >  0.3)
	_fire("ui_up",    dir.y < -0.3)
	_fire("ui_down",  dir.y >  0.3)

func _reset() -> void:
	stick.position = base.size / 2.0 - stick.size / 2.0
	_fire("ui_left", false);  _fire("ui_right", false)
	_fire("ui_up",   false);  _fire("ui_down",  false)
	is_dragging = false

func _fire(action: String, pressed: bool) -> void:
	var ev = InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
