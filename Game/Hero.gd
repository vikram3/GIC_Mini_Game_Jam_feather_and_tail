extends RefCounted
## Plain data for one of the two playable characters.

var kind: String = "mnki"   # "mnki" (ground) or "swan" (air)
var pos := Vector2.ZERO     # pixels, map space
var facing := Vector2.DOWN
var radius: float = 10.0
var path: Array = []        # remaining tiles when acting as follower
var waiting: bool = false   # follower paused because a guard is watching the route
var blocked: bool = false   # follower has no route to the leader
var hidden: bool = false    # MNKI standing in a bush
var sneaking: bool = false
var moving: bool = false
var vel := Vector2.ZERO      # current velocity (smoothed so starts / stops feel soft)
var last_pos := Vector2.ZERO # for footstep distance
var step_dist: float = 0.0
