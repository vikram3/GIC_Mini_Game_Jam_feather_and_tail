@tool
extends HBoxContainer
## A keyboard hint: [ key cap ] description.  Set `key_text` / `desc_text` on the instance.
## The cap's art is `Art/Common/panel_keycap.png` (theme variation KeyCapPanel).

@export var key_text: String = "Key":
    set(v):
        key_text = v
        _refresh()
@export var desc_text: String = "action":
    set(v):
        desc_text = v
        _refresh()


func _ready() -> void:
    _refresh()


func _refresh() -> void:
    if is_node_ready():
        %KeyLabel.text = key_text
        %Desc.text = desc_text
