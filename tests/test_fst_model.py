"""Evidence-model checks against the canonical FST source data."""

from __future__ import annotations

import csv
import json
import os
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from fst_connectivity.model import load_species  # noqa: E402


DATA = Path(os.environ.get(
    "FST_CONNECTIVITY_DATA_PATH", ROOT
))


class ModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.macaque = load_species("macaque", DATA)
        cls.human = load_species("human", DATA)

    def test_payloads_are_json_ready_and_cover_current_fst_views(self):
        for payload, species, node_count in (
            (self.macaque, "macaque", 49),
            (self.human, "human", 56),
        ):
            self.assertEqual(payload["species"], species)
            self.assertEqual(len(payload["nodes"]), node_count)
            self.assertEqual(sum(node["label"] == "FST" for node in payload["nodes"]), 1)
            self.assertEqual(len(payload["nodes"]), len({node["label"] for node in payload["nodes"]}))
            self.assertTrue(all(node["x"] == node["native_x"]
                                and node["y"] == node["native_y"]
                                for node in payload["nodes"]))
            json.dumps(payload)

    def test_every_positive_fst_area_has_a_display_node(self):
        positive = {"weak", "moderate", "strong", "present", "broad"}
        for species, payload in (("macaque", self.macaque),
                                 ("human", self.human)):
            with self.subTest(species=species):
                with (DATA / species / "evidence.csv").open(
                        newline="", encoding="utf-8-sig") as stream:
                    rows = list(csv.DictReader(stream))
                targets = {
                    row["Affiliate"] for row in rows
                    if row["Main"] == "FST"
                    and (row["1_main_to_affiliate_projection"].lower() in positive
                         or row["2_affiliate_to_main_projection"].lower() in positive)
                }
                if species == "human":
                    targets.difference_update({"LO1", "LO2", "LO3"})
                    targets.add("LO1-3")
                labels = {node["label"] for node in payload["nodes"]}
                self.assertFalse(targets - labels)
                self.assertEqual(len({node["id"] for node in payload["nodes"]}),
                                 len(payload["nodes"]))

    def test_human_lo_areas_share_one_display_dot_and_reports(self):
        labels = {node["label"] for node in self.human["nodes"]}
        self.assertIn("LO1-3", labels)
        self.assertFalse({"LO1", "LO2", "LO3"} & labels)
        reports = [event for event in self.human["events"]
                   if event["target"] == "LO1-3"]
        self.assertEqual(len(reports), 18)
        self.assertEqual({event["study"] for event in reports}, {"Bak18", "Rol23"})
        self.assertFalse(any(event["study"] == "Rua25" for event in reports))

    def test_macaque_study_groups_match_matlab_controls(self):
        groups = {row["code"]: row for row in self.macaque["studies"]}
        self.assertEqual(len(groups), 6)
        self.assertEqual(groups["Bou90+Bou92"]["codes"], ["Bou90", "Bou92"])
        self.assertEqual(groups["Bog19+Bog21"]["codes"], ["Bog19", "Bog21"])
        self.assertEqual(groups["mixed_tracer"]["codes"],
                         ["And90", "Sel96", "Fel97", "Bar00", "Ung08"])
        self.assertNotIn("Bar00", groups)
        self.assertEqual(len(self.macaque["source_studies"]), 12)
        self.assertEqual([row["code"] for row in self.human["studies"]],
                         ["Bak18", "Rol23", "Rua25"])

    def test_ungerleider_and_barone_corrections_are_ungraded(self):
        events = self.macaque["events"]
        barone = [event for event in events if event["study"] == "Bar00"]
        self.assertEqual({(event["target"], event["direction"])
                          for event in barone}, {("V1", "out"), ("V4", "out")})
        self.assertTrue(all(event["grade"] == "present"
                            and event["strengthGrade"] == "" for event in barone))
        ungerleider = [event for event in events if event["study"] == "Ung08"]
        self.assertEqual({(event["target"], event["direction"])
                          for event in ungerleider}, {("V4", "out"), ("V4", "in")})
        self.assertTrue(all(event["strengthGrade"] == "" for event in ungerleider))

    def test_fel91_uses_direct_table_three_paths(self):
        fel91 = [event for event in self.macaque["events"]
                 if event["study"] == "Fel91"]
        self.assertEqual({event["target"] for event in fel91},
                         {"7a", "FEF", "LIP", "MSTd", "MT", "STPp", "TF",
                          "V2", "V3", "V3A", "V4", "V4t", "VIP"})
        self.assertTrue(all(event["grade"] == "present"
                            and event["strengthGrade"] == "" for event in fel91))

    def test_ruan_v3d_and_felleman_v3_remain_distinct(self):
        labels = {node["label"] for node in self.macaque["nodes"]}
        self.assertTrue({"V3", "V3d"}.issubset(labels))
        ruan_targets = {event["target"] for event in self.macaque["events"]
                        if event["study"] == "Rua25"}
        self.assertIn("V3d", ruan_targets)
        self.assertNotIn("V3", ruan_targets)
        fel91_targets = {event["target"] for event in self.macaque["events"]
                         if event["study"] == "Fel91"}
        self.assertIn("V3", fel91_targets)

    def test_invalid_species_has_a_clear_error(self):
        with self.assertRaisesRegex(ValueError, "macaque"):
            load_species("gorilla", DATA)


if __name__ == "__main__":
    unittest.main()
