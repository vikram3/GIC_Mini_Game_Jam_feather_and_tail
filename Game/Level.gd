extends RefCounted
## Maze data for Level 1: generation, collision queries and pathfinding.
## Tile grid is (W x H). Maze "cells" sit on odd tile coordinates.

const TILE := 36

const FLOOR := 0
const WALL := 1    # tall maze wall: blocks everyone and blocks sight
const HEDGE := 2   # cuttable hedge: blocks MNKI and sight; Swan flies over it
const LOW := 3     # low garden wall: blocks MNKI, Swan flies over, does not block sight
const BUSH := 4    # hiding spot, walkable
const WATER := 5   # stream / pond: blocks MNKI, Swan flies over, does not block sight
const BRIDGE := 6  # little wooden bridge over a stream: walkable by both

const CW := 15
const CH := 9
const W := CW * 2 + 1
const H := CH * 2 + 1

var tiles: Array = []
var start_tile := Vector2i(1, 1)
var fountain_tile := Vector2i(W - 2, H - 2)
var gate_tile := Vector2i(0, 1)            # entrance gate (in the west wall, next to the start)
var exit_tile := Vector2i(W - 1, H - 2)    # exit gate (in the east wall, next to the fountain)
var fruits: Array = []        # {tile: Vector2i, kind: "ground"/"tree", got: bool}
var guard_routes: Array = []  # each: Array of 2 waypoint tiles
var towers: Array = []        # tiles (Vector2i) of watchtowers manned by a sling teddy
var links: Dictionary = {}    # maze cell -> Array of connected cells
var ground: AStarGrid2D
var air: AStarGrid2D
var safe: AStarGrid2D        # ground grid where armed traps count as solid (guards avoid them)
var traps: Dictionary = {}   # tile -> true while armed
var rng := RandomNumberGenerator.new()
var version: int = 0         # bumped whenever the terrain changes (guards re-scan their view cones)


# ---------------------------------------------------------------- generation

func generate(seed_value: int) -> void:
    for attempt in range(60):
        if _try_generate(seed_value + attempt * 7919, true):
            return
    _try_generate(seed_value, false)


func _try_generate(seed_value: int, strict: bool) -> bool:
    rng.seed = seed_value
    tiles = []
    links = {}
    fruits = []
    guard_routes = []
    towers = []
    traps = {}
    for y in range(H):
        var row: Array = []
        for x in range(W):
            row.append(WALL)
        tiles.append(row)
    _carve()
    var dist: Dictionary = _bfs(Vector2i(0, 0))
    var picks: Array = _pick_nooks(dist)
    if strict and picks.size() < 5:
        return false
    _place_nooks(picks)
    _place_shortcuts(picks)
    _place_bushes(picks)
    _place_bridges(picks)
    _build_grids()
    _make_routes(dist, picks)
    _place_traps()
    _place_towers()
    return true


func _carve() -> void:
    var visited := {}
    var stack: Array = [Vector2i(0, 0)]
    visited[Vector2i(0, 0)] = true
    set_t(cell_tile(Vector2i(0, 0)), FLOOR)
    var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    while stack.size() > 0:
        var c: Vector2i = stack.back()
        var opts: Array = []
        for d in dirs:
            var nb: Vector2i = c + d
            if nb.x >= 0 and nb.y >= 0 and nb.x < CW and nb.y < CH and not visited.has(nb):
                opts.append(nb)
        if opts.is_empty():
            stack.pop_back()
            continue
        var nxt: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
        visited[nxt] = true
        set_t(cell_tile(nxt), FLOOR)
        set_t(passage_tile(c, nxt), FLOOR)
        _link(c, nxt)
        stack.append(nxt)


func _link(a: Vector2i, b: Vector2i) -> void:
    if not links.has(a):
        links[a] = []
    if not links.has(b):
        links[b] = []
    links[a].append(b)
    links[b].append(a)


func _bfs(src: Vector2i) -> Dictionary:
    var dist := {}
    dist[src] = 0
    var q: Array = [src]
    var i: int = 0
    while i < q.size():
        var c: Vector2i = q[i]
        i += 1
        for nb in links.get(c, []):
            if not dist.has(nb):
                dist[nb] = int(dist[c]) + 1
                q.append(nb)
    return dist


func _shuffle(a: Array) -> void:
    for i in range(a.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var tmp = a[i]
        a[i] = a[j]
        a[j] = tmp


func _pick_nooks(dist: Dictionary) -> Array:
    var far_cell := Vector2i(CW - 1, CH - 1)
    var dead: Array = []
    for c in links:
        if links[c].size() == 1 and c != Vector2i(0, 0) and c != far_cell and int(dist[c]) >= 6:
            dead.append(c)
    _shuffle(dead)
    var picks: Array = []
    for c in dead:
        var ok: bool = true
        for p in picks:
            if absi(c.x - p.x) + absi(c.y - p.y) < 4:
                ok = false
        if ok:
            picks.append(c)
        if picks.size() >= 5:
            break
    picks.sort_custom(func(a, b): return int(dist[a]) < int(dist[b]))
    return picks


func _place_nooks(picks: Array) -> void:
    # order by distance from start: ground, tree, hedge-door, ground, tree
    var kinds: Array = ["ground", "tree", "hedge", "ground", "tree"]
    for i in range(picks.size()):
        var c: Vector2i = picks[i]
        var nb: Vector2i = links[c][0]
        var door: Vector2i = passage_tile(c, nb)
        var kind: String = kinds[i]
        if kind == "tree":
            set_t(door, LOW)
        elif kind == "hedge":
            set_t(door, HEDGE)
        var fruit_kind: String = "tree" if kind == "tree" else "ground"
        fruits.append({"tile": cell_tile(c), "kind": fruit_kind, "got": false})


func _place_shortcuts(picks: Array) -> void:
    var blocked := {}
    for c in picks:
        blocked[c] = true
    var cands: Array = []
    var cache := {}
    for cy in range(CH):
        for cx in range(CW):
            var a := Vector2i(cx, cy)
            for d in [Vector2i(1, 0), Vector2i(0, 1)]:
                var b: Vector2i = a + d
                if b.x >= CW or b.y >= CH:
                    continue
                if blocked.has(a) or blocked.has(b):
                    continue
                if links[a].has(b):
                    continue
                if not cache.has(a):
                    cache[a] = _bfs(a)
                if int(cache[a].get(b, 0)) >= 10:
                    cands.append([a, b])
    _shuffle(cands)
    var count: int = mini(14, cands.size())
    for i in range(count):
        var pair: Array = cands[i]
        set_t(passage_tile(pair[0], pair[1]), HEDGE)


func _place_bushes(picks: Array) -> void:
    var skip := {}
    for c in picks:
        skip[c] = true
    skip[Vector2i(0, 0)] = true
    skip[Vector2i(CW - 1, CH - 1)] = true
    var cells: Array = []
    for c in links:
        if not skip.has(c):
            cells.append(c)
    _shuffle(cells)
    var count: int = mini(22, cells.size())
    for i in range(count):
        set_t(cell_tile(cells[i]), BUSH)


func _place_bridges(picks: Array) -> void:
    ## Small streams cut across a few corridors; a wooden bridge carries the path over.
    ## The water sits on the wall pillars beside the corridor, so the maze layout is unchanged.
    var avoid := {}
    for c in picks:
        avoid[c] = true
    avoid[Vector2i(0, 0)] = true
    avoid[Vector2i(CW - 1, CH - 1)] = true
    var cands: Array = []
    for c in links:
        for nb in links[c]:
            if nb.x < c.x or (nb.x == c.x and nb.y < c.y):
                continue
            if avoid.has(c) or avoid.has(nb):
                continue
            var p: Vector2i = passage_tile(c, nb)
            if tile_at(p) != FLOOR:
                continue
            var side_a: Vector2i = p + (Vector2i(0, -1) if nb.x != c.x else Vector2i(-1, 0))
            var side_b: Vector2i = p + (Vector2i(0, 1) if nb.x != c.x else Vector2i(1, 0))
            var ok: bool = true
            for s in [side_a, side_b]:
                if s.x < 1 or s.y < 1 or s.x > W - 2 or s.y > H - 2 or tile_at(s) != WALL:
                    ok = false
            if ok:
                cands.append([p, side_a, side_b])
    _shuffle(cands)
    var placed: Array = []
    for cand in cands:
        var far_enough: bool = true
        for q in placed:
            if absi(cand[0].x - q.x) + absi(cand[0].y - q.y) < 8:
                far_enough = false
        if absi(cand[0].x - start_tile.x) + absi(cand[0].y - start_tile.y) < 5:
            far_enough = false
        if not far_enough:
            continue
        set_t(cand[0], BRIDGE)
        set_t(cand[1], WATER)
        set_t(cand[2], WATER)
        placed.append(cand[0])
        if placed.size() >= 4:
            break


func _make_routes(dist: Dictionary, picks: Array) -> void:
    var special := {}
    for c in picks:
        special[c] = true
    special[Vector2i(0, 0)] = true
    special[Vector2i(CW - 1, CH - 1)] = true
    var maxd: int = 1
    for c in dist:
        maxd = maxi(maxd, int(dist[c]))
    var far_dist: Dictionary = _bfs(Vector2i(CW - 1, CH - 1))
    guard_routes.append(_route_from(dist, maxd * 0.25, maxd * 0.45, special))
    guard_routes.append(_route_from(dist, maxd * 0.45, maxd * 0.70, special))
    guard_routes.append(_route_from(far_dist, 3.0, 6.0, special))
    guard_routes.append(_route_from(dist, maxd * 0.60, maxd * 0.90, special))   # a fourth patrol: more teddies to dodge


func _route_from(d_map: Dictionary, lo: float, hi: float, special: Dictionary) -> Array:
    var cands: Array = []
    for c in d_map:
        if special.has(c):
            continue
        var dv: float = float(d_map[c])
        if dv >= lo and dv <= hi:
            cands.append(c)
    if cands.is_empty():
        for c in d_map:
            if not special.has(c):
                cands.append(c)
    _shuffle(cands)
    var a: Vector2i = cands[0]
    var from_a: Dictionary = _bfs(a)
    var bs: Array = []
    for c in from_a:
        if special.has(c):
            continue
        var dv2: int = int(from_a[c])
        if dv2 >= 6 and dv2 <= 11:
            bs.append(c)
    var b: Vector2i = a
    if not bs.is_empty():
        _shuffle(bs)
        b = bs[0]
    return [cell_tile(a), cell_tile(b)]


# ------------------------------------------------------------------- tiles

func cell_tile(c: Vector2i) -> Vector2i:
    return Vector2i(c.x * 2 + 1, c.y * 2 + 1)


func passage_tile(a: Vector2i, b: Vector2i) -> Vector2i:
    return Vector2i(a.x + b.x + 1, a.y + b.y + 1)


func in_bounds(t: Vector2i) -> bool:
    return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H


func tile_at(t: Vector2i) -> int:
    if not in_bounds(t):
        return WALL
    return int(tiles[t.y][t.x])


func set_t(t: Vector2i, v: int) -> void:
    tiles[t.y][t.x] = v


func tile_of(p: Vector2) -> Vector2i:
    return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func tile_center(t: Vector2i) -> Vector2:
    return (Vector2(t) + Vector2(0.5, 0.5)) * TILE


func solid_for(t: Vector2i, air_unit: bool) -> bool:
    var k: int = tile_at(t)
    if air_unit:
        return k == WALL
    return k == WALL or k == HEDGE or k == LOW or k == WATER


func blocks_sight(t: Vector2i) -> bool:
    var k: int = tile_at(t)
    return k == WALL or k == HEDGE


func cut_hedge(t: Vector2i) -> void:
    if tile_at(t) == HEDGE:
        version += 1
        set_t(t, FLOOR)
        ground.set_point_solid(t, false)
        safe.set_point_solid(t, false)


# ----------------------------------------------------------------- queries

func has_los(a: Vector2i, b: Vector2i) -> bool:
    var x0: int = a.x
    var y0: int = a.y
    var x1: int = b.x
    var y1: int = b.y
    var dx: int = absi(x1 - x0)
    var dy: int = absi(y1 - y0)
    var sx: int = 1 if x0 < x1 else -1
    var sy: int = 1 if y0 < y1 else -1
    var err: int = dx - dy
    while true:
        if (x0 != a.x or y0 != a.y) and (x0 != x1 or y0 != y1):
            if x0 < 0 or y0 < 0 or x0 >= W or y0 >= H:
                return false
            var k: int = tiles[y0][x0]
            if k == WALL or k == HEDGE:
                return false
        if x0 == x1 and y0 == y1:
            break
        var e2: int = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy
    return true


func box_blocked(p: Vector2, r: float, air_unit: bool) -> bool:
    var offs: Array = [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]
    for o in offs:
        if solid_for(tile_of(p + o), air_unit):
            return true
    return false


func move_box(pos: Vector2, motion: Vector2, r: float, air_unit: bool) -> Vector2:
    var p: Vector2 = pos
    var nx := Vector2(p.x + motion.x, p.y)
    if not box_blocked(nx, r, air_unit):
        p = nx
    var ny := Vector2(p.x, p.y + motion.y)
    if not box_blocked(ny, r, air_unit):
        p = ny
    return p


func _build_grids() -> void:
    ground = _make_grid()
    air = _make_grid()
    safe = _make_grid()
    for y in range(H):
        for x in range(W):
            var id := Vector2i(x, y)
            var k: int = int(tiles[y][x])
            ground.set_point_solid(id, k == WALL or k == HEDGE or k == LOW or k == WATER)
            safe.set_point_solid(id, k == WALL or k == HEDGE or k == LOW or k == WATER)
            air.set_point_solid(id, k == WALL)


func _make_grid() -> AStarGrid2D:
    var g := AStarGrid2D.new()
    g.region = Rect2i(0, 0, W, H)
    g.cell_size = Vector2(1, 1)
    g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    g.update()
    return g


func find_path(a: Vector2i, b: Vector2i, air_unit: bool) -> Array:
    var g: AStarGrid2D = air if air_unit else ground
    if not in_bounds(a) or not in_bounds(b):
        return []
    if g.is_point_solid(a) or g.is_point_solid(b):
        return []
    var p: Array = g.get_id_path(a, b)
    return p


## Path for a careful guard: never steps on an armed trap.
func find_path_safe(a: Vector2i, b: Vector2i) -> Array:
    if not in_bounds(a) or not in_bounds(b):
        return []
    if safe.is_point_solid(a) or safe.is_point_solid(b):
        return []
    var p: Array = safe.get_id_path(a, b)
    return p


func disarm_trap(t: Vector2i) -> void:
    if traps.has(t):
        traps.erase(t)
        safe.set_point_solid(t, false)


func _place_traps() -> void:
    # Never on a guard's patrol path, so patrols always stay possible.
    var route_tiles := {}
    for r in guard_routes:
        var p: Array = find_path(r[0], r[1], false)
        for t in p:
            route_tiles[t] = true
    var cands: Array = []
    for c in links:
        for nb in links[c]:
            if nb.x < c.x or (nb.x == c.x and nb.y < c.y):
                continue
            var t2: Vector2i = passage_tile(c, nb)
            if tile_at(t2) != FLOOR:
                continue
            if route_tiles.has(t2):
                continue
            if absi(t2.x - start_tile.x) + absi(t2.y - start_tile.y) < 9:
                continue
            if absi(t2.x - fountain_tile.x) + absi(t2.y - fountain_tile.y) < 3:
                continue
            cands.append(t2)
    _shuffle(cands)
    var count: int = mini(8, cands.size())
    for i in range(count):
        var tt: Vector2i = cands[i]
        traps[tt] = true
        safe.set_point_solid(tt, true)


## Watchtowers stand on maze pillars (wall tiles), spread far apart and away from the start and the exit.
func _place_towers() -> void:
    var cands: Array = []
    for y in range(2, H - 2, 2):
        for x in range(2, W - 2, 2):
            var t := Vector2i(x, y)
            if tile_at(t) != WALL:
                continue
            if absi(x - start_tile.x) + absi(y - start_tile.y) < 10:
                continue
            if absi(x - fountain_tile.x) + absi(y - fountain_tile.y) < 7:
                continue
            cands.append(t)
    _shuffle(cands)
    for t in cands:
        var ok: bool = true
        for q in towers:
            if absi(t.x - q.x) + absi(t.y - q.y) < 14:
                ok = false
        if ok:
            towers.append(t)
        if towers.size() >= 2:
            break


func nearest_free(t: Vector2i, air_unit: bool, radius: int) -> Vector2i:
    var best := Vector2i(-1, -1)
    var best_d: float = 9999.0
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            var c := Vector2i(t.x + dx, t.y + dy)
            if not in_bounds(c) or solid_for(c, air_unit):
                continue
            var d: float = Vector2(dx, dy).length()
            if d < best_d:
                best_d = d
                best = c
    return best


## Advance along `path` (array of tiles, mutated) by speed*delta pixels.
func follow(path: Array, pos: Vector2, speed: float, delta: float) -> Vector2:
    var p: Vector2 = pos
    var remaining: float = speed * delta
    while remaining > 0.0 and path.size() > 0:
        var target: Vector2 = tile_center(path[0])
        var to: Vector2 = target - p
        var d: float = to.length()
        if d <= remaining:
            p = target
            remaining -= d
            path.pop_front()
        else:
            p += to / d * remaining
            remaining = 0.0
    return p
