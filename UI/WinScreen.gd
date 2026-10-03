extends Control
## "Everyone made it out" screen. Layout + art: UI/WinScreen.tscn (Banner, NewBest badge, StatRow icons...).

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


func show_result(fruit: int, total: int, time_text: String, new_best: bool, disarmed: int, caught: int, bonks: int) -> void:
    %FruitRow.value_text = "%d / %d" % [fruit, total]
    %TimeRow.value_text = time_text
    %TrapsRow.value_text = str(disarmed)
    %CaughtRow.value_text = str(caught)
    %BonkRow.value_text = str(bonks)
    %NewBest.visible = new_best
    visible = true
