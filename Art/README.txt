Drop your art here. Everything is optional - a missing file just keeps the vector placeholder.
PNG, WebP or JPG. Names must match exactly (lower-case). Open the project in Godot once so it imports the files.

CHARACTERS (drawn at roughly 40x52 px in the game)
  mnki.png   swan.png   guard.png          <- guard = the teddy bear

MENU
  menu_background.png   Title-screen background, any size (16:9 ideal, 1920x1080). Fills the screen, cropped to fit.
						When present it REPLACES the whole animated vector garden scene.
  title_logo.png        Replaces the "Feather & Tail" text. Scaled to fit about 460x150, transparent background.

HUD ICONS (any square-ish size, ~128px is plenty, transparent background)
  icon_apple.png   icon_pear.png   icon_heart.png

APP / BROWSER-TAB ICON
  Replace icon.svg in the project root (keep the file name), or set it in
  Project Settings > Application > Config > Icon. The Web export uses it as the favicon.

The garden itself (trees, water, bridge, gate, exit, fountain...) is vector art drawn in Game/WorldDraw.gd -
each element is its own _draw_* function, so swapping one for a sprite is a one-function change.
