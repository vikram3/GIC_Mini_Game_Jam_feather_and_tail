extends CanvasLayer
## Autoload "Transition": fades to black, swaps the scene, fades back in.
##   Transition.go("res://Game/Game.tscn")
##   Transition.reload()          # restart the current scene

var rect: ColorRect
var busy: bool = false


func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    rect = ColorRect.new()
    rect.color = Color(0.03, 0.07, 0.05, 1.0)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(rect)
    rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    rect.modulate.a = 1.0          # start black, fade the title screen in
    _fade_to(0.0, 0.6)


func go(path: String) -> void:
    if busy:
        return
    busy = true
    rect.mouse_filter = Control.MOUSE_FILTER_STOP
    await _fade_to(1.0, 0.22)
    get_tree().change_scene_to_file(path)
    await _after_swap()


func reload() -> void:
    if busy:
        return
    busy = true
    rect.mouse_filter = Control.MOUSE_FILTER_STOP
    await _fade_to(1.0, 0.18)
    get_tree().reload_current_scene()
    await _after_swap()


func _after_swap() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    await _fade_to(0.0, 0.3)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    busy = false


func _fade_to(a: float, secs: float) -> void:
    var tw: Tween = create_tween()
    tw.tween_property(rect, "modulate:a", a, secs)
    await tw.finished
