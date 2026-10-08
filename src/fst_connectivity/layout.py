"""Paper-view coordinates shared by the Python connectivity explorer.

These transformations mirror paperConnectivityLayout.m and
paperHumanConnectivityLayout.m. Source nodes.csv coordinates are never edited.
"""

from __future__ import annotations

import json
from pathlib import Path


DATA_DIR = Path(__file__).parent / "data"
COLORS = {
    "blue": "#B3E4F8",
    "red": "#F2B3D0",
    "green": "#F9F384",
    "black": "#000000",
}
PATHWAY_COLORS = {
    "dorsal pathway": "#B3E4F8",
    "lateral pathway": "#F2B3D0",
    "ventral pathway": "#F9F384",
}


def _put(by_label: dict, label: str, point: tuple[float, float]) -> None:
    if label in by_label:
        by_label[label]["x"], by_label[label]["y"] = point


def _finish(nodes: list[dict], *, y_max: float) -> None:
    for node in nodes:
        node["x"] = min(max(node["x"], 5), 529)
        node["y"] = min(max(node["y"], 5), y_max)
        node["fill"] = COLORS[node["color"].strip().lower()]
        node["display_label"] = (
            "basal forebrain" if node["label"] == "basalfore" else node["label"]
        )


def _macaque(nodes: list[dict]) -> dict:
    scale_x = 447 / 2210
    scale_y = 259 / 1275
    offset_x = 31 - 20 * scale_x
    offset_y = 29 - 20 * scale_y
    by_label = {node["label"]: node for node in nodes}
    for node in nodes:
        node["x"] = offset_x + scale_x * node["native_x"]
        node["y"] = offset_y + scale_y * node["native_y"]

    _put(by_label, "TF", (257, 279))
    _put(by_label, "5", (offset_x + scale_x * 1200, offset_y + scale_y * 80))
    _put(by_label, "PO", (offset_x + scale_x * 1830, offset_y + scale_y * 275))

    medial_names = ["V6", "PCCa", "PCCp", "RSC", "24c", "7m", "preSMA"]
    has_extra_medial = any(name in by_label for name in ("24c", "7m", "preSMA"))
    if has_extra_medial:
        medial_rect = [36, 220, 93, 85]
        medial_points = [(51, 253), (96, 275), (51, 297), (96, 297),
                         (81, 253), (113, 253), (51, 275)]
    else:
        medial_rect = [36, 236, 68, 51]
        medial_points = [(47, 260), (85, 260), (47, 281), (85, 281),
                         (47, 260), (85, 260), (47, 281)]
    for name, point in zip(medial_names, medial_points):
        _put(by_label, name, point)

    subcortical_names = ["basalfore", "SC", "claustrum", "pons",
                         "striatum", "pretectum", "thalamus"]
    subcortical_points = [(394, 249), (459, 249), (394, 270), (459, 270),
                          (394, 290), (459, 290), (394, 310)]
    for name, point in zip(subcortical_names, subcortical_points):
        _put(by_label, name, point)

    reference = json.loads(
        (DATA_DIR / "macaque_reference_points.json").read_text(encoding="utf-8")
    )
    for name, point in reference.items():
        _put(by_label, name, tuple(point))
    if has_extra_medial:
        for name, point in zip(medial_names, medial_points):
            _put(by_label, name, point)

    # The paper dots are overridden exactly as in paperConnectivityLayout.m.
    for name in ("VIP", "S1"):
        if name in by_label:
            node = by_label[name]
            _put(by_label, name, (offset_x + scale_x * node["native_x"],
                                  offset_y + scale_y * node["native_y"]))
    _put(by_label, "V4t", (345, 157))
    _put(by_label, "FST", (313, 153))
    _finish(nodes, y_max=323)

    return {
        "species": "macaque",
        "title": "Connectivity in macaques — FST",
        "nodes": nodes,
        "view_box": [0, 0, 534, 328],
        "plot_size": [1335, 820],
        "plot_offset": [0, 0],
        "image_geometry": [offset_x, offset_y, scale_x * 2249, scale_y * 1325],
        "boxes": [
            {"name": "medial cortex", "rect": medial_rect},
            {"name": "subcortical", "rect": [371, 227, 107, 85]},
        ],
        "pathways": [
            {"name": "dorsal pathway", "x": 370, "y": 42},
            {"name": "lateral pathway", "x": 202, "y": 207},
            {"name": "ventral pathway", "x": 288, "y": 286},
        ],
    }


def _human(nodes: list[dict]) -> dict:
    scale = 0.20
    offset_x, offset_y = 30, 25
    center_x, center_y = 2250 / 2, 1523 / 2
    inward = 0.90
    by_label = {node["label"]: node for node in nodes}
    for node in nodes:
        node["x"] = offset_x + scale * (center_x + inward * (node["native_x"] - center_x))
        node["y"] = offset_y + scale * (center_y + inward * (node["native_y"] - center_y))

    early = {"V1": (2120, 920), "V2": (2085, 945), "V3": (2050, 975)}
    for name, (x, y) in early.items():
        _put(by_label, name, (offset_x + scale * x, offset_y + scale * y))
    for name, point in {
        "LO1-3": (412, 222), "LO1": (416.1, 220), "LO2": (408, 238),
        "LO3": (412.5, 207), "PIT": (388, 245.4),
    }.items():
        _put(by_label, name, point)

    medial_names = ["V6", "BA7", "BA23", "BA31", "precuneus", "RSC", "mPFC", "preSMA"]
    medial_rect = [8, 198, 122, 104]
    if "BA31" in by_label:
        medial_points = [(37, 230), (98, 230), (37, 250), (98, 250),
                         (98, 270), (37, 270), (37, 290), (98, 290)]
    else:
        medial_points = [(37, 230), (98, 230), (37, 250), (98, 250),
                         (98, 250), (37, 270), (98, 270), (67, 290)]
    for name, point in zip(medial_names, medial_points):
        _put(by_label, name, point)
    for name, point in {
        "V8": (430, 264), "VMV": (400, 274), "VVC": (344, 294),
        "FFC": (365, 277), "TF": (270, 307),
    }.items():
        _put(by_label, name, point)
    _finish(nodes, y_max=425)

    return {
        "species": "human",
        "title": "Connectivity in humans — FST",
        "nodes": nodes,
        "view_box": [0, 0, 534, 360],
        "plot_size": [1080, 728],
        "plot_offset": [128, 46],
        "image_geometry": [offset_x, offset_y, scale * 2249, scale * 1522],
        "boxes": [{"name": "medial cortex", "rect": medial_rect}],
        "pathways": [
            {"name": "dorsal pathway", "x": 411, "y": 48},
            {"name": "lateral pathway", "x": 190, "y": 278},
            {"name": "ventral pathway", "x": 356, "y": 333},
        ],
    }


def layout_species(species: str, nodes: list[dict]) -> dict:
    """Return paper coordinates and decorations for FST display nodes."""
    prepared = [dict(node, native_x=float(node.get("native_x", node["x"])),
                     native_y=float(node.get("native_y", node["y"])))
                for node in nodes]
    if species == "macaque":
        return _macaque(prepared)
    if species == "human":
        return _human(prepared)
    raise ValueError("species must be 'macaque' or 'human'")
