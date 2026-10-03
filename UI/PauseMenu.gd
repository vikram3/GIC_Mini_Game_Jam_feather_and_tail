extends Control
## Pause overlay. Layout + art: UI/PauseMenu.tscn. HUD.gd shows / hides it and forwards the signals.

signal resume_pressed
signal restart_pressed
signal menu_pressed


func _ready() -> void:
    %ResumeButton.pressed.connect(func() -> void: resume_pressed.emit())
    %RestartButton.pressed.connect(func() -> void: restart_pressed.emit())
    %MenuButton.pressed.connect(func() -> void: menu_pressed.emit())
    %FullscreenButton.pressed.connect(Platform.toggle_fullscreen)
    %FullscreenButton.visible = Platform.is_web and not OS.has_feature("web_ios")
    if Platform.is_touch:
        for b in [%ResumeButton, %RestartButton, %FullscreenButton, %MenuButton]:
            b.custom_minimum_size.y = 54.0
