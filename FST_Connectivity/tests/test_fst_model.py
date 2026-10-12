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
            (self.macaque, "macaque", 48),
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

    def test_human_pfop_keeps_absent_ruan_report_with_positive_studies(self):
        labels = {node["label"] for node in self.human["nodes"]}
        self.assertIn("PFop", labels)
        self.assertNotIn("Pfop", labels)
        reports = [event for event in self.human["events"]
                   if event["target"] == "PFop"]
        self.assertEqual(
            {(event["study"], event["direction"], event["grade"])
             for event in reports},
            {("Rol23", "out", "weak"), ("Rol23", "in", "weak"),
             ("Bak18", "out", "broad"), ("Bak18", "in", "broad"),
             ("Rua25", "out", "absent"), ("Rua25", "in", "absent")},
        )
        self.assertEqual(len(reports), 6)
        self.assertFalse(any(event["target"] == "Pfop"
                             for event in self.human["events"]))

    def test_human_mcc_uses_updated_evidence_and_existing_inset_point(self):
        labels = {node["label"] for node in self.human["nodes"]}
        self.assertIn("MCC", labels)
        self.assertNotIn("mPFC", labels)
        node = next(node for node in self.human["nodes"]
                    if node["label"] == "MCC")
        self.assertEqual((node["native_x"], node["native_y"], node["color"]),
                         (650.0, -900.0, "black"))
        reports = [event for event in self.human["events"]
                   if event["target"] == "MCC"]
        self.assertEqual(len(reports), 4)
        self.assertEqual({(event["study"], event["grade"])
                          for event in reports},
                         {("Rol23", "absent"), ("Bak18", "broad")})

    def test_macaque_study_groups_match_matlab_controls(self):
        groups = {row["code"]: row for row in self.macaque["studies"]}
        self.assertEqual(len(groups), 5)
        self.assertEqual(groups["Bou90+Bou92"]["codes"], ["Bou90", "Bou92"])
        self.assertEqual(groups["Bog19+Bog21"]["codes"], ["Bog19", "Bog21"])
        self.assertEqual(groups["mixed_tracer"]["codes"],
                         ["And90", "Bou90", "Bou92", "Sel96", "Fel97",
                          "Bar00", "Ung08", "Mark14"])
        self.assertEqual(groups["Mark14"]["codes"], ["Mark14"])
        self.assertNotIn("Bar00", groups)
        self.assertEqual(len(self.macaque["source_studies"]), 11)
        self.assertFalse(any(event["study"] == "Fel91"
                             for event in self.macaque["events"]))
        self.assertEqual([row["code"] for row in self.human["studies"]],
                         ["Bak18", "Rol23", "Rua25"])

    def test_combined_tracer_list_omits_repeated_method_prefix(self):
        combined = next(row for row in self.macaque["studies"]
                        if row["code"] == "mixed_tracer")
        self.assertEqual(combined["label"], "Combined tracer evidence")
        self.assertEqual(combined["codes"],
                         ["And90", "Bou90", "Bou92", "Sel96", "Fel97",
                          "Bar00", "Ung08", "Mark14"])
        self.assertEqual(combined["detail"], "\n".join([
            "Andersen et al. (1990)",
            "Boussaoud et al. (1990)",
            "Boussaoud et al. (1992)",
            "Seltzer et al. (1996)",
            "Felleman et al. (1997)",
            "Barone et al. (2000)",
            "Ungerleider et al. (2008)",
            "Markov et al. (2014)",
        ]))
        # Individual strength selections and the broad tracer selection may
        # overlap, but they represent the same eight source papers.
        selected = set(combined["codes"])
        selected.update(next(row for row in self.macaque["studies"]
                             if row["code"] == "Bou90+Bou92")["codes"])
        selected.update(next(row for row in self.macaque["studies"]
                             if row["code"] == "Mark14")["codes"])
        self.assertEqual(len(selected), 8)
        # Paper labels still carry their method outside this combined list.
        self.assertTrue(next(row for row in self.macaque["source_studies"]
                             if row["code"] == "Bar00")["label"].startswith("Tracer: "))

    def test_boussaoud_1990_uses_workbook_numeric_strength(self):
        scores = {(event["target"], event["direction"]): event["strengthGrade"]
                  for event in self.macaque["events"] if event["study"] == "Bou90"}
        for target, outbound, inbound in (
            ("V3d", "1", "1"), ("V4t", "1", "1.5"),
            ("MT", "3", "2.5"), ("VIP", "2.5", "1.5"),
            ("PITv", "1.5", "2"), ("PITd", "1.5", "2"),
            ("AITd", "1", "1.5"), ("FEF", "1.5", "1"),
        ):
            with self.subTest(area=target):
                self.assertEqual(scores[target, "out"], outbound)
                self.assertEqual(scores[target, "in"], inbound)
        for target in ("CITd", "CITv", "STPp", "7a"):
            self.assertFalse(any(score for (area, _), score in scores.items()
                                 if area == target), target)
        self.assertTrue(all(event["strengthGrade"] == ""
                            for event in self.macaque["events"]
                            if event["study"] == "Bou92"))

        with (DATA / "macaque" / "evidence.csv").open(
                newline="", encoding="utf-8-sig") as stream:
            rows = list(csv.DictReader(stream))
        mt = next(row for row in rows if row["Main"] == "FST"
                  and row["Affiliate"] == "MT"
                  and row["1_main_to_affiliate_ref"] == "Bou90")
        self.assertEqual(mt["1_main_to_affiliate_strength_score_1to3"], "3")
        self.assertEqual(mt["2_affiliate_to_main_strength_score_1to3"], "2.5")
        self.assertEqual(mt["1_main_to_affiliate_positive_cases"], "2/2")

    def test_boussaoud_1992_subcortical_directions(self):
        events = [event for event in self.macaque["events"]
                  if event["study"] == "Bou92"]
        positive = {"weak", "moderate", "strong", "present", "broad"}
        afferent = {event["target"] for event in events
                    if event["direction"] == "in" and event["grade"] in positive}
        efferent = {event["target"] for event in events
                    if event["direction"] == "out" and event["grade"] in positive}
        self.assertEqual(afferent, {"basalfore", "pulvinar", "claustrum"})
        self.assertEqual(efferent, {"TRN", "pulvinar", "claustrum",
                                    "striatum", "pretectum", "pons"})

    def test_updated_boussaoud_7a_rows_preserve_local_strength_fields(self):
        with (DATA / "macaque" / "evidence.csv").open(
                newline="", encoding="utf-8-sig") as stream:
            rows = list(csv.DictReader(stream))
        for seed, outbound, inbound in (
            ("FST", "absent", "weak"),
            ("MSTm", "weak", "moderate"),
            ("MSTd", "moderate", "strong"),
        ):
            matches = [row for row in rows if row["Main"] == seed
                       and row["Affiliate"] == "7a"
                       and row["1_main_to_affiliate_ref"] == "Bou90"]
            self.assertEqual(len(matches), 1, seed)
            self.assertEqual(matches[0]["1_main_to_affiliate_projection"],
                             outbound)
            self.assertEqual(matches[0]["2_affiliate_to_main_projection"],
                             inbound)
        self.assertFalse(any(row["Main"] == "FST" and
                             row["Affiliate"] == "AITv" and
                             row["study_type"] == "" for row in rows))
        self.assertIn("1_main_to_affiliate_strength_score_1to3", rows[0])

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

    def test_v3d_evidence_uses_one_dorsal_display_dot(self):
        labels = {node["label"] for node in self.macaque["nodes"]}
        self.assertIn("V3d", labels)
        self.assertNotIn("V3", labels)
        node = next(node for node in self.macaque["nodes"]
                    if node["label"] == "V3d")
        self.assertEqual(node["color"], "blue")
        ruan_targets = {event["target"] for event in self.macaque["events"]
                        if event["study"] == "Rua25"}
        self.assertIn("V3d", ruan_targets)
        self.assertNotIn("V3", ruan_targets)
        self.assertEqual({event["study"] for event in self.macaque["events"]
                          if event["target"] == "V3d" and event["grade"] != "absent"},
                         {"Rua25", "Bou90"})

    def test_invalid_species_has_a_clear_error(self):
        with self.assertRaisesRegex(ValueError, "macaque"):
            load_species("gorilla", DATA)


if __name__ == "__main__":
    unittest.main()
