extends Node2D
## Draws the whole garden in world coordinates. It lives inside SubViewport A;
## SubViewport B shares the same World2D, so both camera views show this drawing.
## Everything here is a vector PLACEHOLDER - swap any of it for real art later.
##
## PERFORMANCE: the garden is split into layers (child DrawProxy nodes, drawn in this order):
##   1. terrain chunks - 8x8-tile blocks of static scenery. Each is drawn ONCE and cached by the
##      engine; only a chunk that gains newly-discovered tiles (or a cut hedge) is redrawn.
##   2. anim   - the few animated tile details (stream flow, lamp glow, pond ripples, fountain, exit).
##   3. fog    - dark overlay on seen-but-not-visible tiles. Redrawn only when visibility changes.
##   4. actors - traps, fruit, teddies, MNKI, Swan, particles. Redrawn every frame (small).

const LevelScript = preload("res://Game/Level.gd")
const GuardScript = preload("res://Game/Guard.gd")
const Sprites = preload("res://Game/Sprites.gd")
const DrawProxy = preload("res://Game/DrawProxy.gd")

const TILE := 36
const WALL := 1
const HEDGE := 2
const LOW := 3
const BUSH := 4
const WATER := 5
const BRIDGE := 6

const PATH_COL := Color(0.86, 0.81, 0.64)
const HEDGE_DARK := Color(0.08, 0.24, 0.14)
const HEDGE_MID := Color(0.12, 0.34, 0.20)
const HEDGE_LIGHT := Color(0.18, 0.45, 0.26)
const WATER_COL := Color(0.25, 0.60, 0.92)
const WATER_DEEP := Color(0.16, 0.45, 0.78)
const WATER_LIGHT := Color(0.72, 0.92, 1.0)
const STONE := Color(0.58, 0.58, 0.63)
const STONE_LIGHT := Color(0.80, 0.80, 0.85)
const WOOD := Color(0.52, 0.33, 0.16)
const WOOD_LIGHT := Color(0.72, 0.52, 0.30)
const GOLD := Color(1.0, 0.85, 0.30)

const FLOWER_COLS := [
    Color(1.0, 0.45, 0.62), Color(1.0, 0.86, 0.25), Color(0.98, 0.98, 0.98),
    Color(0.72, 0.56, 0.96), Color(1.0, 0.60, 0.22),
]

# canopy palettes: [dark, mid, light]
const TREE_PALETTES := [
    [Color(0.08, 0.34, 0.16), Color(0.15, 0.50, 0.24), Color(0.30, 0.65, 0.33)],
    [Color(0.10, 0.38, 0.20), Color(0.20, 0.55, 0.28), Color(0.38, 0.72, 0.38)],
    [Color(0.36, 0.46, 0.20), Color(0.52, 0.64, 0.28), Color(0.95, 0.62, 0.74)],   # blossom
    [Color(0.55, 0.38, 0.10), Color(0.80, 0.58, 0.14), Color(0.96, 0.80, 0.30)],   # autumn gold
]

const CHUNK := 8          # tiles per terrain chunk side
const FOG_COL := Color(0, 0, 0, 0.5)

var game: Node2D
var cv: CanvasItem            # the canvas item currently being drawn (set by proxy_draw)
var clock: float = 0.0
var seed_mix: int = 0
var fruit_tiles: Dictionary = {}
var butterflies: Array = []

var chunks_x: int = 0
var chunks_y: int = 0
var chunk_nodes: Array = []
var dirty_chunks: Dictionary = {}
var anim_node: DrawProxy
var fog_node: DrawProxy
var actors_node: DrawProxy
var fog_version: int = -1
var anim_water: Array = []
var anim_lamps: Array = []
var anim_ponds: Array = []

## Called by Game.gd once `game` is set (the node now lives in Game.tscn, so _ready is too early).
func setup() -> void:
    cv = self
    seed_mix = PlayerData.level_seed & 0xffff
    var level: LevelScript = game.level
    for f in level.fruits:
        fruit_tiles[f["tile"]] = true
    var rng := RandomNumberGenerator.new()
    rng.seed = PlayerData.level_seed
    var cells: Array = []
    for c in level.links:
        cells.append(level.cell_tile(c))
    for i in range(10):
        var t: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
        butterflies.append({
            "anchor": level.tile_center(t),
            "phase": rng.randf() * TAU,
            "col": FLOWER_COLS[rng.randi_range(0, FLOWER_COLS.size() - 1)],
        })

    # which tiles carry animated details (terrain never changes into/out of these)
    for y in range(LevelScript.H):
        for x in range(LevelScript.W):
            var t2 := Vector2i(x, y)
            var kind: int = int(level.tiles[y][x])
            if kind == WATER:
                anim_water.append(t2)
            elif kind == WALL:
                var pk: String = _pillar_kind(t2, level)
                if pk == "lamp":
                    anim_lamps.append(t2)
                elif pk == "pond":
                    anim_ponds.append(t2)

    # layers, in draw order
    chunks_x = ceili(float(LevelScript.W) / float(CHUNK))
    chunks_y = ceili(float(LevelScript.H) / float(CHUNK))
    for cy in range(chunks_y):
        for cx in range(chunks_x):
            var n: DrawProxy = _make_proxy("chunk")
            n.cx = cx
            n.cy = cy
            chunk_nodes.append(n)
    anim_node = _make_proxy("anim")
    fog_node = _make_proxy("fog")
    actors_node = _make_proxy("actors")


func _make_proxy(kind: String) -> DrawProxy:
    var n := DrawProxy.new()
    n.owner_draw = self
    n.kind = kind
    add_child(n)
    return n


func _process(delta: float) -> void:
    clock += delta
    for idx in dirty_chunks:
        (chunk_nodes[idx] as DrawProxy).queue_redraw()
    dirty_chunks.clear()
    if fog_version != game.map_version:
        fog_version = game.map_version
        fog_node.queue_redraw()
    anim_node.queue_redraw()
    actors_node.queue_redraw()


## A tile was discovered (or changed): its terrain chunk must be redrawn.
func mark_seen(t: Vector2i) -> void:
    var cx: int = clampi(t.x / CHUNK, 0, chunks_x - 1)
    var cy: int = clampi(t.y / CHUNK, 0, chunks_y - 1)
    dirty_chunks[cy * chunks_x + cx] = true


func proxy_draw(p: DrawProxy) -> void:
    if game == null or game.level == null:
        return
    cv = p
    match p.kind:
        "chunk":
            _draw_chunk(p.cx, p.cy)
        "anim":
            _draw_anim()
        "fog":
            _draw_fog()
        "actors":
            _draw_actors()
    cv = self


## Deterministic per-tile pseudo random number (so decoration never moves or flickers).
func _h(x: int, y: int, salt: int) -> int:
    var v: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791) ^ (seed_mix * 40503)
    v = (v ^ (v >> 13)) * 1274126177
    return (v ^ (v >> 16)) & 0x7fffffff


## What decoration sits on a wall pillar: "tree", "planter", "lamp", "statue", "pond" or "".
func _pillar_kind(t: Vector2i, level: LevelScript) -> String:
    if t == level.gate_tile or t == level.exit_tile or level.towers.has(t):
        return ""
    if not (t.x % 2 == 0 and t.y % 2 == 0):
        return ""
    var border: bool = t.x == 0 or t.y == 0 or t.x == LevelScript.W - 1 or t.y == LevelScript.H - 1
    var v: int = _h(t.x, t.y, 7) % 100
    if v < 36:
        return "tree"
    if border:
        return ""
    if v < 50:
        return "planter"
    if v < 60:
        return "lamp"
    if v < 68:
        return "statue"
    if v < 82:
        return "pond"
    return ""


# ------------------------------------------------------------- layer 1: terrain
func _draw_chunk(cx: int, cy: int) -> void:
    var level: LevelScript = game.level
    var font: Font = ThemeDB.fallback_font
    var seen: Dictionary = game.seen_tiles
    var x1: int = mini((cx + 1) * CHUNK, LevelScript.W)
    var y1: int = mini((cy + 1) * CHUNK, LevelScript.H)
    for y in range(cy * CHUNK, y1):
        for x in range(cx * CHUNK, x1):
            var t := Vector2i(x, y)
            if not seen.has(t):
                continue
            var r := Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE))
            _draw_tile(r, int(level.tiles[y][x]), true, t, level, font)


# --------------------------------------------------------------- layer 2: anim
func _draw_anim() -> void:
    var level: LevelScript = game.level
    var seen: Dictionary = game.seen_tiles
    var font: Font = ThemeDB.fallback_font
    for t in anim_water:
        if seen.has(t):
            _draw_water_flow(Rect2(Vector2(t) * TILE, Vector2(TILE, TILE)), t, level)
    for t in anim_lamps:
        if seen.has(t):
            _draw_lamp_glow(Vector2(t) * TILE + Vector2(TILE, TILE) * 0.5)
    for t in anim_ponds:
        if seen.has(t):
            _draw_pond_ripple(Vector2(t) * TILE + Vector2(TILE, TILE) * 0.5, t)
    var ft: Vector2i = level.fountain_tile
    if seen.has(ft):
        _draw_fountain(Rect2(Vector2(ft) * TILE, Vector2(TILE, TILE)), 0.0)
    var et: Vector2i = level.exit_tile
    if seen.has(et):
        _draw_exit_gate(Rect2(Vector2(et) * TILE, Vector2(TILE, TILE)), 0.0, font)


# ---------------------------------------------------------------- layer 3: fog
func _draw_fog() -> void:
    var seen: Dictionary = game.seen_tiles
    var vis: Dictionary = game.vis_tiles
    for y in range(LevelScript.H):
        var run_start: int = -1
        for x in range(LevelScript.W + 1):
            var dim: bool = false
            if x < LevelScript.W:
                var t := Vector2i(x, y)
                dim = seen.has(t) and not vis.has(t)
            if dim and run_start < 0:
                run_start = x
            elif not dim and run_start >= 0:
                cv.draw_rect(Rect2(float(run_start * TILE), float(y * TILE), float((x - run_start) * TILE), float(TILE)), FOG_COL)
                run_start = -1


# ------------------------------------------------------------- layer 4: actors
func _draw_actors() -> void:
    var level: LevelScript = game.level
    var font: Font = ThemeDB.fallback_font
    var seen: Dictionary = game.seen_tiles
    var vis: Dictionary = game.vis_tiles

    # traps (only drawn once their tile has been seen)
    for t in level.traps:
        if seen.has(t):
            _draw_trap(t, vis.has(t), level)

    # fruit
    for f in level.fruits:
        if f["got"] or not seen.has(f["tile"]):
            continue
        _draw_fruit(f, level, vis)

    # teddy view cones (only where we can actually see)
    for g in game.guards:
        if not vis.has(level.tile_of(g.pos)):
            continue
        var a: float = 0.16 + (0.14 if g.state == GuardScript.CHASE else 0.0)
        var col := Color(1.0, 0.35, 0.2, a)
        for t in g.cone:
            if vis.has(t):
                cv.draw_rect(Rect2(Vector2(t) * TILE, Vector2(TILE, TILE)), col)

    # follower route
    var follower = game.follower
    if not follower.path.is_empty():
        var pts := PackedVector2Array()
        pts.append(follower.pos)
        for t in follower.path:
            pts.append(level.tile_center(t))
        if pts.size() >= 2:
            cv.draw_polyline(pts, Color(1, 1, 1, 0.45), 2.0)
            cv.draw_circle(pts[pts.size() - 1], 6, Color(1, 0.9, 0.3, 0.8))

    # noise rings
    for e in game.effects:
        var k: float = float(e["age"]) / float(e["max"])
        cv.draw_arc(e["pos"], float(e["radius"]) * k, 0.0, TAU, 48, Color(1, 1, 1, 1.0 - k), 2.0)

    _draw_butterflies(level, vis)

    # teddy guards
    for g in game.guards:
        if vis.has(level.tile_of(g.pos)):
            _draw_guard(g, font)

    # watchtowers with their sling teddies
    for tw in game.towers:
        if seen.has(tw.tile):
            _draw_tower(tw, vis.has(tw.tile), font)

    # heroes: follower first so the leader is on top
    _draw_hero(game.follower, font)
    _draw_hero(game.leader, font)
    _draw_dizzy_stars()

    # sling aim targets and pebbles in flight (above the heroes: Swan needs to see them coming)
    for tw in game.towers:
        if tw.state == 2:       # Tower.AIM
            _draw_reticle(tw)
    for s in game.stones:
        _draw_stone(s)

    # action bars
    if game.cut_progress > 0.0:
        _bar(game.mnki.pos + Vector2(-16, -28), game.cut_progress, Color(0.5, 0.95, 0.4))
    if game.disarm_progress > 0.0:
        _bar(game.mnki.pos + Vector2(-16, -28), game.disarm_progress, Color(0.4, 0.8, 1.0))

    # particles (sparkles, leaves, droplets)
    for pt in game.particles:
        var k2: float = float(pt["age"]) / float(pt["max"])
        var c: Color = pt["col"]
        c.a *= 1.0 - k2
        cv.draw_circle(pt["p"], float(pt["size"]) * (1.0 - 0.5 * k2), c)

    # (speech bubbles are SpeechBubble.tscn nodes now - see Game/BubbleLayer.gd)


func _bar(p: Vector2, frac: float, col: Color) -> void:
    cv.draw_rect(Rect2(p, Vector2(32, 6)), Color(0, 0, 0, 0.7))
    cv.draw_rect(Rect2(p, Vector2(32.0 * clampf(frac, 0.0, 1.0), 6)), col)


# ===================================================================== tiles

func _draw_tile(r: Rect2, kind: int, lit: bool, t: Vector2i, level: LevelScript, font: Font) -> void:
    var dim: float = 0.0 if lit else 0.5
    match kind:
        WALL:
            _draw_wall(r, t, dim, level, font)
        HEDGE:
            _draw_floor_base(r, t, dim)
            _draw_hedge(r, dim, lit)
        LOW:
            _draw_floor_base(r, t, dim)
            _draw_low_wall(r, t, dim)
        BUSH:
            _draw_floor_base(r, t, dim)
            _draw_bush(r, t, dim)
        WATER:
            _draw_water(r, t, dim, level)
        BRIDGE:
            _draw_bridge(r, t, dim, level)
        _:
            _draw_floor(r, t, dim, level)


func _draw_floor_base(r: Rect2, t: Vector2i, dim: float) -> void:
    var sh: float = float(_h(t.x, t.y, 2) % 6) * 0.012
    cv.draw_rect(r, PATH_COL.lightened(sh).darkened(dim))
    cv.draw_rect(r, PATH_COL.darkened(0.14 + dim), false, 1.0)
    var hv: int = _h(t.x, t.y, 3)
    for i in range(2):
        var o := Vector2(5 + (hv >> (i * 5)) % 26, 5 + (hv >> (i * 5 + 3)) % 26)
        cv.draw_circle(r.position + o, 1.3, PATH_COL.darkened(0.22 + dim))


func _draw_floor(r: Rect2, t: Vector2i, dim: float, level: LevelScript) -> void:
    _draw_floor_base(r, t, dim)
    if t == level.fountain_tile:
        return          # the animated fountain is drawn by the anim layer
    if t == level.start_tile:
        cv.draw_rect(r.grow(-7), Color(0.72, 0.30, 0.26).darkened(dim))
        cv.draw_rect(r.grow(-10), Color(0.90, 0.72, 0.40).darkened(dim), false, 1.5)
        return
    if fruit_tiles.has(t) or level.traps.has(t):
        return
    var roll: int = _h(t.x, t.y, 4) % 100
    var corners: Array = [Vector2(8, 8), Vector2(28, 8), Vector2(8, 28), Vector2(28, 28)]
    var co: Vector2 = r.position + corners[_h(t.x, t.y, 5) % 4]
    var is_cell: bool = t.x % 2 == 1 and t.y % 2 == 1
    if roll < 18:
        _draw_flowers(co, t, dim, 3 if roll < 9 else 2)
    elif roll < 32:
        _draw_grass(co, dim)
    elif roll < 36:
        _draw_mushrooms(co, dim)
    elif is_cell and roll < 40:
        _draw_bench(r, dim)
    elif is_cell and roll < 43:
        _draw_birdbath(r, dim)
    elif is_cell and roll < 46:
        _draw_blanket(r, t, dim)


func _draw_flowers(c: Vector2, t: Vector2i, dim: float, n: int) -> void:
    for i in range(n):
        var hv: int = _h(t.x, t.y, 20 + i)
        var o := Vector2(float(hv % 13) - 6.0, float((hv >> 4) % 13) - 6.0)
        var col: Color = FLOWER_COLS[hv % FLOWER_COLS.size()]
        var fp: Vector2 = c + o
        cv.draw_line(fp, fp + Vector2(0, 4), Color(0.2, 0.5, 0.2).darkened(dim), 1.2)
        for k in range(4):
            var a: float = TAU * float(k) / 4.0 + 0.4
            cv.draw_circle(fp + Vector2(cos(a), sin(a)) * 2.1, 1.9, col.darkened(dim))
        cv.draw_circle(fp, 1.3, Color(1.0, 0.8, 0.2).darkened(dim))


func _draw_grass(c: Vector2, dim: float) -> void:
    var gc: Color = Color(0.30, 0.62, 0.28).darkened(dim)
    for i in range(3):
        var x: float = c.x + float(i - 1) * 3.0
        cv.draw_line(Vector2(x, c.y + 3), Vector2(x + float(i - 1) * 1.5, c.y - 3), gc, 1.5)


func _draw_mushrooms(c: Vector2, dim: float) -> void:
    cv.draw_rect(Rect2(c + Vector2(-1, 0), Vector2(2, 4)), Color(0.95, 0.92, 0.82).darkened(dim))
    cv.draw_circle(c + Vector2(0, 0), 4, Color(0.85, 0.2, 0.2).darkened(dim))
    cv.draw_circle(c + Vector2(-1.5, -1), 0.9, Color(1, 1, 1).darkened(dim))
    cv.draw_circle(c + Vector2(1.5, 0.5), 0.9, Color(1, 1, 1).darkened(dim))


func _draw_bench(r: Rect2, dim: float) -> void:
    var p: Vector2 = r.position + Vector2(7, 5)
    cv.draw_rect(Rect2(p + Vector2(0, 3), Vector2(22, 6)), WOOD.darkened(dim))
    cv.draw_rect(Rect2(p, Vector2(22, 3)), WOOD_LIGHT.darkened(dim))
    cv.draw_rect(Rect2(p + Vector2(1, 9), Vector2(3, 3)), Color(0.2, 0.15, 0.1).darkened(dim))
    cv.draw_rect(Rect2(p + Vector2(18, 9), Vector2(3, 3)), Color(0.2, 0.15, 0.1).darkened(dim))


func _draw_birdbath(r: Rect2, dim: float) -> void:
    var c: Vector2 = r.get_center() + Vector2(0, 6)
    cv.draw_circle(c + Vector2(0, 4), 4, STONE.darkened(dim))
    cv.draw_circle(c, 8, STONE_LIGHT.darkened(dim))
    cv.draw_circle(c, 6, WATER_COL.darkened(dim))
    cv.draw_circle(c + Vector2(-2, -1), 1.3, WATER_LIGHT.darkened(dim))


func _draw_blanket(r: Rect2, t: Vector2i, dim: float) -> void:
    var p: Vector2 = r.position + Vector2(8, 10)
    cv.draw_rect(Rect2(p, Vector2(20, 16)), Color(0.85, 0.25, 0.30).darkened(dim))
    for i in range(3):
        cv.draw_rect(Rect2(p + Vector2(float(i) * 7.0, 0), Vector2(3.5, 16)), Color(1, 1, 1, 0.85).darkened(dim))
    cv.draw_circle(p + Vector2(10, 8), 3, Color(0.9, 0.2, 0.2).darkened(dim))


func _draw_hedge(r: Rect2, dim: float, lit: bool) -> void:
    cv.draw_rect(r.grow(-2), Color(0.20, 0.55, 0.22).darkened(dim))
    for i in range(3):
        var off := Vector2(8 + i * 10, 10 + (i % 2) * 14)
        cv.draw_circle(r.position + off, 6, Color(0.32, 0.70, 0.32).darkened(dim))
    # little shears hint: this hedge can be cut by MNKI
    cv.draw_arc(r.get_center(), 15, 0.4, 1.2, 8, Color(1, 1, 0.6, 0.3), 2.0)


func _draw_low_wall(r: Rect2, t: Vector2i, dim: float) -> void:
    cv.draw_rect(Rect2(r.position + Vector2(2, 10), Vector2(TILE - 4, 16)), STONE.darkened(dim))
    cv.draw_rect(Rect2(r.position + Vector2(2, 10), Vector2(TILE - 4, 4)), STONE_LIGHT.darkened(dim))
    for i in range(3):
        cv.draw_line(r.position + Vector2(10 + i * 9, 14), r.position + Vector2(10 + i * 9, 26), STONE_LIGHT.darkened(0.2 + dim), 1.0)
    cv.draw_circle(r.position + Vector2(8 + float(_h(t.x, t.y, 6) % 20), 10), 2.2, Color(1.0, 0.6, 0.8).darkened(dim))


func _draw_bush(r: Rect2, t: Vector2i, dim: float) -> void:
    cv.draw_circle(r.get_center(), 14, Color(0.12, 0.42, 0.18).darkened(dim))
    cv.draw_circle(r.get_center() + Vector2(-4, -4), 8, Color(0.22, 0.58, 0.26).darkened(dim))
    if _h(t.x, t.y, 8) % 3 == 0:
        var col: Color = FLOWER_COLS[_h(t.x, t.y, 10) % FLOWER_COLS.size()]
        for i in range(4):
            var a: float = float(i) * 1.7 + float(_h(t.x, t.y, 11) % 6)
            cv.draw_circle(r.get_center() + Vector2(cos(a), sin(a)) * 8.0, 2.0, col.darkened(dim))


# ------------------------------------------------------------------- walls

func _draw_wall(r: Rect2, t: Vector2i, dim: float, level: LevelScript, font: Font) -> void:
    cv.draw_rect(r, HEDGE_DARK.darkened(dim))
    cv.draw_rect(r.grow(-4), HEDGE_MID.darkened(dim))
    cv.draw_circle(r.get_center() + Vector2(-6, -5), 4, HEDGE_LIGHT.darkened(dim))
    cv.draw_circle(r.get_center() + Vector2(7, 6), 3.5, HEDGE_LIGHT.darkened(dim))
    if t == level.gate_tile:
        _draw_entrance_gate(r, dim, font)
        return
    if t == level.exit_tile:
        return          # the exit gate reacts to the fruit count: drawn by the anim layer
    match _pillar_kind(t, level):
        "tree":
            _draw_tree(r, t, dim)
        "planter":
            _draw_planter(r, t, dim)
        "lamp":
            _draw_lamp(r, dim)
        "statue":
            _draw_statue(r, dim)
        "pond":
            _draw_pond(r, t, dim)


func _draw_tree(r: Rect2, t: Vector2i, dim: float) -> void:
    var c: Vector2 = r.get_center()
    var pal: Array = TREE_PALETTES[_h(t.x, t.y, 9) % TREE_PALETTES.size()]
    cv.draw_circle(c + Vector2(3, 4), 16, Color(0, 0, 0, 0.25))
    cv.draw_circle(c, 16, (pal[0] as Color).darkened(dim))
    cv.draw_circle(c + Vector2(-2, -3), 12, (pal[1] as Color).darkened(dim))
    cv.draw_circle(c + Vector2(-5, -6), 6, (pal[2] as Color).darkened(dim))
    cv.draw_circle(c + Vector2(5, 3), 4, (pal[2] as Color).darkened(0.1 + dim))
    if _h(t.x, t.y, 9) % 4 == 2:
        for i in range(5):   # blossom dots
            var a: float = float(i) * 1.26 + float(t.x)
            cv.draw_circle(c + Vector2(cos(a), sin(a)) * 9.0, 1.6, Color(1, 0.85, 0.9).darkened(dim))


func _draw_planter(r: Rect2, t: Vector2i, dim: float) -> void:
    var p: Vector2 = r.position
    cv.draw_rect(Rect2(p + Vector2(5, 13), Vector2(26, 17)), WOOD.darkened(dim))
    cv.draw_rect(Rect2(p + Vector2(5, 13), Vector2(26, 4)), WOOD_LIGHT.darkened(dim))
    for i in range(5):
        var col: Color = FLOWER_COLS[(_h(t.x, t.y, 30 + i)) % FLOWER_COLS.size()]
        var fp: Vector2 = p + Vector2(8 + i * 5, 10 + (i % 2) * 3)
        cv.draw_line(fp, fp + Vector2(0, 5), Color(0.2, 0.5, 0.2).darkened(dim), 1.2)
        cv.draw_circle(fp, 3.0, col.darkened(dim))
        cv.draw_circle(fp, 1.1, Color(1.0, 0.8, 0.2).darkened(dim))


func _draw_lamp_glow(c: Vector2) -> void:
    var glow: float = 0.16 + 0.05 * sin(clock * 3.0 + c.x)
    cv.draw_circle(c, 17, Color(1.0, 0.9, 0.5, glow))
    cv.draw_circle(c + Vector2(0, -6), 5.5, Color(1.0, 0.92, 0.55))
    cv.draw_circle(c + Vector2(0, -6), 2.5, Color(1.0, 1.0, 0.85))


func _draw_lamp(r: Rect2, dim: float) -> void:
    var c: Vector2 = r.get_center()
    cv.draw_circle(c, 17, Color(1.0, 0.9, 0.5, 0.16))
    cv.draw_circle(c + Vector2(0, 8), 5, STONE.darkened(dim))
    cv.draw_rect(Rect2(c + Vector2(-1.5, -4), Vector2(3, 12)), Color(0.15, 0.15, 0.18).darkened(dim))
    cv.draw_circle(c + Vector2(0, -6), 5.5, Color(1.0, 0.92, 0.55).darkened(dim))
    cv.draw_circle(c + Vector2(0, -6), 2.5, Color(1.0, 1.0, 0.85).darkened(dim))


func _draw_statue(r: Rect2, dim: float) -> void:
    var c: Vector2 = r.get_center()
    cv.draw_rect(Rect2(c + Vector2(-10, 4), Vector2(20, 10)), STONE.darkened(dim))
    cv.draw_rect(Rect2(c + Vector2(-10, 4), Vector2(20, 3)), STONE_LIGHT.darkened(dim))
    cv.draw_circle(c + Vector2(0, -2), 7, STONE_LIGHT.darkened(dim))
    cv.draw_circle(c + Vector2(0, -11), 4.5, STONE_LIGHT.darkened(dim))
    cv.draw_circle(c + Vector2(-3, -3), 2, Color(1, 1, 1, 0.35).darkened(dim))


func _draw_pond(r: Rect2, t: Vector2i, dim: float) -> void:
    var c: Vector2 = r.get_center()
    cv.draw_circle(c, 16, STONE.darkened(dim))
    cv.draw_circle(c, 13.5, WATER_COL.darkened(dim))
    cv.draw_circle(c + Vector2(-5, 3), 4.5, Color(0.25, 0.65, 0.30).darkened(dim))
    cv.draw_circle(c + Vector2(-3, 2), 1.6, Color(1.0, 0.65, 0.78).darkened(dim))
    if _h(t.x, t.y, 12) % 2 == 0:
        cv.draw_circle(c + Vector2(5, 5), 3.2, Color(0.25, 0.65, 0.30).darkened(dim))


func _draw_pond_ripple(c: Vector2, t: Vector2i) -> void:
    var rip: float = fposmod(clock * 0.8 + float(t.x), 1.0)
    cv.draw_arc(c + Vector2(4, -3), 3.0 + rip * 6.0, 0.0, TAU, 14, Color(WATER_LIGHT, 0.7 * (1.0 - rip)), 1.2)


# ------------------------------------------------------------ water, bridge

func _stream_vertical(t: Vector2i, level: LevelScript) -> bool:
    for o in [Vector2i(0, -1), Vector2i(0, 1)]:
        var k: int = level.tile_at(t + o)
        if k == WATER or k == BRIDGE:
            return true
    return false


func _draw_water(r: Rect2, t: Vector2i, dim: float, level: LevelScript) -> void:
    cv.draw_rect(r, WATER_COL.darkened(dim))
    cv.draw_rect(r.grow(-1), WATER_DEEP.darkened(dim), false, 2.0)


func _draw_water_flow(r: Rect2, t: Vector2i, level: LevelScript) -> void:
    var vertical: bool = _stream_vertical(t, level)
    for i in range(3):
        var off: float = fposmod(clock * 16.0 + float(i) * 12.0, TILE)
        if vertical:
            var x: float = r.position.x + 8.0 + float(i) * 10.0
            cv.draw_line(Vector2(x, r.position.y + off), Vector2(x, r.position.y + minf(off + 6.0, TILE)), WATER_LIGHT, 1.5)
        else:
            var y: float = r.position.y + 8.0 + float(i) * 10.0
            cv.draw_line(Vector2(r.position.x + off, y), Vector2(r.position.x + minf(off + 6.0, TILE), y), WATER_LIGHT, 1.5)


func _draw_bridge(r: Rect2, t: Vector2i, dim: float, level: LevelScript) -> void:
    cv.draw_rect(r, WATER_COL.darkened(dim))
    var vertical: bool = _stream_vertical(t, level)
    var p: Vector2 = r.position
    if vertical:
        # stream runs north-south, the deck carries the path east-west
        cv.draw_rect(Rect2(p + Vector2(0, 8), Vector2(TILE, 20)), WOOD_LIGHT.darkened(dim))
        for i in range(6):
            cv.draw_line(p + Vector2(3 + i * 6, 8), p + Vector2(3 + i * 6, 28), WOOD.darkened(dim), 1.2)
        cv.draw_rect(Rect2(p + Vector2(0, 6), Vector2(TILE, 3)), WOOD.darkened(dim))
        cv.draw_rect(Rect2(p + Vector2(0, 27), Vector2(TILE, 3)), WOOD.darkened(dim))
    else:
        cv.draw_rect(Rect2(p + Vector2(8, 0), Vector2(20, TILE)), WOOD_LIGHT.darkened(dim))
        for i in range(6):
            cv.draw_line(p + Vector2(8, 3 + i * 6), p + Vector2(28, 3 + i * 6), WOOD.darkened(dim), 1.2)
        cv.draw_rect(Rect2(p + Vector2(6, 0), Vector2(3, TILE)), WOOD.darkened(dim))
        cv.draw_rect(Rect2(p + Vector2(27, 0), Vector2(3, TILE)), WOOD.darkened(dim))


# --------------------------------------------------------- gate, exit, fountain

func _draw_entrance_gate(r: Rect2, dim: float, font: Font) -> void:
    var p: Vector2 = r.position
    cv.draw_rect(Rect2(p + Vector2(3, 2), Vector2(30, 32)), STONE.darkened(dim))
    cv.draw_rect(Rect2(p + Vector2(3, 2), Vector2(30, 5)), STONE_LIGHT.darkened(dim))
    cv.draw_rect(Rect2(p + Vector2(7, 8), Vector2(22, 22)), WOOD.darkened(dim))
    for i in range(1, 4):
        cv.draw_line(p + Vector2(7 + i * 5.5, 8), p + Vector2(7 + i * 5.5, 30), Color(0.3, 0.18, 0.08).darkened(dim), 1.2)
    cv.draw_circle(p + Vector2(24, 20), 1.8, GOLD.darkened(dim))
    cv.draw_string(font, p + Vector2(0, 8), "GATE", HORIZONTAL_ALIGNMENT_CENTER, TILE, 8, Color(1, 1, 1, 0.9 - dim))


func _draw_exit_gate(r: Rect2, dim: float, font: Font) -> void:
    var p: Vector2 = r.position
    var open: bool = game.collected >= game.fruit_total
    cv.draw_rect(Rect2(p + Vector2(3, 2), Vector2(30, 32)), STONE.darkened(dim))
    cv.draw_rect(Rect2(p + Vector2(3, 2), Vector2(30, 5)), STONE_LIGHT.darkened(dim))
    if open:
        var pulse: float = 0.75 + 0.25 * sin(clock * 3.0)
        cv.draw_rect(Rect2(p + Vector2(7, 8), Vector2(22, 22)), Color(1.0, 0.95, 0.55, pulse).darkened(dim))
        cv.draw_rect(Rect2(p + Vector2(7, 8), Vector2(4, 22)), Color(0.25, 0.25, 0.3).darkened(dim))
        cv.draw_rect(Rect2(p + Vector2(25, 8), Vector2(4, 22)), Color(0.25, 0.25, 0.3).darkened(dim))
        for i in range(4):
            var a: float = float(i) * 0.5 + clock * 0.5
            cv.draw_circle(p + Vector2(18, 19) + Vector2(cos(a * 3.0), sin(a * 4.0)) * 7.0, 1.4, Color(1, 1, 1, 0.9))
        cv.draw_string(font, p + Vector2(0, 8), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, TILE, 8, Color(0.6, 1.0, 0.6, 1.0 - dim))
    else:
        cv.draw_rect(Rect2(p + Vector2(7, 8), Vector2(22, 22)), Color(0.12, 0.12, 0.15).darkened(dim))
        for i in range(5):
            cv.draw_line(p + Vector2(9 + i * 4.5, 8), p + Vector2(9 + i * 4.5, 30), Color(0.55, 0.55, 0.6).darkened(dim), 1.6)
        cv.draw_rect(Rect2(p + Vector2(14, 17), Vector2(8, 7)), GOLD.darkened(dim))
        cv.draw_arc(p + Vector2(18, 17), 3.5, PI, TAU, 8, GOLD.darkened(dim), 1.5)
        cv.draw_string(font, p + Vector2(0, 8), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, TILE, 8, Color(1, 0.6, 0.5, 1.0 - dim))


func _draw_fountain(r: Rect2, dim: float) -> void:
    var c: Vector2 = r.get_center()
    var all_fruit: bool = game.collected >= game.fruit_total
    cv.draw_rect(r.grow(-1), STONE_LIGHT.darkened(0.12 + dim))
    cv.draw_circle(c, 17, STONE.darkened(dim))
    cv.draw_circle(c, 14, WATER_COL.darkened(dim))
    cv.draw_arc(c, 8.0 + sin(clock * 3.0) * 1.5, 0.0, TAU, 20, WATER_LIGHT.darkened(dim), 1.5)
    cv.draw_circle(c, 4, STONE_LIGHT.darkened(dim))
    var jets: int = 7 if all_fruit else 3
    for i in range(jets):
        var k: float = fposmod(clock * 0.9 + float(i) / float(jets), 1.0)
        var a: float = TAU * float(i) / float(jets)
        var jp: Vector2 = c + Vector2(cos(a) * 9.0 * k, sin(a) * 4.5 * k - 15.0 * sin(PI * k))
        cv.draw_circle(jp, 1.8, Color(WATER_LIGHT, 1.0 - k * 0.5).darkened(dim))
    if all_fruit:
        cv.draw_arc(c, 22.0 + sin(clock * 4.0) * 2.5, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.8), 2.5)


# =================================================================== objects

func _draw_butterflies(level: LevelScript, vis: Dictionary) -> void:
    for b in butterflies:
        var ph: float = b["phase"]
        var bp: Vector2 = b["anchor"] + Vector2(cos(clock * 0.7 + ph) * 22.0, sin(clock * 1.1 + ph * 2.0) * 14.0)
        if not vis.has(level.tile_of(bp)):
            continue
        var flap: float = absf(sin(clock * 11.0 + ph))
        var col: Color = b["col"]
        cv.draw_circle(bp + Vector2(-2.5 * flap - 0.5, 0), 2.6, col)
        cv.draw_circle(bp + Vector2(2.5 * flap + 0.5, 0), 2.6, col)
        cv.draw_circle(bp, 1.0, Color(0.2, 0.15, 0.15))


func _draw_trap(t: Vector2i, lit: bool, level: LevelScript) -> void:
    var c: Vector2 = level.tile_center(t)
    var dim: float = 0.0 if lit else 0.45
    var pulse: float = 0.5 + 0.5 * sin(clock * 5.0)
    cv.draw_circle(c, 14, Color(0.30, 0.20, 0.12).darkened(dim))
    for i in range(8):
        var ang: float = TAU * float(i) / 8.0
        var tip: Vector2 = c + Vector2(cos(ang), sin(ang)) * 13.0
        var base_a: Vector2 = c + Vector2(cos(ang + 0.25), sin(ang + 0.25)) * 5.0
        var base_b: Vector2 = c + Vector2(cos(ang - 0.25), sin(ang - 0.25)) * 5.0
        cv.draw_colored_polygon(PackedVector2Array([tip, base_a, base_b]), Color(0.85, 0.25, 0.2).darkened(dim))
    cv.draw_arc(c, 16, 0.0, TAU, 20, Color(1.0, 0.4, 0.2, 0.25 + 0.4 * pulse * (0.0 if not lit else 1.0)), 2.0)
    if game.disarm_progress > 0.0 and game.disarm_target == t:
        cv.draw_arc(c, 19, -PI / 2.0, -PI / 2.0 + TAU * game.disarm_progress, 24, Color(0.4, 0.85, 1.0), 3.0)


func _draw_fruit(f: Dictionary, level: LevelScript, vis: Dictionary) -> void:
    var c: Vector2 = level.tile_center(f["tile"])
    var dim: float = 0.0 if vis.has(f["tile"]) else 0.45
    var bob: float = sin(clock * 3.0 + c.x) * 2.0
    if f["kind"] == "ground":
        # basket of red apples (MNKI)
        cv.draw_circle(c + Vector2(0, 8), 12, Color(0, 0, 0, 0.18))
        cv.draw_rect(Rect2(c + Vector2(-11, 0), Vector2(22, 12)), WOOD.darkened(dim))
        cv.draw_rect(Rect2(c + Vector2(-11, 0), Vector2(22, 3)), WOOD_LIGHT.darkened(dim))
        for i in range(3):
            var ap: Vector2 = c + Vector2(-7 + i * 7, -3 + (i % 2) * 2)
            cv.draw_circle(ap, 5.5, Color(0.88, 0.14, 0.14).darkened(dim))
            cv.draw_circle(ap + Vector2(-1.5, -1.5), 1.5, Color(1, 0.7, 0.7, 0.85).darkened(dim))
        cv.draw_circle(c + Vector2(4, -10), 2.5, Color(0.2, 0.6, 0.2).darkened(dim))
        cv.draw_arc(c + Vector2(0, -2), 17, 0.0, TAU, 20, Color(1, 0.6, 0.6, 0.4 + 0.15 * sin(clock * 4.0)).darkened(dim), 1.5)
    else:
        # little pear tree (Swan)
        cv.draw_circle(c + Vector2(3, 6), 14, Color(0, 0, 0, 0.18))
        cv.draw_rect(Rect2(c + Vector2(-2.5, 2), Vector2(5, 12)), WOOD.darkened(dim))
        cv.draw_circle(c + Vector2(0, -3), 13, Color(0.14, 0.48, 0.22).darkened(dim))
        cv.draw_circle(c + Vector2(-3, -6), 8, Color(0.26, 0.62, 0.30).darkened(dim))
        for i in range(3):
            var pp: Vector2 = c + Vector2(-6 + i * 6, -4 + (i % 2) * 5 + bob * 0.5)
            cv.draw_circle(pp + Vector2(0, 2), 3.4, Color(0.96, 0.80, 0.22).darkened(dim))
            cv.draw_circle(pp + Vector2(0, -2), 2.3, Color(0.96, 0.80, 0.22).darkened(dim))
        cv.draw_arc(c + Vector2(0, -2 + bob), 18, 0.0, TAU, 20, Color(1, 1, 0.7, 0.45).darkened(dim), 1.5)


# =================================================================== teddies

func _draw_guard(g, font: Font) -> void:
    var p: Vector2 = g.pos
    var f: Vector2 = g.facing
    if f.length() < 0.1:
        f = Vector2.RIGHT
    f = f.normalized()
    cv.draw_circle(p + Vector2(2, 12), 12, Color(0, 0, 0, 0.2))
    if game.tex_guard != null:
        cv.draw_texture_rect(game.tex_guard, Rect2(p - Vector2(20, 26), Vector2(40, 52)), false)
    else:
        _draw_teddy(g, p, f)
    var bp: Vector2 = p + Vector2(-14, -38)
    cv.draw_rect(Rect2(bp, Vector2(28, 4)), Color(0, 0, 0, 0.6))
    cv.draw_rect(Rect2(bp, Vector2(28.0 * clampf(g.alert, 0.0, 1.0), 4)), Color(1.0, 0.3, 0.2))
    var icon: String = ""
    if game.harmed_guard == g:
        icon = "x_x"
    elif g.state == GuardScript.CHASE:
        icon = "!"
    elif g.state == GuardScript.SUSPICIOUS or g.state == GuardScript.SEARCH or g.noticing:
        icon = "?"
    elif g.state == GuardScript.RECOVER:
        icon = "~"
    if icon != "":
        cv.draw_texture_rect(game.alert_tex[icon], Rect2(p + Vector2(-11, -64), Vector2(22, 22)), false)


func _draw_teddy(g, p: Vector2, f: Vector2) -> void:
    var mood: String = "calm"
    if game.harmed_guard == g:
        mood = "hurt"
    elif g.state == GuardScript.RECOVER:
        mood = "happy"
    elif g.state == GuardScript.CHASE:
        mood = "angry"
    var walking: bool = (not g.path.is_empty()) or g.state == GuardScript.CHASE
    Sprites.teddy(cv, p, f, g.variant, mood, clock, walking)


# =================================================================== heroes

func _draw_hero(h, font: Font) -> void:
    var p: Vector2 = h.pos
    var is_swan: bool = h.kind == "swan"
    var f: Vector2 = h.facing
    if f.length() < 0.1:
        f = Vector2.DOWN
    var alpha: float = 0.55 if h.hidden else 1.0
    if is_swan and game.swan_inv > 0.0 and int(clock * 14.0) % 2 == 0:
        alpha = 0.45
    var tex: Texture2D = game.tex_swan if is_swan else game.tex_mnki
    var is_leader: bool = h == game.leader

    if is_swan:
        var bob: float = sin(clock * 5.0) * 2.0
        cv.draw_circle(p + Vector2(5, 13), 9, Color(0, 0, 0, 0.22))
        var q: Vector2 = p + Vector2(0, bob - 6)
        if tex != null:
            cv.draw_texture_rect(tex, Rect2(q - Vector2(20, 22), Vector2(40, 48)), false)
        else:
            Sprites.swan(cv, q, f, alpha, clock)
        if is_leader:
            cv.draw_arc(q, 17, 0.0, TAU, 24, Color(1.0, 0.9, 0.2), 2.0)
    else:
        cv.draw_circle(p + Vector2(3, 10), 10, Color(0, 0, 0, 0.22))
        if tex != null:
            cv.draw_texture_rect(tex, Rect2(p - Vector2(20, 26), Vector2(40, 52)), false)
        else:
            Sprites.mnki(cv, p, f, alpha, h.sneaking)
        if is_leader:
            cv.draw_arc(p, 16, 0.0, TAU, 24, Color(1.0, 0.9, 0.2), 2.0)

    var label: String = "LEAD"
    if not is_leader:
        label = "follows"
        if game.follower_mode == "hold":
            label = "holding"
        elif h.waiting:
            label = "waiting..."
        elif game.follower_mode == "goto":
            label = "going"
        elif h.blocked:
            label = "no route"
    elif h.kind == "mnki" and h.hidden:
        label = "hidden"
    # when both friends stand together, put the follower's label underneath so they don't overlap
    var label_y: float = -26.0
    if not is_leader and p.distance_to(game.leader.pos) < 36.0:
        label_y = 34.0
    cv.draw_string(font, p + Vector2(-40, label_y), label, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 10, Color(1, 1, 1, 0.9))


# ================================================================ sling towers

func _draw_tower(tw, lit: bool, font: Font) -> void:
    var c: Vector2 = tw.pos
    var dim: float = 0.0 if lit else 0.35
    # range ring: shows where this teddy can reach Swan (stronger once it has noticed her)
    if lit:
        var ra: float = 0.10 if tw.state == 0 else 0.30
        cv.draw_arc(c, tw.RANGE * TILE, 0.0, TAU, 72, Color(1.0, 0.3, 0.2, ra), 2.0)
    # stone tower body
    cv.draw_circle(c + Vector2(3, 17), 15, Color(0, 0, 0, 0.22))
    cv.draw_rect(Rect2(c + Vector2(-15, -8), Vector2(30, 26)), STONE.darkened(0.15 + dim))
    cv.draw_rect(Rect2(c + Vector2(-15, -8), Vector2(30, 6)), STONE_LIGHT.darkened(dim))
    for row in range(3):
        var yy: float = -2.0 + row * 7.0
        cv.draw_line(c + Vector2(-15, yy + 5), c + Vector2(15, yy + 5), STONE.darkened(0.4 + dim), 1.0)
        var off: float = 0.0 if row % 2 == 0 else 7.0
        for bx in range(2):
            cv.draw_line(c + Vector2(-8 + off + bx * 14.0, yy), c + Vector2(-8 + off + bx * 14.0, yy + 5), STONE.darkened(0.4 + dim), 1.0)
    cv.draw_rect(Rect2(c + Vector2(-4, 8), Vector2(8, 10)), Color(0.22, 0.14, 0.08).darkened(dim))
    # wooden platform
    cv.draw_rect(Rect2(c + Vector2(-19, -14), Vector2(38, 8)), WOOD.darkened(dim))
    cv.draw_rect(Rect2(c + Vector2(-19, -14), Vector2(38, 3)), WOOD_LIGHT.darkened(dim))
    if not lit:
        return
    # the sling teddy (angry while taking aim, happy after a hit)
    var mood: String = "calm"
    if tw.state == 2 or tw.state == 1:
        mood = "angry"
    var bob: float = sin(clock * 3.0 + float(tw.tile.x)) * 0.8
    var tp: Vector2 = c + Vector2(0, -20 + bob)
    Sprites.teddy(cv, tp, tw.facing, 2, mood, clock, false)
    # the sling: a Y-stick and a leather strap that swings back while aiming and snaps forward on release
    var f: Vector2 = tw.facing
    var hand: Vector2 = tp + Vector2(11.5, 3.0)
    var pull: float = 0.0
    if tw.state == 2:
        pull = clampf(1.0 - tw.timer / 1.1, 0.0, 1.0)
    var rest: Vector2 = hand + Vector2(4, -11)
    var back: Vector2 = hand + Vector2(-f.x * 9.0 * pull, -f.y * 6.0 * pull) + Vector2(2, -8)
    var snap: Vector2 = hand + Vector2(f.x * 10.0 * tw.recoil, f.y * 8.0 * tw.recoil) + Vector2(2, -10)
    var strap: Vector2 = back if tw.state == 2 else (snap if tw.recoil > 0.05 else rest)
    cv.draw_line(hand, hand + Vector2(0, -10), WOOD_LIGHT, 2.0)
    cv.draw_line(hand + Vector2(0, -10), hand + Vector2(-3, -14), WOOD_LIGHT, 2.0)
    cv.draw_line(hand + Vector2(0, -10), hand + Vector2(3, -14), WOOD_LIGHT, 2.0)
    cv.draw_line(hand + Vector2(-3, -14), strap, Color(0.35, 0.2, 0.1), 1.2)
    cv.draw_line(hand + Vector2(3, -14), strap, Color(0.35, 0.2, 0.1), 1.2)
    if tw.state == 2:
        cv.draw_circle(strap, 2.2, Color(0.7, 0.68, 0.62))
    # railing in front of the teddy
    cv.draw_rect(Rect2(c + Vector2(-19, -12), Vector2(38, 4)), WOOD_LIGHT)
    for px in range(5):
        cv.draw_rect(Rect2(c + Vector2(-19 + px * 9.0, -16), Vector2(2, 8)), WOOD)
    # little flag
    cv.draw_line(c + Vector2(17, -14), c + Vector2(17, -46), WOOD, 2.0)
    var wave: float = sin(clock * 4.0) * 2.0
    cv.draw_colored_polygon(PackedVector2Array([c + Vector2(17, -46), c + Vector2(30, -42 + wave), c + Vector2(17, -37)]), Color(0.85, 0.22, 0.2))
    # "?" / "!" over the teddy and a notice bar
    var icon: String = ""
    if tw.state == 1:
        icon = "?"
    elif tw.state == 2:
        icon = "!"
    if icon != "":
        cv.draw_texture_rect(game.alert_tex[icon], Rect2(c + Vector2(-11, -76), Vector2(22, 22)), false)
    if tw.alert > 0.02:
        var bp: Vector2 = c + Vector2(-14, -48)
        cv.draw_rect(Rect2(bp, Vector2(28, 4)), Color(0, 0, 0, 0.6))
        cv.draw_rect(Rect2(bp, Vector2(28.0 * clampf(tw.alert, 0.0, 1.0), 4)), Color(1.0, 0.3, 0.2))


## The red landing spot of the pebble: it shrinks to a point just before the shot.
func _draw_reticle(tw) -> void:
    var p: Vector2 = tw.aim_pt
    var k: float = clampf(1.0 - tw.timer / 1.1, 0.0, 1.0)
    var locked: bool = tw.timer <= 0.3
    var col := Color(1.0, 0.25, 0.2, 0.55 + 0.35 * k)
    cv.draw_line(tw.pos + Vector2(0, -18), p, Color(1.0, 0.3, 0.2, 0.18), 1.5)
    cv.draw_arc(p, 20.0, 0.0, TAU, 28, col, 2.0)
    cv.draw_arc(p, lerpf(20.0, 6.0, k), 0.0, TAU, 20, Color(1.0, 0.8, 0.3, 0.8), 2.0)
    cv.draw_line(p + Vector2(-26, 0), p + Vector2(-10, 0), col, 2.0)
    cv.draw_line(p + Vector2(26, 0), p + Vector2(10, 0), col, 2.0)
    cv.draw_line(p + Vector2(0, -26), p + Vector2(0, -10), col, 2.0)
    cv.draw_line(p + Vector2(0, 26), p + Vector2(0, 10), col, 2.0)
    if locked:
        cv.draw_circle(p, 3.0, Color(1, 1, 1, 0.9))


func _draw_stone(s: Dictionary) -> void:
    var k: float = clampf(float(s["age"]) / float(s["dur"]), 0.0, 1.0)
    var from: Vector2 = s["from"]
    var to: Vector2 = s["to"]
    var ground: Vector2 = from.lerp(to, k)
    var height: float = sin(k * PI) * 46.0
    cv.draw_circle(ground + Vector2(1, 2), 3.2, Color(0, 0, 0, 0.3))
    var p: Vector2 = ground + Vector2(0, -height)
    cv.draw_circle(p, 4.2, Color(0.35, 0.33, 0.30))
    cv.draw_circle(p + Vector2(-1, -1), 2.4, Color(0.65, 0.62, 0.56))


## Little stars circle Swan's head while she is dizzy.
func _draw_dizzy_stars() -> void:
    if game.swan_stun <= 0.0:
        return
    var c: Vector2 = game.swan.pos + Vector2(0, -26)
    for i in range(3):
        var a: float = clock * 6.0 + float(i) * TAU / 3.0
        var sp: Vector2 = c + Vector2(cos(a) * 13.0, sin(a) * 4.5)
        cv.draw_circle(sp, 2.6, GOLD)
        cv.draw_circle(sp, 1.2, Color(1, 1, 0.8))
