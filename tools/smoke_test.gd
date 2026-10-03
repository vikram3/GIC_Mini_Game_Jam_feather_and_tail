extends SceneTree
## Headless smoke test:  godot --headless --fixed-fps 60 --script res://tools/smoke_test.gd
## Boots the menu, then the game, and drives it with scripted input for a few thousand frames.
## Any script error shows up in the output.

var frames: int = 0
var game: Node = null
var menu: Node = null
var phase: String = "menu"


func _initialize() -> void:
    menu = (load("res://Menus/Main_Menu.tscn") as PackedScene).instantiate()
    root.add_child(menu)


func _press(a: String, on: bool) -> void:
    if on:
        Input.action_press(a)
    else:
        Input.action_release(a)


func _tap(a: String) -> void:
    var ev := InputEventAction.new()
    ev.action = a
    ev.pressed = true
    Input.parse_input_event(ev)
    var up := InputEventAction.new()
    up.action = a
    up.pressed = false
    Input.parse_input_event(up)


func _process(_delta: float) -> bool:
    frames += 1
    if phase == "menu":
        if frames == 30:
            menu.call("_on_options")
        if frames == 40:
            menu.call("_on_options")
            menu.call("_on_how")
        if frames == 50:
            menu.call("_on_how")
        if frames == 60:
            menu.queue_free()
            game = (load("res://Game/Game.tscn") as PackedScene).instantiate()
            root.add_child(game)
            current_scene = game
            phase = "game"
            frames = 0
        return false

    # ---- game phase
    var dirs: Array = ["move_right", "move_down", "move_left", "move_up"]
    var di: int = (frames / 90) % 4
    for i in range(4):
        _press(dirs[i], i == di)
    if frames % 400 == 100:
        _tap("switch_leader")
    if frames % 330 == 50:
        _tap("chirp")
    _press("cut", frames % 200 < 120)
    _press("disarm", frames % 300 < 100)
    _press("sneak", frames % 500 < 120)

    if frames == 500:
        # teleport MNKI next to a teddy -> notice, chase, caught
        var g = game.guards[0]
        game.mnki.pos = g.pos + Vector2(60, 0)
    if frames == 800:
        # grab every fruit
        for f in game.level.fruits:
            var c: Vector2 = game.level.tile_center(f["tile"])
            game.mnki.pos = c
            game.swan.pos = c
            game._update_pickups()
    if frames == 900:
        game.call("_toggle_pause")
    if frames == 920:
        game.call("_toggle_pause")
    if frames == 1000:
        game.call("_swap_leader")
        game.call("_command_goto", game.level.tile_of(game.mnki.pos))
    if frames == 1100:
        # win: both at the fountain
        var fc: Vector2 = game.level.tile_center(game.level.fountain_tile)
        game.mnki.pos = fc
        game.swan.pos = fc
    if frames == 1200 and game.play_state == 2:
        print("SMOKE: reached WIN state OK")
        game.call("_restart")
    if frames == 1500:
        game = current_scene
        print("SMOKE: restarted, new game state=%d" % game.play_state)
    if frames == 1700:
        game.call("on_guard_harmed", game.guards[0])
    if frames > 1800:
        print("SMOKE: finished OK (state=%d, seen=%d, particles=%d)" % [game.play_state, game.seen_tiles.size(), game.particles.size()])
        quit()
    return false
