extends Control

signal changed(value: Vector2)

var value := Vector2.ZERO
var radius := 70.0
var knob_radius := 28.0
var active_pointer := -1
var center := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	center = size * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		center = size * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_pointer == -1:
			active_pointer = event.index
			_update_value(event.position)
		elif not event.pressed and event.index == active_pointer:
			active_pointer = -1
			_set_value(Vector2.ZERO)
	elif event is InputEventScreenDrag and event.index == active_pointer:
		_update_value(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			active_pointer = -2
			_update_value(event.position)
		elif active_pointer == -2:
			active_pointer = -1
			_set_value(Vector2.ZERO)
	elif event is InputEventMouseMotion and active_pointer == -2:
		_update_value(event.position)

func _update_value(pointer_position: Vector2) -> void:
	var offset := pointer_position - center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_set_value(offset / radius)

func _set_value(next_value: Vector2) -> void:
	value = next_value.limit_length(1.0)
	changed.emit(value)
	queue_redraw()

func _draw() -> void:
	center = size * 0.5
	radius = minf(size.x, size.y) * 0.36
	knob_radius = radius * 0.38
	draw_circle(center, radius + 8.0, Color(0.02, 0.06, 0.11, 0.55))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.24, 0.75, 0.86, 0.35), 2.0, true)
	draw_arc(center, radius * 0.55, 0.0, TAU, 48, Color(0.24, 0.75, 0.86, 0.13), 1.0, true)
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), Color(0.24, 0.75, 0.86, 0.10), 1.0)
	draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), Color(0.24, 0.75, 0.86, 0.10), 1.0)
	var knob := center + value * radius
	draw_circle(knob, knob_radius + 5.0, Color(0.12, 0.65, 0.78, 0.12))
	draw_circle(knob, knob_radius, Color(0.10, 0.32, 0.43, 0.88))
	draw_arc(knob, knob_radius, 0.0, TAU, 40, Color(0.44, 0.94, 1.0, 0.75), 2.0, true)
