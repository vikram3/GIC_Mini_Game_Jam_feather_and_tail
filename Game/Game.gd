extends Node2D
## Feather & Tail - Level 1 (Pacifist).
## MNKI changes the path (cuts hedges, disarms traps). Swan sees the path
## (flies, scouts). Either can lead. Nobody fights - nobody may be harmed -
## and the teddy-bear guards must be avoided.
## Camera: one merged view while the friends are close, split screen when apart.

const LevelScript = preload("res://Game/Level.gd")
const HeroScript = preload("res://Game/Hero.gd")
const GuardScript = preload("res://Game/Guard.gd")
const WorldDrawScript = preload("res://Game/WorldDraw.gd")
const OverlayScript = preload("res://Game/Overlay.gd")
const UIThemeScript = preload("res://Game/UITheme.gd")
const AudioOptionsScript = preload("res://Game/AudioOptions.gd")
const TowerScript = preload("res://Game/Tower.gd")
const SpeechScript = preload("res://Game/Speech.gd")
const TouchControlsScript = preload("res://Game/TouchControls.gd")

const TILE := 36
const ZOOM := 1.8
const SCREEN := Vector2(1280, 720)

# split / merge thresholds in world pixels (hysteresis avoids flicker)
const SPLIT_X := 460.0
const SPLIT_Y := 170.0
const MERGE_X := 380.0
const MERGE_Y := 130.0

const WALL := 1
const HEDGE := 2
const LOW := 3
const BUSH := 4
const WATER := 5
const BRIDGE := 6

const PLAYING := 0
const PAUSED := 1
const WON := 2
const LOST := 3

const WALK_SPEED := 105.0
const SNEAK_SPEED := 52.0
const SWAN_SPEED := 150.0
const FOLLOW_SPEED_MNKI := 100.0
const FOLLOW_SPEED_SWAN := 140.0
const CUT_TIME := 1.1
const DISARM_TIME := 1.0
const CHIRP_COOLDOWN := 4.0
const STONE_HIT_R := 20.0     # a sling pebble bonks Swan if it lands this close
const BONK_STUN := 1.8        # seconds Swan is dizzy after a hit
const BONK_SAFE := 3.6        # seconds after a hit during which she cannot be hit again

var level: LevelScript
var mnki: HeroScript
var swan: HeroScript
var leader: HeroScript
var follower: HeroScript
var guards: Array = []
var harmed_guard = null
var towers: Array = []         # sling teddies on watchtowers (see Tower.gd)
var stones: Array = []         # pebbles in flight: {from, to, age, dur, tower}
var swan_stun: float = 0.0
var swan_inv: float = 0.0
var swan_bonks: int = 0
var tower_hint_shown: bool = false
var chase_hint_shown: bool = false
var speech                     # Speech.gd: speech bubbles + dialogue
var chat_cd: float = 1.5
var intro_done: bool = false

var follower_mode: String = "follow"   # "follow", "goto", "hold"
var seen_tiles: Dictionary = {}
var vis_tiles: Dictionary = {}
var danger: Dictionary = {}

var play_state: int = PLAYING
var elapsed: float = 0.0
var caught: int = 0
var collected: int = 0
var fruit_total: int = 0
var traps_disarmed: int = 0
var cut_progress: float = 0.0
var cut_target := Vector2i(-1, -1)
var disarm_progress: float = 0.0
var disarm_target := Vector2i(-1, -1)
var chirp_cd: float = 0.0
var repath_timer: float = 0.0
var msg_timer: float = 0.0
var hint_cd: float = 0.0
var warn_cd: float = 0.0
var effects: Array = []
var particles: Array = []
var shake: float = 0.0

# caches / bookkeeping for performance
var map_version: int = 0                 # bumped when what the map shows changes (fog, minimap)
var last_mt := Vector2i(-999, -999)
var last_st := Vector2i(-999, -999)
var last_level_version: int = -1
var fruit_streak: int = 0
var cut_tick: float = 0.0
var disarm_tick: float = 0.0
var was_hidden: bool = false

# camera / split-screen state
var merge: float = 1.0          # 1 = single merged view, 0 = fully split
var want_split: bool = false
var split_vertical: bool = true # true: side by side, false: stacked
var a_is_mnki: bool = true
var hero_a: HeroScript
var hero_b: HeroScript
var rect_a := Rect2(Vector2.ZERO, SCREEN)
var rect_b := Rect2(Vector2.ZERO, Vector2.ZERO)
var cam_pos_a := Vector2.ZERO
var cam_pos_b := Vector2.ZERO
var cont_a: SubViewportContainer
var cont_b: SubViewportContainer
var sub_a: SubViewport
var sub_b: SubViewport
var cam_a: Camera2D
var cam_b: Camera2D
var world: Node2D

var tex_mnki: Texture2D = null
var tex_swan: Texture2D = null
var tex_guard: Texture2D = null

var msg_label: Label
var overlay: Control
var overlay_title: Label
var overlay_info: Label
var resume_btn: Button
var options_box: VBoxContainer
var touch: Control = null              # TouchControls.gd - only exists on touch devices


func _ready() -> void:
    level = LevelScript.new()
    level.generate(PlayerData.level_seed)
    fruit_total = level.fruits.size()

    mnki = HeroScript.new()
    mnki.kind = "mnki"
    mnki.pos = level.tile_center(level.start_tile)
    swan = HeroScript.new()
    swan.kind = "swan"
    swan.pos = level.tile_center(level.start_tile) + Vector2(0, -3)
    leader = mnki
    follower = swan
    hero_a = mnki
    hero_b = swan

    for route in level.guard_routes:
        var g: GuardScript = GuardScript.new()
        g.variant = guards.size()      # picks the teddy's fur colour
        g.route = route
        g.pos = level.tile_center(route[0])
        g.route_i = 1
        guards.append(g)

    for tt in level.towers:
        var tw: TowerScript = TowerScript.new()
        tw.setup(tt, level)
        towers.append(tw)
    speech = SpeechScript.new()
    speech.game = self

    tex_mnki = _try_tex("res://Art/mnki.png")
    tex_swan = _try_tex("res://Art/swan.png")
    tex_guard = _try_tex("res://Art/guard.png")

    mnki.last_pos = mnki.pos
    swan.last_pos = swan.pos

    _build_views()
    _build_hud()
    Sound.set_mode("game")
    Sound.ensure_music()
    Sound.set_tension(0.0)
    Sound.set_duck(false)
    cam_pos_a = mnki.pos
    cam_pos_b = swan.pos
    _update_visibility()
    _update_views(1.0)
    show_message("Harm no one. Avoid the teddy guards. Gather all the fruit, then reach the exit together.", 7.0)


func _try_tex(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return load(path) as Texture2D
    return null


# --------------------------------------------------------------- split screen

func _build_views() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 0
    add_child(layer)

    cont_a = SubViewportContainer.new()
    cont_a.stretch = true
    cont_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(cont_a)
    sub_a = SubViewport.new()
    sub_a.size = Vector2i(1280, 720)
    sub_a.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    sub_a.disable_3d = true
    cont_a.add_child(sub_a)

    world = WorldDrawScript.new()
    world.game = self
    sub_a.add_child(world)
    cam_a = Camera2D.new()
    cam_a.zoom = Vector2(ZOOM, ZOOM)
    sub_a.add_child(cam_a)
    cam_a.make_current()

    cont_b = SubViewportContainer.new()
    cont_b.stretch = true
    cont_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(cont_b)
    sub_b = SubViewport.new()
    sub_b.size = Vector2i(640, 720)
    sub_b.render_target_update_mode = SubViewport.UPDATE_DISABLED   # only rendered while split
    sub_b.disable_3d = true
    sub_b.world_2d = sub_a.world_2d     # same garden, second camera
    cont_b.add_child(sub_b)
    cam_b = Camera2D.new()
    cam_b.zoom = Vector2(ZOOM, ZOOM)
    sub_b.add_child(cam_b)
    cam_b.make_current()
    cont_b.visible = false


func _update_views(delta: float) -> void:
    var d: Vector2 = swan.pos - mnki.pos
    var ax: float = absf(d.x)
    var ay: float = absf(d.y)
    if not want_split:
        if ax > SPLIT_X or ay > SPLIT_Y:
            want_split = true
            split_vertical = (ax / SPLIT_X) >= (ay / SPLIT_Y)
            if split_vertical:
                a_is_mnki = d.x > 0.0     # Swan to the right -> MNKI in the left panel
            else:
                a_is_mnki = d.y > 0.0     # Swan below -> MNKI in the top panel
    else:
        if ax < MERGE_X and ay < MERGE_Y:
            want_split = false
    merge = move_toward(merge, 0.0 if want_split else 1.0, delta * 2.5)
    var em: float = smoothstep(0.0, 1.0, merge)

    hero_a = mnki if a_is_mnki else swan
    hero_b = swan if a_is_mnki else mnki

    if split_vertical:
        var wa: float = lerpf(SCREEN.x * 0.5, SCREEN.x, em)
        rect_a = Rect2(0.0, 0.0, wa, SCREEN.y)
        rect_b = Rect2(wa, 0.0, SCREEN.x - wa, SCREEN.y)
    else:
        var ha: float = lerpf(SCREEN.y * 0.5, SCREEN.y, em)
        rect_a = Rect2(0.0, 0.0, SCREEN.x, ha)
        rect_b = Rect2(0.0, ha, SCREEN.x, SCREEN.y - ha)

    cont_a.position = rect_a.position
    cont_a.size = rect_a.size
    var split_now: bool = merge < 0.995
    if split_now != cont_b.visible:
        cont_b.visible = split_now
        sub_b.render_target_update_mode = SubViewport.UPDATE_ALWAYS if split_now else SubViewport.UPDATE_DISABLED
    if cont_b.visible:
        cont_b.position = rect_b.position
        cont_b.size = Vector2(maxf(rect_b.size.x, 4.0), maxf(rect_b.size.y, 4.0))

    var mid: Vector2 = (mnki.pos + swan.pos) * 0.5
    var ta: Vector2 = _clamp_cam(hero_a.pos.lerp(mid, em), rect_a.size)
    var tb: Vector2 = _clamp_cam(hero_b.pos.lerp(mid, em), rect_b.size)
    var k: float = 1.0 - exp(-12.0 * delta)
    cam_pos_a = cam_pos_a.lerp(ta, k)
    cam_pos_b = cam_pos_b.lerp(tb, k)
    cam_a.position = cam_pos_a
    cam_b.position = cam_pos_b
    if shake > 0.0:
        shake = maxf(0.0, shake - delta * 2.6)
        var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 7.0
        cam_a.offset = off
        cam_b.offset = off
    elif cam_a.offset != Vector2.ZERO:
        cam_a.offset = Vector2.ZERO
        cam_b.offset = Vector2.ZERO


func _clamp_cam(p: Vector2, view_size: Vector2) -> Vector2:
    var half: Vector2 = view_size / (2.0 * ZOOM)
    var mw: float = float(LevelScript.W * TILE)
    var mh: float = float(LevelScript.H * TILE)
    var x: float = mw * 0.5
    var y: float = mh * 0.5
    if half.x * 2.0 < mw:
        x = clampf(p.x, half.x, mw - half.x)
    if half.y * 2.0 < mh + 40.0:
        y = clampf(p.y, half.y - 30.0, mh - half.y + 6.0)
    return Vector2(x, y)


func screen_to_world(sp: Vector2) -> Vector2:
    var use_b: bool = merge < 0.5 and rect_b.has_point(sp)
    var r: Rect2 = rect_b if use_b else rect_a
    var c: Vector2 = cam_pos_b if use_b else cam_pos_a
    return c + (sp - r.position - r.size * 0.5) / ZOOM


# ------------------------------------------------------------------ main loop

func _process(raw_delta: float) -> void:
    var delta: float = minf(raw_delta, 0.05)    # a hitch must never teleport anyone through a wall
    if msg_timer > 0.0:
        msg_timer -= delta
    if play_state == PLAYING:
        elapsed += delta
        chirp_cd = maxf(0.0, chirp_cd - delta)
        hint_cd = maxf(0.0, hint_cd - delta)
        warn_cd = maxf(0.0, warn_cd - delta)
        _update_leader(delta)
        _update_follower(delta)
        _update_visibility()
        swan_stun = maxf(0.0, swan_stun - delta)
        swan_inv = maxf(0.0, swan_inv - delta)
        _update_guards(delta)
        _update_towers(delta)
        _update_stones(delta)
        _update_danger()
        _check_trap_warning()
        _update_pickups()
        _update_footsteps()
        _update_effects(delta)
        speech.update(delta)
        _update_chatter(delta)
        _check_win()
    _update_views(raw_delta)
    _update_hud()


## Called by TouchControls when the player taps the garden: same as a mouse click.
func touch_tap(sp: Vector2) -> void:
    if play_state != PLAYING:
        return
    _command_goto(level.tile_of(screen_to_world(sp)))


func _notification(what: int) -> void:
    # tab hidden / app switched away (browser or phone): pause instead of letting the teddies keep walking
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and (Platform.is_web or Platform.is_touch):
        if play_state == PLAYING and overlay != null:
            _toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        _toggle_pause()
        return
    if event.is_action_pressed("restart"):
        _restart()
        return
    if play_state != PLAYING:
        return
    if event.is_action_pressed("switch_leader"):
        _swap_leader()
    elif event.is_action_pressed("hold_toggle"):
        Sound.play("command", 0.8, 0.85 if follower_mode != "hold" else 1.0)
        if follower_mode == "hold":
            follower_mode = "follow"
            show_message("%s follows again." % hero_name(follower), 1.8)
            speech.hero_bark(follower.kind, "f_follow")
        else:
            follower_mode = "hold"
            follower.path.clear()
            show_message("%s holds position." % hero_name(follower), 1.8)
            speech.hero_bark(follower.kind, "m_hold" if follower == mnki else "s_hold")
    elif event.is_action_pressed("cancel"):
        _cancel_command()
    elif event.is_action_pressed("chirp"):
        _chirp()
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            var w: Vector2 = screen_to_world(get_viewport().get_mouse_position())
            _command_goto(level.tile_of(w))
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _cancel_command()


# ------------------------------------------------------------------- leader

func _update_leader(delta: float) -> void:
    var dir := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down"))
    if dir.length() > 1.0:
        dir = dir.normalized()
    var is_swan: bool = leader.kind == "swan"
    if is_swan and swan_stun > 0.0:
        dir = Vector2.ZERO        # dizzy from a sling pebble
    var sneak: bool = Input.is_action_pressed("sneak") and not is_swan
    leader.sneaking = sneak
    var speed: float = SWAN_SPEED if is_swan else (SNEAK_SPEED if sneak else WALK_SPEED)
    leader.moving = dir != Vector2.ZERO
    # soft acceleration / braking: starts and stops feel smooth instead of snapping
    var accel: float = 1250.0 if leader.moving else 1700.0
    leader.vel = leader.vel.move_toward(dir * speed, accel * delta)
    if leader.moving:
        leader.facing = dir.normalized()
    if leader.vel.length_squared() > 0.25:
        leader.pos = level.move_box(leader.pos, leader.vel * delta, leader.radius, is_swan)
    if leader == mnki:
        _update_cutting(delta)
        _update_disarm(delta)
    else:
        cut_progress = 0.0
        disarm_progress = 0.0
    mnki.hidden = level.tile_at(level.tile_of(mnki.pos)) == BUSH
    if mnki.hidden and not was_hidden:
        Sound.play("rustle", 0.8, 1.0, 0.1)
        _burst(mnki.pos, Color(0.35, 0.75, 0.35), 6, 40.0, 0.5, 2.2)
        _on_mnki_hide()
    was_hidden = mnki.hidden


func _update_cutting(delta: float) -> void:
    var target: Vector2i = _find_hedge_target()
    var holding: bool = Input.is_action_pressed("cut") and not mnki.moving
    if holding and target.x >= 0:
        if target != cut_target:
            cut_target = target
            cut_progress = 0.0
        mnki.facing = Vector2(target - level.tile_of(mnki.pos)).normalized()
        cut_progress += delta / CUT_TIME
        cut_tick -= delta
        if cut_tick <= 0.0:
            cut_tick = 0.16
            Sound.play("scrape", 0.8, 0.9 + cut_progress * 0.5, 0.05)
        if cut_progress >= 1.0:
            level.cut_hedge(target)
            world.mark_seen(target)
            map_version += 1
            _burst(level.tile_center(target), Color(0.35, 0.78, 0.30), 16, 70.0, 0.7, 2.6)
            Sound.play("snip", 1.0, 1.0, 0.04)
            shake = maxf(shake, 0.12)
            cut_progress = 0.0
            cut_target = Vector2i(-1, -1)
            emit_noise(target, 7.0)
            show_message("Snip! The hedge rustles loudly - nearby teddies may come to look.", 3.0)
            if speech.ready("hedge", 6.0):
                speech.hero_bark("mnki", "m_hedge")
    else:
        cut_progress = 0.0
        cut_target = Vector2i(-1, -1)


func _update_disarm(delta: float) -> void:
    var target: Vector2i = _find_trap_target()
    var holding: bool = Input.is_action_pressed("disarm") and not mnki.moving
    if holding and target.x >= 0:
        if target != disarm_target:
            disarm_target = target
            disarm_progress = 0.0
        disarm_progress += delta / DISARM_TIME
        disarm_tick -= delta
        if disarm_tick <= 0.0:
            disarm_tick = 0.2
            Sound.play("disarm_tick", 0.8, 0.9 + disarm_progress * 0.6, 0.03)
        if disarm_progress >= 1.0:
            level.disarm_trap(target)
            traps_disarmed += 1
            Sound.play("disarm_done")
            _burst(level.tile_center(target), Color(0.5, 0.85, 1.0), 14, 60.0, 0.7, 2.4)
            disarm_progress = 0.0
            disarm_target = Vector2i(-1, -1)
            show_message("Trap safely disarmed. No teddy can be hurt here now.", 3.0)
            if randf() < 0.5:
                speech.duo("trap")
            else:
                speech.hero_bark("mnki", "m_trap")
    else:
        disarm_progress = 0.0
        disarm_target = Vector2i(-1, -1)


func _find_trap_target() -> Vector2i:
    var here: Vector2i = level.tile_of(mnki.pos)
    var offs: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for o in offs:
        var t: Vector2i = here + o
        if level.traps.has(t):
            return t
    return Vector2i(-1, -1)


func _find_hedge_target() -> Vector2i:
    var here: Vector2i = level.tile_of(mnki.pos)
    var dirs: Array = [_cardinal(mnki.facing), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for d in dirs:
        var t: Vector2i = here + d
        if level.tile_at(t) == HEDGE:
            return t
    return Vector2i(-1, -1)


func _cardinal(v: Vector2) -> Vector2i:
    if absf(v.x) > absf(v.y):
        return Vector2i(1 if v.x > 0.0 else -1, 0)
    return Vector2i(0, 1 if v.y > 0.0 else -1)


func _swap_leader() -> void:
    var tmp: HeroScript = leader
    leader = follower
    follower = tmp
    follower.path.clear()
    follower.waiting = false
    follower.blocked = false
    follower.sneaking = false
    follower_mode = "follow"
    cut_progress = 0.0
    disarm_progress = 0.0
    tmp.vel = Vector2.ZERO
    Sound.play("swap")
    _burst(leader.pos, Color(1.0, 0.9, 0.4), 10, 55.0, 0.5, 2.2)
    show_message("%s is leading now." % hero_name(leader), 2.0)
    speech.hero_bark(leader.kind, "m_lead" if leader == mnki else "s_lead")


func _chirp() -> void:
    if leader != swan:
        Sound.play("deny", 0.8)
        show_message(("Only Swan can chirp. Tap SWAP to let her lead." if Platform.is_touch else "Only Swan can chirp. Press Tab to let her lead."), 2.2)
        return
    if chirp_cd > 0.0:
        return
    chirp_cd = CHIRP_COOLDOWN
    Sound.play("chirp", 1.0, 1.0, 0.05)
    emit_noise(level.tile_of(swan.pos), 8.0)
    show_message("Swan chirps - curious teddies go to look at the sound.", 2.2)
    speech.hero_bark("swan", "s_chirp")


## Noise lures teddies to investigate (they walk carefully around traps).
func emit_noise(tile: Vector2i, radius: float) -> void:
    for g in guards:
        var before: int = g.state
        g.hear(tile, radius, level)
        if g.state == GuardScript.SUSPICIOUS and before != GuardScript.SUSPICIOUS:
            _guard_bark(g, "g_hear")
    effects.append({"pos": level.tile_center(tile), "age": 0.0, "max": 1.0, "radius": radius * TILE})


# ----------------------------------------------------------------- follower

func _command_goto(t: Vector2i) -> void:
    if not level.in_bounds(t):
        return
    if not seen_tiles.has(t):
        Sound.play("deny", 0.8)
        show_message("Scout that spot first - Swan can fly ahead.", 2.2)
        return
    var air_unit: bool = follower.kind == "swan"
    var dest: Vector2i = level.nearest_free(t, air_unit, 2)
    if dest.x < 0:
        Sound.play("deny", 0.8)
        show_message("%s can't stand there." % hero_name(follower), 2.0)
        return
    var ft: Vector2i = level.tile_of(follower.pos)
    var p: Array = level.find_path(ft, dest, air_unit)
    if p.is_empty() and ft != dest:
        Sound.play("deny", 0.8)
        show_message("No route for %s. Try cutting a hedge." % hero_name(follower), 2.5)
        return
    _strip(p, ft)
    follower.path = p
    follower_mode = "goto"
    Sound.play("command", 0.9, 1.2)
    show_message("%s is heading there." % hero_name(follower), 1.6)
    speech.hero_bark(follower.kind, "f_go")


func _cancel_command() -> void:
    Sound.play("command", 0.7, 0.8)
    follower.path.clear()
    follower.waiting = false
    follower_mode = "follow"
    show_message("%s follows you again." % hero_name(follower), 1.6)
    speech.hero_bark(follower.kind, "f_follow")


func _update_follower(delta: float) -> void:
    var air_unit: bool = follower.kind == "swan"
    var speed: float = FOLLOW_SPEED_SWAN if air_unit else FOLLOW_SPEED_MNKI
    var ft: Vector2i = level.tile_of(follower.pos)
    follower.waiting = false
    follower.moving = false
    follower.sneaking = false

    if follower_mode == "follow":
        var dist_px: float = follower.pos.distance_to(leader.pos)
        repath_timer -= delta
        if dist_px > TILE * 2.0:
            if repath_timer <= 0.0:
                repath_timer = 0.4
                var lt: Vector2i = level.nearest_free(level.tile_of(leader.pos), air_unit, 2)
                follower.path = level.find_path(ft, lt, air_unit)
                _strip(follower.path, ft)
                follower.blocked = follower.path.is_empty()
        elif dist_px < TILE * 1.3:
            follower.path.clear()
            follower.blocked = false

    if follower.kind == "mnki":
        follower.hidden = level.tile_at(ft) == BUSH

    var dizzy_follower: bool = follower == swan and swan_stun > 0.0
    if not follower.path.is_empty() and not dizzy_follower:
        # danger response: never walk into a guard's view
        if not air_unit:
            var nxt: Vector2i = follower.path[0]
            if danger.has(nxt) and not danger.has(ft):
                follower.waiting = true
        if not follower.waiting:
            var np: Vector2 = level.follow(follower.path, follower.pos, speed, delta)
            if np.distance_to(follower.pos) > 0.01:
                follower.facing = (np - follower.pos).normalized()
                follower.moving = true
            follower.pos = np
            if follower.path.is_empty() and follower_mode == "goto":
                follower_mode = "hold"
                show_message("%s arrived and is waiting." % hero_name(follower), 1.8)


func _strip(p: Array, cur: Vector2i) -> void:
    if not p.is_empty() and p[0] == cur:
        p.pop_front()


# ------------------------------------------------------------- world updates

func _update_visibility() -> void:
    var mt: Vector2i = level.tile_of(mnki.pos)
    var st: Vector2i = level.tile_of(swan.pos)
    if mt == last_mt and st == last_st and level.version == last_level_version:
        return          # nobody changed tile: the visible area is exactly what it was
    last_mt = mt
    last_st = st
    last_level_version = level.version
    vis_tiles.clear()
    for dy in range(-5, 6):
        for dx in range(-5, 6):
            if dx * dx + dy * dy > 28:
                continue
            var t := Vector2i(mt.x + dx, mt.y + dy)
            if level.in_bounds(t) and level.has_los(mt, t):
                vis_tiles[t] = true
    # Swan sees from above: no line of sight needed, much bigger radius
    for dy in range(-8, 9):
        for dx in range(-8, 9):
            if dx * dx + dy * dy > 70:
                continue
            var t2 := Vector2i(st.x + dx, st.y + dy)
            if level.in_bounds(t2):
                vis_tiles[t2] = true
    for t3 in vis_tiles:
        if not seen_tiles.has(t3):
            seen_tiles[t3] = true
            world.mark_seen(t3)     # that terrain chunk must be (re)drawn once
    map_version += 1                # fog + minimap refresh


## Runs every teddy, plays their sounds and drives the music tension.
func _update_guards(delta: float) -> void:
    var tension: float = 0.0
    for g in guards:
        var before: int = g.state
        g.update(delta, self)
        var lost_hide: bool = g.lost_by_hiding
        g.lost_by_hiding = false
        if g.state != before and g.state == GuardScript.CHASE:
            _guard_sound("alert", g, 1.0, 0.5)
            _burst(g.pos + Vector2(0, -30), Color(1.0, 0.4, 0.3), 8, 45.0, 0.5, 2.4)
            _on_guard_chase(g)
        elif g.state != before and g.state == GuardScript.SEARCH and before == GuardScript.CHASE:
            if lost_hide:
                _on_lost_by_hiding(g)
            else:
                _guard_bark(g, "g_lost")
        if g.noticing and not g.snd_noticing and g.state != GuardScript.CHASE:
            _guard_sound("notice", g, 0.8, 0.0)
            if vis_tiles.has(level.tile_of(g.pos)) and speech.ready("g_notice", 5.0):
                _guard_bark(g, "g_notice")
        # a little guard banter while patrolling or searching
        if g.state == GuardScript.SEARCH and not g.noticing and randf() < delta * 0.3:
            if vis_tiles.has(level.tile_of(g.pos)) and speech.ready("g_search", 4.0):
                _guard_bark(g, "g_search")
        elif g.state == GuardScript.PATROL and not g.noticing and randf() < delta * 0.1:
            if vis_tiles.has(level.tile_of(g.pos)) and _nearest_hero_dist(g.pos) < TILE * 6.0 and speech.ready("g_idle", 9.0):
                _guard_bark(g, "g_idle", SpeechScript.PRIO_CHAT)
        g.snd_noticing = g.noticing
        # tension for the music
        if g.state == GuardScript.CHASE:
            tension = 1.0
        elif g.noticing or g.state == GuardScript.SEARCH or g.state == GuardScript.SUSPICIOUS:
            tension = maxf(tension, 0.35)
        # soft teddy footsteps
        var moved: float = g.pos.distance_to(g.last_pos)
        g.last_pos = g.pos
        if moved > 0.0 and moved < 20.0 and g.state != GuardScript.RECOVER:
            g.step_dist += moved
            if g.step_dist >= 30.0:
                g.step_dist = 0.0
                _guard_sound("guard_step", g, 0.5, 0.0, 9.0)
    Sound.set_tension(tension)


func _nearest_hero_dist(p: Vector2) -> float:
    return minf(p.distance_to(mnki.pos), p.distance_to(swan.pos))


func _guard_sound(snd: String, g, vol: float, floor_gain: float, max_tiles: float = 12.0) -> void:
    Sound.play_dist(snd, _nearest_hero_dist(g.pos), max_tiles * TILE, vol, floor_gain)


## Footsteps for both friends: grass/sand, wood on bridges, wing-beats for Swan.
func _update_footsteps() -> void:
    for h in [mnki, swan]:
        var d: float = h.pos.distance_to(h.last_pos)
        h.last_pos = h.pos
        if not h.moving or d <= 0.0 or d > 20.0:
            continue
        h.step_dist += d
        var is_lead: bool = h == leader
        if h.kind == "swan":
            if h.step_dist >= 44.0:
                h.step_dist = 0.0
                Sound.play("flap", 0.9 if is_lead else 0.5, 1.0, 0.1)
            continue
        var stride: float = 30.0 if h.sneaking else 23.0
        if h.step_dist >= stride:
            h.step_dist = 0.0
            var vol: float = (0.35 if h.sneaking else 0.8) * (1.0 if is_lead else 0.55)
            if h.hidden:
                vol *= 0.6
            if level.tile_at(level.tile_of(h.pos)) == BRIDGE:
                Sound.play_rand("step_wood", 2, vol, 1.0, 0.08)
            else:
                Sound.play_rand("step", 3, vol, 1.0, 0.08)


func _update_danger() -> void:
    danger.clear()
    for g in guards:
        if g.state == GuardScript.RECOVER:
            continue
        for t in g.cone:
            danger[t] = true


## Pacifist alarm: a chasing guard is about to run over a trap.
func _check_trap_warning() -> void:
    if warn_cd > 0.0:
        return
    for g in guards:
        if g.state != GuardScript.CHASE:
            continue
        var n: int = mini(g.path.size(), 6)
        for i in range(n):
            if level.traps.has(g.path[i]):
                warn_cd = 2.0
                Sound.play("danger")
                show_message("DANGER! A teddy is about to run into a trap - break line of sight / hide!", 2.5)
                return


func _update_pickups() -> void:
    for f in level.fruits:
        if f["got"]:
            continue
        var c: Vector2 = level.tile_center(f["tile"])
        var picked: bool = false
        if f["kind"] == "ground" and mnki.pos.distance_to(c) < 20.0:
            picked = true
        elif f["kind"] == "tree" and swan.pos.distance_to(c) < 22.0:
            picked = true
        if picked:
            f["got"] = true
            collected += 1
            map_version += 1
            fruit_streak += 1
            var is_pear: bool = f["kind"] == "tree"
            Sound.play("pickup_pear" if is_pear else "pickup_apple", 1.0, 1.0 + 0.06 * float(fruit_streak - 1))
            _burst(c + Vector2(0, -6), Color(1.0, 0.9, 0.35) if is_pear else Color(1.0, 0.45, 0.4), 16, 80.0, 0.8, 2.6)
            _burst(c + Vector2(0, -6), Color(1, 1, 1), 8, 50.0, 0.6, 1.8)
            if collected >= fruit_total:
                Sound.play("exit_open")
                shake = maxf(shake, 0.1)
                show_message("That's all the fruit! The exit gate is open - go through it together.", 4.0)
                speech.duo("allfruit")
            else:
                show_message("Fruit %d of %d!" % [collected, fruit_total], 1.8)
                speech.fruit(is_pear)


# ------------------------------------------------------ sling teddies (towers)

func _update_towers(delta: float) -> void:
    for tw in towers:
        tw.update(delta, self)


func on_tower_notice(tw) -> void:
    Sound.play("notice", 0.6, 0.75)
    if speech.ready("t_notice", 5.0):
        speech.bark(tw, "tower", "t_notice")
    if not tower_hint_shown:
        tower_hint_shown = true
        show_message("A sling teddy on a tower is watching Swan! Keep moving to dodge the pebbles, or stay out of its range.", 5.0)
        speech.converse([["swan", speech.pick("s_tower")], ["mnki", speech.pick("m_tower_reply")]], true, 0.6)


func on_tower_aim(tw) -> void:
    Sound.play("deny", 0.45, 1.5)
    if speech.ready("t_aim", 4.0):
        speech.bark(tw, "tower", "t_aim")


func on_tower_lost(tw) -> void:
    if speech.ready("t_lost", 6.0):
        speech.bark(tw, "tower", "t_lost")


## The sling lets go: a slow pebble that lands on the spot the red target showed.
func fire_stone(tw, target: Vector2) -> void:
    var from: Vector2 = tw.pos + Vector2(0, -18)
    var dist: float = from.distance_to(target)
    stones.append({"from": from, "to": target, "age": 0.0, "dur": maxf(dist / TowerScript.STONE_SPEED, 0.4), "tower": tw})
    Sound.play("flap", 0.8, 1.9, 0.05)
    _burst(from, Color(0.9, 0.85, 0.7), 5, 30.0, 0.35, 1.8)
    if speech.ready("t_fire", 3.0):
        speech.bark(tw, "tower", "t_fire")


func _update_stones(delta: float) -> void:
    var i: int = stones.size() - 1
    while i >= 0:
        var s: Dictionary = stones[i]
        s["age"] = float(s["age"]) + delta
        if float(s["age"]) >= float(s["dur"]):
            stones.remove_at(i)
            _stone_lands(s)
        i -= 1


func _stone_lands(s: Dictionary) -> void:
    var to: Vector2 = s["to"]
    var tw = s["tower"]
    var d: float = swan.pos.distance_to(to)
    _burst(to, Color(0.82, 0.76, 0.58), 10, 50.0, 0.5, 2.2)
    Sound.play("step_wood1", 0.6, 0.7)
    if d <= STONE_HIT_R and swan_inv <= 0.0:
        on_swan_bonk(tw)
    else:
        if speech.ready("t_miss", 3.0):
            speech.bark(tw, "tower", "t_miss")
        if d < 70.0 and speech.ready("s_dodge", 7.0) and randf() < 0.7:
            speech.hero_bark("swan", "s_dodge")


## Swan got hit by a pebble: dizzy for a moment, then briefly safe. Never fatal.
func on_swan_bonk(tw) -> void:
    swan_bonks += 1
    swan_stun = BONK_STUN
    swan_inv = BONK_SAFE
    swan.vel = Vector2.ZERO
    Sound.play("step_wood1", 1.0, 0.55)
    Sound.play("deny", 0.7, 0.6)
    shake = maxf(shake, 0.35)
    _burst(swan.pos, Color(1, 1, 1), 14, 70.0, 0.7, 2.6)
    _burst(swan.pos + Vector2(0, -10), Color(1.0, 0.9, 0.3), 8, 40.0, 0.8, 2.2)
    show_message("Bonk! A sling pebble hit Swan - she is dizzy for a moment. Keep moving to dodge the next one!", 3.2)
    speech.interrupt()
    speech.bark(tw, "tower", "t_hit", SpeechScript.PRIO_URGENT)
    speech.hero_bark("swan", "s_bonk", SpeechScript.PRIO_URGENT)
    if randf() < 0.7:
        speech.duo("bonk", true, 1.8)


# ----------------------------------------------------------- dialogue helpers

func _guard_bark(g, key: String, prio: int = 1) -> void:
    if not vis_tiles.has(level.tile_of(g.pos)):
        return
    speech.bark(g, "guard", key, prio)


func _anyone_chasing() -> bool:
    for g in guards:
        if g.state == GuardScript.CHASE:
            return true
    return false


func _on_mnki_hide() -> void:
    if _anyone_chasing():
        if speech.ready("hide_chased", 3.0):
            speech.hero_bark("mnki", "m_hide_chased", SpeechScript.PRIO_URGENT)
    elif speech.ready("hide", 14.0) and randf() < 0.5:
        speech.hero_bark("mnki", "m_hide")


## A teddy has spotted MNKI: it shouts, calls its friends, and the heroes react.
func _on_guard_chase(g) -> void:
    var called: Array = []
    for o in guards:
        if o == g or o.state == GuardScript.CHASE or o.state == GuardScript.RECOVER:
            continue
        if o.pos.distance_to(g.pos) > TILE * 11.0:
            continue
        var ob: int = o.state
        o.hear(level.tile_of(mnki.pos), 99.0, level)
        if o.state == GuardScript.SUSPICIOUS and ob != GuardScript.SUSPICIOUS:
            called.append(o)
    speech.interrupt()
    _guard_bark(g, "g_call" if not called.is_empty() else "g_chase", SpeechScript.PRIO_URGENT)
    for o2 in called:
        if vis_tiles.has(level.tile_of(o2.pos)):
            _guard_bark(o2, "g_answer", SpeechScript.PRIO_URGENT)
            break
    if speech.ready("chased_heroes", 7.0):
        speech.converse([["mnki", speech.pick("m_chased")], ["swan", speech.pick("s_chased")]], true)
    if not chase_hint_shown:
        chase_hint_shown = true
        show_message("A teddy is chasing MNKI! They run faster than you - break line of sight and hide in a bush before they get close.", 5.5)


## MNKI hid in a bush while the teddy was still far away: it loses the trail.
func _on_lost_by_hiding(g) -> void:
    _guard_bark(g, "g_lost", SpeechScript.PRIO_URGENT)
    show_message("Hidden! The teddy lost your trail. Stay still until it wanders off.", 3.2)
    Sound.play("swap", 0.5, 1.3)
    if speech.ready("relief", 6.0):
        speech.interrupt()
        if randf() < 0.5:
            speech.duo("relief", true, 1.0)
        else:
            speech.converse([["mnki", speech.pick("m_lost")], ["swan", speech.pick("s_lost")]], true, 1.0)


## When things are calm and the friends are close, they talk: love, and words of wisdom.
func _update_chatter(delta: float) -> void:
    chat_cd -= delta
    if chat_cd > 0.0:
        return
    if speech.is_chatting() or speech.hero_is_talking():
        chat_cd = 1.5
        return
    var calm: bool = swan_stun <= 0.0 and mnki.pos.distance_to(swan.pos) <= TILE * 6.0
    for g in guards:
        if g.state != GuardScript.PATROL or g.noticing:
            calm = false
    for tw in towers:
        if tw.state == TowerScript.AIM or tw.state == TowerScript.WATCH:
            calm = false
    if not calm:
        chat_cd = 2.5
        return
    if not intro_done:
        intro_done = true
        speech.duo("intro", false)
    else:
        speech.chat()
    chat_cd = randf_range(16.0, 26.0)


func _update_effects(delta: float) -> void:
    var i: int = effects.size() - 1
    while i >= 0:
        var e: Dictionary = effects[i]
        e["age"] = float(e["age"]) + delta
        if float(e["age"]) >= float(e["max"]):
            effects.remove_at(i)
        i -= 1
    i = particles.size() - 1
    var damp: float = maxf(0.0, 1.0 - 2.2 * delta)
    while i >= 0:
        var pt: Dictionary = particles[i]
        pt["age"] = float(pt["age"]) + delta
        if float(pt["age"]) >= float(pt["max"]):
            particles.remove_at(i)
        else:
            var v: Vector2 = pt["v"]
            v.y += float(pt["grav"]) * delta
            v *= damp
            pt["v"] = v
            pt["p"] = (pt["p"] as Vector2) + v * delta
        i -= 1


## A little puff of coloured specks (sparkles, leaves, droplets).
func _burst(at: Vector2, col: Color, n: int, speed: float, life: float, size: float = 2.5, grav: float = 0.0) -> void:
    for k in range(n):
        if particles.size() >= 200:
            return
        var a: float = randf() * TAU
        var sp: float = speed * randf_range(0.35, 1.0)
        particles.append({
            "p": at, "v": Vector2(cos(a), sin(a)) * sp, "age": 0.0,
            "max": life * randf_range(0.7, 1.2), "col": col, "size": size, "grav": grav,
        })


func _check_win() -> void:
    var fc: Vector2 = level.tile_center(level.fountain_tile)
    var near_m: bool = mnki.pos.distance_to(fc) < TILE * 1.6
    var near_s: bool = swan.pos.distance_to(fc) < TILE * 1.6
    if not (near_m or near_s):
        return
    if collected < fruit_total:
        if hint_cd <= 0.0:
            hint_cd = 5.0
            Sound.play("locked")
            show_message("The exit gate is locked. %d fruit to go." % (fruit_total - collected), 3.0)
            if speech.ready("locked", 8.0):
                speech.hero_bark("mnki" if near_m else "swan", "m_locked" if near_m else "s_locked")
        return
    if near_m and near_s:
        play_state = WON
        Sound.play("win")
        Sound.set_duck(true)
        options_box.visible = false
        var best: bool = PlayerData.record_win(elapsed)
        overlay_title.text = "Everyone made it out - and everyone is safe!"
        overlay_title.add_theme_color_override("font_color", UIThemeScript.GOLD)
        var extra: String = "  (new best!)" if best else ""
        overlay_info.text = "Fruit %d/%d   Time %s%s\nTraps disarmed: %d    Walked back to the gate: %d    Swan bonked: %d\nTeddies harmed: 0  -  true pacifists." % [
            collected, fruit_total, PlayerData.format_time(elapsed), extra, traps_disarmed, caught, swan_bonks]
        resume_btn.visible = false
        overlay.visible = true
    elif hint_cd <= 0.0:
        hint_cd = 5.0
        show_message("Bring both friends to the exit gate.", 2.5)


## A guard reaches MNKI. Nonviolent recovery: he is walked back to the gate.
func on_caught(by) -> void:
    caught += 1
    PlayerData.total_caught += 1
    mnki.pos = level.tile_center(level.start_tile)
    mnki.last_pos = mnki.pos
    mnki.vel = Vector2.ZERO
    mnki.hidden = false
    was_hidden = false
    Sound.play("caught")
    shake = maxf(shake, 0.6)
    _burst(by.pos, Color(1.0, 0.85, 0.5), 12, 60.0, 0.6, 2.4)
    cut_progress = 0.0
    disarm_progress = 0.0
    follower.path.clear()
    follower.waiting = false
    follower_mode = "follow"
    for g in guards:
        g.calm()
    by.state = GuardScript.RECOVER
    by.timer = 2.5
    show_message("A teddy politely walked MNKI back to the gate. No harm done!", 3.5)
    speech.clear()
    speech.duo("caught")


## The one thing that must never happen. Pacifist run failed.
func on_guard_harmed(g) -> void:
    if play_state != PLAYING:
        return
    play_state = LOST
    harmed_guard = g
    Sound.play("harmed")
    Sound.set_duck(true)
    Sound.set_tension(0.0)
    shake = 0.8
    get_tree().create_timer(0.9).timeout.connect(func() -> void: Sound.play("lose"))
    options_box.visible = false
    overlay_title.text = "A teddy got hurt!"
    overlay_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
    overlay_info.text = "Feather & Tail is a pacifist game - nobody may be harmed.\nA chasing teddy ran into a trap. Stay unseen near traps,\nbreak line of sight, or disarm them first (hold %s as MNKI)." % ("DISARM" if Platform.is_touch else "E")
    resume_btn.visible = false
    overlay.visible = true


func hero_name(h: HeroScript) -> String:
    return "MNKI" if h.kind == "mnki" else "Swan"


func show_message(text: String, secs: float) -> void:
    if msg_label == null:
        return
    msg_label.text = text
    msg_timer = secs


# ----------------------------------------------------------------- UI / HUD

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 5
    add_child(layer)

    # one themed root so every panel / button / label shares the same garden look
    var root := Control.new()
    root.theme = UIThemeScript.make()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var ov := OverlayScript.new()
    ov.game = self
    root.add_child(ov)
    ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # on-screen controls: phones / tablets only (a PC never creates them)
    if Platform.is_touch:
        touch = TouchControlsScript.new()
        touch.game = self
        root.add_child(touch)
        touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # toast message (bottom centre; narrower on touch so it clears the buttons)
    msg_label = Label.new()
    msg_label.position = Vector2(260, 590) if Platform.is_touch else Vector2(200, 622)
    msg_label.size = Vector2(760, 42) if Platform.is_touch else Vector2(880, 42)
    msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    msg_label.add_theme_font_size_override("font_size", 16 if Platform.is_touch else 18)
    msg_label.add_theme_stylebox_override("normal", UIThemeScript.box(Color(0.05, 0.13, 0.10, 0.9), Color(0.45, 0.75, 0.50, 0.8), 14, 2))
    msg_label.visible = false
    root.add_child(msg_label)

    # pause / win / lose panel
    overlay = Control.new()
    overlay.visible = false
    root.add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    overlay.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var card := PanelContainer.new()
    center.add_child(card)
    var margin := MarginContainer.new()
    for side in ["margin_left", "margin_right"]:
        margin.add_theme_constant_override(side, 44)
    for side in ["margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 30)
    card.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    margin.add_child(box)

    overlay_title = Label.new()
    overlay_title.add_theme_font_size_override("font_size", 40)
    overlay_title.add_theme_color_override("font_color", UIThemeScript.CREAM)
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(overlay_title)

    overlay_info = Label.new()
    overlay_info.add_theme_font_size_override("font_size", 19)
    overlay_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(overlay_info)

    options_box = VBoxContainer.new()
    options_box.add_theme_constant_override("separation", 8)
    options_box.visible = false
    AudioOptionsScript.build(options_box)
    box.add_child(options_box)

    resume_btn = _make_button("Resume", _toggle_pause, box)
    _make_button("Restart", _restart, box)
    if Platform.is_web and not OS.has_feature("web_ios"):
        _make_button("Fullscreen", Platform.toggle_fullscreen, box)
    _make_button("Main menu", _to_menu, box)


func _make_button(text: String, cb: Callable, parent: Control) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(260, 54 if Platform.is_touch else 44)
    b.pressed.connect(cb)
    parent.add_child(b)
    return b


func _toggle_pause() -> void:
    if play_state == PLAYING:
        play_state = PAUSED
        overlay_title.text = "Paused"
        overlay_title.add_theme_color_override("font_color", UIThemeScript.CREAM)
        overlay_info.text = "Take a breath. The teddies are patient."
        resume_btn.visible = true
        options_box.visible = true
        overlay.visible = true
        Sound.play("pause_open")
        Sound.set_duck(true)
    elif play_state == PAUSED:
        play_state = PLAYING
        overlay.visible = false
        Sound.play("pause_close")
        Sound.set_duck(false)


func _restart() -> void:
    Transition.reload()


func _to_menu() -> void:
    Transition.go("res://Menus/Main_Menu.tscn")


func _update_hud() -> void:
    msg_label.visible = msg_timer > 0.0
    if touch != null:
        touch.set_active(play_state == PLAYING)
