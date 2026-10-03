extends RefCounted
## Optional drop-in art. If a file exists in res://Art/ it is used, otherwise the vector placeholder is drawn.
##   var t: Texture2D = ArtLoader.tex("menu_background")   # -> res://Art/menu_background.png (or null)
## Files looked for (PNG, WebP or JPG):
##   menu_background  title_logo  icon_apple  icon_pear  icon_heart  (+ mnki / swan / guard, see Game.gd)

static var _cache: Dictionary = {}


static func tex(name: String) -> Texture2D:
    if _cache.has(name):
        return _cache[name]
    var t: Texture2D = null
    for ext in ["png", "webp", "jpg"]:
        var path: String = "res://Art/%s.%s" % [name, ext]
        if ResourceLoader.exists(path):
            t = load(path) as Texture2D
            break
    _cache[name] = t
    return t


## Draw `t` scaled to fill the whole rect (like CSS background-size: cover), centred.
static func draw_cover(ci: CanvasItem, t: Texture2D, rect: Rect2) -> void:
    var ts: Vector2 = t.get_size()
    var k: float = maxf(rect.size.x / ts.x, rect.size.y / ts.y)
    var sz: Vector2 = ts * k
    ci.draw_texture_rect(t, Rect2(rect.position + (rect.size - sz) * 0.5, sz), false)
