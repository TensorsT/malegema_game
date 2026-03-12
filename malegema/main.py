from __future__ import annotations

import argparse
import os
import sys

# Support both:
# 1) python -m malegema.main
# 2) python malegema/main.py
if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
    from malegema.cli import run_cli
    from malegema.gui import run_gui
else:
    from .cli import run_cli
    from .gui import run_gui


def main() -> None:
    parser = argparse.ArgumentParser(description="Malegema: Python rewrite of whatajong core game")
    parser.add_argument(
        "--seed",
        default=None,
        help="Optional seed. Omit to generate a different game each run",
    )
    parser.add_argument(
        "--deck",
        default="full",
        choices=["full", "classic"],
        help="Deck mode: full includes special tiles, classic only suit tiles",
    )
    parser.add_argument(
        "--mode",
        default="gui",
        choices=["gui", "cli"],
        help="Launch mode: gui (desktop) or cli (terminal)",
    )
    args = parser.parse_args()
    if args.mode == "gui":
        run_gui(seed=args.seed, deck_mode=args.deck)
    else:
        run_cli(seed=args.seed, deck_mode=args.deck)


if __name__ == "__main__":
    main()
