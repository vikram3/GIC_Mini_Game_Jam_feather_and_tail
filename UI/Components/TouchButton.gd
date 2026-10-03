@tool
extends Control
## A round on-screen button for phones / tablets. TouchControls.gd reads these properties:
##   action  - the input action it presses (cut, chirp, disarm, sneak, switch_leader, hold_toggle, cancel, pause)
##   mode    - tap (one press) / hold (held while the finger is down) / toggle (on-off)
##   who     - which leader it is shown for: any / mnki / swan
##   cond    - "goto" = only shown while the follower is walking to a commanded spot
## Art: Bg (normal) / BgDown (pressed) / Glyph (optional icon on top) / Label (text). Resize the root to resize the button.

@export var action: String = ""
@export_enum("tap", "hold", "toggle") var mode: String = "tap"
@export_enum("any", "mnki", "swan") var who: String = "any"
@export var cond: String = ""
@export var label_text: String = "":
    set(v):
        label_text = v
        _refresh()
@export var glyph: Texture2D:
    set(v):
        glyph = v
        _refresh()


func _ready() -> void:
    resized.connect(_fit_font)
    _refresh()
    _fit_font()


func center() -> Vector2:
    return get_global_rect().get_center()


func radius() -> float:
    return minf(size.x, size.y) * 0.5


func set_down(on: bool) -> void:
    %Bg.visible = not on
    %BgDown.visible = on
    if on:
        %Label.add_theme_color_override("font_color", Color(0.15, 0.10, 0.02))
    else:
        %Label.remove_theme_color_override("font_color")


func set_label(t: String) -> void:
    %Label.text = t


func _refresh() -> void:
    if not is_node_ready():
        return
    %Label.text = label_text
    %Glyph.texture = glyph
    %Glyph.visible = glyph != null


func _fit_font() -> void:
    if not is_node_ready():
        return
    var r: float = radius()
    %Label.add_theme_font_size_override("font_size", 20 if r >= 50.0 else (16 if r >= 36.0 else 14))
