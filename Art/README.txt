FEATHER & TAIL - ART SLOTS
==========================
Every GUI / HUD / icon image is a PNG "slot". Replace the file (SAME NAME, same folder) and the game re-skins
itself. Or open the .tscn in Godot and drag a new texture onto the node (nodes are named after what they are).
Missing something? run  python tools/make_ui_placeholders.py  - it only creates files that don't exist yet.

NINE-SLICE (stretchable) images keep their corners; set the margins in UI/GardenTheme.tres (StyleBoxTexture)
or on the NinePatchRect in the scene.

Art/Menu       menu_background (1920x1080)   title_logo (transparent)
Art/Icons      icon_apple  icon_pear  icon_heart  (yours)   icon_heart_hurt  icon_fruit  icon_clock  icon_trap
               icon_walkback  icon_bonk (win-screen rows)   alert_notice(?) alert_chase(!) alert_recover(~)
               alert_hurt - small icons floating over teddies in the garden (~64px)
Art/Common     panel_card (big menu card, 9-slice 28)    panel_hud (top bar, 9-slice 18)   panel_toast (message)
               panel_keycap (key hints)   button_normal / hover / pressed / disabled / focus (9-slice 18)
               slider_track  slider_fill  slider_grabber  slider_grabber_hover
Art/HUD        portrait_mnki  portrait_swan (square, round or not)   portrait_ring_leader / _follower
               fruit_slot   frame_leader / frame_idle (split-screen borders, 9-slice 14)   divider_v / divider_h
               leader_separator   minimap_frame (9-slice 18)   minimap_mnki/swan/guard/trap/apple/pear (tiny dots)
Art/Touch      joy_base  joy_knob  btn_round  btn_round_down  icon_pause   (phones/tablets only)
Art/Bubbles    bubble_mnki / swan / guard / tower (9-slice 14)   bubble_tail_<same>  (speech bubbles)
Art/Screens    banner_pause  banner_win  banner_lose   badge_new_best   rotate_phone

Characters (optional, drawn ~40x52): Art/mnki.png  Art/swan.png  Art/guard.png - picked up automatically.
App icon: icon.svg in the project root.
