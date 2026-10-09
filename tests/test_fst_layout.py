"""Checks for the paper coordinates shared with the MATLAB views."""

from __future__ import annotations

import re
import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from fst_connectivity.layout import layout_species  # noqa: E402
from fst_connectivity.model import load_species  # noqa: E402


DATA = ROOT


class LayoutTests(unittest.TestCase):
    def test_macaque_registered_reference_points(self):
        raw = load_species("macaque", DATA)
        view = layout_species("macaque", raw["nodes"])
        nodes = {node["label"]: node for node in view["nodes"]}
        self.assertEqual(view["plot_size"], [1335, 820])
        self.assertEqual(view["plot_offset"], [0, 0])
        self.assertEqual((nodes["FST"]["x"], nodes["FST"]["y"]), (313, 153))
        self.assertEqual((nodes["V4t"]["x"], nodes["V4t"]["y"]), (345, 163))
        self.assertEqual(nodes["V4t"]["fill"], "#F9F384")
        self.assertEqual(nodes["basalfore"]["display_label"], "basal forebrain")
        self.assertEqual(nodes["PITd"]["fill"], "#F9F384")
        for name in ("CITd", "AITd", "V4t"):
            self.assertEqual(nodes[name]["fill"], "#F9F384")
        for name in ("MT", "MSTm"):
            self.assertEqual(nodes[name]["fill"], "#B3E4F8")
        self.assertEqual(nodes["S1"]["fill"], "#000000")
        self.assertEqual((nodes["A1"]["x"], nodes["A1"]["y"]), (254, 131))
        self.assertEqual((nodes["BA23"]["x"], nodes["BA23"]["y"]),
                         (68, 34))
        self.assertEqual((nodes["BA31"]["x"], nodes["BA31"]["y"]),
                         (28, 54))
        self.assertEqual((nodes["pulvinar"]["x"], nodes["pulvinar"]["y"]),
                         (406, 302))
        self.assertEqual((nodes["TRN"]["x"], nodes["TRN"]["y"]), (449, 302))
        self.assertEqual(nodes["V3d"]["fill"], "#B3E4F8")
        self.assertEqual(nodes["A1"]["fill"], "#000000")
        self.assertFalse({"VOT/TEO", "SEF", "STGp", "PCCa", "PCCp", "thalamus"}
                         & nodes.keys())
        self.assertEqual(len(view["boxes"]), 2)
        self.assertEqual(view["boxes"][0]["rect"], [12, 6, 72, 56])
        self.assertEqual(view["boxes"][1]["rect"], [382, 229, 90, 79])
        for label, point in {
            "S1": (223.3, 40.5), "AIP": (245.6, 67.7),
            "VIP": (286.7, 63.6), "V3A": (388, 80),
            "V3d": (390.5, 107.5), "insula": (180, 164),
        }.items():
            self.assertEqual((nodes[label]["x"], nodes[label]["y"]), point)

        # Both interactive implementations must use the same lateral points.
        matlab = (ROOT / "paperConnectivityLayout.m").read_text(encoding="utf-8")
        names = re.findall(r'"([^"]+)"', re.search(
            r'referenceLabels = \[(.*?)\];', matlab, re.S).group(1))
        values = [float(value) for value in re.findall(
            r'\d+(?:\.\d+)?', re.search(
                r'referenceXY = \[(.*?)\];', matlab, re.S).group(1))]
        reference = json.loads((ROOT / "src" / "fst_connectivity" / "data"
                                / "macaque_reference_points.json").read_text(
                                    encoding="utf-8"))
        self.assertEqual(len(values), 2 * len(names))
        for name, x, y in zip(names, values[::2], values[1::2]):
            if name in reference:
                self.assertEqual(reference[name], [x, y], name)

    def test_human_matches_matlab_paper_coordinates(self):
        raw = load_species("human", DATA)
        view = layout_species("human", raw["nodes"])
        nodes = {node["label"]: node for node in view["nodes"]}
        self.assertEqual(view["plot_size"], [1080, 728])
        self.assertEqual(view["plot_offset"], [128, 46])
        self.assertEqual(nodes["LO1-3"]["fill"], "#F9F384")
        self.assertEqual(nodes["V4t"]["fill"], "#F9F384")
        self.assertEqual(nodes["PIT"]["fill"], "#F9F384")
        for name in ("MT", "MST"):
            self.assertEqual(nodes[name]["fill"], "#B3E4F8")
        for name in ("BA1/2", "3a/3b"):
            self.assertEqual(nodes[name]["fill"], "#000000")
        self.assertEqual(nodes["SMA"]["fill"], "#000000")
        self.assertNotIn("SEF", nodes)
        self.assertEqual(view["boxes"], [
            {"name": "medial cortex", "rect": [40, 228, 80, 72]}])

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
        anchors = dict(zip(names, zip(pixels[::2], pixels[1::2])))
        self.assertEqual(anchors["PMd"], (354, 130))
        self.assertEqual(anchors["SMA"], (354, 92))
        self.assertEqual(anchors["FEF"], (344, 184))
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
        medial_points = list(map(int, re.findall(r'\d+', matlab_array("medialPoints"))))
        self.assertEqual((len(medial_names), len(medial_points)), (7, 14))
        medial_anchors = dict(zip(medial_names,
                                  zip(medial_points[::2], medial_points[1::2])))
        self.assertEqual(medial_anchors["MCC"], (56, 256))
        self.assertEqual(medial_anchors["BA7"], (79, 275))
        self.assertEqual(medial_anchors["precuneus"], (102, 294))
        medial_rect = list(map(float, re.findall(r'\d+(?:\.\d+)?', matlab_array("medialRect"))))
        self.assertEqual(view["boxes"], [{"name": "medial cortex", "rect": medial_rect}])
        for name, x, y in zip(medial_names, medial_points[::2], medial_points[1::2]):
            with self.subTest(area=name):
                self.assertAlmostEqual(nodes[name]["x"], x, places=9)
                self.assertAlmostEqual(nodes[name]["y"], y, places=9)

    def test_layout_does_not_change_input_nodes(self):
        raw = load_species("human", DATA)
        original = [dict(node) for node in raw["nodes"]]
        view = layout_species("human", raw["nodes"])
        self.assertEqual(raw["nodes"], original)
        self.assertEqual(layout_species("human", view["nodes"])["nodes"], view["nodes"])

    def test_optional_inset_nodes_have_distinct_slots(self):
        macaque = load_species("macaque", DATA)["nodes"]
        extras = ("PCCa", "PCCp", "24c", "7m", "preSMA", "thalamus")
        macaque += [
            {"id": 100 + i, "label": label, "x": 0, "y": 0,
             "color": "black"}
            for i, label in enumerate(extras)
        ]
        nodes = {node["label"]: node for node in
                 layout_species("macaque", macaque)["nodes"]}
        medial = ("V6", "PCCa", "PCCp", "RSC", "24c", "7m",
                  "preSMA", "BA23", "BA31")
        self.assertEqual(len({(nodes[name]["x"], nodes[name]["y"])
                              for name in medial}), len(medial))
        self.assertNotEqual((nodes["thalamus"]["x"], nodes["thalamus"]["y"]),
                            (nodes["pulvinar"]["x"], nodes["pulvinar"]["y"]))

        human = load_species("human", DATA)["nodes"]
        human.append({"id": 100, "label": "BA31", "x": 0, "y": 0,
                      "color": "black"})
        nodes = {node["label"]: node for node in
                 layout_species("human", human)["nodes"]}
        self.assertEqual((nodes["BA31"]["x"], nodes["BA31"]["y"]),
                         (79, 294))
        self.assertNotEqual((nodes["BA31"]["x"], nodes["BA31"]["y"]),
                            (nodes["BA7"]["x"], nodes["BA7"]["y"]))


if __name__ == "__main__":
    unittest.main()
