"""Checks for the paper coordinates shared with the MATLAB views."""

from __future__ import annotations

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

    def test_human_combined_lo_and_centered_canvas(self):
        raw = load_species("human", DATA)
        view = layout_species("human", raw["nodes"])
        nodes = {node["label"]: node for node in view["nodes"]}
        self.assertEqual(view["plot_size"], [1080, 728])
        self.assertEqual(view["plot_offset"], [128, 46])
        self.assertEqual((nodes["LO1-3"]["x"], nodes["LO1-3"]["y"]), (412, 222))
        self.assertEqual((nodes["PIT"]["x"], nodes["PIT"]["y"]), (388, 245.4))
        self.assertEqual(nodes["LO1-3"]["fill"], "#F9F384")
        self.assertEqual(len(view["boxes"]), 1)

    def test_layout_does_not_change_input_nodes(self):
        raw = load_species("human", DATA)
        original = [dict(node) for node in raw["nodes"]]
        view = layout_species("human", raw["nodes"])
        self.assertEqual(raw["nodes"], original)
        self.assertEqual(layout_species("human", view["nodes"])["nodes"], view["nodes"])


if __name__ == "__main__":
    unittest.main()
