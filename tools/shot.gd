extends SceneTree
## Saves a screenshot of a staged scene:  godot --path . --script res://tools/shot.gd   (needs a display)
var game: Node = null
var frames: int = 0

func _initialize() -> void:
    game = (load("res://Game/Game.tscn") as PackedScene).instantiate()
    root.add_child(game)
    current_scene = game

func _process(_d: float) -> bool:
    frames += 1
    var lvl = game.level
    if frames == 2:
        var tw = game.towers[0]
        var st: Vector2i = lvl.nearest_free(tw.tile + Vector2i(0, 3), true, 4)
        game.swan.pos = lvl.tile_center(st)
        game.mnki.pos = game.swan.pos + Vector2(-40, 20)
        game.follower_mode = "hold"
        game.leader = game.swan
        game.follower = game.mnki
        for g in game.guards:
            g.route = []
        game.cam_pos_a = game.swan.pos
        game.cam_pos_b = game.swan.pos
    if frames > 2 and frames < 400:
        game.follower_mode = "hold"
    if frames == 60:
        game.speech.say(game.mnki, "mnki", "Keep moving, Swan! Dodge the pebbles!", 1, 8.0)
    if frames == 100:
        game.speech.say(game.swan, "swan", "Fear is only love for what we might lose.", 1, 8.0)
    if frames == 98:
        var img: Image = root.get_viewport().get_texture().get_image()
        img.save_png("/home/claude/shot_aim.png")
        print("saved aim shot, tower state ", game.towers[0].state)
    if frames == 230:
        var img2: Image = root.get_viewport().get_texture().get_image()
        img2.save_png("/home/claude/shot_after.png")
        print("saved second shot")
        quit(0)
    return false
