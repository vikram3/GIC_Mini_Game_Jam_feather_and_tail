@tool
extends HBoxContainer
## One labelled volume slider (Label + HSlider). Set `key` (master / music / sfx) and `label_text`
## on the scene instance. The slider's look comes from UI/GardenTheme.tres (Art/Common/slider_*.png).

@export var key: String = "master"
@export var label_text: String = "Volume":
    set(v):
        label_text = v
        _refresh()


func _ready() -> void:
    _refresh()
    if Engine.is_editor_hint():
        return
    var slider: HSlider = %Slider
    slider.value = PlayerData.get_volume(key)
    slider.value_changed.connect(_on_changed)
    slider.drag_ended.connect(_on_drag_ended)


func _refresh() -> void:
    if is_node_ready():
        %Label.text = label_text


func _on_changed(v: float) -> void:
    PlayerData.set_volume(key, v)
    Sound.apply_volumes()


func _on_drag_ended(_changed: bool) -> void:
    Sound.play("ui_click", 0.6)
