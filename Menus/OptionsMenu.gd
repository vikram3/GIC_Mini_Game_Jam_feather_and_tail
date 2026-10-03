extends Control
## Title-screen Options overlay (volume sliders). Layout + art live in Menus/OptionsMenu.tscn.

signal closed


func _ready() -> void:
    %BackButton.pressed.connect(func() -> void: closed.emit())
    if Platform.is_touch:
        %BackButton.custom_minimum_size.y = 52.0
