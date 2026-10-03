extends Node
## Autoload "Platform": what are we running on?
##   Platform.is_touch   - true on phones / tablets (touch controls are shown only then)
##   Platform.is_web     - true in the HTML5 export
##   Platform.toggle_fullscreen()
##
## Testing touch controls on a PC:
##   - web build:  open index.html?touch=1   (use ?touch=0 to force them off)
##   - editor/desktop: run with the user argument  -- --touch
## A normal PC never shows them.

var is_web: bool = false
var is_touch: bool = false

var _rotate_layer: CanvasLayer
var _rotate_shown: bool = false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    is_web = OS.has_feature("web")
    is_touch = _detect_touch()
    if is_touch:
        _build_rotate_overlay()
        get_window().size_changed.connect(_check_orientation)
        _check_orientation()


func _unhandled_input(event: InputEvent) -> void:
    # F11 = fullscreen on desktop and in the browser
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
        toggle_fullscreen()


func _detect_touch() -> bool:
    if "--touch" in OS.get_cmdline_user_args():
        return true
    if is_web:
        # explicit override from the URL: ?touch=1 / ?touch=0
        var forced = JavaScriptBridge.eval("(function(){var p=new URLSearchParams(window.location.search).get('touch');return p===null?'':p;})()", true)
        if str(forced) == "1":
            return true
        if str(forced) == "0":
            return false
        if OS.has_feature("web_android") or OS.has_feature("web_ios"):
            return true
        # the PRIMARY pointer is a finger (phones, tablets); a laptop with a touch screen
        # still has a mouse / trackpad as primary pointer, so it does not get the overlay
        var coarse = JavaScriptBridge.eval("(window.matchMedia && window.matchMedia('(pointer: coarse)').matches) ? 1 : 0", true)
        return int(coarse) == 1
    return OS.has_feature("android") or OS.has_feature("ios")


func toggle_fullscreen() -> void:
    var mode: int = DisplayServer.window_get_mode()
    if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func is_fullscreen() -> bool:
    var mode: int = DisplayServer.window_get_mode()
    return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# ---------------------------------------------------- "rotate your device"
# The game is a 16:9 landscape game: in portrait it would shrink to a thin strip,
# so on touch devices we ask the player to turn the phone and pause until they do.

func _build_rotate_overlay() -> void:
    # layout + art: UI/RotateDevice.tscn
    _rotate_layer = (load("res://UI/RotateDevice.tscn") as PackedScene).instantiate()
    add_child(_rotate_layer)


func _check_orientation() -> void:
    var s: Vector2i = DisplayServer.window_get_size()
    var portrait: bool = s.y > s.x
    if portrait == _rotate_shown:
        return
    _rotate_shown = portrait
    _rotate_layer.visible = portrait
    get_tree().paused = portrait
