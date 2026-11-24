extends Control

signal move_changed(value: Vector2)
signal look_changed(relative: Vector2)

var _screen_size := Vector2.ZERO
var _move_id := -1
var _look_id := -1
var _move_value := Vector2.ZERO
var _stick_origin := Vector2.ZERO
var _stick_radius := 72.0

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    _screen_size = get_viewport_rect().size
    _stick_origin = Vector2(132.0,_screen_size.y-148.0)
    queue_redraw()

func _process(_delta: float) -> void:
    var size := get_viewport_rect().size
    if size != _screen_size:
        _screen_size = size
        _stick_origin = Vector2(132.0,_screen_size.y-148.0)
        queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_down(event.index,event.position)
        else:
            _touch_up(event.index)
    elif event is InputEventScreenDrag:
        if event.index == _move_id:
            var delta := (event.position-_stick_origin)/_stick_radius
            _move_value = delta.limit_length(1.0)
            move_changed.emit(_move_value)
            queue_redraw()
        elif event.index == _look_id:
            look_changed.emit(event.relative)

func _touch_down(index: int,position: Vector2) -> void:
    if position.x < _screen_size.x*0.38 and position.y > _screen_size.y*0.43 and _move_id == -1:
        if _is_run_button(position):
            return
        _move_id = index
        _move_value = ((position-_stick_origin)/_stick_radius).limit_length(1.0)
        move_changed.emit(_move_value)
        queue_redraw()
        return
    if position.x > _screen_size.x*0.40 and _look_id == -1 and not _is_action_button(position):
        _look_id = index

func _touch_up(index: int) -> void:
    if index == _move_id:
        _move_id = -1
        _move_value = Vector2.ZERO
        move_changed.emit(Vector2.ZERO)
        queue_redraw()
    if index == _look_id:
        _look_id = -1

func _is_run_button(p: Vector2) -> bool:
    return Rect2(_screen_size.x*0.025,_screen_size.y*0.62,_screen_size.x*0.13,_screen_size.y*0.15).has_point(p)

func _is_action_button(p: Vector2) -> bool:
    var rects := [
        Rect2(Vector2(_screen_size.x*0.84,_screen_size.y*0.74),Vector2(_screen_size.x*0.14,_screen_size.y*0.19)),
        Rect2(Vector2(_screen_size.x*0.72,_screen_size.y*0.82),Vector2(_screen_size.x*0.12,_screen_size.y*0.15)),
        Rect2(Vector2(_screen_size.x*0.86,_screen_size.y*0.56),Vector2(_screen_size.x*0.12,_screen_size.y*0.15)),
        Rect2(Vector2(_screen_size.x*0.70,_screen_size.y*0.57),Vector2(_screen_size.x*0.13,_screen_size.y*0.16)),
        Rect2(Vector2(_screen_size.x*0.58,_screen_size.y*0.79),Vector2(_screen_size.x*0.12,_screen_size.y*0.15)),
        Rect2(Vector2(_screen_size.x*0.86,_screen_size.y*0.39),Vector2(_screen_size.x*0.12,_screen_size.y*0.15)),
        Rect2(Vector2(_screen_size.x*0.91,_screen_size.y*0.025),Vector2(_screen_size.x*0.07,_screen_size.y*0.12))
    ]
    for rect in rects:
        if rect.has_point(p):
            return true
    return false

func _draw() -> void:
    if _screen_size == Vector2.ZERO:
        return
    draw_circle(_stick_origin,_stick_radius+8.0,Color(0.018,0.03,0.055,0.34))
    draw_arc(_stick_origin,_stick_radius+8.0,0,TAU,64,Color(0.85,0.9,0.98,0.66),3.0,true)
    draw_arc(_stick_origin,_stick_radius*0.52,0,TAU,64,Color(0.85,0.9,0.98,0.22),2.0,true)
    var knob := _stick_origin + _move_value*_stick_radius*0.52
    draw_circle(knob,30.0,Color(0.56,0.63,0.74,0.34))
    draw_arc(knob,30.0,0,TAU,48,Color("#ff3859"),2.5,true)
