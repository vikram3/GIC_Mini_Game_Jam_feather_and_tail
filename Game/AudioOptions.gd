extends RefCounted
## Master / music / effects volume sliders, shared by the title screen and the pause menu.
##   AudioOptions.build(some_vbox)


static func build(parent: Control) -> void:
    _row(parent, "Master volume", "master")
    _row(parent, "Music", "music")
    _row(parent, "Sound effects", "sfx")


static func _row(parent: Control, text: String, key: String) -> void:
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 14)
    parent.add_child(h)

    var l := Label.new()
    l.text = text
    l.custom_minimum_size = Vector2(160, 0)
    h.add_child(l)

    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.05
    s.value = PlayerData.get_volume(key)
    s.custom_minimum_size = Vector2(240, 26)
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    s.value_changed.connect(_on_changed.bind(key))
    s.drag_ended.connect(_on_drag_ended)
    h.add_child(s)


static func _on_changed(v: float, key: String) -> void:
    PlayerData.set_volume(key, v)
    Sound.apply_volumes()


static func _on_drag_ended(_changed: bool) -> void:
    Sound.play("ui_click", 0.6)
