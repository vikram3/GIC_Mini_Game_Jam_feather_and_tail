extends Node2D
## Turns the data in Speech.gd (`game.speech.bubbles`) into SpeechBubble.tscn nodes that float above the
## speakers. It sits after the World node inside the world viewport, so bubbles draw above everything and
## show up in both split-screen views.

const BubbleScene := preload("res://UI/SpeechBubble.tscn")

var game: Node2D
var _live: Dictionary = {}     # speaker instance id -> {node, data}


func setup(g: Node2D) -> void:
    game = g


func _process(_delta: float) -> void:
    if game == null or game.speech == null:
        return
    var level = game.level
    var seen: Dictionary = {}
    for b in game.speech.bubbles:
        var src = b["src"]
        var kind: String = b["kind"]
        var id: int = src.get_instance_id()
        var e: Dictionary = _live.get(id, {})
        if e.is_empty() or not is_same(e["data"], b):
            if not e.is_empty():
                e["node"].queue_free()
            var n: Control = BubbleScene.instantiate()
            add_child(n)
            n.setup(kind, b["text"])
            e = {"node": n, "data": b}
            _live[id] = e
        seen[id] = true
        var node: Control = e["node"]
        var age: float = b["age"]
        var dur: float = b["dur"]
        var a: float = clampf(age / 0.12, 0.0, 1.0) * clampf((dur - age) / 0.35, 0.0, 1.0)
        var hidden: bool = a <= 0.01
        if (kind == "guard" or kind == "tower") and not game.vis_tiles.has(level.tile_of(src.pos)):
            hidden = true
        node.visible = not hidden
        if hidden:
            continue
        var anchor: Vector2 = _anchor(src.pos, kind)
        var pop: float = 1.0 + 0.12 * (1.0 - clampf(age / 0.18, 0.0, 1.0))
        node.place(anchor, src.pos.x - anchor.x, a, pop)
    for id in _live.keys():
        if not seen.has(id):
            _live[id]["node"].queue_free()
            _live.erase(id)


func _anchor(p: Vector2, kind: String) -> Vector2:
    var close: bool = game.mnki.pos.distance_to(game.swan.pos) < 80.0
    match kind:
        "mnki":
            return p + Vector2(-34.0 if close else 0.0, -36.0)
        "swan":
            return p + Vector2(34.0 if close else 0.0, -46.0)
        "guard":
            return p + Vector2(0, -58)
    return p + Vector2(0, -56)       # sling teddy on its tower
