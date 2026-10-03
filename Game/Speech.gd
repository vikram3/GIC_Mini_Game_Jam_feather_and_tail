extends RefCounted
## Speech bubbles and all the dialogue in the game.
##  - say()      : one bubble above one character (MNKI, Swan, a teddy guard or the tower teddy)
##  - converse() : a short back-and-forth that plays one line after another
##  - chat()     : a random MNKI <-> Swan conversation about love and wisdom (plays when it is calm)
## Every bank of lines is shuffled and dealt like a deck of cards, so nothing repeats until the whole bank was used.

const PRIO_CHAT := 0     # friendly chatter: any event can interrupt it
const PRIO_NORMAL := 1
const PRIO_URGENT := 2   # chases, bonks, being caught

# ------------------------------------------------------------------ one-liners
const LINES := {
    # MNKI
    "m_hedge": ["Snip! Sorry, hedge.", "Just a little trim, nothing personal.", "Every shortcut starts with one brave snip.", "Pardon me, leafy friend!"],
    "m_trap": ["Click... safe! Nobody gets hurt.", "Disarmed! The teddies stay fluffy.", "Gentle fingers keep the garden kind."],
    "m_hide": ["Shh... I'm a bush now.", "Nobody here but shrubbery.", "Leaves, don't betray me."],
    "m_hide_chased": ["Don't breathe, don't breathe...", "Please don't look in the bush!", "Bush mode: activated."],
    "m_lead": ["Follow me, Swan!", "My turn! Stay close.", "I'll find us a way."],
    "m_hold": ["I'll wait right here.", "Staying put.", "Holding still..."],
    "m_chased": ["Uh-oh! Find a bush!", "Teddy trouble! HIDE!", "RUN! ...to a bush!"],
    "m_lost": ["Phew... they lost me.", "Bushes are wonderful.", "Stay still... stay still..."],
    "m_caught": ["Oh, come on!", "So close!", "I almost made it to a bush..."],
    "m_locked": ["Locked! We need all the fruit first.", "The gate won't budge. More fruit!"],
    "m_apple": ["Crunch! A sweet red apple.", "Got one!", "Mmm, crisp and juicy!"],
    "m_tower_reply": ["Keep moving, Swan! Dodge the pebbles!", "Stay out of its range, love!"],
    # Swan
    "s_chirp": ["Chirp chirp!", "Tweet! Over here, teddies!", "Cheep-cheep! Come and see!"],
    "s_lead": ["Up we go! Follow my wings.", "I'll scout ahead, love.", "My turn to lead!"],
    "s_hold": ["I'll wait right here.", "Not moving a feather.", "Perched and patient."],
    "s_chased": ["MNKI, hide in a bush!", "Break their sight, MNKI!", "Quick, behind some leaves!"],
    "s_lost": ["Well hidden, my love!", "Clever monkey! They're confused.", "Wonderful! Wait for them to wander off."],
    "s_locked": ["The gate wants a full basket.", "Fruit first, freedom after."],
    "s_bonk": ["Ouch! How rude!", "Bonk! My poor feathers!", "Oof! That one stung!"],
    "s_dodge": ["Ha! Too slow!", "Missed me!", "Nice try, tower teddy!"],
    "s_tower": ["A sling teddy! Stay out of its range.", "That tower teddy is watching me..."],
    # both, as followers
    "f_follow": ["Back at your side!", "Coming!", "Right behind you."],
    "f_go": ["On my way!", "Heading there now.", "Got it!"],
    # teddy guards
    "g_notice": ["Hm? Who's there?", "Did something rustle?", "I smell... monkey?", "Is somebody in my garden?"],
    "g_chase": ["HALT! Stop right there!", "Come back here, monkey!", "You're out of bounds, little one!", "Nobody sneaks past Sergeant Teddy!"],
    "g_call": ["Friends! Intruder!", "Over here, everyone!", "Monkey spotted! To me!"],
    "g_answer": ["Coming!", "On my way!", "Right behind you, Sarge!"],
    "g_search": ["Where did he go?", "Come out, come out...", "He was just here!", "That bush looks suspicious..."],
    "g_lost": ["Where did he go?!", "Hmph! Vanished!", "I could've sworn he was here..."],
    "g_hear": ["What was that noise?", "I'll go take a look!", "Sounds like trouble!"],
    "g_idle": ["All quiet in the garden...", "La la la, patrol patrol.", "Lovely weather for guarding.", "Who ate my honey cake?", "Left foot, right foot, repeat."],
    "g_caught": ["Back to the gate we go!", "Gotcha, little monkey!", "Rules are rules, friend."],
    # the sling teddy on the tower
    "t_notice": ["I see you, birdie!", "Is that a swan up there?", "Stay in my sights..."],
    "t_aim": ["Hold still, feathers!", "Aiming... aiming...", "Steady, steady..."],
    "t_fire": ["Sling away!", "Fly-by pebble!", "Catch this, birdie!"],
    "t_hit": ["Bonk! Got her!", "Ha! Right on target!", "Bullseye!"],
    "t_miss": ["Drat! Missed!", "She's too quick!", "Wiggly bird!"],
    "t_lost": ["Hmph, she flew off.", "Come back, birdie!", "Out of range again..."],
}

# ----------------------------------------------------- short scripted exchanges
# each one: [[speaker, text], ...]   speaker is "mnki" or "swan"
const DUOS := {
    "apple": [
        [["mnki", "Crunch! A sweet red apple."], ["swan", "Joy shared is joy doubled, my love."]],
        [["mnki", "One apple closer to the gate!"], ["swan", "Every small step is part of the journey."]],
        [["mnki", "I'm saving the shiniest bite for you."], ["swan", "Kindness is the sweetest fruit of all."]],
        [["mnki", "Apples taste better with you near."], ["swan", "Everything does, dear MNKI."]],
        [["mnki", "Got one!"], ["swan", "Patience and a gentle paw. Well done."]],
    ],
    "pear": [
        [["swan", "A golden pear! The tree trusted the sun."], ["mnki", "And I trust you, Swan."]],
        [["swan", "Got it! Sweet as a quiet morning."], ["mnki", "Sweet as your singing."]],
        [["swan", "One more pear for our basket of memories."], ["mnki", "Our basket is already full, love."]],
        [["swan", "A golden pear! Fortune favours the curious."], ["mnki", "Then you're the luckiest bird alive."]],
    ],
    "trap": [
        [["mnki", "Click... safe! Nobody gets hurt."], ["swan", "Gentle hands are the strongest hands."]],
        [["mnki", "Disarmed! The teddies stay fluffy."], ["swan", "Protecting others is how love begins."]],
    ],
    "relief": [
        [["swan", "Are you alright, my love?"], ["mnki", "My heart is racing. But you're here, so I'm fine."], ["swan", "Breathe. Fear passes. Love stays."]],
        [["mnki", "They lost me! Bushes are wise."], ["swan", "The wise know when to be still."]],
    ],
    "caught": [
        [["mnki", "Oh, come on! So close!"], ["swan", "We'll try again, my love. Together."], ["mnki", "Together. Always."]],
        [["mnki", "Sorry, Swan. They got me."], ["swan", "A fall is just a lesson with feathers."]],
    ],
    "bonk": [
        [["mnki", "Swan! Are you alright?!"], ["swan", "Only my pride, dear. Their aim is better than their manners."], ["mnki", "Rest a moment. I'm right here."]],
        [["mnki", "Swan, look at me. Are you hurt?"], ["swan", "Just dizzy. Your voice steadies me."]],
    ],
    "allfruit": [
        [["swan", "That's every last piece of fruit!"], ["mnki", "The gate is open. Shall we go home?"], ["swan", "Together, always."]],
    ],
    "intro": [
        [["swan", "Stay close, MNKI. I'll watch the sky."], ["mnki", "Always. Wherever you fly, I follow."], ["swan", "Then let's walk gently, and harm no one."]],
    ],
}

# ------------------------------------- love and wisdom: calm-moment conversations
const CHATS := [
    [["swan", "MNKI, do you know why I fly so high?"], ["mnki", "To see the whole garden?"], ["swan", "To see it all, and then land beside you."], ["mnki", "Love is the only place worth landing."]],
    [["mnki", "I cut hedges. You cross them in one wingbeat."], ["swan", "And still we arrive together."], ["mnki", "Maybe the way matters less than who walks it with you."]],
    [["swan", "A kind heart is a strong shield, MNKI."], ["mnki", "Stronger than a sling?"], ["swan", "A sling stops once. Kindness keeps going."]],
    [["mnki", "I'm a little afraid of the teddies."], ["swan", "Fear is only love for what we might lose."], ["mnki", "Then I must be very full of love."], ["swan", "You overflow, my dear."]],
    [["swan", "Patience is a wing, MNKI. Hurry only tires it."], ["mnki", "And what is love?"], ["swan", "The wind beneath it."]],
    [["mnki", "You make this big maze feel small."], ["swan", "You make it feel like home."], ["mnki", "Home isn't a place, is it?"], ["swan", "It's whoever waits at the end of the path with you."]],
    [["swan", "The wise listen twice as much as they speak."], ["mnki", "I listen to you the most."], ["swan", "Because I sing?"], ["mnki", "Because your quiet is wiser than the noise."]],
    [["mnki", "If they catch me, will you still love me?"], ["swan", "I'd love you from the far side of a hundred gates."], ["mnki", "Then no gate is ever really locked."]],
    [["swan", "Be gentle with the teddies, MNKI. They are afraid, too."], ["mnki", "Afraid of what?"], ["swan", "Of being unseen. Everyone is guarding something."]],
    [["mnki", "What's the secret of a long journey?"], ["swan", "Small steps and a hand to hold."], ["mnki", "I only have a tail."], ["swan", "Then I'll hold your tail. Gladly."]],
    [["swan", "Every apple was once a blossom that kept trusting the sun."], ["mnki", "Then I'll trust you the same way."], ["swan", "And I you."]],
    [["mnki", "I don't need to win, Swan. I just need to arrive with you."], ["swan", "Then we've already won."]],
    [["swan", "Courage isn't loud, MNKI. It whispers: try once more."], ["mnki", "Then I hear it every time you're near."]],
    [["mnki", "Wise Swan, how do I stay brave?"], ["swan", "Be brave for someone, not against something."], ["mnki", "Then I'll be brave for you."]],
    [["swan", "A lantern doesn't fight the dark. It simply glows."], ["mnki", "Like you."], ["swan", "Like us."]],
    [["mnki", "Do you think the teddies ever get lonely up there?"], ["swan", "Whoever guards alone needs a friend most."], ["mnki", "Maybe one day we'll bring them honey cake."]],
    [["swan", "Do you know what I love about you?"], ["mnki", "My excellent hedge-cutting?"], ["swan", "That you stop to be careful with a trap, even when no one is watching."]],
    [["mnki", "Which is stronger, Swan: wings or roots?"], ["swan", "Wings carry us. Roots remind us where we belong."], ["mnki", "You are both for me."]],
]

var game: Node2D
var bubbles: Array = []     # {src, kind, text, age, dur, prio, lines}
var queue: Array = []       # pending lines of the running conversation
var queue_wait: float = 0.0
var cds: Dictionary = {}
var _bags: Dictionary = {}


# ------------------------------------------------------------------ lifecycle

func update(delta: float) -> void:
    var i: int = bubbles.size() - 1
    while i >= 0:
        var b: Dictionary = bubbles[i]
        b["age"] = float(b["age"]) + delta
        if float(b["age"]) >= float(b["dur"]):
            bubbles.remove_at(i)
        i -= 1
    for k in cds:
        cds[k] = maxf(0.0, float(cds[k]) - delta)
    if not queue.is_empty():
        queue_wait -= delta
        if queue_wait <= 0.0:
            var line: Array = queue.pop_front()
            var d: float = _duration(String(line[1]))
            say(_src(String(line[0])), String(line[0]), String(line[1]), PRIO_CHAT, d)
            queue_wait = d + 0.25


func clear() -> void:
    bubbles.clear()
    queue.clear()


# ----------------------------------------------------------------- primitives

func _duration(text: String) -> float:
    return clampf(1.6 + float(text.length()) * 0.05, 2.3, 5.5)


func _src(kind: String):
    return game.mnki if kind == "mnki" else game.swan


## One bubble above `src`. A character only ever has one bubble: a new one replaces the old
## unless the old one is more important and still showing.
func say(src, kind: String, text: String, prio: int = PRIO_NORMAL, dur: float = -1.0) -> void:
    if src == null:
        return
    if dur < 0.0:
        dur = _duration(text)
    for b in bubbles:
        if b["src"] == src:
            if int(b["prio"]) > prio and float(b["age"]) < float(b["dur"]):
                return
            bubbles.erase(b)
            break
    bubbles.append({"src": src, "kind": kind, "text": text, "age": 0.0, "dur": dur, "prio": prio, "lines": []})
    _blip(kind)


## Draws the next line of a bank (a shuffled deck: no repeats until it runs out).
func pick(key: String) -> String:
    var bag: Array = _bags.get(key, [])
    if bag.is_empty():
        bag = (LINES[key] as Array).duplicate()
        bag.shuffle()
    var s: String = String(bag.pop_back())
    _bags[key] = bag
    return s


## Cooldown gate: true at most once per `cd` seconds for this key.
func ready(key: String, cd: float) -> bool:
    if float(cds.get(key, 0.0)) > 0.0:
        return false
    cds[key] = cd
    return true


func bark(src, kind: String, key: String, prio: int = PRIO_NORMAL) -> void:
    say(src, kind, pick(key), prio)


func hero_bark(kind: String, key: String, prio: int = PRIO_NORMAL) -> void:
    say(_src(kind), kind, pick(key), prio)


# --------------------------------------------------------------- conversations

func is_chatting() -> bool:
    if not queue.is_empty():
        return true
    for b in bubbles:
        if int(b["prio"]) == PRIO_CHAT:
            return true
    return false


func hero_is_talking() -> bool:
    for b in bubbles:
        if b["kind"] == "mnki" or b["kind"] == "swan":
            return true
    return false


## Plays `lines` one after another. `force` cuts off any chat that is running.
func converse(lines: Array, force: bool = false, delay: float = 0.0) -> bool:
    if is_chatting():
        if not force:
            return false
        interrupt()
    queue = lines.duplicate()
    queue_wait = delay
    return true


## Stops the friendly chatter (something more important happened).
func interrupt() -> void:
    queue.clear()
    var i: int = bubbles.size() - 1
    while i >= 0:
        if int(bubbles[i]["prio"]) == PRIO_CHAT:
            bubbles.remove_at(i)
        i -= 1


func duo(key: String, force: bool = true, delay: float = 0.0) -> bool:
    var opts: Array = DUOS[key]
    var idx: int = _deal("duo_" + key, opts.size())
    return converse(opts[idx], force, delay)


## A calm-moment conversation about love and wisdom.
func chat() -> bool:
    return converse(CHATS[_deal("chats", CHATS.size())])


## A fruit was collected: sometimes just a happy shout, usually a little exchange.
func fruit(is_pear: bool) -> void:
    if randf() < 0.7:
        duo("pear" if is_pear else "apple")
    elif is_pear:
        say(game.swan, "swan", "A golden pear!", PRIO_NORMAL)
    else:
        hero_bark("mnki", "m_apple")


func _deal(key: String, n: int) -> int:
    var bag: Array = _bags.get(key, [])
    if bag.is_empty():
        for i in range(n):
            bag.append(i)
        bag.shuffle()
    var v: int = int(bag.pop_back())
    _bags[key] = bag
    return v


## A tiny voice blip so every bubble also "speaks" (re-using the UI tick, pitched per character).
func _blip(kind: String) -> void:
    var pitch: float = 1.0
    match kind:
        "swan":
            pitch = 1.75
        "mnki":
            pitch = 1.2
        "guard":
            pitch = 0.78
        "tower":
            pitch = 0.62
    Sound.play("ui_hover", 0.35, pitch, 0.06)
