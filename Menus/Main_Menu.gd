extends Control
## Title screen for Feather & Tail (built in code so the scene file stays tiny).

const UIThemeScript = preload("res://Game/UITheme.gd")
const BackdropScript = preload("res://Menus/Backdrop.gd")
const AudioOptionsScript = preload("res://Game/AudioOptions.gd")

const TAGLINE := "Harm no one. Avoid the guards. Escape together."

var how_to_overlay: Control
var options_overlay: Control


func _ready() -> void:
    theme = UIThemeScript.make()
    Sound.set_mode("menu")
    Sound.ensure_music()

    var backdrop := BackdropScript.new()
    add_child(backdrop)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # ---- title card (left side)
    var left := MarginContainer.new()
    left.add_theme_constant_override("margin_left", 70)
    add_child(left)
    left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
    left.custom_minimum_size = Vector2(640, 0)
    var vc := CenterContainer.new()
    left.add_child(vc)

    var card := PanelContainer.new()
    vc.add_child(card)
    var pad := MarginContainer.new()
    for side in ["margin_left", "margin_right"]:
        pad.add_theme_constant_override(side, 40)
    for side in ["margin_top", "margin_bottom"]:
        pad.add_theme_constant_override(side, 30)
    card.add_child(pad)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.custom_minimum_size = Vector2(500, 0)
    pad.add_child(box)

    var title := Label.new()
    title.text = "Feather & Tail"
    title.add_theme_font_size_override("font_size", 62)
    title.add_theme_color_override("font_color", UIThemeScript.GOLD)
    title.add_theme_constant_override("outline_size", 8)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var tag := Label.new()
    tag.text = TAGLINE
    tag.add_theme_font_size_override("font_size", 19)
    tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(tag)

    var sub := Label.new()
    sub.text = "MNKI and Swan are pacifists. Slip past the teddy-bear guards, hurt nobody, and reach the exit gate."
    sub.add_theme_font_size_override("font_size", 14)
    sub.add_theme_color_override("font_color", Color(0.75, 0.88, 0.78))
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(sub)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 8)
    box.add_child(spacer)

    var play := _button("Play", box)
    play.pressed.connect(_on_play)
    var rnd := _button("Play a random garden", box)
    rnd.pressed.connect(_on_random)
    var how := _button("How to play", box)
    how.pressed.connect(_on_how)
    var opts := _button("Options", box)
    opts.pressed.connect(_on_options)
    var quit := _button("Quit", box)
    quit.pressed.connect(_on_quit)

    if PlayerData.best_time > 0.0:
        var best := Label.new()
        best.text = "Best time: %s" % PlayerData.format_time(PlayerData.best_time)
        best.add_theme_color_override("font_color", UIThemeScript.GOLD)
        best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(best)

    _build_how_to()
    _build_options()
    play.grab_focus()


func _button(text: String, parent: Control) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(320, 48)
    parent.add_child(b)
    return b


func _row(grid: GridContainer, key: String, what: String) -> void:
    var k := Label.new()
    k.text = key
    k.add_theme_color_override("font_color", UIThemeScript.GOLD)
    k.add_theme_font_size_override("font_size", 16)
    grid.add_child(k)
    var w := Label.new()
    w.text = what
    w.add_theme_font_size_override("font_size", 16)
    w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    w.custom_minimum_size = Vector2(430, 0)
    grid.add_child(w)


func _heading(text: String, parent: Control) -> void:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 22)
    l.add_theme_color_override("font_color", UIThemeScript.GOLD)
    parent.add_child(l)


func _build_how_to() -> void:
    how_to_overlay = Control.new()
    how_to_overlay.visible = false
    add_child(how_to_overlay)
    how_to_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    how_to_overlay.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    how_to_overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var card := PanelContainer.new()
    center.add_child(card)
    var pad := MarginContainer.new()
    for side in ["margin_left", "margin_right"]:
        pad.add_theme_constant_override(side, 34)
    for side in ["margin_top", "margin_bottom"]:
        pad.add_theme_constant_override(side, 22)
    card.add_child(pad)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 10)
    pad.add_child(outer)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(760, 470)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 8)
    scroll.add_child(col)

    _heading("Goal", col)
    var goal := Label.new()
    goal.text = "Collect every fruit - red apples for MNKI, golden pears for Swan - then bring BOTH friends to the exit gate beside the fountain. Nobody may be harmed, not even the teddy-bear guards."
    goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    goal.custom_minimum_size = Vector2(700, 0)
    col.add_child(goal)

    _heading("Controls", col)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 22)
    grid.add_theme_constant_override("v_separation", 4)
    col.add_child(grid)
    _row(grid, "WASD / Arrows", "Move whoever is leading")
    _row(grid, "Tab", "Swap leader - the other friend follows")
    _row(grid, "Click", "Send your friend to a spot you have already seen")
    _row(grid, "H  /  X  /  Right-click", "Hold position  /  cancel the command")
    _row(grid, "MNKI: F (hold)", "Cut an adjacent hedge for a shortcut - noisy!")
    _row(grid, "MNKI: E (hold)", "Disarm an adjacent garden trap")
    _row(grid, "MNKI: Shift", "Sneak - teddies notice you from less far away")
    _row(grid, "Swan: Space", "Chirp - curious teddies walk over to look")
    _row(grid, "Esc  /  R", "Pause  /  restart")

    _heading("The garden", col)
    var garden := Label.new()
    garden.text = "Hedges can be cut by MNKI. Low stone walls and streams block MNKI, but Swan flies right over them. Wooden bridges let both friends cross. Bushes hide MNKI. Swan sees a wide area from above, including every teddy's view cone."
    garden.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    garden.custom_minimum_size = Vector2(700, 0)
    col.add_child(garden)

    _heading("The teddy guards", col)
    var teddies := Label.new()
    teddies.text = "Teddies never attack. If one catches MNKI, he is politely walked back to the gate. BUT a teddy that is chasing in a hurry will run straight over a trap and get hurt - and that ends the run. Break line of sight, hide, or disarm traps first. Teddies run FASTER than MNKI and call their friends, so you cannot outrun them: slip into a bush while they are still far away and they lose your trail. Sling teddies on watchtowers lob pebbles at Swan - the red target shows where a pebble will land, so keep moving to dodge. A hit only makes her dizzy."
    teddies.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    teddies.custom_minimum_size = Vector2(700, 0)
    col.add_child(teddies)

    var close := _button("Got it", outer)
    close.pressed.connect(_on_how)


func _build_options() -> void:
    options_overlay = Control.new()
    options_overlay.visible = false
    add_child(options_overlay)
    options_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    options_overlay.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    options_overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var card := PanelContainer.new()
    center.add_child(card)
    var pad := MarginContainer.new()
    for side in ["margin_left", "margin_right"]:
        pad.add_theme_constant_override(side, 44)
    for side in ["margin_top", "margin_bottom"]:
        pad.add_theme_constant_override(side, 30)
    card.add_child(pad)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    box.custom_minimum_size = Vector2(520, 0)
    pad.add_child(box)

    _heading("Sound", box)
    AudioOptionsScript.build(box)
    var hint := Label.new()
    hint.text = "Press M at any time to mute / unmute."
    hint.add_theme_font_size_override("font_size", 14)
    hint.add_theme_color_override("font_color", Color(0.75, 0.88, 0.78))
    box.add_child(hint)
    var back := _button("Back", box)
    back.pressed.connect(_on_options)


func _on_options() -> void:
    options_overlay.visible = not options_overlay.visible


func _on_play() -> void:
    PlayerData.level_seed = PlayerData.DEFAULT_SEED
    Transition.go("res://Game/Game.tscn")


func _on_random() -> void:
    PlayerData.level_seed = randi()
    Transition.go("res://Game/Game.tscn")


func _on_how() -> void:
    how_to_overlay.visible = not how_to_overlay.visible


func _on_quit() -> void:
    get_tree().quit()
