extends Control
## On-screen touch controls. Only created on touch devices (see Platform.is_touch),
## so a PC never sees them.
##
## - Floating joystick: put a thumb anywhere in the bottom-left area to steer.
## - Buttons (bottom-right): context sensitive - MNKI gets CUT / DISARM / SNEAK, Swan gets CHIRP;
##   SWAP, HOLD (follower) and a small pause button are always there.
## - Tap anywhere else in the garden to send the follower to that spot (same as a mouse click).
##
## Everything is translated into the SAME input actions the keyboard uses
## (move_*, cut, disarm, sneak, chirp, switch_leader, hold_toggle, cancel, pause),
## so Game.gd needs no special touch code apart from `touch_tap()`.
## Multi-touch works: steer with one thumb while holding CUT with the other.

const JOY_ZONE := Rect2(0, 230, 500, 490)     # where a thumb may start the joystick
const JOY_RADIUS := 78.0
const JOY_DEFAULT := Vector2(150, 570)         # where the faint idle ring is drawn
const DEAD := 0.18                             # stick dead zone (fraction of radius)
const FULL := 0.70                             # tilt at which full speed is reached
const TAP_MAX_MOVE := 26.0
const TAP_MAX_MS := 450

var game: Node2D
var font: Font
var enabled: bool = true

var joy_id: int = -1
var joy_origin: Vector2 = JOY_DEFAULT
var joy_vec: Vector2 = Vector2.ZERO            # -1..1 per axis, length <= 1

var buttons: Array = []
var finger_btn: Dictionary = {}                # touch index -> button id
var taps: Dictionary = {}                      # touch index -> {pos, t}
var sneak_on: bool = false
var _held_move: Dictionary = {}                # action -> true while WE hold it
var _sig: int = -1


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    font = ThemeDB.fallback_font
    _make_buttons()


func _make_buttons() -> void:
    #            id        centre              r   label     mode      action         leader   cond
    buttons = [
        _b("cut",    Vector2(1160, 590), 56.0, "CUT",    "hold",   "cut",           "mnki", ""),
        _b("chirp",  Vector2(1160, 590), 56.0, "CHIRP",  "tap",    "chirp",         "swan", ""),
        _b("disarm", Vector2(1030, 655), 44.0, "DISARM", "hold",   "disarm",        "mnki", ""),
        _b("sneak",  Vector2(1040, 535), 38.0, "SNEAK",  "toggle", "sneak",         "mnki", ""),
        _b("swap",   Vector2(1195, 450), 40.0, "SWAP",   "tap",    "switch_leader", "any",  ""),
        _b("hold",   Vector2(900, 662),  34.0, "HOLD",   "tap",    "hold_toggle",   "any",  ""),
        _b("cancel", Vector2(900, 592),  30.0, "X",      "tap",    "cancel",        "any",  "goto"),
        _b("pause",  Vector2(939, 33),   22.0, "",       "tap",    "pause",         "any",  ""),
    ]


func _b(id: String, c: Vector2, r: float, label: String, mode: String, action: String, who: String, cond: String) -> Dictionary:
    return {"id": id, "c": c, "r": r, "label": label, "mode": mode, "action": action, "who": who, "cond": cond}


# ------------------------------------------------------------- game hooks

func set_active(on: bool) -> void:
    if on == enabled:
        return
    enabled = on
    visible = on
    if not on:
        _release_all()
    queue_redraw()


func _notification(what: int) -> void:
    # tree paused (portrait warning) or the tab lost focus: never leave an action stuck down
    if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _release_all()


func _process(_delta: float) -> void:
    if game == null or not enabled:
        return
    # cheap change detection: redraw only when what the buttons show has changed
    var s: int = hash([game.leader.kind, game.follower_mode, sneak_on, finger_btn.size(), joy_id])
    if s != _sig:
        _sig = s
        queue_redraw()


# --------------------------------------------------------------- helpers

func _btn_visible(b: Dictionary) -> bool:
    if game == null:
        return false
    if b["who"] != "any" and game.leader.kind != b["who"]:
        return false
    if b["cond"] == "goto" and game.follower_mode != "goto":
        return false
    return true


func _hit_button(p: Vector2) -> Dictionary:
    for b in buttons:
        if not _btn_visible(b):
            continue
        if p.distance_to(b["c"]) <= float(b["r"]) + 14.0:     # generous finger-sized target
            return b
    return {}


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
    for id in finger_btn.values():
        var b: Dictionary = _by_id(id)
        if not b.is_empty() and b["mode"] == "hold":
            Input.action_release(b["action"])
    finger_btn.clear()
    taps.clear()
    joy_id = -1
    joy_vec = Vector2.ZERO
    _apply_move()
    Input.action_release("cut")
    Input.action_release("disarm")
    queue_redraw()


func _by_id(id: String) -> Dictionary:
    for b in buttons:
        if b["id"] == id:
            return b
    return {}


# ----------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _on_touch(event)
    elif event is InputEventScreenDrag:
        _on_drag(event)
    elif enabled and (event is InputEventMouseButton or event is InputEventMouseMotion):
        # Godot also turns the first finger into a fake mouse click. We handle fingers ourselves,
        # so swallow the fake one - otherwise every thumb press would also command the follower.
        if event.device == InputEvent.DEVICE_ID_EMULATION:
            get_viewport().set_input_as_handled()


func _on_touch(ev: InputEventScreenTouch) -> void:
    var idx: int = ev.index
    if ev.pressed:
        if not enabled:
            return
        var b: Dictionary = _hit_button(ev.position)
        if not b.is_empty():
            _press_button(b, idx)
            get_viewport().set_input_as_handled()
        elif joy_id == -1 and JOY_ZONE.has_point(ev.position):
            joy_id = idx
            var lo := Vector2(JOY_RADIUS + 12.0, JOY_ZONE.position.y + JOY_RADIUS)
            var hi := Vector2(JOY_ZONE.end.x - JOY_RADIUS, 720.0 - JOY_RADIUS - 12.0)
            joy_origin = ev.position.clamp(lo, hi)
            joy_vec = Vector2.ZERO
            _apply_move()
            queue_redraw()
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
            queue_redraw()
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
            # drag the base along so the thumb never has to travel back across the stick
            joy_origin += d - d.normalized() * JOY_RADIUS
            joy_origin = joy_origin.clamp(Vector2(JOY_RADIUS + 12.0, JOY_ZONE.position.y + JOY_RADIUS), Vector2(JOY_ZONE.end.x - JOY_RADIUS, 720.0 - JOY_RADIUS - 12.0))
            d = ev.position - joy_origin
        joy_vec = (d / JOY_RADIUS).limit_length(1.0)
        _apply_move()
        queue_redraw()
        get_viewport().set_input_as_handled()
    elif taps.has(ev.index):
        # a finger that moves far is a swipe, not a tap
        if ev.position.distance_to(taps[ev.index]["pos"]) > TAP_MAX_MOVE:
            taps.erase(ev.index)


func _press_button(b: Dictionary, idx: int) -> void:
    finger_btn[idx] = b["id"]
    match b["mode"]:
        "hold":
            Input.action_press(b["action"])
        "toggle":
            sneak_on = not sneak_on
            if sneak_on:
                Input.action_press(b["action"])
            else:
                Input.action_release(b["action"])
        _:
            _fire(b["action"])
    queue_redraw()


func _release_button(idx: int) -> void:
    var b: Dictionary = _by_id(finger_btn[idx])
    finger_btn.erase(idx)
    if not b.is_empty() and b["mode"] == "hold":
        Input.action_release(b["action"])
    queue_redraw()


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


# ------------------------------------------------------------------ draw

func _draw() -> void:
    if game == null or not enabled:
        return
    var active: bool = joy_id != -1
    var base: Vector2 = joy_origin if active else JOY_DEFAULT
    var a: float = 1.0 if active else 0.55
    draw_circle(base, JOY_RADIUS, Color(0.05, 0.13, 0.10, 0.30 * a))
    draw_arc(base, JOY_RADIUS, 0.0, TAU, 48, Color(0.75, 0.92, 0.78, 0.55 * a), 3.0, true)
    var knob: Vector2 = base + joy_vec * JOY_RADIUS
    draw_circle(knob, 36.0, Color(0.97, 0.92, 0.72, 0.35 + 0.25 * a))
    draw_arc(knob, 36.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.35, 0.8 * a), 2.5, true)

    var down_ids: Array = finger_btn.values()
    for b in buttons:
        if not _btn_visible(b):
            continue
        var c: Vector2 = b["c"]
        var r: float = float(b["r"])
        var down: bool = down_ids.has(b["id"]) or (b["mode"] == "toggle" and sneak_on)
        var fill := Color(0.17, 0.40, 0.25, 0.62) if not down else Color(0.95, 0.80, 0.30, 0.80)
        var edge := Color(0.55, 0.85, 0.60, 0.85) if not down else Color(1.0, 0.95, 0.6, 1.0)
        draw_circle(c, r, fill)
        draw_arc(c, r, 0.0, TAU, 40, edge, 3.0, true)
        var txt_col := Color(1.0, 0.96, 0.84) if not down else Color(0.15, 0.10, 0.02)
        if b["id"] == "pause":
            draw_rect(Rect2(c + Vector2(-8, -9), Vector2(5, 18)), txt_col)
            draw_rect(Rect2(c + Vector2(3, -9), Vector2(5, 18)), txt_col)
            continue
        var label: String = b["label"]
        if b["id"] == "hold" and game.follower_mode == "hold":
            label = "GO"
        var fs: int = 20 if r >= 50.0 else (16 if r >= 36.0 else 14)
        draw_string(font, Vector2(c.x - r, c.y + float(fs) * 0.36) + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(0, 0, 0, 0.5))
        draw_string(font, Vector2(c.x - r, c.y + float(fs) * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, txt_col)
