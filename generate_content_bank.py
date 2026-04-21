#!/usr/bin/env python3
"""
Pre-generate TikTok titles and voiceover scripts for every SYNERGY_COMBO.

Run once to populate content_bank/ with ready-to-use content for all 53 combos.
Each combo gets 3 title options + a full voiceover script in its own .txt file.

Usage
-----
    python generate_content_bank.py
"""

import json
import random
from pathlib import Path

from autoplay import SYNERGY_COMBOS
from content import (
    generate_title,
    generate_caption,
    generate_voiceover,
    ORB_NAME,
    ARENA_NAME,
    MODE_NAME,
)

OUT_DIR     = Path("content_bank")
SCRIPTS_DIR = OUT_DIR / "scripts"


def format_script_file(combo: dict, titles: list[str], caption: str, vo: dict) -> str:
    orb   = combo["orb"]
    arena = combo["arena"]
    mode  = combo["mode"]
    tag   = combo.get("tag", f"{orb}_{arena}_{mode}")

    return (
        f"# {ORB_NAME.get(orb, orb)}  ×  {ARENA_NAME.get(arena, arena)}  ×  {MODE_NAME.get(mode, mode)}\n"
        f"# Tag: {tag}\n"
        f"# HP:  {combo.get('hp') or 'mode default'}\n"
        f"\n"
        f"{'─'*60}\n"
        f"TITLE OPTIONS\n"
        f"{'─'*60}\n"
        + "\n".join(f"  {i+1}.  {t}" for i, t in enumerate(titles))
        + f"\n\n"
        f"{'─'*60}\n"
        f"CAPTION / HASHTAGS\n"
        f"{'─'*60}\n"
        f"{caption}\n"
        f"\n"
        f"{'─'*60}\n"
        f"VOICEOVER SCRIPT\n"
        f"{'─'*60}\n"
        f"\n"
        f"[HOOK]\n"
        f"  {vo['hook']}\n"
        f"\n"
        f"[ORB SETUP]\n"
        f"  {vo['orb_setup']}\n"
        f"\n"
        f"[ARENA SETUP]\n"
        f"  {vo['arena_setup']}\n"
        f"\n"
        f"[COMMENTARY — read 3-4 of these during gameplay footage]\n"
        + "\n".join(f"  — {line}" for line in vo["commentary"])
        + f"\n\n"
        f"[RESULT]\n"
        f"  {vo['result']}\n"
        f"\n"
        f"[OUTRO / CTA]\n"
        f"  {vo['outro']}\n"
    )


def main() -> None:
    OUT_DIR.mkdir(exist_ok=True)
    SCRIPTS_DIR.mkdir(exist_ok=True)

    titles_bank: dict = {}
    full_bank:   dict = {}

    print(f"Generating content for {len(SYNERGY_COMBOS)} combos…\n")

    for combo in SYNERGY_COMBOS:
        orb   = combo["orb"]
        arena = combo["arena"]
        mode  = combo["mode"]
        tag   = combo.get("tag", f"{orb}_{arena}_{mode}")
        key   = f"{orb}_{arena}_{mode}"

        # 3 title variations per combo
        titles  = [generate_title(combo) for _ in range(3)]
        caption = generate_caption(combo)
        vo      = generate_voiceover(combo)

        # Save per-combo script file
        script_text = format_script_file(combo, titles, caption, vo)
        (SCRIPTS_DIR / f"{tag}.txt").write_text(script_text, encoding="utf-8")

        titles_bank[key] = {
            "tag":     tag,
            "orb":     orb,
            "arena":   arena,
            "mode":    mode,
            "hp":      combo.get("hp"),
            "titles":  titles,
            "caption": caption,
        }

        full_bank[key] = {
            **titles_bank[key],
            "voiceover": vo,
        }

        print(f"  ✓  {tag}")
        print(f"       Title 1: {titles[0]}")
        print(f"       Hook:    {vo['hook']}")
        print()

    # titles.json — quick lookup for all titles
    (OUT_DIR / "titles.json").write_text(
        json.dumps(titles_bank, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    # all_content.json — complete bank including voiceovers
    (OUT_DIR / "all_content.json").write_text(
        json.dumps(full_bank, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    # Quick-reference sheet: one title per combo, alphabetical
    quick_lines = ["BOSS BALL BLITZ — CONTENT QUICK REFERENCE", "=" * 60, ""]
    for key, data in sorted(full_bank.items()):
        quick_lines.append(f"[{data['tag']}]")
        quick_lines.append(f"  Title  : {data['titles'][0]}")
        quick_lines.append(f"  Caption: {data['caption'][:80]}…")
        quick_lines.append(f"  Hook   : {data['voiceover']['hook']}")
        quick_lines.append("")

    (OUT_DIR / "quick_reference.txt").write_text(
        "\n".join(quick_lines), encoding="utf-8"
    )

    print("─" * 60)
    print(f"✅  Content bank saved to  {OUT_DIR}/")
    print(f"    {len(SYNERGY_COMBOS)} scripts   →  {SCRIPTS_DIR}/")
    print(f"    titles.json            ({len(titles_bank)} entries)")
    print(f"    all_content.json       (full voiceover bank)")
    print(f"    quick_reference.txt    (one-page cheat sheet)")


if __name__ == "__main__":
    main()
