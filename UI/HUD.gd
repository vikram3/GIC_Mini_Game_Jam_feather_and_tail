extends CanvasLayer
## In-game HUD controller. EVERYTHING visual lives in UI/HUD.tscn (open it, select a node, swap its texture).
## This script only fills the nodes with live data - Game.gd calls update_hud() every frame.
##
## Node map (all unique-name nodes, shown in the scene tree with a % badge):
##   SplitFrames  : FrameA/B (LeaderFrame*/IdleFrame*, NameLabel*), DividerV/H
##   TopBar       : FruitPanel (Slots) | LeaderPanel (faces, rings, names) | PeacePanel (heart, counters, timer)
##   Minimap      : UI/Minimap.tscn         KeyHints : HintsMnki / HintsSwan
##   TouchControls: UI/TouchControls.tscn   Toast : message pill
##   PauseMenu / WinScreen / LoseScreen : full-screen overlays

const FruitSlotScene := preload("res://UI/Components/FruitSlot.tscn")

signal resume_pressed
signal restart_pressed
signal menu_pressed

var game: Node2D
var clock: float = 0.0
var _slots: Array = []


func _ready() -> void:
    %PauseMenu.resume_pressed.connect(func() -> void: resume_pressed.emit())
    %PauseMenu.restart_pressed.connect(func() -> void: restart_pressed.emit())
    %PauseMenu.menu_pressed.connect(func() -> void: menu_pressed.emit())
    %WinScreen.restart_pressed.connect(func() -> void: restart_pressed.emit())
    %WinScreen.menu_pressed.connect(func() -> void: menu_pressed.emit())
    %LoseScreen.restart_pressed.connect(func() -> void: restart_pressed.emit())
    %LoseScreen.menu_pressed.connect(func() -> void: menu_pressed.emit())
    %TouchControls.visible = false


func setup(g: Node2D) -> void:
    game = g
    %Minimap.game = g
    %TouchControls.game = g
    %TouchControls.visible = Platform.is_touch
    %KeyHints.visible = not Platform.is_touch
    if Platform.is_touch:
        %Toast.offset_left = -380.0
        %Toast.offset_right = 380.0
        %Toast.offset_top = -132.0
        %Toast.offset_bottom = -90.0
    for f in game.level.fruits:
        var s: Control = FruitSlotScene.instantiate()
        %Slots.add_child(s)
        s.setup(f["kind"], false)
        _slots.append(s)
    %FruitCount.text = "0 / %d" % game.fruit_total


func is_overlay_open() -> bool:
    return %PauseMenu.visible or %WinScreen.visible or %LoseScreen.visible


func show_pause(on: bool) -> void:
    %PauseMenu.visible = on


func show_win(fruit: int, total: int, time_text: String, new_best: bool, disarmed: int, caught: int, bonks: int) -> void:
    %PauseMenu.visible = false
    %WinScreen.show_result(fruit, total, time_text, new_best, disarmed, caught, bonks)


func show_lose() -> void:
    %PauseMenu.visible = false
    %LoseScreen.show_lose()


func show_message(text: String) -> void:
    %ToastLabel.text = text


func set_touch_active(on: bool) -> void:
    if Platform.is_touch:
        %TouchControls.set_active(on)


func update_hud(delta: float) -> void:
    if game == null or game.level == null:
        return
    clock += delta
    %Toast.visible = game.msg_timer > 0.0
    _update_split()
    _update_fruit()
    _update_leader()
    _update_peace()
    _update_hints()
    %Minimap.refresh()


# ------------------------------------------------------------------ pieces
func _update_split() -> void:
    var split: bool = game.merge < 0.995
    %SplitFrames.visible = split
    if not split:
        return
    var ra: Rect2 = game.rect_a
    var rb: Rect2 = game.rect_b
    %DividerV.visible = game.split_vertical
    %DividerH.visible = not game.split_vertical
    if game.split_vertical:
        %DividerV.position = Vector2(rb.position.x - 3.0, 0.0)
    else:
        %DividerH.position = Vector2(0.0, rb.position.y - 3.0)
    _frame("A", ra, game.hero_a)
    _frame("B", rb, game.hero_b)


func _frame(which: String, r: Rect2, h) -> void:
    var holder: Control = get_node("%Frame" + which)
    holder.position = r.position
    holder.size = r.size
    var lead: bool = h == game.leader
    get_node("%LeaderFrame" + which).visible = lead
    get_node("%IdleFrame" + which).visible = not lead
    var lab: Label = get_node("%NameLabel" + which)
    var t: String = game.hero_name(h) + (" (ground)" if h.kind == "mnki" else " (air)")
    if lead:
        t += "  - LEADING"
    if lab.text != t:
        lab.text = t
    lab.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 0.95) if lead else Color(1, 1, 1, 0.45))


func _update_fruit() -> void:
    var fruits: Array = game.level.fruits
    for i in range(mini(fruits.size(), _slots.size())):
        _slots[i].setup(fruits[i]["kind"], fruits[i]["got"])
    var t: String = "%d / %d" % [game.collected, game.fruit_total]
    if %FruitCount.text != t:
        %FruitCount.text = t


func _portrait(kind: String) -> Texture2D:
    return %PortraitMnki.texture if kind == "mnki" else %PortraitSwan.texture


func _update_leader() -> void:
    var lead = game.leader
    var fol = game.follower
    %LeaderFace.texture = _portrait(lead.kind)
    %FollowerFace.texture = _portrait(fol.kind)
    %LeaderName.text = "%s leads" % game.hero_name(lead)
    %SwapHint.text = "tap SWAP" if Platform.is_touch else "Tab to swap"
    var fstate: String = "following"
    if game.follower_mode == "hold":
        fstate = "holding"
    elif fol.waiting:
        fstate = "waiting (teddy ahead)"
    elif game.follower_mode == "goto":
        fstate = "heading to target"
    elif fol.blocked:
        fstate = "no route!"
    %FollowerName.text = game.hero_name(fol)
    %FollowerState.text = fstate
    var warn: bool = fol.waiting or fol.blocked
    %FollowerState.add_theme_color_override("font_color", Color(1.0, 0.7, 0.45) if warn else Color(0.75, 0.9, 0.75))


func _update_peace() -> void:
    var harmed: bool = game.harmed_guard != null
    %HeartIcon.visible = not harmed
    %HeartHurtIcon.visible = harmed
    var pulse: float = 1.0 + 0.06 * sin(clock * 3.0)
    %HeartIcon.scale = Vector2(pulse, pulse)
    %HurtLabel.text = "Teddies hurt: %d" % (1 if harmed else 0)
    %HurtLabel.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55) if harmed else Color(1.0, 0.96, 0.84))
    %StatsLabel.text = "Traps %d  |  Walked back %d" % [game.level.traps.size(), game.caught]
    %TimerLabel.text = PlayerData.format_time(game.elapsed)


func _update_hints() -> void:
    if Platform.is_touch:
        return
    var mnki: bool = game.leader.kind == "mnki"
    %HintsMnki.visible = mnki
    %HintsSwan.visible = not mnki
