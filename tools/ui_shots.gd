extends SceneTree
## Saves screenshots of the menu, HUD, bubbles and end screens (needs a display):
##   godot --path . --script res://tools/ui_shots.gd
var n: Node
var f := 0
func _initialize() -> void:
    n = (load("res://Menus/Main_Menu.tscn") as PackedScene).instantiate()
    root.add_child(n)
func _shot(name: String) -> void:
    root.get_viewport().get_texture().get_image().save_png("/tmp/%s.png" % name)
func _process(_d: float) -> bool:
    f += 1
    if f == 40: _shot("ui_menu"); n.get_node("%HowToPlay").visible = true
    if f == 50: _shot("ui_how"); n.queue_free(); n = (load("res://Game/Game.tscn") as PackedScene).instantiate(); root.add_child(n); current_scene = n
    if f == 110:
        n.speech.say(n.mnki, "mnki", "Keep moving, Swan! Dodge the pebbles!", 1, 20.0)
        n.speech.say(n.swan, "swan", "Fear is only love for what we might lose.", 1, 20.0)
        n.show_message("Harm no one. Avoid the teddy guards.", 20.0)
    if f == 150: _shot("ui_game")
    if f == 151: n.get_node("%HUD").show_pause(true)
    if f == 160: _shot("ui_pause"); n.get_node("%HUD").show_pause(false); n.get_node("%HUD").show_win(5,5,"1:23",true,2,1,0)
    if f == 170: _shot("ui_win"); quit()
    return false
