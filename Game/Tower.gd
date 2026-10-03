extends RefCounted
## A teddy with a sling on a watchtower. It only watches the SKY: when Swan flies into range it notices her,
## takes aim (a red target shows where the pebble will land), and lobs a pebble over the walls.
## The pebble is slow and the target is shown in advance, so Swan can dodge by simply moving.
## A hit "bonks" Swan (she is dizzy for a moment) - never fatal, and she cannot be hit again straight away.

const LevelScript = preload("res://Game/Level.gd")

const TILE := 36

const IDLE := 0
const WATCH := 1    # noticed Swan, working up to a shot
const AIM := 2      # target is shown to the player
const COOL := 3     # reloading the sling

const RANGE := 6.5          # tiles
const LOSE_RANGE := 7.5     # tiles: gives up beyond this
const NOTICE_TIME := 0.7
const AIM_TIME := 1.1
const LOCK_TIME := 0.3      # the target stops moving this long before the shot
const COOLDOWN := 2.4
const STONE_SPEED := 200.0  # px / second
const LEAD := 0.6           # how much the teddy leads a moving target (1.0 = perfect aim)

var tile := Vector2i.ZERO
var pos := Vector2.ZERO      # tile centre
var facing := Vector2.DOWN
var state: int = IDLE
var timer: float = 0.0
var aim_pt := Vector2.ZERO   # where the pebble will land
var recoil: float = 0.0      # little sling-swing animation after a shot
var alert: float = 0.0       # 0..1 for the HUD-ish "!" bar

var _last_swan := Vector2.ZERO
var _swan_vel := Vector2.ZERO


func setup(t: Vector2i, level) -> void:
    tile = t
    pos = level.tile_center(t)


func update(delta: float, game: Node2D) -> void:
    var sw = game.swan
    recoil = maxf(0.0, recoil - delta * 3.0)

    # track how fast Swan is moving so the teddy can lead its shot
    if delta > 0.0:
        var v: Vector2 = (sw.pos - _last_swan) / delta
        _swan_vel = _swan_vel.lerp(v, 1.0 - exp(-8.0 * delta))
    _last_swan = sw.pos

    var d: float = pos.distance_to(sw.pos) / TILE
    var in_range: bool = d <= RANGE
    var gave_up: bool = d > LOSE_RANGE
    if d > 0.1:
        var to: Vector2 = (sw.pos - pos).normalized()
        if state != IDLE:
            facing = facing.lerp(to, 1.0 - exp(-10.0 * delta)).normalized()

    match state:
        IDLE:
            alert = maxf(0.0, alert - delta)
            if in_range and game.swan_inv <= 0.0:
                state = WATCH
                timer = NOTICE_TIME
                facing = (sw.pos - pos).normalized()
                game.on_tower_notice(self)
        WATCH:
            if gave_up:
                _lose(game)
                return
            if game.swan_inv > 0.0:
                timer = maxf(timer, 0.5)       # she was just hit: give her a breather
            else:
                timer -= delta
            alert = clampf(1.0 - timer / NOTICE_TIME, 0.0, 1.0)
            if timer <= 0.0 and in_range:
                state = AIM
                timer = AIM_TIME
                aim_pt = _predict(sw.pos, game)
                game.on_tower_aim(self)
        AIM:
            if gave_up:
                _lose(game)
                return
            timer -= delta
            alert = 1.0
            if timer > LOCK_TIME:
                aim_pt = aim_pt.lerp(_predict(sw.pos, game), 1.0 - exp(-9.0 * delta))
            if timer <= 0.0:
                state = COOL
                timer = COOLDOWN
                recoil = 1.0
                game.fire_stone(self, aim_pt)
        COOL:
            timer -= delta
            alert = maxf(0.0, alert - delta * 0.8)
            if timer <= 0.0:
                if gave_up or not in_range:
                    state = IDLE
                else:
                    state = WATCH
                    timer = 0.35


func _lose(game: Node2D) -> void:
    state = IDLE
    alert = 0.0
    game.on_tower_lost(self)


## Where the pebble should land so that it meets Swan if she keeps flying straight.
func _predict(swan_pos: Vector2, game: Node2D) -> Vector2:
    var travel: float = pos.distance_to(swan_pos) / STONE_SPEED
    var p: Vector2 = swan_pos + _swan_vel * travel * LEAD
    var mw: float = float(LevelScript.W * TILE)
    var mh: float = float(LevelScript.H * TILE)
    return Vector2(clampf(p.x, TILE, mw - TILE), clampf(p.y, TILE, mh - TILE))
