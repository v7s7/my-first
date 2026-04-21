#!/usr/bin/env python3
"""
Boss Ball Blitz — free automation agent with video replay.

Picks an exciting orb + arena + mode combo automatically (no API, no cost),
records a headless Chromium gameplay session, and saves a .webm video plus
a JSON metadata file and a ready-to-read voiceover script alongside it.

Usage
-----
    python autoplay.py                        # one video → replay.webm
    python autoplay.py -o runs/run.webm       # custom output path
    python autoplay.py --build                # force Flutter rebuild first
    python autoplay.py --duration 45          # override recording length (s)
    python autoplay.py --batch 10             # record 10 videos in sequence
    python autoplay.py --batch 10 -o runs/    # save batch into a folder

Requirements
------------
    pip install playwright
    python -m playwright install chromium
    flutter SDK must be on PATH
"""

import argparse
import asyncio
import json
import random
import subprocess
import sys
import time
from pathlib import Path

from content import generate_content

# ── Game constants ─────────────────────────────────────────────────────────────

AVAILABLE_ORBS = {
    "basic":     "SHOCK – shockwave ring on every bounce (+3K bonus)",
    "laser":     "LASER – rapid-fire beam, 30 ticks × 1K DoT",
    "combo":     "COMBO – damage doubles each wall bounce (up to 64K)",
    "chain":     "CHAIN – 3 lightning bolts fire in quick succession",
    "fire":      "INFERNO – places burning fire zones with DoT",
    "prismatic": "PRISMATIC – wall bounces create reflective beams",
    "nova":      "NOVA STAR – radial explosion burst on boss hit",
    "void":      "VOID – warp / phase mechanic",
    "hook":      "HOOK – homing toward boss when within 400 px",
    "splitter":  "SHURIKEN – spawns 3 spinning blades (8K each)",
    "zapper":    "ZAPPER – creates crackling thunder zones",
    "clone":     "ECHO – 3 ghost echoes deal DoT for 3.5 s",
    "blackhole": "VOID STAR – vortex pulls boss + 1.5K/0.3s suction",
    "mine":      "MINE – plants proximity mines on bounces (8K each)",
    "ice":       "ICE – freezes boss 2.5 s (2× damage while frozen)",
    "firetrap":  "FIRE TRAP – burning trap zone variant",
}

AVAILABLE_ARENAS = {
    "tiny":        "52% screen – insane pressure, orb moves fast",
    "small":       "70% screen – close quarters",
    "normal":      "87% screen – balanced (default)",
    "full":        "100% screen – open arena",
    "pillarsSmall":"87% + 4 small pillars at quadrant centres",
    "pillarsBig":  "100% + 2 large pillars flanking centre",
    "corridors":   "87% + S-curve lane dividers",
    "maze":        "100% + mirrored L-shaped walls",
}

AVAILABLE_MODES = {
    "time_attack": "60 s to defeat 1 M HP boss",
    "blitz":       "30 s, 2 M HP boss – frantic",
    "speed_run":   "15 s, score = total damage dealt",
}

MODE_DURATIONS = {
    "time_attack": 68,
    "blitz":       38,
    "speed_run":   23,
}

# ── 53 curated synergy combos ──────────────────────────────────────────────────

SYNERGY_COMBOS = [
    # ICE — constant freeze loop
    {"orb": "ice",       "arena": "tiny",        "mode": "blitz",       "hp": 1000000, "tag": "ice_tiny_blitz"},
    {"orb": "ice",       "arena": "small",       "mode": "blitz",       "hp":  800000, "tag": "ice_small_blitz"},
    {"orb": "ice",       "arena": "corridors",   "mode": "time_attack", "hp": 1500000, "tag": "ice_corridors"},
    {"orb": "ice",       "arena": "maze",        "mode": "speed_run",   "hp":    None, "tag": "ice_maze_speedrun"},
    {"orb": "ice",       "arena": "pillarsSmall","mode": "blitz",       "hp": 1200000, "tag": "ice_pillars_blitz"},

    # MINE — fill the arena with explosives
    {"orb": "mine",      "arena": "maze",        "mode": "time_attack", "hp":    None, "tag": "mine_maze"},
    {"orb": "mine",      "arena": "corridors",   "mode": "time_attack", "hp": 1000000, "tag": "mine_corridors"},
    {"orb": "mine",      "arena": "tiny",        "mode": "blitz",       "hp":  500000, "tag": "mine_tiny_blitz"},
    {"orb": "mine",      "arena": "pillarsSmall","mode": "time_attack", "hp": 1500000, "tag": "mine_pillars_small"},
    {"orb": "mine",      "arena": "pillarsBig",  "mode": "time_attack", "hp": 2000000, "tag": "mine_pillars_big"},

    # BLACKHOLE — inescapable vortex
    {"orb": "blackhole", "arena": "corridors",   "mode": "blitz",       "hp": 1500000, "tag": "blackhole_corridors"},
    {"orb": "blackhole", "arena": "tiny",        "mode": "blitz",       "hp": 1000000, "tag": "blackhole_tiny"},
    {"orb": "blackhole", "arena": "maze",        "mode": "time_attack", "hp": 2000000, "tag": "blackhole_maze"},
    {"orb": "blackhole", "arena": "small",       "mode": "speed_run",   "hp":    None, "tag": "blackhole_small_speedrun"},
    {"orb": "blackhole", "arena": "pillarsSmall","mode": "blitz",       "hp": 1200000, "tag": "blackhole_pillars"},

    # COMBO — build the multiplier
    {"orb": "combo",     "arena": "full",        "mode": "time_attack", "hp": 2000000, "tag": "combo_full"},
    {"orb": "combo",     "arena": "pillarsBig",  "mode": "time_attack", "hp": 3000000, "tag": "combo_pillars_big"},
    {"orb": "combo",     "arena": "normal",      "mode": "time_attack", "hp": 1500000, "tag": "combo_normal"},
    {"orb": "combo",     "arena": "maze",        "mode": "time_attack", "hp": 2500000, "tag": "combo_maze"},

    # LASER — consistent beam DPS
    {"orb": "laser",     "arena": "small",       "mode": "speed_run",   "hp":    None, "tag": "laser_small_speedrun"},
    {"orb": "laser",     "arena": "tiny",        "mode": "blitz",       "hp":  800000, "tag": "laser_tiny_blitz"},
    {"orb": "laser",     "arena": "corridors",   "mode": "speed_run",   "hp":    None, "tag": "laser_corridors_speedrun"},
    {"orb": "laser",     "arena": "normal",      "mode": "time_attack", "hp": 1000000, "tag": "laser_normal"},

    # CHAIN — triple lightning
    {"orb": "chain",     "arena": "pillarsSmall","mode": "blitz",       "hp": 1000000, "tag": "chain_pillars_small"},
    {"orb": "chain",     "arena": "maze",        "mode": "time_attack", "hp": 1500000, "tag": "chain_maze"},
    {"orb": "chain",     "arena": "tiny",        "mode": "blitz",       "hp":  800000, "tag": "chain_tiny_blitz"},
    {"orb": "chain",     "arena": "pillarsBig",  "mode": "time_attack", "hp": 2000000, "tag": "chain_pillars_big"},

    # NOVA — explosion burst
    {"orb": "nova",      "arena": "tiny",        "mode": "speed_run",   "hp":  500000, "tag": "nova_tiny_speedrun"},
    {"orb": "nova",      "arena": "small",       "mode": "blitz",       "hp":  800000, "tag": "nova_small_blitz"},
    {"orb": "nova",      "arena": "corridors",   "mode": "time_attack", "hp": 1000000, "tag": "nova_corridors"},

    # HOOK — homing precision
    {"orb": "hook",      "arena": "pillarsBig",  "mode": "time_attack", "hp":    None, "tag": "hook_pillars_big"},
    {"orb": "hook",      "arena": "full",        "mode": "time_attack", "hp": 2000000, "tag": "hook_full"},
    {"orb": "hook",      "arena": "corridors",   "mode": "blitz",       "hp": 1000000, "tag": "hook_corridors_blitz"},

    # SPLITTER — shuriken blades
    {"orb": "splitter",  "arena": "corridors",   "mode": "speed_run",   "hp":    None, "tag": "splitter_corridors_speedrun"},
    {"orb": "splitter",  "arena": "tiny",        "mode": "blitz",       "hp":  500000, "tag": "splitter_tiny_blitz"},
    {"orb": "splitter",  "arena": "maze",        "mode": "time_attack", "hp": 1500000, "tag": "splitter_maze"},

    # ZAPPER — thunder zone area denial
    {"orb": "zapper",    "arena": "maze",        "mode": "time_attack", "hp": 2000000, "tag": "zapper_maze"},
    {"orb": "zapper",    "arena": "corridors",   "mode": "blitz",       "hp": 1500000, "tag": "zapper_corridors_blitz"},
    {"orb": "zapper",    "arena": "pillarsSmall","mode": "time_attack", "hp": 1000000, "tag": "zapper_pillars_small"},

    # VOID — phase through walls
    {"orb": "void",      "arena": "maze",        "mode": "blitz",       "hp": 1000000, "tag": "void_maze_blitz"},
    {"orb": "void",      "arena": "tiny",        "mode": "speed_run",   "hp":    None, "tag": "void_tiny_speedrun"},
    {"orb": "void",      "arena": "corridors",   "mode": "time_attack", "hp": 1500000, "tag": "void_corridors"},

    # CLONE — ghost echo swarm
    {"orb": "clone",     "arena": "full",        "mode": "time_attack", "hp": 2000000, "tag": "clone_full"},
    {"orb": "clone",     "arena": "corridors",   "mode": "blitz",       "hp": 1000000, "tag": "clone_corridors_blitz"},
    {"orb": "clone",     "arena": "maze",        "mode": "time_attack", "hp": 1500000, "tag": "clone_maze"},

    # FIRE — burn zones
    {"orb": "fire",      "arena": "corridors",   "mode": "time_attack", "hp": 1000000, "tag": "fire_corridors"},
    {"orb": "fire",      "arena": "maze",        "mode": "time_attack", "hp": 1500000, "tag": "fire_maze"},

    # FIRETRAP — trap zone coverage
    {"orb": "firetrap",  "arena": "maze",        "mode": "time_attack", "hp": 2000000, "tag": "firetrap_maze"},
    {"orb": "firetrap",  "arena": "corridors",   "mode": "blitz",       "hp": 1000000, "tag": "firetrap_corridors_blitz"},

    # PRISMATIC — reflective beam web
    {"orb": "prismatic", "arena": "full",        "mode": "time_attack", "hp": 2000000, "tag": "prismatic_full"},
    {"orb": "prismatic", "arena": "pillarsBig",  "mode": "time_attack", "hp": 1500000, "tag": "prismatic_pillars_big"},

    # BASIC — classic shock, extreme conditions
    {"orb": "basic",     "arena": "tiny",        "mode": "blitz",       "hp":  500000, "tag": "basic_tiny_blitz"},
    {"orb": "basic",     "arena": "maze",        "mode": "time_attack", "hp": 3000000, "tag": "basic_maze_endurance"},
]  # 53 total

# ── Combo log (duplicate avoidance) ───────────────────────────────────────────

_LOG_FILE = Path("combo_log.json")


def _load_log() -> dict:
    if _LOG_FILE.exists():
        return json.loads(_LOG_FILE.read_text())
    return {"played": [], "total_runs": 0, "videos": []}


def _save_log(log: dict) -> None:
    _LOG_FILE.write_text(json.dumps(log, indent=2))


def _combo_key(params: dict) -> str:
    return f"{params['orb']}_{params['arena']}_{params['mode']}"


# ── Parameter selection ────────────────────────────────────────────────────────

def choose_parameters_random(log: dict | None = None) -> dict:
    """Pick an unplayed synergy combo (50%) or fully random (50%)."""
    played = set((log or {}).get("played", []))
    unplayed = [c for c in SYNERGY_COMBOS if _combo_key(c) not in played]

    if not unplayed:
        print("All 53 synergy combos recorded — cycling from the beginning…")
        if log is not None:
            log["played"] = []
        unplayed = list(SYNERGY_COMBOS)

    if random.random() < 0.5:
        params = random.choice(unplayed).copy()
    else:
        params = {
            "orb":   random.choice(list(AVAILABLE_ORBS.keys())),
            "arena": random.choice(list(AVAILABLE_ARENAS.keys())),
            "mode":  random.choice(list(AVAILABLE_MODES.keys())),
            "hp":    random.choice([500000, 1000000, 1500000, 2000000, 3000000, None]),
            "tag":   "random",
        }

    params["reason"] = f"{AVAILABLE_ORBS[params['orb']]} in {params['arena']} arena"
    return params


# ── Flutter build & serve ──────────────────────────────────────────────────────

def build_flutter_web(project_dir: Path) -> bool:
    print("Building Flutter web app (this takes ~1 min on first run)…")
    result = subprocess.run(
        ["flutter", "build", "web", "--release", "--web-renderer", "canvaskit"],
        cwd=project_dir,
    )
    return result.returncode == 0


def serve_flutter_web(project_dir: Path, port: int) -> subprocess.Popen:
    web_dir = project_dir / "build" / "web"
    proc = subprocess.Popen(
        ["python3", "-m", "http.server", str(port), "--bind", "127.0.0.1"],
        cwd=web_dir,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(2)
    return proc


# ── Playwright recording ───────────────────────────────────────────────────────

async def record_gameplay(
    params: dict,
    output_path: Path,
    port: int,
    duration: int,
) -> bool:
    from playwright.async_api import async_playwright

    orb   = params["orb"]
    arena = params["arena"]
    mode  = params["mode"]
    hp    = params.get("hp")

    hp_param = f"&hp={hp}" if hp else ""
    url = (
        f"http://127.0.0.1:{port}/"
        f"?autoplay=true&orb={orb}&arena={arena}&mode={mode}{hp_param}"
    )

    print(f"\nGame URL  : {url}")
    print(f"Recording : {duration} s  →  {output_path}\n")

    tmp_video_dir = output_path.parent / "_playwright_tmp"
    tmp_video_dir.mkdir(parents=True, exist_ok=True)

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            args=[
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu",
                "--enable-unsafe-webgpu",
            ],
        )

        # TikTok portrait format: 1080×1920
        context = await browser.new_context(
            viewport={"width": 1080, "height": 1920},
            record_video_dir=str(tmp_video_dir),
            record_video_size={"width": 1080, "height": 1920},
        )

        page = await context.new_page()

        print("Loading game…")
        await page.goto(url, wait_until="networkidle", timeout=60_000)
        await asyncio.sleep(2)

        print(f"Game running… waiting {duration} s")
        for remaining in range(duration, 0, -5):
            await asyncio.sleep(min(5, remaining))
            print(f"  {remaining - min(5, remaining)} s remaining…", flush=True)

        await context.close()
        await browser.close()

    candidates = sorted(tmp_video_dir.glob("*.webm"), key=lambda p: p.stat().st_mtime)
    if not candidates:
        print("ERROR: Playwright did not produce a video file.")
        return False

    candidates[-1].rename(output_path)
    try:
        tmp_video_dir.rmdir()
    except OSError:
        pass

    return True


# ── Metadata & script saving ───────────────────────────────────────────────────

def save_run_files(output_path: Path, params: dict, content: dict, run_num: int) -> None:
    """Save .json metadata and _script.txt alongside the video."""
    vo = content["voiceover"]

    meta = {
        "run":     run_num,
        "video":   str(output_path),
        "orb":     params["orb"],
        "arena":   params["arena"],
        "mode":    params["mode"],
        "hp":      params.get("hp"),
        "tag":     params.get("tag", "random"),
        "title":   content["title"],
        "caption": content["caption"],
    }

    meta_path   = output_path.with_suffix(".json")
    script_path = output_path.with_name(output_path.stem + "_script.txt")

    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    script_path.write_text(vo["script"], encoding="utf-8")


# ── Entry point ────────────────────────────────────────────────────────────────

async def run(args: argparse.Namespace) -> None:
    project_dir = Path(__file__).parent.resolve()
    log         = _load_log()
    batch       = args.batch

    # Resolve output path(s)
    out_arg = Path(args.output)
    if batch > 1 and out_arg.suffix == "":
        # Treat as directory
        out_dir = out_arg.resolve()
        out_dir.mkdir(parents=True, exist_ok=True)
        def make_output(i: int) -> Path:
            return out_dir / f"run_{log['total_runs'] + i + 1:04d}.webm"
    elif batch > 1:
        stem = out_arg.stem
        ext  = out_arg.suffix
        out_dir = out_arg.parent.resolve()
        out_dir.mkdir(parents=True, exist_ok=True)
        def make_output(i: int) -> Path:
            return out_dir / f"{stem}_{i + 1:03d}{ext}"
    else:
        single = out_arg.resolve()
        single.parent.mkdir(parents=True, exist_ok=True)
        def make_output(_: int) -> Path:
            return single

    # Build Flutter once
    web_index = project_dir / "build" / "web" / "index.html"
    if args.build or not web_index.exists():
        if not build_flutter_web(project_dir):
            print("Flutter build failed.")
            sys.exit(1)
    else:
        print("Flutter web build exists. Use --build to force a rebuild.")

    server = serve_flutter_web(project_dir, args.port)

    try:
        for i in range(batch):
            if batch > 1:
                print(f"\n{'='*56}")
                print(f"  Video {i+1} of {batch}")

            params  = choose_parameters_random(log)
            content = generate_content(params)

            print("\n" + "=" * 56)
            print("  Random pick")
            print("=" * 56)
            print(f"  Orb    : {params.get('orb','?')}  ({AVAILABLE_ORBS.get(params.get('orb',''), '')})")
            print(f"  Arena  : {params.get('arena','?')}  ({AVAILABLE_ARENAS.get(params.get('arena',''), '')})")
            print(f"  Mode   : {params.get('mode','?')}  ({AVAILABLE_MODES.get(params.get('mode',''), '')})")
            hp_display = str(params['hp']) if params.get('hp') else "mode default"
            print(f"  HP     : {hp_display}")
            print(f"  Title  : {content['title']}")
            print(f"  Hook   : {content['voiceover']['hook']}")
            print("=" * 56 + "\n")

            output_path = make_output(i)
            duration    = args.duration or MODE_DURATIONS.get(params.get("mode", "time_attack"), 70)
            success     = await record_gameplay(params, output_path, args.port, duration)

            if success:
                size_mb = output_path.stat().st_size / 1_048_576
                print(f"\nSaved → {output_path}  ({size_mb:.1f} MB)")

                # Mark as played and persist
                key = _combo_key(params)
                if key not in log["played"] and params.get("tag") != "random":
                    log["played"].append(key)
                log["total_runs"] += 1
                log["videos"].append({
                    "run":   log["total_runs"],
                    "file":  str(output_path),
                    "key":   key,
                    "title": content["title"],
                })
                _save_log(log)

                save_run_files(output_path, params, content, log["total_runs"])
                print(f"  Metadata → {output_path.with_suffix('.json').name}")
                print(f"  Script   → {output_path.stem}_script.txt")
            else:
                print("\nRecording failed – no video file was produced.")
                if batch == 1:
                    sys.exit(1)

    finally:
        server.terminate()
        server.wait()

    print(f"\nAll done. Total runs recorded: {log['total_runs']}")
    print(f"Synergy combos played so far : {len(log['played'])} / {len(SYNERGY_COMBOS)}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Record Boss Ball Blitz gameplay videos — free, no API needed.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--output", "-o", default="replay.webm",
        help="Output file or directory for batch mode (default: replay.webm)")
    parser.add_argument("--duration", "-d", type=int, default=None,
        help="Recording length in seconds (default: auto from mode)")
    parser.add_argument("--port", "-p", type=int, default=8765,
        help="Local HTTP server port (default: 8765)")
    parser.add_argument("--build", action="store_true",
        help="Force a Flutter web rebuild before recording")
    parser.add_argument("--batch", "-b", type=int, default=1,
        help="Number of videos to record in sequence (default: 1)")

    asyncio.run(run(parser.parse_args()))


if __name__ == "__main__":
    main()
