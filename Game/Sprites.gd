extends RefCounted
## Vector PLACEHOLDER characters, shared by the game world and the menu.
## Every function draws onto the CanvasItem `ci` and must be called from inside
## that item's _draw(). Replace with real art via Art/*.png whenever you like.

const GOLD := Color(1.0, 0.85, 0.30)

# teddy guards: [fur, light fur, dark fur, hat]
const TEDDY_FUR := [
    [Color(0.78, 0.52, 0.28), Color(0.95, 0.78, 0.52), Color(0.35, 0.20, 0.10), Color(0.25, 0.38, 0.75)],
    [Color(0.92, 0.80, 0.62), Color(1.00, 0.94, 0.82), Color(0.45, 0.30, 0.18), Color(0.20, 0.58, 0.45)],
    [Color(0.50, 0.31, 0.19), Color(0.74, 0.55, 0.38), Color(0.20, 0.11, 0.07), Color(0.55, 0.30, 0.65)],
]


## A teddy-bear guard. mood: "calm", "angry" (chasing), "happy" (escorting), "hurt".
static func teddy(ci: CanvasItem, p: Vector2, f: Vector2, variant: int, mood: String, t: float, walking: bool) -> void:
    var fur: Array = TEDDY_FUR[variant % TEDDY_FUR.size()]
    var main: Color = fur[0]
    var light: Color = fur[1]
    var dark: Color = fur[2]
    var hat: Color = fur[3]
    var swing: float = sin(t * 10.0 + float(variant)) if walking else 0.0
    var c: Vector2 = p + Vector2(0, -2.0 - absf(swing) * 1.2)
    var angry: bool = mood == "angry"
    var happy: bool = mood == "happy"
    var hurt: bool = mood == "hurt"
    if f.length() < 0.1:
        f = Vector2.RIGHT
    f = f.normalized()

    # feet
    ci.draw_circle(c + Vector2(-7, 12 + swing * 1.5), 4.6, main)
    ci.draw_circle(c + Vector2(7, 12 - swing * 1.5), 4.6, main)
    ci.draw_circle(c + Vector2(-7, 12.5 + swing * 1.5), 2.2, light)
    ci.draw_circle(c + Vector2(7, 12.5 - swing * 1.5), 2.2, light)
    # body, belly, arms
    ci.draw_circle(c + Vector2(0, 5), 10.5, main)
    ci.draw_circle(c + Vector2(0, 6.5), 6.5, light)
    ci.draw_circle(c + Vector2(-11.5, 3 - swing), 4.3, main)
    ci.draw_circle(c + Vector2(11.5, 3 + swing), 4.3, main)
    # sheriff badge
    ci.draw_circle(c + Vector2(5.5, 1.5), 2.8, dark)
    ci.draw_circle(c + Vector2(5.5, 1.5), 1.9, GOLD)

    # head
    var h: Vector2 = c + Vector2(0, -8)
    ci.draw_circle(h + Vector2(-9.5, -7.5), 5.0, main)
    ci.draw_circle(h + Vector2(9.5, -7.5), 5.0, main)
    ci.draw_circle(h + Vector2(-9.5, -7.5), 2.6, light)
    ci.draw_circle(h + Vector2(9.5, -7.5), 2.6, light)
    ci.draw_circle(h, 10.5, main)
    # muzzle + nose
    ci.draw_circle(h + Vector2(0, 4.2) + f * 1.2, 4.7, light)
    ci.draw_circle(h + Vector2(0, 2.7) + f * 1.2, 1.9, dark)

    # eyes look where the teddy is facing
    for side in [-1.0, 1.0]:
        var ep: Vector2 = h + Vector2(4.3 * side, -1.8) + f * 1.4
        if hurt:
            ci.draw_line(ep + Vector2(-1.5, -1.5), ep + Vector2(1.5, 1.5), dark, 1.3)
            ci.draw_line(ep + Vector2(-1.5, 1.5), ep + Vector2(1.5, -1.5), dark, 1.3)
        elif happy:
            ci.draw_arc(ep + Vector2(0, 0.8), 1.8, PI, TAU, 6, dark, 1.4)
        else:
            ci.draw_circle(ep, 1.8, dark)
            ci.draw_circle(ep + Vector2(-0.5, -0.5), 0.6, Color.WHITE)
        if angry:
            ci.draw_line(ep + Vector2(-2.2 * side, -3.6), ep + Vector2(1.8 * side, -2.2), dark, 1.4)

    # mouth
    if angry:
        ci.draw_circle(h + Vector2(0, 7.8) + f * 1.2, 1.7, dark)
    elif hurt:
        ci.draw_line(h + Vector2(-2, 8), h + Vector2(2, 8), dark, 1.3)
    else:
        ci.draw_arc(h + Vector2(0, 6.2) + f * 1.2, 2.6, 0.3, PI - 0.3, 8, dark, 1.2)

    # little guard cap with a badge
    var cap := PackedVector2Array([
        h + Vector2(-8.5, -6), h + Vector2(8.5, -6), h + Vector2(6.5, -14.5), h + Vector2(-6.5, -14.5)])
    ci.draw_colored_polygon(cap, hat)
    ci.draw_line(h + Vector2(-10.5, -6), h + Vector2(10.5, -6), hat.darkened(0.35), 2.6)
    ci.draw_circle(h + Vector2(0, -10.5), 2.2, GOLD)

    if hurt:
        ci.draw_rect(Rect2(h + Vector2(-5, 3), Vector2(10, 3.5)), Color(0.96, 0.82, 0.62))
        ci.draw_line(h + Vector2(-5, 3), h + Vector2(5, 6.5), Color(0.8, 0.5, 0.4), 1.0)


## MNKI, the monkey (ground friend). Top-down placeholder.
static func mnki(ci: CanvasItem, p: Vector2, f: Vector2, alpha: float, sneaking: bool) -> void:
    if f.length() < 0.1:
        f = Vector2.DOWN
    var perp: Vector2 = f.orthogonal()
    var s: float = 0.85 if sneaking else 1.0
    var tail := PackedVector2Array([p - f * 9, p - f * 15 + perp * 6, p - f * 20 - perp * 2, p - f * 23 + perp * 5])
    ci.draw_polyline(tail, Color(0.45, 0.28, 0.14, alpha), 3.0)
    ci.draw_circle(p, 11 * s, Color(0.85, 0.15, 0.15, alpha))
    var head: Vector2 = p + f * 3.0
    ci.draw_circle(head, 7.5 * s, Color(0.22, 0.14, 0.09, alpha))
    ci.draw_circle(head + f * 1.5, 5.5 * s, Color(0.66, 0.46, 0.30, alpha))
    ci.draw_arc(head, 7.0 * s, 0.0, TAU, 14, Color(1.0, 0.85, 0.25, alpha), 1.5)
    ci.draw_circle(head + f * 3.0 + perp * 2.0, 1.2, Color(0.1, 0.06, 0.04))
    ci.draw_circle(head + f * 3.0 - perp * 2.0, 1.2, Color(0.1, 0.06, 0.04))


## Swan (air friend). Top-down placeholder; `t` drives the wing flap.
static func swan(ci: CanvasItem, q: Vector2, f: Vector2, alpha: float, t: float) -> void:
    if f.length() < 0.1:
        f = Vector2.DOWN
    var perp: Vector2 = f.orthogonal()
    var flap: float = 1.0 + 0.18 * sin(t * 9.0)
    var w1 := PackedVector2Array([q + perp * 6, q + perp * 22 * flap - f * 6, q + perp * 16 * flap - f * 16, q + perp * 4 - f * 9])
    var w2 := PackedVector2Array([q - perp * 6, q - perp * 22 * flap - f * 6, q - perp * 16 * flap - f * 16, q - perp * 4 - f * 9])
    ci.draw_colored_polygon(w1, Color(0.92, 0.95, 1.0, alpha))
    ci.draw_colored_polygon(w2, Color(0.92, 0.95, 1.0, alpha))
    ci.draw_circle(q, 9, Color(1, 1, 1, alpha))
    var beak := PackedVector2Array([q + f * 13, q + f * 8 + perp * 3, q + f * 8 - perp * 3])
    ci.draw_colored_polygon(beak, Color(1.0, 0.6, 0.15, alpha))
    ci.draw_circle(q - f * 2.0 + Vector2(0, -3), 3, Color(1.0, 0.85, 0.2, alpha))
    ci.draw_circle(q + f * 3.0 + perp * 3.0, 1.5, Color(0.2, 0.12, 0.08))
    ci.draw_circle(q + f * 3.0 - perp * 3.0, 1.5, Color(0.2, 0.12, 0.08))
