#!/usr/bin/env python3
"""
Boss Ball Blitz — TikTok content generator.

Produces titles, captions, and voiceover scripts in the style of
satisfying physics simulation creators (@earclacks Weapon Ball format).

Public API:
    generate_title(params)     → str
    generate_caption(params)   → str
    generate_voiceover(params) → dict
    generate_content(params)   → dict  (all three combined)
"""

import random

# ── Display names ──────────────────────────────────────────────────────────────

ORB_NAME = {
    "basic":     "SHOCK ORB",
    "laser":     "LASER ORB",
    "combo":     "COMBO ORB",
    "chain":     "CHAIN ORB",
    "fire":      "INFERNO ORB",
    "prismatic": "PRISMATIC ORB",
    "nova":      "NOVA STAR",
    "void":      "VOID ORB",
    "hook":      "HOOK ORB",
    "splitter":  "SHURIKEN ORB",
    "zapper":    "ZAPPER ORB",
    "clone":     "ECHO ORB",
    "blackhole": "VOID STAR",
    "mine":      "MINE ORB",
    "ice":       "ICE ORB",
    "firetrap":  "FIRE TRAP",
}

ARENA_NAME = {
    "tiny":        "TINY ARENA",
    "small":       "SMALL ARENA",
    "normal":      "NORMAL ARENA",
    "full":        "FULL ARENA",
    "pillarsSmall":"PILLAR ARENA",
    "pillarsBig":  "MEGA PILLAR ARENA",
    "corridors":   "CORRIDOR ARENA",
    "maze":        "THE MAZE",
}

MODE_NAME = {
    "time_attack": "TIME ATTACK",
    "blitz":       "BLITZ",
    "speed_run":   "SPEED RUN",
}

# ── Title templates ({O}=orb, {A}=arena, {M}=mode) ────────────────────────────

_TITLES = [
    # Battle / earclacks style
    "{O} vs THE BOSS 💀",
    "FINAL ROUND: {O} in {A} ⚔️",
    "{O} BATTLE ROYALE 🏹",
    "Boss Ball Battle: {O} Edition 🔥",
    "{O} vs {M} — who wins? 🏆",
    "WEAPON BALL: {O} enters {A} ⚡",
    "TOURNAMENT ARC: {O} vs Boss 🏟️",

    # POV
    "POV: you unlock {O} for the first time 😳",
    "POV: {O} in {A} hits different 💀",
    "POV: you find the most broken combo in Boss Ball 🤯",
    "POV: the boss sees {O} coming 😈",

    # Question / clickbait
    "Can {O} beat {M} in {A}? 🤔",
    "Is {O} actually broken? 🧐",
    "What happens when you put {O} in {A}? 👀",
    "Can this orb one-shot the boss? 💥",
    "Which orb is strongest in {A}? ⚔️",

    # Reaction / discovery
    "This {O} combo is UNPLAYABLE 😭",
    "They need to NERF {O} immediately 🔥",
    "Nobody told me {O} does THIS 😱",
    "{O} just broke {A} 💥",
    "Wait… {O} can do THAT?! 😳",
    "I put {O} in {A} and this happened 👇",
    "The devs didn't want you to find this combo 🚫",
    "{O} is carrying this entire run 💪",

    # Tier / ranking
    "Rating every orb: {O} review 🏅",
    "{O} = S TIER? Let's find out 👇",
    "The BEST orb in Boss Ball? Testing {O} 🥇",
    "Orb tier list: where does {O} land? 📊",

    # Stats / speedrun
    "New record attempt: {O} in {M} ⚡",
    "{O} max damage run 📈",
    "FASTEST boss kill: {O} edition 💨",
    "How much damage can {O} do in {M}? 🔢",

    # Satisfying / physics
    "{O} in {A} is the most satisfying thing 🎯",
    "The physics of {O} will BLOW your mind 🧠",
    "{O} + {A} = perfect chaos 💫",
    "Watch {O} fill every corner of {A} 🌀",
    "Satisfying {O} run — no commentary 🎵",
    "{O} bouncing in {A} is pure ASMR 🔊",
]

# ── Hashtags by orb ────────────────────────────────────────────────────────────

_TAGS = {
    "ice":      "#ice #freeze #satisfying #physics #bossfight #gaming #simulation",
    "mine":     "#mines #explosion #satisfying #physics #gaming #trap #bossfight",
    "blackhole":"#blackhole #vortex #satisfying #physics #gaming #simulation #bossfight",
    "combo":    "#combo #multiplier #satisfying #gaming #bossfight #streak #physics",
    "laser":    "#laser #beam #satisfying #gaming #physics #bossfight #simulation",
    "chain":    "#lightning #chain #satisfying #gaming #electric #bossfight #physics",
    "nova":     "#explosion #nova #satisfying #gaming #physics #bossfight #boom",
    "hook":     "#homing #hook #satisfying #gaming #physics #bossfight #tracking",
    "splitter": "#shuriken #blades #satisfying #gaming #physics #bossfight #spin",
    "zapper":   "#lightning #thunder #satisfying #gaming #electric #bossfight #zap",
    "clone":    "#clone #echo #satisfying #gaming #physics #bossfight #swarm",
    "void":     "#void #warp #satisfying #gaming #physics #bossfight #teleport",
    "fire":     "#fire #inferno #satisfying #gaming #physics #bossfight #burn",
    "firetrap": "#fire #trap #satisfying #gaming #physics #bossfight #explosion",
    "prismatic":"#prism #beam #satisfying #gaming #physics #bossfight #reflect",
    "basic":    "#shock #satisfying #gaming #physics #bossfight #simulation #classic",
}
_BASE_TAGS = "#bossbattle #ballgame #physicsgame #simulation #weaponball"

# ── Voiceover building blocks ──────────────────────────────────────────────────

_HOOK = {
    "blitz": [
        "Okay. Thirty seconds. Two million HP. Let's GO.",
        "BLITZ mode. Thirty seconds on the clock. This is going to be INSANE.",
        "Two million HP. Half a minute. Watch what happens.",
        "Thirty seconds. Boss has two million HP. Can we even do this?",
        "BLITZ. Maximum pressure. Let's see what this orb can do.",
    ],
    "time_attack": [
        "Sixty seconds. One million HP boss. Let's see if this combo works.",
        "Time Attack. One million HP. The clock starts NOW.",
        "One minute. One boss. One orb. Let's find out.",
        "This is Time Attack mode. One million HP. Sixty seconds. GO.",
        "Sixty seconds on the clock. That boss is going DOWN.",
    ],
    "speed_run": [
        "FIFTEEN seconds. Max damage. GO.",
        "Speed Run. Pure chaos. Fifteen seconds to do as much damage as possible.",
        "Fifteen seconds. Every single hit counts.",
        "Speed Run mode. No mercy. Fifteen seconds on the clock.",
        "The fastest fifteen seconds you'll ever watch.",
    ],
}

_ORB_SETUP = {
    "ice":      "Ice Orb. Every hit freezes the boss for two and a half seconds. While frozen — double damage. It cannot fight back.",
    "mine":     "Mine Orb. Plants a proximity mine on every single bounce. Watch the arena fill up with explosives.",
    "blackhole":"Void Star Orb. Creates a gravitational vortex. The boss gets PULLED into it and cannot escape.",
    "combo":    "Combo Orb. The damage doubles every wall bounce. At max streak — sixty four thousand damage per hit.",
    "laser":    "Laser Orb. Thirty ticks of beam damage on contact. Consistent. Relentless. Absolutely deadly.",
    "chain":    "Chain Orb. Three lightning bolts fire the instant it touches anything. Chain reaction every single time.",
    "nova":     "Nova Star Orb. Radial explosion burst on every boss hit. It is basically a bomb with legs.",
    "hook":     "Hook Orb. Once it gets within four hundred pixels of the boss — it homes in automatically. You cannot dodge it.",
    "splitter": "Shuriken Orb. Spawns three spinning blades on each hit. Eight thousand damage each. Do the math.",
    "zapper":   "Zapper Orb. Every bounce drops a crackling thunder zone across the entire arena.",
    "clone":    "Echo Orb. Three ghost clones appear on contact and deal damage for three and a half seconds. It is a full swarm.",
    "void":     "Void Orb. Phases through walls. Warps across the arena. The boss has absolutely nowhere to hide.",
    "fire":     "Inferno Orb. Places burning fire zones everywhere it bounces. Damage over time. The floor becomes lava.",
    "firetrap": "Fire Trap Orb. Sets burning trap zones on every bounce. The entire arena becomes a fire minefield.",
    "prismatic":"Prismatic Orb. Wall bounces fire reflective beams across the whole arena. A full beam web forms.",
    "basic":    "Shock Orb. Classic. A shockwave ring fires on every bounce. Plus three thousand bonus damage every single hit.",
}

_ARENA_SETUP = {
    "tiny":        "We are in the TINY arena. Fifty-two percent of screen. The boss has absolutely NOWHERE to go.",
    "small":       "Small arena. Close quarters. Every bounce comes back instantly.",
    "normal":      "Normal arena. Balanced field. This is where the orb really shows what it can do.",
    "full":        "Full arena. One hundred percent screen. Maximum distance between walls — maximum bounce buildup.",
    "pillarsSmall":"Pillar arena. Four pillars at every corner. The orb ricochets off everything in here.",
    "pillarsBig":  "MEGA pillar arena. Two giant pillars flanking the center. Absolute ricochet chaos.",
    "corridors":   "Corridor arena. Tight S-curve lanes. Once the orb fills these corridors — nothing survives.",
    "maze":        "THE MAZE. L-shaped walls mirrored across the entire arena. Once the traps are set — there is no escape route.",
}

_COMMENTARY = {
    "ice": [
        "Watch — the moment it hits — FREEZE.",
        "Frozen again. Double damage window is OPEN.",
        "The boss cannot move. It is completely stuck.",
        "Freeze. Hit. Freeze. Hit. The cycle never ends.",
        "Two and a half seconds of pure punishment every single bounce.",
        "Frozen solid. Hit it again.",
        "It cannot run. It cannot dodge. It just takes every hit.",
        "The tiny arena makes this even more brutal.",
    ],
    "mine": [
        "Mine down.",
        "Another mine. And another.",
        "Look at how many mines are covering this arena right now.",
        "The boss just walked into three mines at once.",
        "The entire floor is a death trap.",
        "Every bounce plants another mine. There is no safe zone left.",
        "BOOM. There goes another cluster.",
        "It stepped right into it. Every time.",
    ],
    "blackhole": [
        "There is the vortex — the boss is getting PULLED IN.",
        "It cannot escape the gravitational field.",
        "Fifteen hundred damage every point three seconds from suction alone.",
        "The boss is trapped in orbit. It has absolutely no choice.",
        "Watch how it circles. Around and around.",
        "The vortex does not stop. The damage does not stop.",
        "Fully locked in. Completely helpless.",
        "The corridors make the vortex inescapable.",
    ],
    "combo": [
        "Multiplier building. Two times.",
        "Four times damage now.",
        "EIGHT times. Keep it going. Do not hit the boss yet.",
        "Sixteen times multiplier — one more bounce.",
        "THIRTY-TWO TIMES. Almost there.",
        "SIXTY FOUR THOUSAND DAMAGE. One single hit.",
        "The multiplier resets. Build it again from scratch.",
        "Every wall bounce is worth more than the last.",
        "The full arena gives us maximum bounces before contact.",
    ],
    "laser": [
        "Thirty ticks of beam damage on contact.",
        "Thirty thousand damage. Every single hit.",
        "The beam does not stop until the cooldown ends.",
        "Clean. Efficient. Brutal.",
        "No RNG. No luck. Just consistent damage every time.",
        "It hits the boss and the laser just keeps going.",
    ],
    "chain": [
        "Three lightning bolts. Instantly.",
        "BOOM. BOOM. BOOM.",
        "The chain reaction just triggered off the pillar.",
        "Lightning bouncing between walls and boss.",
        "Triple hit on one contact. That is the chain.",
        "The pillars redirect every bolt perfectly.",
    ],
    "nova": [
        "EXPLOSION.",
        "Radial burst — everything in range takes the hit.",
        "Nova going off again.",
        "The whole arena lights up on contact.",
        "The boss has nowhere to run from a radial explosion.",
        "Tiny arena means every explosion fills the whole space.",
    ],
    "hook": [
        "It locked on. The boss cannot outrun it.",
        "Homing activated. Four hundred pixel range.",
        "Straight at the boss. No hesitation. No mercy.",
        "You cannot dodge a homing orb. That is literally the point.",
        "Track. Lock. Hit. Repeat.",
        "The pillars deflect it but the homing pulls it right back.",
    ],
    "splitter": [
        "Three blades. Eight thousand each. Twenty-four thousand damage total.",
        "The blades are bouncing all over the arena.",
        "Shuriken spiral — you cannot avoid all three.",
        "Twenty-four thousand. Again. And again.",
        "The blades fan out and surround the boss completely.",
        "In the corridors the blades have nowhere to go but the boss.",
    ],
    "zapper": [
        "Thunder zone placed.",
        "The whole arena is electric now.",
        "Boss walked directly into the thunder field.",
        "Zone after zone after zone.",
        "Every square meter of this maze is now dangerous.",
        "The zapper fills the maze faster than anything else.",
    ],
    "clone": [
        "Three echo clones deployed.",
        "Ghost army is active. Three and a half seconds of damage.",
        "The clones are circling. Closing in from all sides.",
        "Swarm mode. The boss is completely surrounded.",
        "Three echoes dealing continuous damage simultaneously.",
        "In the full arena the clones spread and cover everything.",
    ],
    "void": [
        "Phase warp. Through the wall.",
        "The boss had no idea where it was coming from.",
        "Void teleport. Completely unpredictable trajectory.",
        "It phased out and reappeared on the other side instantly.",
        "No wall can stop the Void Orb. None.",
        "In the maze the void just ignores every wall entirely.",
    ],
    "fire": [
        "Fire zone placed.",
        "The arena floor is on fire.",
        "Boss walked right into the burn zone.",
        "Damage over time. Every second. Non-stop.",
        "The fire zones are stacking everywhere it goes.",
        "The corridors trap the fire zones in every lane.",
    ],
    "firetrap": [
        "Trap set.",
        "Another trap. And another one.",
        "The boss cannot cross without triggering something.",
        "Fire everywhere. Every path is blocked.",
        "Trap activated. Burning.",
        "The maze is completely covered in fire traps now.",
    ],
    "prismatic": [
        "Reflective beam fired.",
        "Look at those beams crossing the entire arena.",
        "It bounced off the wall and hit the boss from behind.",
        "Beam web forming. The arena is completely covered.",
        "Multiple beams active at the same time.",
        "The full arena gives the beams maximum room to spread.",
    ],
    "basic": [
        "Shockwave ring expanding.",
        "Classic hit. Classic shockwave.",
        "Plus three thousand bonus on every single bounce.",
        "Simple. Reliable. Satisfying.",
        "Every wall hit sends out another shockwave ring.",
        "In the maze the shockwaves bounce off every wall.",
    ],
}

_RESULT = [
    "BOSS DEFEATED. Let's GO. 🔥",
    "Done. Boss is DOWN. 💀",
    "That is how you do it. Easy work.",
    "ELIMINATED. No contest.",
    "Timer is up — but look at that damage number.",
    "That score speaks for itself.",
    "Clean run. Perfect execution.",
    "This orb is S-tier. No debate.",
]

_OUTRO = [
    "Follow for more orb battles. 🏹",
    "Which orb should I test next? Drop it in the comments. 👇",
    "Like if this orb deserves S-tier. ✅",
    "More boss battles every single day. 🔥",
    "Comment your favorite orb below. 💬",
    "The full tier list is coming. Stay tuned. 📊",
    "Share this with someone who needs to see this combo. 🎮",
    "Subscribe for the full orb rankings. 🏆",
    "Tag someone who would pick this orb. 👀",
]


# ── Public functions ───────────────────────────────────────────────────────────

def generate_title(params: dict) -> str:
    o = ORB_NAME.get(params["orb"], params["orb"].upper())
    a = ARENA_NAME.get(params["arena"], params["arena"].upper())
    m = MODE_NAME.get(params["mode"], params["mode"].upper())
    return random.choice(_TITLES).replace("{O}", o).replace("{A}", a).replace("{M}", m)


def generate_caption(params: dict) -> str:
    orb_tags = _TAGS.get(params["orb"], "#satisfying #physics #gaming #bossfight")
    return f"{orb_tags} {_BASE_TAGS}"


def generate_voiceover(params: dict) -> dict:
    orb   = params["orb"]
    arena = params["arena"]
    mode  = params["mode"]

    hook       = random.choice(_HOOK.get(mode, _HOOK["time_attack"]))
    orb_line   = _ORB_SETUP.get(orb, f"{ORB_NAME.get(orb, orb.upper())}. Unique ability activates on every hit.")
    arena_line = _ARENA_SETUP.get(arena, f"Arena: {ARENA_NAME.get(arena, arena)}.")
    pool       = _COMMENTARY.get(orb, ["Watch this.", "Look at that damage.", "Incredible."])
    commentary = random.sample(pool, min(4, len(pool)))
    result     = random.choice(_RESULT)
    outro      = random.choice(_OUTRO)

    script = "\n".join([
        f"[HOOK]  {hook}",
        f"[SETUP] {orb_line}",
        f"        {arena_line}",
        *[f"[—]     {line}" for line in commentary],
        f"[END]   {result}",
        f"[CTA]   {outro}",
    ])

    return {
        "hook":        hook,
        "orb_setup":   orb_line,
        "arena_setup": arena_line,
        "commentary":  commentary,
        "result":      result,
        "outro":       outro,
        "script":      script,
    }


def generate_content(params: dict) -> dict:
    """Return title, caption, and voiceover for one run."""
    return {
        "title":     generate_title(params),
        "caption":   generate_caption(params),
        "voiceover": generate_voiceover(params),
    }
