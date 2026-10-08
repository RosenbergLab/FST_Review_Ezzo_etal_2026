"""Command-line entry point for the FST connectivity explorer."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .view import launch


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="fst-connectivity",
        description="Open the macaque and human FST connectivity explorer.",
    )
    parser.add_argument(
        "--output", type=Path, metavar="FILE",
        help="save a self-contained HTML file at FILE (default: temporary file)",
    )
    parser.add_argument(
        "--species", choices=("macaque", "human"), default="macaque",
        help="species shown first (both remain available in the figure)",
    )
    parser.add_argument(
        "--data-dir", type=Path, metavar="DIRECTORY",
        help="read updated human/ and macaque/ CSVs from DIRECTORY",
    )
    parser.add_argument(
        "--no-open", action="store_true", help="write the figure without opening a browser",
    )
    parser.add_argument("--version", action="version", version="fst-connectivity 0.1.2")
    options = parser.parse_args(argv)
    try:
        path = launch(
            options.output,
            data_dir=options.data_dir,
            initial_species=options.species,
            open_browser=not options.no_open,
        )
    except (OSError, ValueError, KeyError) as error:
        print(f"fst-connectivity: {error}", file=sys.stderr)
        return 2
    print(path)
    return 0
