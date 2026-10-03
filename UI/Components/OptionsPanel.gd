extends VBoxContainer
## The three volume sliders (+ optional heading and mute hint). Used by the title Options screen
## and by the pause menu.

@export var show_heading: bool = true
@export var show_hint: bool = true


func _ready() -> void:
    %Heading.visible = show_heading
    %MuteHint.visible = show_hint
    %MuteHint.text = "Use the Master volume slider to mute." if Platform.is_touch else "Press M at any time to mute / unmute."
