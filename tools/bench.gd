extends SceneTree
var frames := 0
var game: Node
var t0 := 0
func _initialize() -> void:
    game = (load("res://Game/Game.tscn") as PackedScene).instantiate()
    root.add_child(game)
    current_scene = game
func _process(_d: float) -> bool:
    frames += 1
    if frames == 1:
        # reveal a big part of the map like a mid-game state
        for y in range(game.level.H):
            for x in range(game.level.W):
                if (x + y) % 3 != 0:
                    game.seen_tiles[Vector2i(x, y)] = true
    if frames == 60:
        t0 = Time.get_ticks_usec()
    var dirs := ["move_right", "move_down", "move_left", "move_up"]
    var di: int = (frames / 60) % 4
    for i in range(4):
        if i == di: Input.action_press(dirs[i])
        else: Input.action_release(dirs[i])
    if frames == 660:
        var dt := float(Time.get_ticks_usec() - t0) / 600.0
        print("BENCH avg ms per frame: %.3f" % (dt / 1000.0))
        quit()
    return false
