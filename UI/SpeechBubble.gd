extends Control
## One speech bubble in the garden. The scene holds one background + tail per speaker (BgMnki / TailMnki,
## BgSwan, BgGuard, BgTower) - replace their textures in the scene or the PNGs in Art/Bubbles/.
## BubbleLayer.gd creates / moves / fades these; the node's origin is the point just above the speaker.

const BUBBLE_W := 128.0
const NAMES := {"mnki": "MNKI", "swan": "Swan", "guard": "Teddy", "tower": "Sling Teddy"}
const NAME_COLORS := {
    "mnki": Color(0.7, 0.12, 0.12), "swan": Color(0.22, 0.42, 0.80),
    "guard": Color(0.50, 0.28, 0.10), "tower": Color(0.62, 0.20, 0.14),
}

var _bw: float = 0.0
var _bh: float = 0.0
var _tail: Control = null


func setup(kind: String, text: String) -> void:
    for k in NAMES:
        var cap: String = String(k).capitalize()
        get_node("%Bg" + cap).visible = k == kind
        get_node("%Tail" + cap).visible = k == kind
    _tail = get_node("%Tail" + kind.capitalize())

    var font: Font = %TextLabel.get_theme_font("font")
    var fs: int = %TextLabel.get_theme_font_size("font_size")
    var nfs: int = %NameLabel.get_theme_font_size("font_size")
    var ts: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_W, fs)
    var name_w: float = font.get_string_size(NAMES[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
    var name_h: float = font.get_height(nfs)
    _bw = maxf(ts.x, name_w) + 14.0
    _bh = ts.y + name_h + 8.0

    var bg: NinePatchRect = get_node("%Bg" + kind.capitalize())
    bg.size = Vector2(_bw, _bh)
    %NameLabel.text = NAMES[kind]
    %NameLabel.add_theme_color_override("font_color", NAME_COLORS[kind])
    %NameLabel.size = Vector2(_bw - 8.0, name_h)
    %TextLabel.text = text
    %TextLabel.size = Vector2(ts.x + 2.0, ts.y)
    # everything is laid out around the origin (bottom-centre of the bubble sits 7px above it)
    var origin := Vector2(-_bw * 0.5, -_bh - 7.0)
    bg.position = origin
    %NameLabel.position = origin + Vector2(7, 3)
    %TextLabel.position = origin + Vector2(7, 3.0 + name_h)


## `src_dx` = how far the speaker is to the right of the bubble's centre (the tail slides toward them).
func place(anchor: Vector2, src_dx: float, alpha: float, pop: float) -> void:
    position = anchor
    scale = Vector2(pop, pop)
    modulate.a = alpha
    var tx: float = clampf(src_dx + _bw * 0.5, 10.0, _bw - 10.0) - _bw * 0.5
    if _tail != null:
        _tail.position = Vector2(tx - 8.0, -11.0)
