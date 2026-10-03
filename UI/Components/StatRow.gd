@tool
extends HBoxContainer
## One line of the win screen:  [icon]  Name ..................... value

@export var icon: Texture2D:
    set(v):
        icon = v
        _refresh()
@export var label_text: String = "Stat":
    set(v):
        label_text = v
        _refresh()
@export var value_text: String = "0":
    set(v):
        value_text = v
        _refresh()


func _ready() -> void:
    _refresh()


func _refresh() -> void:
    if not is_node_ready():
        return
    %Icon.texture = icon
    %Icon.visible = icon != null
    %Name.text = label_text
    %Value.text = value_text
