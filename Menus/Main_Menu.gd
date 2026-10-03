extends Control
## Title screen. Layout, text and art live in Menus/Main_Menu.tscn (open it and re-skin freely):
##   Background  - Art/Menu/menu_background.png      Logo - Art/Menu/title_logo.png
##   TitleCard   - the card panel (UI/GardenTheme.tres -> Art/Common/panel_card.png)
## This script only wires the buttons.


func _ready() -> void:
    Sound.set_mode("menu")
    Sound.ensure_music()

    %PlayButton.pressed.connect(_on_play)
    %RandomButton.pressed.connect(_on_random)
    %HowButton.pressed.connect(_on_how)
    %OptionsButton.pressed.connect(_on_options)
    %FullscreenButton.pressed.connect(Platform.toggle_fullscreen)
    %QuitButton.pressed.connect(_on_quit)
    %HowToPlay.closed.connect(_on_how)
    %OptionsMenu.closed.connect(_on_options)

    if Platform.is_web:
        # a browser tab cannot "quit"; offer fullscreen instead (not possible on iPhone Safari)
        %QuitButton.visible = false
        %FullscreenButton.visible = not OS.has_feature("web_ios")
    else:
        %FullscreenButton.visible = false

    if Platform.is_touch:
        for b in [%PlayButton, %RandomButton, %HowButton, %OptionsButton, %FullscreenButton, %QuitButton]:
            b.custom_minimum_size.y = 52.0

    if PlayerData.best_time > 0.0:
        %BestTime.text = "Best time: %s" % PlayerData.format_time(PlayerData.best_time)
        %BestTime.visible = true
    %PlayButton.grab_focus()


func _on_options() -> void:
    %OptionsMenu.visible = not %OptionsMenu.visible


func _on_how() -> void:
    %HowToPlay.visible = not %HowToPlay.visible


func _on_play() -> void:
    PlayerData.level_seed = PlayerData.DEFAULT_SEED
    Transition.go("res://Game/Game.tscn")


func _on_random() -> void:
    PlayerData.level_seed = randi()
    Transition.go("res://Game/Game.tscn")


func _on_quit() -> void:
    get_tree().quit()
