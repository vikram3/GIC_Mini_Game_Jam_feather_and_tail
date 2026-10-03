extends RefCounted
## Shared look for all menus and panels: soft garden-green panels, cream text, pill buttons.
## Usage:  control.theme = UITheme.make()

const CREAM := Color(1.0, 0.96, 0.84)
const GOLD := Color(1.0, 0.85, 0.35)
const LEAF := Color(0.20, 0.45, 0.28)
const LEAF_DARK := Color(0.07, 0.17, 0.12)
const PANEL_BG := Color(0.06, 0.15, 0.11, 0.985)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 12, border_w: int = 0) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.set_corner_radius_all(radius)
    if border_w > 0:
        sb.set_border_width_all(border_w)
        sb.border_color = border
    sb.content_margin_left = 18.0
    sb.content_margin_right = 18.0
    sb.content_margin_top = 10.0
    sb.content_margin_bottom = 10.0
    return sb


static func make() -> Theme:
    var th := Theme.new()
    th.set_default_font_size(18)

    # buttons
    th.set_stylebox("normal", "Button", box(Color(0.17, 0.40, 0.25), Color(0.45, 0.75, 0.50), 14, 2))
    th.set_stylebox("hover", "Button", box(Color(0.24, 0.52, 0.32), GOLD, 14, 2))
    th.set_stylebox("pressed", "Button", box(Color(0.12, 0.30, 0.19), GOLD, 14, 2))
    th.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 14, 3))
    th.set_stylebox("disabled", "Button", box(Color(0.15, 0.2, 0.17), Color(0.3, 0.3, 0.3), 14, 2))
    th.set_color("font_color", "Button", CREAM)
    th.set_color("font_hover_color", "Button", Color.WHITE)
    th.set_color("font_pressed_color", "Button", GOLD)
    th.set_color("font_focus_color", "Button", Color.WHITE)
    th.set_font_size("font_size", "Button", 22)

    # panels
    th.set_stylebox("panel", "PanelContainer", box(PANEL_BG, Color(0.45, 0.75, 0.50, 0.8), 18, 2))
    th.set_stylebox("panel", "Panel", box(PANEL_BG, Color(0.45, 0.75, 0.50, 0.8), 18, 2))

    # sliders (volume options)
    var track: StyleBoxFlat = box(Color(0.04, 0.10, 0.07), Color(0.45, 0.75, 0.50, 0.6), 4, 1)
    track.content_margin_top = 4.0
    track.content_margin_bottom = 4.0
    var fill: StyleBoxFlat = box(Color(0.35, 0.70, 0.42), Color(0, 0, 0, 0), 4, 0)
    fill.content_margin_top = 4.0
    fill.content_margin_bottom = 4.0
    th.set_stylebox("slider", "HSlider", track)
    th.set_stylebox("grabber_area", "HSlider", fill)
    th.set_stylebox("grabber_area_highlight", "HSlider", fill)

    # labels
    th.set_color("font_color", "Label", CREAM)
    th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.55))
    th.set_constant("outline_size", "Label", 3)
    return th
