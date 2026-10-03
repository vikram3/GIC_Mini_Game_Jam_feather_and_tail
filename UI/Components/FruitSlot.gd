extends Control
## One fruit in the HUD fruit bar. `setup("ground", false)` = a faded red apple (not collected yet),
## `setup("air", true)` = a bright golden pear. Art: Apple / Pear / SlotBg children (edit in the scene).

var _kind: String = ""
var _got: bool = false


func setup(kind: String, got: bool) -> void:
    if kind == _kind and got == _got:
        return
    _kind = kind
    _got = got
    var is_apple: bool = kind == "ground"
    %Apple.visible = is_apple
    %Pear.visible = not is_apple
    var icon: TextureRect = %Apple if is_apple else %Pear
    icon.modulate = Color(1, 1, 1, 1.0 if got else 0.28)
