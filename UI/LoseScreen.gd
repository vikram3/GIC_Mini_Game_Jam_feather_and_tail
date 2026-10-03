extends Control
## "A teddy got hurt" screen. Layout + art: UI/LoseScreen.tscn.

signal restart_pressed
signal menu_pressed


func _ready() -> void:
    %RestartButton.pressed.connect(func() -> void: restart_pressed.emit())
    %MenuButton.pressed.connect(func() -> void: menu_pressed.emit())
    %FullscreenButton.pressed.connect(Platform.toggle_fullscreen)
    %FullscreenButton.visible = Platform.is_web and not OS.has_feature("web_ios")
    if Platform.is_touch:
        for b in [%RestartButton, %FullscreenButton, %MenuButton]:
            b.custom_minimum_size.y = 54.0


func show_lose() -> void:
    var key: String = "DISARM" if Platform.is_touch else "E"
    %Info.text = "Feather & Tail is a pacifist game - nobody may be harmed.\nA chasing teddy ran into a trap. Stay unseen near traps,\nbreak line of sight, or disarm them first (hold %s as MNKI)." % key
    visible = true
