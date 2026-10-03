extends Control
## Screen-space HUD drawn in code: top panels (fruit, who leads, peace counter),
## key-hint chips, split-screen frames and a minimap.

const LevelScript = preload("res://Game/Level.gd")
const ArtLoader = preload("res://Game/ArtLoader.gd")

const MAP_PX := 5   # minimap pixels per tile

const CREAM := Color(1.0, 0.96, 0.84)
const GOLD := Color(1.0, 0.85, 0.35)
const PANEL_BG := Color(0.05, 0.13, 0.10, 0.88)
const PANEL_EDGE := Color(0.45, 0.75, 0.50, 0.75)

var game: Node2D
var font: Font
var sb_panel: StyleBoxFlat
var sb_key: StyleBoxFlat
var clock: float = 0.0
var mm_img: Image                 # minimap pixels, rebuilt only when the map changes
var mm_tex: ImageTexture
var mm_version: int = -1
var redraw_acc: float = 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    font = ThemeDB.fallback_font
    sb_panel = StyleBoxFlat.new()
    sb_panel.bg_color = PANEL_BG
    sb_panel.border_color = PANEL_EDGE
    sb_panel.set_border_width_all(2)
    sb_panel.set_corner_radius_all(14)
    sb_panel.shadow_color = Color(0, 0, 0, 0.35)
    sb_panel.shadow_size = 4
    sb_key = StyleBoxFlat.new()
    sb_key.bg_color = Color(0.95, 0.90, 0.75)
    sb_key.border_color = Color(0.55, 0.45, 0.30)
    sb_key.set_border_width_all(1)
    sb_key.border_width_bottom = 3
    sb_key.set_corner_radius_all(5)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mm_img = Image.create(LevelScript.W, LevelScript.H, false, Image.FORMAT_RGBA8)
    mm_tex = ImageTexture.create_from_image(mm_img)


func _process(delta: float) -> void:
    clock += delta
    # the HUD is text-heavy: redraw it at ~30 Hz (full rate only while the split / merge animates)
    redraw_acc += delta
    var animating: bool = game != null and game.merge > 0.001 and game.merge < 0.999
    if animating or redraw_acc >= 0.033:
        redraw_acc = 0.0
        queue_redraw()


func _draw() -> void:
    if game == null or game.level == null:
        return
    if game.merge < 0.995:
        var ra: Rect2 = game.rect_a
        var rb: Rect2 = game.rect_b
        if game.split_vertical:
            draw_rect(Rect2(rb.position.x - 3, 0, 6, 720), Color(0.02, 0.03, 0.03))
        else:
            draw_rect(Rect2(0, rb.position.y - 3, 1280, 6), Color(0.02, 0.03, 0.03))
        _panel_frame(ra, game.hero_a)
        _panel_frame(rb, game.hero_b)
    _draw_fruit_panel()
    _draw_leader_panel()
    _draw_peace_panel()
    _draw_key_hints()
    _draw_minimap()


# ------------------------------------------------------------------ helpers

func _text(pos: Vector2, s: String, size: int, col: Color = CREAM, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
    draw_string(font, pos + Vector2(1, 1), s, align, width, size, Color(0, 0, 0, 0.6))
    draw_string(font, pos, s, align, width, size, col)


func _text_w(s: String, size: int) -> float:
    return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


func _panel(r: Rect2) -> void:
    draw_style_box(sb_panel, r)


func _panel_frame(r: Rect2, h) -> void:
    var is_leader: bool = h == game.leader
    var col := Color(1.0, 0.9, 0.2, 0.95) if is_leader else Color(1, 1, 1, 0.25)
    draw_rect(r.grow(-2), col, false, 3.0)
    var name_text: String = game.hero_name(h) + (" (ground)" if h.kind == "mnki" else " (air)")
    if is_leader:
        name_text += "  - LEADING"
    _text(r.position + Vector2(14, 84), name_text, 15, col)


# ----------------------------------------------------------------- icons

## Draws Art/icon_<name>.png centred on c (about 2.4 x radius wide), tinted by col's alpha. Returns false if no file.
func _art_icon(name: String, c: Vector2, r: float, alpha: float = 1.0) -> bool:
    var t: Texture2D = ArtLoader.tex("icon_" + name)
    if t == null:
        return false
    var sz: float = r * 2.4
    var ts: Vector2 = t.get_size()
    var k: float = sz / maxf(ts.x, ts.y)
    var d: Vector2 = ts * k
    draw_texture_rect(t, Rect2(c - d * 0.5, d), false, Color(1, 1, 1, alpha))
    return true


func _icon_apple(c: Vector2, r: float, col: Color = Color(0.88, 0.14, 0.14)) -> void:
    if _art_icon("apple", c, r, col.a if col.a < 0.99 else 1.0):
        return
    draw_circle(c + Vector2(0, 1), r, col)
    draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.28, Color(1, 0.75, 0.75, 0.8))
    draw_line(c + Vector2(0, -r * 0.8), c + Vector2(1, -r * 1.3), Color(0.35, 0.22, 0.1), 1.5)
    draw_circle(c + Vector2(r * 0.55, -r * 1.0), r * 0.3, Color(0.25, 0.65, 0.25))


func _icon_pear(c: Vector2, r: float, col: Color = Color(0.96, 0.80, 0.22)) -> void:
    if _art_icon("pear", c, r, col.a if col.a < 0.99 else 1.0):
        return
    draw_circle(c + Vector2(0, r * 0.35), r, col)
    draw_circle(c + Vector2(0, -r * 0.55), r * 0.62, col)
    draw_line(c + Vector2(0, -r * 1.1), c + Vector2(1, -r * 1.5), Color(0.35, 0.22, 0.1), 1.5)
    draw_circle(c + Vector2(-r * 0.35, r * 0.1), r * 0.25, Color(1, 1, 0.85, 0.8))


func _icon_heart(c: Vector2, r: float, col: Color) -> void:
    if _art_icon("heart", c, r * 1.1):
        return
    draw_circle(c + Vector2(-r * 0.5, -r * 0.3), r * 0.55, col)
    draw_circle(c + Vector2(r * 0.5, -r * 0.3), r * 0.55, col)
    draw_colored_polygon(PackedVector2Array([
        c + Vector2(-r * 1.02, -r * 0.05), c + Vector2(r * 1.02, -r * 0.05), c + Vector2(0, r * 1.05)]), col)


func _portrait(c: Vector2, kind: String, r: float, leader: bool) -> void:
    draw_circle(c, r, Color(0.12, 0.30, 0.20))
    if kind == "mnki":
        draw_circle(c + Vector2(0, r * 0.62), r * 0.55, Color(0.85, 0.15, 0.15))
        draw_circle(c + Vector2(0, -r * 0.1), r * 0.58, Color(0.22, 0.14, 0.09))
        draw_circle(c + Vector2(0, r * 0.05), r * 0.42, Color(0.70, 0.50, 0.32))
        draw_circle(c + Vector2(-r * 0.2, -r * 0.05), r * 0.08, Color(0.1, 0.06, 0.04))
        draw_circle(c + Vector2(r * 0.2, -r * 0.05), r * 0.08, Color(0.1, 0.06, 0.04))
    else:
        draw_circle(c + Vector2(0, r * 0.1), r * 0.62, Color(1, 1, 1))
        draw_colored_polygon(PackedVector2Array([
            c + Vector2(-r * 0.25, r * 0.15), c + Vector2(r * 0.25, r * 0.15), c + Vector2(0, r * 0.55)]), Color(1.0, 0.6, 0.15))
        draw_circle(c + Vector2(-r * 0.22, -r * 0.1), r * 0.08, Color(0.1, 0.08, 0.06))
        draw_circle(c + Vector2(r * 0.22, -r * 0.1), r * 0.08, Color(0.1, 0.08, 0.06))
        draw_circle(c + Vector2(0, -r * 0.55), r * 0.14, GOLD)
    draw_arc(c, r, 0.0, TAU, 28, GOLD if leader else Color(1, 1, 1, 0.3), 2.5 if leader else 1.5)


# ------------------------------------------------------------------ panels

func _draw_fruit_panel() -> void:
    var level: LevelScript = game.level
    var n: int = level.fruits.size()
    var w: float = 30.0 + 76.0 + float(n) * 34.0
    _panel(Rect2(12, 10, w, 46))
    _text(Vector2(26, 31), "Fruit", 14, Color(0.8, 0.9, 0.8))
    _text(Vector2(26, 48), "%d / %d" % [game.collected, game.fruit_total], 15, GOLD)
    for i in range(n):
        var f: Dictionary = level.fruits[i]
        var c := Vector2(30.0 + 76.0 + float(i) * 34.0, 33.0)
        if f["got"]:
            if f["kind"] == "ground":
                _icon_apple(c, 9.0)
            else:
                _icon_pear(c, 8.0)
        else:
            draw_circle(c, 11, Color(0, 0, 0, 0.35))
            draw_arc(c, 11, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.5)
            if f["kind"] == "ground":
                _icon_apple(c, 7.0, Color(0.88, 0.14, 0.14, 0.28))
            else:
                _icon_pear(c, 6.5, Color(0.96, 0.80, 0.22, 0.28))


func _draw_leader_panel() -> void:
    var r := Rect2(410, 10, 460, 46)
    _panel(r)
    var lead = game.leader
    var fol = game.follower
    _portrait(Vector2(442, 33), lead.kind, 16.0, true)
    _text(Vector2(466, 31), "%s leads" % game.hero_name(lead), 17, CREAM)
    _text(Vector2(466, 48), "tap SWAP" if Platform.is_touch else "Tab to swap", 12, Color(0.75, 0.85, 0.75))
    draw_line(Vector2(610, 18), Vector2(610, 48), Color(1, 1, 1, 0.15), 1.0)
    _portrait(Vector2(640, 33), fol.kind, 13.0, false)
    var fstate: String = "following"
    if game.follower_mode == "hold":
        fstate = "holding"
    elif fol.waiting:
        fstate = "waiting (teddy ahead)"
    elif game.follower_mode == "goto":
        fstate = "heading to target"
    elif fol.blocked:
        fstate = "no route!"
    _text(Vector2(662, 31), game.hero_name(fol), 15, CREAM)
    var scol := Color(1.0, 0.7, 0.45) if (fol.waiting or fol.blocked) else Color(0.75, 0.9, 0.75)
    _text(Vector2(662, 48), fstate, 12, scol)


func _draw_peace_panel() -> void:
    _panel(Rect2(1008, 10, 260, 46))
    var pulse: float = 1.0 + 0.06 * sin(clock * 3.0)
    var harmed: bool = game.harmed_guard != null
    _icon_heart(Vector2(1036, 31), 8.0 * pulse, Color(0.9, 0.25, 0.30) if harmed else Color(1.0, 0.45, 0.62))
    _text(Vector2(1054, 30), "Teddies hurt: %d" % (1 if harmed else 0), 14, Color(1.0, 0.6, 0.55) if harmed else CREAM)
    _text(Vector2(1054, 48), "Traps %d  |  Walked back %d" % [game.level.traps.size(), game.caught], 12, Color(0.75, 0.85, 0.75))
    _text(Vector2(1150, 36), PlayerData.format_time(game.elapsed), 20, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 108.0)


func _draw_key_hints() -> void:
    if Platform.is_touch:
        return      # on-screen buttons replace the keyboard hints
    var hints: Array = []
    if game.leader.kind == "mnki":
        hints = [["WASD", "move"], ["Shift", "sneak"], ["F", "cut hedge"], ["E", "disarm trap"], ["Tab", "swap"], ["Click", "command"], ["H", "hold"], ["Esc", "pause"]]
    else:
        hints = [["WASD", "fly"], ["Space", "chirp"], ["Tab", "swap"], ["Click", "command"], ["H", "hold"], ["Esc", "pause"]]
    var x: float = 14.0
    var y: float = 684.0
    for h in hints:
        var kw: float = _text_w(h[0], 12) + 14.0
        draw_style_box(sb_key, Rect2(x, y, kw, 22))
        draw_string(font, Vector2(x + 7.0, y + 16.0), h[0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.25, 0.2, 0.12))
        x += kw + 5.0
        _text(Vector2(x, y + 16.0), h[1], 12, Color(1, 1, 1, 0.85))
        x += _text_w(h[1], 12) + 16.0


# ----------------------------------------------------------------- minimap

func _rebuild_minimap() -> void:
    var level: LevelScript = game.level
    mm_img.fill(Color(0, 0, 0, 0))
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
            mm_img.set_pixel(x, y, col)
    mm_tex.update(mm_img)


func _draw_minimap() -> void:
    var level: LevelScript = game.level
    var w: int = LevelScript.W * MAP_PX
    var h: int = LevelScript.H * MAP_PX
    var origin := Vector2(1280 - w - 22, 78)   # top-right: the exit / fountain are bottom-right, keep them visible
    _panel(Rect2(origin - Vector2(8, 8), Vector2(w + 16, h + 16)))
    if mm_version != game.map_version:
        mm_version = game.map_version
        _rebuild_minimap()
    draw_texture_rect(mm_tex, Rect2(origin, Vector2(w, h)), false)
    for t in level.traps:
        if game.seen_tiles.has(t):
            draw_rect(Rect2(origin + Vector2(t) * MAP_PX, Vector2(MAP_PX, MAP_PX)), Color(0.95, 0.2, 0.15))
    for f in level.fruits:
        if not f["got"] and game.seen_tiles.has(f["tile"]):
            var fc: Color = Color(0.95, 0.2, 0.2) if f["kind"] == "ground" else Color(0.98, 0.85, 0.2)
            draw_circle(origin + (Vector2(f["tile"]) + Vector2(0.5, 0.5)) * MAP_PX, 2.5, fc)
    for g in game.guards:
        if game.vis_tiles.has(level.tile_of(g.pos)):
            draw_circle(origin + g.pos / LevelScript.TILE * MAP_PX, 2.7, Color(0.85, 0.6, 0.3))
            draw_circle(origin + g.pos / LevelScript.TILE * MAP_PX, 1.2, Color(0.95, 0.8, 0.55))
    draw_circle(origin + game.mnki.pos / LevelScript.TILE * MAP_PX, 3.0, Color(1.0, 0.25, 0.25))
    draw_circle(origin + game.swan.pos / LevelScript.TILE * MAP_PX, 3.0, Color(1, 1, 1))
