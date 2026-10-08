"""Create the offline, self-contained FST connectivity explorer."""

from __future__ import annotations

import base64
import json
import tempfile
import webbrowser
from pathlib import Path

from .layout import DATA_DIR, layout_species
from .model import load_species


TEMPLATE = Path(__file__).with_name("explorer.html")


def _default_data_dir() -> Path:
    """Use bundled evidence after installation and canonical CSVs in a checkout."""
    if all((DATA_DIR / species / "evidence.csv").is_file()
           for species in ("macaque", "human")):
        return DATA_DIR
    checkout = Path(__file__).resolve().parents[2]
    if (checkout / "pyproject.toml").is_file() and all(
            (checkout / species / "evidence.csv").is_file()
            for species in ("macaque", "human")):
        return checkout
    return DATA_DIR


def build_payload(
    *, data_dir: str | Path | None = None, initial_species: str = "macaque"
) -> dict:
    """Build JSON-ready plot data for both FST views from the curated CSVs."""
    if initial_species not in {"macaque", "human"}:
        raise ValueError("initial_species must be 'macaque' or 'human'")
    root = Path(data_dir) if data_dir is not None else _default_data_dir()
    payload = {"initial_species": initial_species}
    for species in ("macaque", "human"):
        evidence = load_species(species, root)
        layout = layout_species(species, evidence["nodes"])
        image_path = (
            root / species / "surface_snapshots" / "veryinflated_lat_white.png"
        )
        if not image_path.is_file():
            # A caller may point at the review's raw CSV/TIFF folders. The
            # bundled PNG is pixel-identical to the lateral TIFF source.
            image_path = (
                DATA_DIR / species / "surface_snapshots" / "veryinflated_lat_white.png"
            )
        image = base64.b64encode(image_path.read_bytes()).decode("ascii")
        payload[species] = {
            **evidence,
            **layout,
            "image": "data:image/png;base64," + image,
        }
    return payload


def render_html(
    output: str | Path | None = None,
    *,
    data_dir: str | Path | None = None,
    initial_species: str = "macaque",
) -> Path:
    """Write an offline HTML explorer with both images and all data embedded.

    The output opens directly in a browser and makes no network requests.
    No source CSV or MATLAB output file is changed.
    """
    if output is None:
        output_path = Path(tempfile.mkdtemp(prefix="fst-connectivity-")) / (
            "FST_connectivity_explorer.html"
        )
    else:
        output_path = Path(output).expanduser().resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
    payload = build_payload(data_dir=data_dir, initial_species=initial_species)
    encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    encoded = encoded.replace("</", "<\\/").replace("<", "\\u003c")
    document = TEMPLATE.read_text(encoding="utf-8").replace(
        "__CONNECTIVITY_PAYLOAD__", encoded
    )
    output_path.write_text(document, encoding="utf-8")
    return output_path


def launch(
    output: str | Path | None = None,
    *,
    data_dir: str | Path | None = None,
    initial_species: str = "macaque",
    open_browser: bool = True,
) -> Path:
    """Create the explorer and optionally open it in the default browser."""
    path = render_html(output, data_dir=data_dir, initial_species=initial_species)
    if open_browser:
        webbrowser.open(path.as_uri())
    return path
