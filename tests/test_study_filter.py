"""Scientific source-selection checks for the macaque FST plot."""

import unittest
from pathlib import Path

import pandas as pd

from study_filter import POSITIVE, study_events


ROOT = Path(__file__).resolve().parents[1]


class StudySelectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        nodes = pd.read_csv(ROOT / "macaque" / "selectnodes.csv")
        evidence = pd.read_csv(ROOT / "macaque" / "evidence.csv")
        evidence = evidence[
            (evidence["Main"] == "FST")
            & evidence["study_type"].isin({"tracer", "DTI tractography", "inactivation"})
        ]
        cls.plot_labels = set(nodes["label"])
        cls.events, cls.studies = study_events(
            evidence,
            ROOT / "macaque" / "citations.txt",
            ROOT / "macaque" / "fel91_fst_connections.csv",
            cls.plot_labels,
        )

    @classmethod
    def connected(cls, codes):
        return {
            event["target"]
            for event in cls.events
            if event["study"] in codes and event["grade"] in POSITIVE
        }

    def test_fel91_uses_table_three_connections(self):
        self.assertEqual(
            self.connected({"Fel91"}),
            {"7a", "FEF", "LIP", "MSTd", "MT", "STPp", "TF",
             "V2", "V3", "V3A", "V4", "V4t", "VIP"},
        )
        # Fel91 occurs in CITd hierarchy metadata but Table 3 does not
        # report a direct FST-CITd pathway.
        self.assertNotIn("CITd", self.connected({"Fel91"}))

    def test_selected_studies_form_a_union(self):
        fel91 = self.connected({"Fel91"})
        mark14 = self.connected({"Mark14"})
        self.assertEqual(self.connected({"Fel91", "Mark14"}), fel91 | mark14)
        self.assertEqual(len(fel91 | mark14), 23)

    def test_absent_results_do_not_create_connections(self):
        self.assertEqual(len(self.connected({"Mark14"})), 16)
        self.assertFalse({"S1", "5", "M1"} & self.connected({"Mark14"}))

    def test_all_studies_cover_default_plot(self):
        all_codes = {study["code"] for study in self.studies}
        self.assertEqual(len(all_codes), 12)
        self.assertEqual(self.connected(all_codes), self.plot_labels - {"FST"})


if __name__ == "__main__":
    unittest.main()
