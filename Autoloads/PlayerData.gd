extends Node
## Global data + input map registration for Feather & Tail.

const SAVE_PATH := "user://feather_tail.cfg"
const DEFAULT_SEED := 20261001

var level_seed: int = DEFAULT_SEED
var best_time: float = -1.0
var total_caught: int = 0

# audio settings (0..1), saved between runs
var vol_master: float = 1.0
var vol_music: float = 0.8
var vol_sfx: float = 0.9
var muted: bool = false


func _ready() -> void:
    _register_inputs()
    _load()


func _register_inputs() -> void:
    _add_key("move_left", KEY_A)
    _add_key("move_left", KEY_LEFT)
    _add_key("move_right", KEY_D)
    _add_key("move_right", KEY_RIGHT)
    _add_key("move_up", KEY_W)
    _add_key("move_up", KEY_UP)
    _add_key("move_down", KEY_S)
    _add_key("move_down", KEY_DOWN)
    _add_key("switch_leader", KEY_TAB)
    _add_key("cut", KEY_F)
    _add_key("disarm", KEY_E)
    _add_key("chirp", KEY_SPACE)
    _add_key("sneak", KEY_SHIFT)
    _add_key("hold_toggle", KEY_H)
    _add_key("cancel", KEY_X)
    _add_key("restart", KEY_R)
    _add_key("pause", KEY_ESCAPE)
    _add_key("mute", KEY_M)


func _add_key(action: String, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var ev := InputEventKey.new()
    ev.physical_keycode = keycode
    InputMap.action_add_event(action, ev)


func _load() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        best_time = float(cfg.get_value("stats", "best_time", -1.0))
        vol_master = clampf(float(cfg.get_value("audio", "master", vol_master)), 0.0, 1.0)
        vol_music = clampf(float(cfg.get_value("audio", "music", vol_music)), 0.0, 1.0)
        vol_sfx = clampf(float(cfg.get_value("audio", "sfx", vol_sfx)), 0.0, 1.0)
        muted = bool(cfg.get_value("audio", "muted", false))


## Returns true if this run is a new best time.
func record_win(time_sec: float) -> bool:
    var is_best: bool = best_time < 0.0 or time_sec < best_time
    if is_best:
        best_time = time_sec
        save_all()
    return is_best


## One place that writes everything, so settings and stats never overwrite each other.
func save_all() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("stats", "best_time", best_time)
    cfg.set_value("audio", "master", vol_master)
    cfg.set_value("audio", "music", vol_music)
    cfg.set_value("audio", "sfx", vol_sfx)
    cfg.set_value("audio", "muted", muted)
    cfg.save(SAVE_PATH)


func get_volume(key: String) -> float:
    match key:
        "master":
            return vol_master
        "music":
            return vol_music
    return vol_sfx


func set_volume(key: String, v: float) -> void:
    match key:
        "master":
            vol_master = v
        "music":
            vol_music = v
        _:
            vol_sfx = v
    save_all()


func format_time(t: float) -> String:
    var secs: int = int(t)
    return "%d:%02d" % [secs / 60, secs % 60]
