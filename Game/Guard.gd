extends RefCounted
## A teddy-bear garden guard. Teddies never attack: if they catch MNKI they
## politely escort him back to the gate. They patrol, notice, chase and search.

const LevelScript = preload("res://Game/Level.gd")

const TILE := 36

const PATROL := 0
const SUSPICIOUS := 1   # walking to investigate a noise
const CHASE := 2
const SEARCH := 3       # lost the target, looking around
const RECOVER := 4      # just escorted someone, taking a breather

const PATROL_SPEED := 62.0
const INVESTIGATE_SPEED := 82.0
const CHASE_SPEED := 124.0     # faster than MNKI's walk (105): running in the open will not save you - hide!
const VIEW_RANGE := 6.0        # tiles
const HALF_ANGLE_COS := 0.72   # roughly a 88 degree cone
const CLOSE_RANGE := 1.3       # tiles: notices anything this close in LOS
const HIDDEN_REACH := 1.1      # tiles: a chasing teddy can only spot a HIDDEN MNKI this close
const HIDE_SAFE := 2.3         # tiles: hide while the teddy is farther than this and it loses you...
const HIDE_LOSE_TIME := 0.5    # ...after this long. Closer than HIDE_SAFE and it walks right up to the bush.
const GIVE_UP_TIME := 6.5      # seconds without seeing MNKI (and not hidden) before a chase ends

var variant: int = 0           # which teddy fur colour to draw (see WorldDraw.TEDDY_FUR)
var pos := Vector2.ZERO
var facing := Vector2.RIGHT
var state: int = PATROL
var route: Array = []
var route_i: int = 1
var path: Array = []
var alert: float = 0.0
var timer: float = 0.0
var wait_at_wp: bool = false
var noticing: bool = false
var last_seen := Vector2i(-1, -1)
var lost_timer: float = 0.0
var repath_cd: float = 0.0
var cone: Dictionary = {}
var hide_t: float = 0.0
var lost_by_hiding: bool = false   # read (and cleared) by Game.gd to play the dialogue

# audio bookkeeping (used by Game.gd)
var snd_noticing: bool = false
var step_dist: float = 0.0
var last_pos := Vector2.ZERO

# view-cone cache: the cone is only re-scanned when something relevant changed
var _cone_tile := Vector2i(-9999, -9999)
var _cone_face := Vector2.ZERO
var _cone_ver: int = -1


func calm() -> void:
    state = PATROL
    alert = 0.0
    path = []
    wait_at_wp = false
    noticing = false
    lost_timer = 0.0
    hide_t = 0.0


func update(delta: float, game: Node2D) -> void:
    var level: LevelScript = game.level
    var mn = game.mnki
    noticing = false

    if state == RECOVER:
        timer -= delta
        cone.clear()
        _cone_tile = Vector2i(-9999, -9999)
        if timer <= 0.0:
            calm()
        return

    if state != CHASE:
        var s: float = _detect(level, mn)
        if s > 0.0:
            alert += (0.8 + s * 2.0) * delta
            noticing = true
            var to_target: Vector2 = mn.pos - pos
            if to_target.length() > 0.1:
                facing = to_target.normalized()
        else:
            alert = maxf(0.0, alert - 0.45 * delta)
        if alert >= 1.0:
            _start_chase(level, mn)

    match state:
        PATROL:
            if not noticing:
                _patrol(delta, level)
        SUSPICIOUS:
            if not noticing:
                if not path.is_empty():
                    _walk(delta, level, INVESTIGATE_SPEED)
                else:
                    timer -= delta
                    facing = facing.rotated(delta * 2.0)
                    if timer <= 0.0:
                        state = PATROL
                        wait_at_wp = false
        SEARCH:
            if not noticing:
                if not path.is_empty():
                    _walk(delta, level, INVESTIGATE_SPEED)
                else:
                    timer -= delta
                    facing = facing.rotated(delta * 2.2)
                    if timer <= 0.0:
                        calm()
        CHASE:
            _chase(delta, level, mn, game)

    if state == RECOVER:
        return
    if level.traps.has(level.tile_of(pos)):
        game.on_guard_harmed(self)
        return
    _update_cone(level)


# ------------------------------------------------------------------ senses

func _detect(level: LevelScript, mn) -> float:
    var d: float = pos.distance_to(mn.pos) / TILE
    var rng_eff: float = VIEW_RANGE
    if mn.sneaking:
        rng_eff *= 0.55
    if mn.hidden:
        rng_eff = HIDDEN_REACH
    if d > rng_eff:
        return 0.0
    var close: bool = d <= CLOSE_RANGE
    if not close:
        var dirv: Vector2 = (mn.pos - pos).normalized()
        if facing.dot(dirv) < HALF_ANGLE_COS:
            return 0.0
    if not level.has_los(level.tile_of(pos), level.tile_of(mn.pos)):
        return 0.0
    return clampf(1.0 - d / rng_eff, 0.0, 1.0) + 0.25


func _update_cone(level: LevelScript) -> void:
    var gt: Vector2i = level.tile_of(pos)
    if gt == _cone_tile and level.version == _cone_ver and facing.dot(_cone_face) > 0.995:
        return          # nothing changed enough to matter: keep the cached cone
    _cone_tile = gt
    _cone_ver = level.version
    _cone_face = facing
    cone.clear()
    var r: int = int(ceil(VIEW_RANGE))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            var t := Vector2i(gt.x + dx, gt.y + dy)
            if not level.in_bounds(t):
                continue
            var v := Vector2(dx, dy)
            var dist: float = v.length()
            if dist > VIEW_RANGE:
                continue
            if dist > CLOSE_RANGE and facing.dot(v / dist) < HALF_ANGLE_COS:
                continue
            if level.tile_at(t) == LevelScript.WALL:
                continue
            if level.has_los(gt, t):
                cone[t] = true


## Called when a noise happens at `tile` (hedge cut, Swan's chirp...).
func hear(tile: Vector2i, radius: float, level: LevelScript) -> void:
    if state == CHASE or state == RECOVER:
        return
    var gt: Vector2i = level.tile_of(pos)
    if Vector2(gt - tile).length() > radius:
        return
    var dest: Vector2i = level.nearest_free(tile, false, 3)
    if dest.x < 0:
        return
    var p: Array = level.find_path_safe(gt, dest)
    if p.is_empty() and gt != dest:
        return
    path = p
    _strip(path, gt)
    state = SUSPICIOUS
    timer = 2.4
    wait_at_wp = false


# --------------------------------------------------------------- behaviour

func _patrol(delta: float, level: LevelScript) -> void:
    if route.size() < 2:
        return
    var cur: Vector2i = level.tile_of(pos)
    var target: Vector2i = route[route_i]
    if path.is_empty():
        if cur == target:
            if not wait_at_wp:
                wait_at_wp = true
                timer = 1.3
            timer -= delta
            facing = facing.rotated(delta * 1.8)
            if timer <= 0.0:
                wait_at_wp = false
                route_i = (route_i + 1) % route.size()
            return
        path = level.find_path_safe(cur, target)
        _strip(path, cur)
        if path.is_empty():
            return
    _walk(delta, level, PATROL_SPEED)


func _start_chase(level: LevelScript, mn) -> void:
    state = CHASE
    alert = 1.0
    lost_timer = 0.0
    hide_t = 0.0
    repath_cd = 0.0
    last_seen = level.tile_of(mn.pos)
    path = []


func _chase(delta: float, level: LevelScript, mn, game: Node2D) -> void:
    var gt: Vector2i = level.tile_of(pos)
    var mt: Vector2i = level.tile_of(mn.pos)
    var d_tiles: float = pos.distance_to(mn.pos) / TILE
    var reach: float = VIEW_RANGE * 1.5
    if mn.hidden:
        reach = HIDDEN_REACH
    var sees: bool = d_tiles <= reach and level.has_los(gt, mt)

    if sees:
        last_seen = mt
        lost_timer = 0.0
        alert = 1.0
        hide_t = 0.0
        var to_t: Vector2 = mn.pos - pos
        if to_t.length() > 0.1:
            facing = to_t.normalized()
    else:
        lost_timer += delta
        alert = maxf(0.0, alert - 0.2 * delta)
        if mn.hidden and d_tiles > HIDE_SAFE:
            # MNKI slipped into a bush while we were far enough away: the trail goes cold right here
            hide_t += delta
            if hide_t >= HIDE_LOSE_TIME:
                lost_by_hiding = true
                state = SEARCH
                timer = 4.0
                alert = 0.0
                path = []
                hide_t = 0.0
                return
        else:
            hide_t = 0.0

    repath_cd -= delta
    if repath_cd <= 0.0:
        repath_cd = 0.25
        if sees:
            path = level.find_path(gt, last_seen, false)   # in a hurry: ignores traps
        else:
            path = level.find_path_safe(gt, last_seen)     # calm again: avoids traps
            if path.is_empty() and gt != last_seen:
                state = SEARCH
                timer = 3.0
                alert = 0.0
                return
        _strip(path, gt)

    if not path.is_empty():
        _walk(delta, level, CHASE_SPEED)
    elif sees:
        pos = pos.move_toward(mn.pos, CHASE_SPEED * delta)

    if sees and pos.distance_to(mn.pos) / TILE < 0.75:
        game.on_caught(self)
        return

    if not sees and (path.is_empty() or lost_timer > GIVE_UP_TIME):
        state = SEARCH
        timer = 3.0
        alert = 0.0
        path = []


func _walk(delta: float, level: LevelScript, speed: float) -> void:
    var np: Vector2 = level.follow(path, pos, speed, delta)
    if np.distance_to(pos) > 0.01:
        facing = (np - pos).normalized()
    pos = np


func _strip(p: Array, cur: Vector2i) -> void:
    if not p.is_empty() and p[0] == cur:
        p.pop_front()
