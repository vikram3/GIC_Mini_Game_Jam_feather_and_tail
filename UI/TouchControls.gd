extends Control
## On-screen touch controls (phones / tablets only). Layout + art: UI/TouchControls.tscn
##   Joystick (Base + Knob)   Buttons/*  (UI/Components/TouchButton.tscn instances - move / resize / re-skin them)
##   JoyZone                  the area where a thumb may start the joystick
## Everything is translated into the SAME input actions the keyboard uses, so Game.gd needs no touch code
## apart from touch_tap(). Multi-touch works: steer with one thumb while holding CUT with the other.

const JOY_RADIUS := 78.0
const JOY_DEFAULT := Vector2(150, 570)
const DEAD := 0.18
const FULL := 0.70
const TAP_MAX_MOVE := 26.0
const TAP_MAX_MS := 450

var game: Node2D
var enabled: bool = true

var joy_id: int = -1
var joy_origin: Vector2 = JOY_DEFAULT
var joy_vec: Vector2 = Vector2.ZERO

var buttons: Array = []
var finger_btn: Dictionary = {}     # touch index -> TouchButton
var taps: Dictionary = {}
var sneak_on: bool = false
var _held_move: Dictionary = {}
var _joy_zone: Rect2


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    for b in %Buttons.get_children():
        buttons.append(b)
    _joy_zone = Rect2(%JoyZone.position, %JoyZone.size)
    _update_joystick()


func set_active(on: bool) -> void:
    if on == enabled:
        return
    enabled = on
    visible = on and Platform.is_touch
    if not on:
        _release_all()


func _notification(what: int) -> void:
    if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _release_all()


func _process(_delta: float) -> void:
    if game == null or not enabled:
        return
    var down_buttons: Array = finger_btn.values()
    for b in buttons:
        b.visible = _btn_visible(b)
        b.set_down(down_buttons.has(b) or (b.mode == "toggle" and sneak_on))
        if b.action == "hold_toggle":
            b.set_label("GO" if game.follower_mode == "hold" else b.label_text)


func _btn_visible(b) -> bool:
    if game == null:
        return false
    if b.who != "any" and game.leader.kind != b.who:
        return false
    if b.cond == "goto" and game.follower_mode != "goto":
        return false
    return true


func _hit_button(p: Vector2):
    for b in buttons:
        if not _btn_visible(b):
            continue
        if p.distance_to(b.center()) <= b.radius() + 14.0:
            return b
    return null


func _fire(action: String) -> void:
    var down := InputEventAction.new()
    down.action = action
    down.pressed = true
    Input.parse_input_event(down)
    var up := InputEventAction.new()
    up.action = action
    up.pressed = false
    Input.parse_input_event(up)


func _release_all() -> void:
    for b in finger_btn.values():
        if b.mode == "hold":
            Input.action_release(b.action)
    finger_btn.clear()
    taps.clear()
    joy_id = -1
    joy_vec = Vector2.ZERO
    _apply_move()
    Input.action_release("cut")
    Input.action_release("disarm")
    _update_joystick()


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _on_touch(event)
    elif event is InputEventScreenDrag:
        _on_drag(event)
    elif enabled and (event is InputEventMouseButton or event is InputEventMouseMotion):
        # Godot also turns the first finger into a fake mouse click; we handle fingers ourselves.
        if event.device == InputEvent.DEVICE_ID_EMULATION:
            get_viewport().set_input_as_handled()


func _joy_limits() -> Rect2:
    var lo := Vector2(JOY_RADIUS + 12.0, _joy_zone.position.y + JOY_RADIUS)
    var hi := Vector2(_joy_zone.end.x - JOY_RADIUS, 720.0 - JOY_RADIUS - 12.0)
    return Rect2(lo, hi - lo)


func _on_touch(ev: InputEventScreenTouch) -> void:
    var idx: int = ev.index
    if ev.pressed:
        if not enabled:
            return
        var b = _hit_button(ev.position)
        if b != null:
            _press_button(b, idx)
            get_viewport().set_input_as_handled()
        elif joy_id == -1 and _joy_zone.has_point(ev.position):
            joy_id = idx
            var lim: Rect2 = _joy_limits()
            joy_origin = ev.position.clamp(lim.position, lim.end)
            joy_vec = Vector2.ZERO
            _apply_move()
            _update_joystick()
            get_viewport().set_input_as_handled()
        else:
            taps[idx] = {"pos": ev.position, "t": Time.get_ticks_msec()}
    else:
        if finger_btn.has(idx):
            _release_button(idx)
        if idx == joy_id:
            joy_id = -1
            joy_vec = Vector2.ZERO
            _apply_move()
            _update_joystick()
        if taps.has(idx):
            var t: Dictionary = taps[idx]
            taps.erase(idx)
            var quick: bool = Time.get_ticks_msec() - int(t["t"]) <= TAP_MAX_MS
            if enabled and quick and ev.position.distance_to(t["pos"]) <= TAP_MAX_MOVE and game != null:
                game.touch_tap(ev.position)


func _on_drag(ev: InputEventScreenDrag) -> void:
    if ev.index == joy_id:
        var d: Vector2 = ev.position - joy_origin
        if d.length() > JOY_RADIUS:
            joy_origin += d - d.normalized() * JOY_RADIUS
            var lim: Rect2 = _joy_limits()
            joy_origin = joy_origin.clamp(lim.position, lim.end)
            d = ev.position - joy_origin
        joy_vec = (d / JOY_RADIUS).limit_length(1.0)
        _apply_move()
        _update_joystick()
        get_viewport().set_input_as_handled()
    elif taps.has(ev.index):
        if ev.position.distance_to(taps[ev.index]["pos"]) > TAP_MAX_MOVE:
            taps.erase(ev.index)


func _press_button(b, idx: int) -> void:
    finger_btn[idx] = b
    match b.mode:
        "hold":
            Input.action_press(b.action)
        "toggle":
            sneak_on = not sneak_on
            if sneak_on:
                Input.action_press(b.action)
            else:
                Input.action_release(b.action)
        _:
            _fire(b.action)


func _release_button(idx: int) -> void:
    var b = finger_btn[idx]
    finger_btn.erase(idx)
    if b.mode == "hold":
        Input.action_release(b.action)


func _apply_move() -> void:
    var m: float = joy_vec.length()
    var d := Vector2.ZERO
    if m > DEAD:
        d = joy_vec.normalized() * clampf((m - DEAD) / (FULL - DEAD), 0.0, 1.0)
    _set_axis("move_left", maxf(-d.x, 0.0))
    _set_axis("move_right", maxf(d.x, 0.0))
    _set_axis("move_up", maxf(-d.y, 0.0))
    _set_axis("move_down", maxf(d.y, 0.0))


func _set_axis(action: String, strength: float) -> void:
    if strength > 0.01:
        Input.action_press(action, strength)
        _held_move[action] = true
    elif _held_move.has(action):
        Input.action_release(action)
        _held_move.erase(action)


## Moves the Joystick art (Base follows the thumb, Knob leans toward it). Faint when idle.
func _update_joystick() -> void:
    var active: bool = joy_id != -1
    var base: Vector2 = joy_origin if active else JOY_DEFAULT
    %Joystick.position = base - %Joystick.size * 0.5
    %Joystick.modulate.a = 1.0 if active else 0.55
    var knob_c: Vector2 = %Joystick.size * 0.5 + joy_vec * JOY_RADIUS
    %Knob.position = knob_c - %Knob.size * 0.5
