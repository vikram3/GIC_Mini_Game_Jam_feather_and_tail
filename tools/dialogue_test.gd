extends SceneTree
## Headless test for the sling towers, the chase / hide rules and the dialogue:
##   godot --headless --fixed-fps 60 --script res://tools/dialogue_test.gd
## Prints what happens and "TEST FAIL ..." for anything that does not behave as designed.

const GuardScript = preload("res://Game/Guard.gd")
const TowerScript = preload("res://Game/Tower.gd")

var game: Node = null
var frames: int = 0
var phase: int = 0
var phase_frame: int = 0
var fails: int = 0
var seen_text: Dictionary = {}
var chase_guard = null
var bush_tile := Vector2i(-1, -1)
var stones_seen: int = 0
var stones_fired: int = 0
var last_stone_count: int = 0
var dodge_start_bonks: int = 0
var dodge_start_stones: int = 0
var hit_seen: bool = false
var miss_seen: bool = false


func _initialize() -> void:
    game = (load("res://Game/Game.tscn") as PackedScene).instantiate()
    root.add_child(game)
    current_scene = game


func _fail(msg: String) -> void:
    fails += 1
    print("TEST FAIL: ", msg)


func _log_speech() -> void:
    for b in game.speech.bubbles:
        var key: String = "%s|%s" % [b["kind"], b["text"]]
        if not seen_text.has(key):
            seen_text[key] = true
            print("  [%s] %s" % [String(b["kind"]).to_upper(), b["text"]])


func _next(p: int) -> void:
    phase = p
    phase_frame = 0


func _process(_delta: float) -> bool:
    frames += 1
    phase_frame += 1
    _log_speech()
    var lvl = game.level
    if game.stones.size() > last_stone_count:
        stones_fired += game.stones.size() - last_stone_count
    last_stone_count = game.stones.size()

    match phase:
        0:
            print("== towers placed: %d at %s" % [game.towers.size(), str(lvl.towers)])
            if game.towers.size() != 2:
                _fail("expected 2 towers")
            for t in lvl.towers:
                if lvl.tile_at(t) != 1:
                    _fail("tower not on a wall pillar: %s" % str(t))
            print("== guards: %d" % game.guards.size())
            # keep everybody away from the guards, park Swan in range of tower 0 and hold her still
            var tw = game.towers[0]
            var st: Vector2i = lvl.nearest_free(tw.tile + Vector2i(0, 4), true, 4)
            game.swan.pos = lvl.tile_center(st)
            game.follower_mode = "hold"
            game.follower.path.clear()
            for g in game.guards:
                g.route = []          # guards stand still for this test
            print("== swan parked %.1f tiles from tower 0" % (tw.pos.distance_to(game.swan.pos) / 36.0))
            _next(1)
        1:
            var tw1 = game.towers[0]
            game.follower_mode = "hold"
            if game.stones.size() > stones_seen:
                stones_seen = game.stones.size()
            if game.swan_stun > 0.0 and not hit_seen:
                hit_seen = true
                print("== BONK after %d frames (stun %.2f, tower state %d)" % [phase_frame, game.swan_stun, tw1.state])
            if phase_frame > 420:
                if not hit_seen:
                    _fail("a stationary Swan in range was never hit")
                if game.swan_bonks < 1:
                    _fail("swan_bonks not counted")
                # a hit swan must not be hit again during the safe period
                print("== bonks so far: %d" % game.swan_bonks)
                _next(2)
        2:
            # a Swan that reads the red target and flies away from it should not get bonked
            var tw2 = game.towers[0]
            if phase_frame == 1:
                game.swan_inv = 0.0
                game.swan_stun = 0.0
                dodge_start_bonks = game.swan_bonks
                dodge_start_stones = stones_fired
                print("== dodge test start (bonks=%d)" % dodge_start_bonks)
            game.follower_mode = "hold"
            var aimed = null
            for tt in game.towers:
                if tt.state == TowerScript.AIM:
                    aimed = tt
            if aimed != null:
                var away: Vector2 = game.swan.pos - aimed.aim_pt
                if away.length() < 1.0:
                    away = Vector2.RIGHT
                away = away.normalized()
                var moved: bool = false
                for ang in [0.0, 0.9, -0.9, 1.8, -1.8, 3.1]:
                    var np: Vector2 = game.swan.pos + away.rotated(ang) * 150.0 / 60.0
                    if not lvl.box_blocked(np, 10.0, true):
                        game.swan.pos = np
                        moved = true
                        break
            if phase_frame > 900:
                print("== in 15 s: %d pebbles fired, %d new bonks while dodging" % [stones_fired - dodge_start_stones, game.swan_bonks - dodge_start_bonks])
                if stones_fired - dodge_start_stones < 2:
                    _fail("tower did not keep firing at a Swan in range")
                if game.swan_bonks - dodge_start_bonks > 1:
                    _fail("a dodging Swan was hit more than once")
                _next(3)
        3:
            # --- chase: put MNKI in front of a patrolling teddy
            game.swan.pos = lvl.tile_center(lvl.start_tile)
            game.swan_inv = 99.0
            chase_guard = game.guards[0]
            chase_guard.calm()
            for g2 in game.guards:
                g2.calm()
            var gt: Vector2i = lvl.tile_of(chase_guard.pos)
            var found := Vector2i(-1, -1)
            for dist in [4, 3]:
                for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                    var t: Vector2i = gt + d * dist
                    if lvl.in_bounds(t) and not lvl.solid_for(t, false) and lvl.tile_at(t) != 4 and lvl.has_los(gt, t) and found.x < 0:
                        found = t
                        chase_guard.facing = Vector2(d)
            if found.x < 0:
                print("== no straight corridor found near guard 0, skipping chase test")
                _next(6)
                return false
            game.mnki.pos = lvl.tile_center(found)
            game.mnki.hidden = false
            game.leader = game.mnki
            game.follower = game.swan
            print("== MNKI placed %s, guard at %s" % [str(found), str(gt)])
            _next(4)
        4:
            game.mnki.vel = Vector2.ZERO
            if chase_guard.state == GuardScript.CHASE:
                print("== guard started chasing after %d frames" % phase_frame)
                # find a bush that is far from the guard
                var best := Vector2i(-1, -1)
                var bestd: float = 0.0
                for y in range(lvl.H):
                    for x in range(lvl.W):
                        if lvl.tile_at(Vector2i(x, y)) == 4:
                            var dd: float = lvl.tile_center(Vector2i(x, y)).distance_to(chase_guard.pos) / 36.0
                            if dd > 3.5 and (best.x < 0 or dd < bestd):
                                best = Vector2i(x, y)
                                bestd = dd
                bush_tile = best
                print("== hiding in the bush %s (%.1f tiles from the teddy)" % [str(best), bestd])
                game.mnki.pos = lvl.tile_center(best)
                game.mnki.last_pos = game.mnki.pos
                # keep the other guards out of it so only guard 0 reacts
                _next(5)
            elif phase_frame > 240:
                _fail("a teddy that has MNKI in clear view never started chasing")
                _next(6)
        5:
            game.mnki.vel = Vector2.ZERO
            game.mnki.pos = lvl.tile_center(bush_tile)
            if chase_guard.state == GuardScript.SEARCH:
                print("== guard lost the trail (state SEARCH) after %d frames of hiding" % phase_frame)
                _next(10)
            elif chase_guard.state == GuardScript.RECOVER:
                _fail("guard caught MNKI even though he hid far away")
                _next(10)
            elif phase_frame > 180:
                _fail("hiding in a bush far from the teddy did not shake it (state %d)" % chase_guard.state)
                _next(10)
        10:
            # --- hiding too late: the teddy is right behind MNKI, so the bush does not save him
            for g5 in game.guards:
                g5.calm()
            game.swan.pos = lvl.tile_center(lvl.start_tile)
            var gt2: Vector2i = lvl.tile_of(chase_guard.pos)
            var spot := Vector2i(-1, -1)
            for dist2 in [2, 3]:
                for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                    var t2: Vector2i = gt2 + d2 * dist2
                    if spot.x < 0 and lvl.in_bounds(t2) and lvl.tile_at(t2) == 0 and lvl.has_los(gt2, t2) and lvl.has_los(gt2, gt2 + d2):
                        spot = t2
            if spot.x < 0:
                print("== no spot for the close-hide test, skipping")
                _next(6)
                return false
            lvl.set_t(spot, 4)      # a bush appears 2 tiles from the teddy
            game.mnki.pos = lvl.tile_center(spot)
            game.mnki.last_pos = game.mnki.pos
            game.mnki.hidden = true
            game.leader = game.mnki
            chase_guard.state = GuardScript.CHASE
            chase_guard._start_chase(lvl, game.mnki)
            print("== close hide: bush %.1f tiles from the chasing teddy" % (lvl.tile_center(spot).distance_to(chase_guard.pos) / 36.0))
            bush_tile = spot
            _next(11)
        11:
            game.mnki.pos = lvl.tile_center(bush_tile)
            game.mnki.vel = Vector2.ZERO
            if chase_guard.state == GuardScript.RECOVER:
                print("== teddy walked up to the too-close bush and found MNKI (caught) after %d frames" % phase_frame)
                _next(6)
            elif chase_guard.state == GuardScript.SEARCH and chase_guard.lost_by_hiding:
                _fail("hiding right under the teddy's nose should not shake it")
                _next(6)
            elif phase_frame > 240:
                print("== close hide: teddy state after 4 s = %d" % chase_guard.state)
                _next(6)
        6:
            # --- calm chat between the friends
            for g3 in game.guards:
                g3.calm()
            game.mnki.pos = lvl.tile_center(lvl.start_tile)
            game.swan.pos = lvl.tile_center(lvl.start_tile) + Vector2(20, 0)
            game.speech.clear()
            game.chat_cd = 0.0
            game.intro_done = true
            print("== calm: waiting for a love-and-wisdom chat")
            _next(7)
        7:
            for g4 in game.guards:
                g4.calm()
            game.mnki.pos = lvl.tile_center(lvl.start_tile)
            game.swan.pos = lvl.tile_center(lvl.start_tile) + Vector2(20, 0)
            if phase_frame > 1500:
                print("== chat lines shown: %d" % seen_text.size())
                if game.speech.queue.is_empty() and not game.speech.is_chatting() and phase_frame > 1700:
                    pass
                print("TEST DONE  fails=%d" % fails)
                quit(0 if fails == 0 else 1)
    return false
