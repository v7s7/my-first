#!/usr/bin/env python3
"""
Boss Ball Blitz – game automation with video replay (100% free, no API needed).

A random orb, arena, HP, and mode are chosen automatically, then a headless
Chromium session plays the game and saves a .webm replay.

Usage
-----
    python autoplay.py                        # save to replay.webm
    python autoplay.py -o my_run.webm         # custom output path
    python autoplay.py --build                # force Flutter rebuild first
    python autoplay.py --duration 45          # override recording length (s)

Requirements
------------
    pip install playwright
    python -m playwright install chromium
    flutter SDK must be on PATH
"""

import argparse
import asyncio
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import random

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

# How long (seconds) to keep recording after the timer starts
# (adds a 5 s buffer so the game-over screen is captured)
MODE_DURATIONS = {
    "time_attack": 68,
    "blitz":       38,
    "speed_run":   23,
}


# ── Random parameter selection ─────────────────────────────────────────────────

# Pre-defined high-synergy combos — picked 50% of the time for exciting runs
SYNERGY_COMBOS = [
    {"orb": "ice",       "arena": "tiny",       "mode": "blitz",       "hp": 1000000},
    {"orb": "mine",      "arena": "maze",        "mode": "time_attack", "hp": None},
    {"orb": "blackhole", "arena": "corridors",   "mode": "blitz",       "hp": 1500000},
    {"orb": "combo",     "arena": "full",        "mode": "time_attack", "hp": 2000000},
    {"orb": "laser",     "arena": "small",       "mode": "speed_run",   "hp": None},
    {"orb": "chain",     "arena": "pillarsSmall","mode": "blitz",       "hp": 1000000},
    {"orb": "nova",      "arena": "tiny",        "mode": "speed_run",   "hp": 500000},
    {"orb": "hook",      "arena": "pillarsBig",  "mode": "time_attack", "hp": None},
    {"orb": "splitter",  "arena": "corridors",   "mode": "speed_run",   "hp": None},
    {"orb": "zapper",    "arena": "maze",        "mode": "time_attack", "hp": 2000000},
]


def choose_parameters_random() -> dict:
    """Pick an entertaining orb / arena / mode / HP combo — no API needed."""
    if random.random() < 0.5:
        params = random.choice(SYNERGY_COMBOS).copy()
    else:
        params = {
            "orb":   random.choice(list(AVAILABLE_ORBS.keys())),
            "arena": random.choice(list(AVAILABLE_ARENAS.keys())),
            "mode":  random.choice(list(AVAILABLE_MODES.keys())),
            "hp":    random.choice([500000, 1000000, 1500000, 2000000, 3000000, None]),
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
    time.sleep(2)  # give the server a moment to bind
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

    print(f"\nGame URL : {url}")
    print(f"Recording: {duration} s  →  {output_path}\n")

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

        context = await browser.new_context(
            viewport={"width": 390, "height": 844},
            record_video_dir=str(tmp_video_dir),
            record_video_size={"width": 390, "height": 844},
        )

        page = await context.new_page()

        # Wait for Flutter canvas to be ready
        print("Loading game…")
        await page.goto(url, wait_until="networkidle", timeout=60_000)

        # Give the game engine 2 s to initialise before the timer starts
        await asyncio.sleep(2)

        print(f"Game running… waiting {duration} s")
        for remaining in range(duration, 0, -5):
            await asyncio.sleep(min(5, remaining))
            print(f"  {remaining - min(5, remaining)} s remaining…", flush=True)

        await context.close()
        await browser.close()

    # Playwright names the file automatically — rename to what the user wants
    candidates = sorted(tmp_video_dir.glob("*.webm"), key=lambda p: p.stat().st_mtime)
    if not candidates:
        print("ERROR: Playwright did not produce a video file.")
        return False

    latest = candidates[-1]
    latest.rename(output_path)

    # Clean up temp dir
    try:
        tmp_video_dir.rmdir()
    except OSError:
        pass

    return True


# ── Entry point ────────────────────────────────────────────────────────────────

async def run(args: argparse.Namespace) -> None:
    project_dir = Path(__file__).parent.resolve()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # 1 ── Pick random game parameters
    params = choose_parameters_random()

    print("\n" + "=" * 56)
    print("  Random pick")
    print("=" * 56)
    print(f"  Orb   : {params.get('orb',  '?')}  ({AVAILABLE_ORBS.get(params.get('orb',''), '')})")
    print(f"  Arena : {params.get('arena','?')}  ({AVAILABLE_ARENAS.get(params.get('arena',''), '')})")
    print(f"  Mode  : {params.get('mode', '?')}  ({AVAILABLE_MODES.get(params.get('mode',''), '')})")
    hp_display = str(params['hp']) if params.get('hp') else "mode default"
    print(f"  HP    : {hp_display}")
    print(f"  Reason: {params.get('reason', '')}")
    print("=" * 56 + "\n")

    # 2 ── Build Flutter web if needed
    web_index = project_dir / "build" / "web" / "index.html"
    if args.build or not web_index.exists():
        if not build_flutter_web(project_dir):
            print("Flutter build failed.")
            sys.exit(1)
    else:
        print("Flutter web build already exists. Use --build to force a rebuild.")

    # 3 ── Start local HTTP server
    server = serve_flutter_web(project_dir, args.port)

    try:
        # 4 ── Record gameplay
        duration = args.duration or MODE_DURATIONS.get(params.get("mode", "time_attack"), 70)
        success  = await record_gameplay(params, output_path, args.port, duration)

        if success:
            size_mb = output_path.stat().st_size / 1_048_576
            print(f"\nDone!  Replay saved → {output_path}  ({size_mb:.1f} MB)")
            print(json.dumps(params, indent=2))
        else:
            print("\nRecording failed – no video file was produced.")
            sys.exit(1)
    finally:
        server.terminate()
        server.wait()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Play Boss Ball Blitz with Claude AI and capture a video replay.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--output", "-o",
        default="replay.webm",
        help="Output video file (default: replay.webm)",
    )
    parser.add_argument(
        "--duration", "-d",
        type=int,
        default=None,
        help="Recording length in seconds (default: auto from mode timer + buffer)",
    )
    parser.add_argument(
        "--port", "-p",
        type=int,
        default=8765,
        help="Local HTTP server port (default: 8765)",
    )
    parser.add_argument(
        "--build",
        action="store_true",
        help="Force a Flutter web rebuild before recording",
    )

    asyncio.run(run(parser.parse_args()))


if __name__ == "__main__":
    main()
