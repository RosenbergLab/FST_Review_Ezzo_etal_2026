"""Checks for the paper coordinates shared with the MATLAB views."""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from fst_connectivity.layout import layout_species  # noqa: E402
from fst_connectivity.model import load_species  # noqa: E402


DATA = ROOT / "src" / "fst_connectivity" / "data"


class LayoutTests(unittest.TestCase):
    def test_macaque_reference_and_native_overrides(self):
        raw = load_species("macaque", DATA)
        view = layout_species("macaque", raw["nodes"])
        nodes = {node["label"]: node for node in view["nodes"]}
        self.assertEqual(view["plot_size"], [1335, 820])
        self.assertEqual(view["plot_offset"], [0, 0])
        self.assertEqual((nodes["FST"]["x"], nodes["FST"]["y"]), (313, 153))
        self.assertEqual((nodes["V4t"]["x"], nodes["V4t"]["y"]), (345, 157))
        self.assertEqual(nodes["basalfore"]["display_label"], "basal forebrain")
        self.assertEqual(nodes["PITd"]["fill"], "#F9F384")
        self.assertEqual(len(view["boxes"]), 2)
        for label in ("VIP", "S1"):
            node = nodes[label]
            self.assertNotEqual((node["x"], node["y"]),
                                {"VIP": (223.3, 40.5), "S1": (245.6, 67.7)}[label])

    def test_human_matches_matlab_paper_coordinates(self):
        raw = load_species("human", DATA)
        view = layout_species("human", raw["nodes"])
        nodes = {node["label"]: node for node in view["nodes"]}
        self.assertEqual(view["plot_size"], [1080, 728])
        self.assertEqual(view["plot_offset"], [128, 46])
        self.assertEqual(nodes["LO1-3"]["fill"], "#F9F384")

        # Compare with the MATLAB source, so a future MATLAB move cannot leave
        # the downloadable browser view silently using the older positions.
        matlab = (ROOT / "paperHumanConnectivityLayout.m").read_text(encoding="utf-8")
        def matlab_array(name):
            match = re.search(rf'{name} = \[(.*?)\];', matlab, re.S)
            self.assertIsNotNone(match, name)
            return match.group(1)

        names = re.findall(
            r'"([^"]+)"', matlab_array("referenceNames")
        )
        pixels = list(map(int, re.findall(r'\d+', matlab_array("referencePixels"))))
        self.assertEqual((len(names), len(pixels)), (49, 98))
        paper_bounds = list(map(float, re.findall(r'\d+(?:\.\d+)?', matlab_array("paperBounds"))))
        lateral_bounds = list(map(float, re.findall(r'\d+(?:\.\d+)?', matlab_array("lateralBounds"))))
        px0, py0, px1, py1 = paper_bounds
        x0, y0, x1, y1 = lateral_bounds

        def plot_point(px, py):
            return (x0 + (px - px0) * (x1 - x0) / (px1 - px0),
                    y0 + (py - py0) * (y1 - y0) / (py1 - py0))

        for name, px, py in zip(names, pixels[::2], pixels[1::2]):
            with self.subTest(area=name):
                x, y = plot_point(px, py)
                self.assertAlmostEqual(nodes[name]["x"], x, places=9)
                self.assertAlmostEqual(nodes[name]["y"], y, places=9)

        medial_names = re.findall(r'"([^"]+)"', matlab_array("medialNames"))
        medial_pixels = list(map(int, re.findall(r'\d+', matlab_array("medialPixels"))))
        self.assertEqual((len(medial_names), len(medial_pixels)), (7, 14))
        medial_rect = list(map(float, re.findall(r'\d+(?:\.\d+)?', matlab_array("medialRect"))))
        self.assertEqual(view["boxes"], [{"name": "medial cortex", "rect": medial_rect}])
        for name, px, py in zip(medial_names, medial_pixels[::2], medial_pixels[1::2]):
            with self.subTest(area=name):
                x, y = plot_point(px, py)
                self.assertAlmostEqual(nodes[name]["x"], x, places=9)
                self.assertAlmostEqual(nodes[name]["y"], y, places=9)

    def test_layout_does_not_change_input_nodes(self):
        raw = load_species("human", DATA)
        original = [dict(node) for node in raw["nodes"]]
        view = layout_species("human", raw["nodes"])
        self.assertEqual(raw["nodes"], original)
        self.assertEqual(layout_species("human", view["nodes"])["nodes"], view["nodes"])


if __name__ == "__main__":
    unittest.main()
