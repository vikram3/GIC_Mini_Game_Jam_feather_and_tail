extends Node2D
## A tiny canvas item that hands its _draw() to WorldDraw. WorldDraw splits the garden into
## several of these so that rarely-changing parts (terrain chunks, fog) are drawn once and
## cached by the engine, while only the animated parts are redrawn every frame.

var owner_draw: Node2D
var kind: String = ""
var cx: int = 0
var cy: int = 0


func _draw() -> void:
    if owner_draw != null:
        owner_draw.call("proxy_draw", self)
