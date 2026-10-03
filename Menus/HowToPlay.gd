extends Control
## "How to play" overlay. All text and layout live in Menus/HowToPlay.tscn - this only picks which
## controls table (keyboard or touch) is shown.

signal closed


func _ready() -> void:
    %ControlsKeyboard.visible = not Platform.is_touch
    %ControlsTouch.visible = Platform.is_touch
    %CloseButton.pressed.connect(func() -> void: closed.emit())
    if Platform.is_touch:
        %CloseButton.custom_minimum_size.y = 52.0
