extends Control
## Animated garden scene behind the title screen: stream + bridge, path, fountain,
## trees, flowers, lamps, exit gate - and MNKI, Swan and a teddy guard who hasn't noticed them.
## All vector placeholders, drawn in 1280x720 space.

const Sprites = preload("res://Game/Sprites.gd")
const ArtLoader = preload("res://Game/ArtLoader.gd")

const PATH_COL := Color(0.86, 0.81, 0.64)
const WATER_COL := Color(0.25, 0.60, 0.92)
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
const TREE_PALETTES := [
    [Color(0.08, 0.34, 0.16), Color(0.15, 0.50, 0.24), Color(0.30, 0.65, 0.33)],
    [Color(0.36, 0.46, 0.20), Color(0.52, 0.64, 0.28), Color(0.95, 0.62, 0.74)],
    [Color(0.55, 0.38, 0.10), Color(0.80, 0.58, 0.14), Color(0.96, 0.80, 0.30)],
]

var is_static: bool = false     # the static twin draws the unchanging scenery ONCE (cached by the engine)
var clock: float = 0.0
var tufts: Array = []
var flowers: Array = []
var butterflies: Array = []
var path_pts := PackedVector2Array()
var stream_pts := PackedVector2Array()

# [x, y, radius, palette]
var trees: Array = [
    [50, 60, 72, 0], [190, 34, 54, 1], [1235, 60, 76, 0], [1110, 52, 54, 2],
    [1245, 650, 82, 1], [1125, 695, 58, 0], [28, 360, 58, 2], [640, 40, 56, 0],
    [790, 695, 52, 2], [520, 700, 50, 1],
]


var bg_tex: Texture2D = null    # Art/menu_background.png - when present it replaces the whole vector scene


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg_tex = ArtLoader.tex("menu_background")
    if bg_tex != null:
        set_process(false)          # a still picture needs no per-frame redraw
        queue_redraw()
        return
    if not is_static:
        # a second copy of this node draws all the non-moving scenery behind us
        var back: Control = get_script().new()
        back.is_static = true
        back.show_behind_parent = true
        add_child(back)
        back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        set_process(false)
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    for i in range(280):
        tufts.append(Vector2(rng.randf() * 1280.0, rng.randf() * 720.0))
    for i in range(9):
        var cc := Vector2(rng.randf_range(40.0, 1240.0), rng.randf_range(80.0, 690.0))
        for k in range(8):
            flowers.append({
                "p": cc + Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(-22.0, 22.0)),
                "c": FLOWER_COLS[rng.randi_range(0, FLOWER_COLS.size() - 1)],
                "ph": rng.randf() * TAU,
            })
    for i in range(9):
        butterflies.append({
            "a": Vector2(rng.randf_range(660.0, 1200.0), rng.randf_range(200.0, 600.0)),
            "ph": rng.randf() * TAU,
            "c": FLOWER_COLS[rng.randi_range(0, FLOWER_COLS.size() - 1)],
        })
    # winding path: gate corner -> bridge -> fountain plaza
    for i in range(41):
        var t: float = float(i) / 40.0
        path_pts.append(_bez(Vector2(-30, 660), Vector2(360, 650), Vector2(700, 560), t))
    for i in range(1, 41):
        var t2: float = float(i) / 40.0
        path_pts.append(_bez(Vector2(700, 560), Vector2(900, 520), Vector2(1060, 400), t2))
    for i in range(0, 41):
        var y: float = -20.0 + 780.0 * float(i) / 40.0
        stream_pts.append(Vector2(700.0 + sin(y / 95.0) * 22.0, y))


func _bez(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
    return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _process(delta: float) -> void:
    clock += delta
    queue_redraw()


func _draw() -> void:
    if bg_tex != null:
        ArtLoader.draw_cover(self, bg_tex, Rect2(Vector2.ZERO, Vector2(1280, 720)))
        return
    if is_static:
        _draw_static()
    else:
        _draw_dynamic()


func _draw_static() -> void:
    # grass gradient
    draw_polygon(
        PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
        PackedColorArray([Color(0.09, 0.24, 0.16), Color(0.10, 0.26, 0.17), Color(0.20, 0.43, 0.27), Color(0.18, 0.40, 0.25)]))
    for tp in tufts:
        draw_line(tp, tp + Vector2(-2, -5), Color(0.28, 0.58, 0.30, 0.55), 1.5)
        draw_line(tp, tp + Vector2(2, -6), Color(0.28, 0.58, 0.30, 0.55), 1.5)

    # hedge-maze edge along the top
    for i in range(36):
        var hx: float = float(i) * 36.0
        draw_rect(Rect2(hx, 0, 36, 30), Color(0.08, 0.24, 0.14))
        draw_rect(Rect2(hx + 3, 3, 30, 24), Color(0.12, 0.34, 0.20))
        draw_circle(Vector2(hx + 12, 12), 4, Color(0.18, 0.45, 0.26))
        draw_circle(Vector2(hx + 25, 18), 3.5, Color(0.18, 0.45, 0.26))

    # path
    draw_polyline(path_pts, PATH_COL.darkened(0.3), 54.0)
    draw_polyline(path_pts, PATH_COL, 46.0)

    # stream
    draw_polyline(stream_pts, WATER_COL.darkened(0.25), 44.0)
    draw_polyline(stream_pts, WATER_COL, 36.0)

    _draw_bridge(Vector2(702, 566))
    _draw_pond_base(Vector2(930, 655), 58.0)
    _draw_fountain_base(Vector2(1060, 400), 66.0)
    _draw_exit_gate_base(Vector2(1232, 400))
    for lp in [Vector2(775, 470), Vector2(985, 505), Vector2(1135, 300)]:
        _draw_lamp_base(lp)

    for f in flowers:
        var fp: Vector2 = f["p"]
        draw_line(fp, fp + Vector2(0, 7), Color(0.2, 0.5, 0.2), 1.5)
        for k in range(5):
            var a: float = TAU * float(k) / 5.0
            draw_circle(fp + Vector2(cos(a), sin(a)) * 3.6, 3.2, f["c"])
        draw_circle(fp, 2.3, Color(1.0, 0.8, 0.2))

    for tr in trees:
        _draw_tree(Vector2(tr[0], tr[1]), float(tr[2]), tr[3])


func _draw_dynamic() -> void:
    # stream sparkle
    for i in range(10):
        var y: float = fposmod(clock * 40.0 + float(i) * 78.0, 780.0) - 20.0
        var x: float = 700.0 + sin(y / 95.0) * 22.0 + float((i * 7) % 20) - 10.0
        draw_line(Vector2(x, y), Vector2(x, y + 12), WATER_LIGHT, 2.0)

    _draw_pond_anim(Vector2(930, 655), 58.0)
    _draw_fountain_anim(Vector2(1060, 400), 66.0)
    _draw_exit_gate_anim(Vector2(1232, 400))
    for lp in [Vector2(775, 470), Vector2(985, 505), Vector2(1135, 300)]:
        _draw_lamp_glow(lp)

    # the cast: two friends sneaking past a teddy who has not noticed them
    var bob: float = sin(clock * 2.0)
    _draw_char_shadow(Vector2(862, 545), 34.0)
    _draw_scaled(Vector2(860, 512), 3.4, "mnki", 0)
    _draw_char_shadow(Vector2(962, 520), 28.0)
    _draw_scaled(Vector2(960, 440 + bob * 6.0), 3.4, "swan", 0)
    _draw_char_shadow(Vector2(1170, 600), 36.0)
    _draw_scaled(Vector2(1168, 556), 3.6, "teddy", 0)

    # "?" bubble over the teddy - he is not sure what he heard
    var bp := Vector2(1168, 450 + sin(clock * 3.0) * 3.0)
    draw_circle(bp, 17, Color(1, 1, 1, 0.95))
    draw_string(ThemeDB.fallback_font, bp + Vector2(-8, 9), "?", HORIZONTAL_ALIGNMENT_CENTER, 16.0, 26, Color(0.3, 0.2, 0.1))

    # butterflies
    for b in butterflies:
        var ph: float = b["ph"]
        var bpos: Vector2 = b["a"] + Vector2(cos(clock * 0.6 + ph) * 36.0, sin(clock * 1.0 + ph * 2.0) * 22.0)
        var flap: float = absf(sin(clock * 11.0 + ph))
        draw_circle(bpos + Vector2(-3.5 * flap - 0.5, 0), 3.6, b["c"])
        draw_circle(bpos + Vector2(3.5 * flap + 0.5, 0), 3.6, b["c"])
        draw_circle(bpos, 1.3, Color(0.2, 0.15, 0.15))


func _draw_char_shadow(p: Vector2, r: float) -> void:
    draw_circle(p, r, Color(0, 0, 0, 0.18))


func _draw_scaled(p: Vector2, s: float, who: String, variant: int) -> void:
    draw_set_transform(p, 0.0, Vector2(s, s))
    match who:
        "mnki":
            Sprites.mnki(self, Vector2.ZERO, Vector2(0.4, -0.9), 1.0, false)
        "swan":
            Sprites.swan(self, Vector2.ZERO, Vector2(-0.4, 0.9), 1.0, clock)
        "teddy":
            Sprites.teddy(self, Vector2.ZERO, Vector2(1, 0.2), variant, "calm", clock, false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tree(c: Vector2, r: float, pal_i: int) -> void:
    var pal: Array = TREE_PALETTES[pal_i]
    draw_circle(c + Vector2(r * 0.18, r * 0.22), r, Color(0, 0, 0, 0.22))
    draw_circle(c, r, pal[0])
    draw_circle(c + Vector2(-r * 0.12, -r * 0.18), r * 0.74, pal[1])
    draw_circle(c + Vector2(-r * 0.30, -r * 0.38), r * 0.38, pal[2])
    draw_circle(c + Vector2(r * 0.32, r * 0.2), r * 0.24, pal[2].darkened(0.1))


func _draw_lamp_base(c: Vector2) -> void:
    draw_circle(c, 40, Color(1.0, 0.9, 0.5, 0.18))
    draw_circle(c + Vector2(0, 18), 9, STONE)
    draw_rect(Rect2(c + Vector2(-3, -10), Vector2(6, 28)), Color(0.15, 0.15, 0.18))
    draw_circle(c + Vector2(0, -14), 11, Color(1.0, 0.92, 0.55))
    draw_circle(c + Vector2(0, -14), 5, Color(1.0, 1.0, 0.85))


func _draw_lamp_glow(c: Vector2) -> void:
    var glow: float = 0.05 * sin(clock * 3.0 + c.x) + 0.03
    draw_circle(c + Vector2(0, -14), 22, Color(1.0, 0.9, 0.5, maxf(glow, 0.0)))
    draw_circle(c + Vector2(0, -14), 11, Color(1.0, 0.92, 0.55))
    draw_circle(c + Vector2(0, -14), 5, Color(1.0, 1.0, 0.85))


func _draw_bridge(c: Vector2) -> void:
    draw_rect(Rect2(c + Vector2(-44, -34), Vector2(88, 68)), WOOD_LIGHT)
    for i in range(8):
        draw_line(c + Vector2(-40 + i * 11, -34), c + Vector2(-40 + i * 11, 34), WOOD, 2.0)
    draw_rect(Rect2(c + Vector2(-44, -38), Vector2(88, 7)), WOOD)
    draw_rect(Rect2(c + Vector2(-44, 31), Vector2(88, 7)), WOOD)
    for px in [-44.0, 36.0]:
        draw_rect(Rect2(c + Vector2(px, -42), Vector2(8, 12)), WOOD.darkened(0.2))
        draw_rect(Rect2(c + Vector2(px, 30), Vector2(8, 12)), WOOD.darkened(0.2))


func _draw_pond_base(c: Vector2, r: float) -> void:
    draw_circle(c, r + 7, STONE)
    draw_circle(c, r, WATER_COL)
    for pad in [Vector2(-22, 8), Vector2(18, 20), Vector2(-4, -22), Vector2(26, -14)]:
        draw_circle(c + pad, 10, Color(0.25, 0.65, 0.30))
        draw_line(c + pad, c + pad + Vector2(9, -3), WATER_COL, 2.0)
    draw_circle(c + Vector2(-20, 6), 4, Color(1.0, 0.65, 0.78))
    draw_circle(c + Vector2(20, 18), 4, Color(1.0, 0.95, 0.6))


func _draw_pond_anim(c: Vector2, r: float) -> void:
    for i in range(3):
        var k: float = fposmod(clock * 0.5 + float(i) / 3.0, 1.0)
        draw_arc(c + Vector2(10, -6), 6.0 + k * 34.0, 0.0, TAU, 28, Color(WATER_LIGHT, 0.8 * (1.0 - k)), 2.0)


func _draw_fountain_base(c: Vector2, r: float) -> void:
    draw_circle(c, r + 14, STONE_LIGHT.darkened(0.1))
    draw_circle(c, r, STONE)
    draw_circle(c, r - 8, WATER_COL)
    draw_circle(c, 11, STONE_LIGHT)


func _draw_fountain_anim(c: Vector2, r: float) -> void:
    draw_arc(c, r * 0.55 + sin(clock * 3.0) * 3.0, 0.0, TAU, 32, WATER_LIGHT, 2.5)
    for i in range(9):
        var k: float = fposmod(clock * 0.8 + float(i) / 9.0, 1.0)
        var a: float = TAU * float(i) / 9.0
        var jp: Vector2 = c + Vector2(cos(a) * 34.0 * k, sin(a) * 16.0 * k - 46.0 * sin(PI * k))
        draw_circle(jp, 3.6, Color(WATER_LIGHT, 1.0 - k * 0.5))


func _draw_exit_gate_base(c: Vector2) -> void:
    draw_rect(Rect2(c + Vector2(-26, -50), Vector2(52, 100)), STONE)
    draw_rect(Rect2(c + Vector2(-26, -50), Vector2(52, 10)), STONE_LIGHT)


func _draw_exit_gate_anim(c: Vector2) -> void:
    var pulse: float = 0.75 + 0.25 * sin(clock * 3.0)
    draw_rect(Rect2(c + Vector2(-17, -36), Vector2(34, 72)), Color(1.0, 0.95, 0.55, pulse))
    draw_rect(Rect2(c + Vector2(-17, -36), Vector2(7, 72)), Color(0.25, 0.25, 0.3))
    draw_rect(Rect2(c + Vector2(10, -36), Vector2(7, 72)), Color(0.25, 0.25, 0.3))
    draw_string(ThemeDB.fallback_font, c + Vector2(-26, -56), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 52.0, 16, Color(0.6, 1.0, 0.6))
