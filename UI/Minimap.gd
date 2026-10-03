extends Control
## Scouted-map panel. The scene holds the frame art, the map image and the marker art:
##   Frame (NinePatchRect)  Map (the painted tiles, built in code)  Markers/{Traps,Fruits,Guards,MnkiMarker,SwanMarker}
##   Templates/{TrapMarker,AppleMarker,PearMarker,GuardMarker}  <- art + size for markers that are cloned at run time
## HUD.gd calls refresh() every frame.

const LevelScript = preload("res://Game/Level.gd")
const MAP_PX := 5      # minimap pixels per tile

var game: Node2D
var _img: Image
var _tex: ImageTexture
var _version: int = -1
var _pools: Dictionary = {}


func _ready() -> void:
    _img = Image.create(LevelScript.W, LevelScript.H, false, Image.FORMAT_RGBA8)
    _tex = ImageTexture.create_from_image(_img)
    var w: float = float(LevelScript.W * MAP_PX)
    var h: float = float(LevelScript.H * MAP_PX)
    custom_minimum_size = Vector2(w + 16.0, h + 16.0)
    size = custom_minimum_size
    %Map.texture = _tex
    for n in [%Map, %Markers]:
        n.position = Vector2(8, 8)
        n.size = Vector2(w, h)


func refresh() -> void:
    if game == null or game.level == null:
        return
    var level: LevelScript = game.level
    if _version != game.map_version:
        _version = game.map_version
        _rebuild_image()

    var traps: Array = []
    for t in level.traps:
        if game.seen_tiles.has(t):
            traps.append(t)
    var nodes: Array = _acquire("trap", %Traps, %TrapMarker, traps.size())
    for i in range(traps.size()):
        _put(nodes[i], (Vector2(traps[i]) + Vector2(0.5, 0.5)) * MAP_PX)

    var apples: Array = []
    var pears: Array = []
    for f in level.fruits:
        if not f["got"] and game.seen_tiles.has(f["tile"]):
            (apples if f["kind"] == "ground" else pears).append(f)
    var an: Array = _acquire("apple", %Fruits, %AppleMarker, apples.size())
    for i in range(apples.size()):
        _put(an[i], (Vector2(apples[i]["tile"]) + Vector2(0.5, 0.5)) * MAP_PX)
    var pn: Array = _acquire("pear", %Fruits, %PearMarker, pears.size())
    for i in range(pears.size()):
        _put(pn[i], (Vector2(pears[i]["tile"]) + Vector2(0.5, 0.5)) * MAP_PX)

    var seen_guards: Array = []
    for g in game.guards:
        if game.vis_tiles.has(level.tile_of(g.pos)):
            seen_guards.append(g)
    var gn: Array = _acquire("guard", %Guards, %GuardMarker, seen_guards.size())
    for i in range(seen_guards.size()):
        _put(gn[i], seen_guards[i].pos / LevelScript.TILE * MAP_PX)

    _put(%MnkiMarker, game.mnki.pos / LevelScript.TILE * MAP_PX)
    _put(%SwanMarker, game.swan.pos / LevelScript.TILE * MAP_PX)


func _put(n: Control, centre: Vector2) -> void:
    n.position = centre - n.size * 0.5


func _acquire(key: String, container: Control, template: Control, count: int) -> Array:
    var arr: Array = _pools.get(key, [])
    while arr.size() < count:
        var n: Control = template.duplicate()
        n.unique_name_in_owner = false
        container.add_child(n)
        arr.append(n)
    for i in range(arr.size()):
        arr[i].visible = i < count
    _pools[key] = arr
    return arr


func _rebuild_image() -> void:
    var level: LevelScript = game.level
    _img.fill(Color(0, 0, 0, 0))
    for y in range(LevelScript.H):
        for x in range(LevelScript.W):
            var t := Vector2i(x, y)
            if not game.seen_tiles.has(t):
                continue
            var kind: int = int(level.tiles[y][x])
            var col := Color(0.80, 0.85, 0.66)
            if kind == LevelScript.WALL:
                col = Color(0.10, 0.30, 0.18)
            elif kind == LevelScript.HEDGE:
                col = Color(0.25, 0.65, 0.28)
            elif kind == LevelScript.LOW:
                col = Color(0.6, 0.6, 0.65)
            elif kind == LevelScript.BUSH:
                col = Color(0.18, 0.5, 0.22)
            elif kind == LevelScript.WATER:
                col = Color(0.25, 0.60, 0.92)
            elif kind == LevelScript.BRIDGE:
                col = Color(0.62, 0.42, 0.22)
            if t == level.fountain_tile:
                col = Color(0.3, 0.65, 1.0)
            elif t == level.exit_tile:
                col = Color(0.4, 0.95, 0.5) if game.collected >= game.fruit_total else Color(0.8, 0.4, 0.3)
            elif t == level.gate_tile:
                col = Color(0.7, 0.5, 0.25)
            if not game.vis_tiles.has(t):
                col = col.darkened(0.4)
            _img.set_pixel(x, y, col)
    _tex.update(_img)
