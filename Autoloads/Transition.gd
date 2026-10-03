extends CanvasLayer
## Autoload "Transition" (Autoloads/Transition.tscn): fades to black, swaps the scene, fades back in.
##   Transition.go("res://Game/Game.tscn")
##   Transition.reload()          # restart the current scene
## The black rectangle is the `Fade` node - give it a TextureRect / loading art instead if you like.

@onready var rect: CanvasItem = %Fade
var busy: bool = false


func _ready() -> void:
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
