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

    medial_names = ["V6", "PCCa", "PCCp", "RSC", "24c", "7m", "preSMA",
                    "BA23", "BA31"]
    has_extra_medial = any(name in by_label for name in ("24c", "7m", "preSMA"))
    if has_extra_medial:
        medial_rect = [36, 220, 93, 85]
        medial_points = [(51, 253), (96, 275), (51, 297), (96, 297),
                         (81, 253), (113, 253), (51, 275),
                         (96, 275), (51, 297)]
    else:
        medial_rect = [5, 5, 134, 66]
        medial_points = [(49, 34), (127, 34), (54, 55), (120, 55),
                         (49, 34), (127, 34), (54, 55),
                         (127, 34), (54, 55)]

    subcortical_names = ["basalfore", "SC", "claustrum", "pons",
                         "striatum", "pretectum", "thalamus", "pulvinar", "TRN"]
    subcortical_points = [(394, 249), (459, 249), (394, 270), (459, 270),
                          (394, 290), (459, 290), (394, 310),
                          (394, 306.7), (459, 306.7)]
    for name, point in zip(subcortical_names, subcortical_points):
        _put(by_label, name, point)

    reference = json.loads(
        (DATA_DIR / "macaque_reference_points.json").read_text(encoding="utf-8")
    )
    for name, point in reference.items():
        _put(by_label, name, tuple(point))
    for name, point in zip(medial_names, medial_points):
        _put(by_label, name, point)

    # The paper dots are overridden exactly as in paperConnectivityLayout.m.
    _put(by_label, "V4t", (345, 163))
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
            {"name": "lateral pathway", "x": 95, "y": 200},
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

    # The paper's dot centers are registered to the lateral TIFF outline.
    # Keep the inward native coordinates above as a fallback for future areas.
    paper_left, paper_top, paper_right, paper_bottom = 33, 62, 865, 648
    lateral_left, lateral_top, lateral_right, lateral_bottom = 43.6, 28, 466.2, 326.4
    paper_scale_x = (lateral_right - lateral_left) / (paper_right - paper_left)
    paper_scale_y = (lateral_bottom - lateral_top) / (paper_bottom - paper_top)

    def paper_point(x: float, y: float) -> tuple[float, float]:
        return (lateral_left + (x - paper_left) * paper_scale_x,
                lateral_top + (y - paper_top) * paper_scale_y)

    # Match referenceNames/referencePixels in paperHumanConnectivityLayout.m.
    reference_pixels = (
        ("PMd", 354, 130), ("SMA", 354, 92), ("FEF", 344, 184),
        ("M1", 405, 165), ("55b", 355, 232), ("3a/3b", 469, 179),
        ("BA1/2", 529, 145), ("AIP", 592, 162), ("VIP", 654, 117),
        ("LIP", 675, 162), ("MIP", 711, 151), ("IPS0/1", 740, 193),
        ("PFm", 666, 260), ("V7", 812, 285), ("V3A/B", 835, 347),
        ("BA8", 249, 299), ("PMv", 325, 327), ("op", 382, 356),
        ("PFop", 441, 342), ("BA44", 255, 376), ("aud", 470, 418),
        ("insula", 265, 503), ("TPOJ1", 587, 363), ("TPOJ2", 648, 389),
        ("TPOJ3", 692, 352), ("STSp", 522, 452), ("STSa", 402, 521),
        ("TE1a", 449, 577), ("TE1m", 515, 551), ("TE1p", 579, 522),
        ("TE2a", 461, 615), ("TE2p", 592, 576), ("TG", 339, 628),
        ("PHT", 619, 439), ("MST", 675, 439), ("MT", 724, 425),
        ("LO1-3", 772, 432), ("PH", 647, 512), ("PIT", 705, 521),
        ("FFC", 672, 554), ("V4t", 767, 477), ("V4", 813, 460),
        ("V3", 845, 444), ("V1", 882, 435), ("V2", 876, 475),
        ("V8", 768, 553), ("VMV", 731, 591), ("VVC", 637, 606),
        ("FST", 707, 477),
    )
    for name, paper_x, paper_y in reference_pixels:
        _put(by_label, name, paper_point(paper_x, paper_y))

    medial_rect = [33, 229, 95, 72]
    medial_pixels = (
        ("mPFC", 91, 499), ("BA23", 180, 499),
        ("V6", 65, 527), ("preSMA", 174, 527),
        ("RSC", 83, 553), ("BA7", 175, 553),
        ("precuneus", 154, 580),
    )
    for name, paper_x, paper_y in medial_pixels:
        _put(by_label, name, paper_point(paper_x, paper_y))
    _put(by_label, "BA31", (medial_rect[0] + medial_rect[2] / 2, 275))
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
