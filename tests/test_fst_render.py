"""Offline export and command-line smoke checks."""

from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from fst_connectivity.view import build_payload, render_html  # noqa: E402


class RenderTests(unittest.TestCase):
    def test_self_contained_html_contains_both_current_views(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as directory:
            path = render_html(Path(directory) / "explorer.html", initial_species="human")
            document = path.read_text(encoding="utf-8")
            self.assertIn("FST connectivity explorer", document)
            self.assertNotIn("__CONNECTIVITY_PAYLOAD__", document)
            self.assertNotIn("src=\"https://", document)
            encoded = re.search(
                r'<script id="connectivity-data" type="application/json">(.*?)</script>',
                document, re.S,
            ).group(1)
            payload = json.loads(encoded)
            self.assertEqual(payload["initial_species"], "human")
            self.assertEqual(len(payload["macaque"]["nodes"]), 49)
            self.assertEqual(len(payload["human"]["nodes"]), 56)
            for species in ("macaque", "human"):
                image = payload[species]["image"]
                self.assertTrue(image.startswith("data:image/png;base64,"))
                self.assertEqual(base64.b64decode(image.split(",", 1)[1])[:8],
                                 b"\x89PNG\r\n\x1a\n")

    def test_command_runs_outside_repository(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as directory:
            output = Path(directory) / "from-command.html"
            environment = os.environ.copy()
            environment["PYTHONPATH"] = str(ROOT / "src")
            command = [sys.executable, "-m", "fst_connectivity", "--no-open",
                       "--output", str(output)]
            result = subprocess.run(command, cwd=directory, env=environment,
                                    capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(output.is_file())
            self.assertEqual(Path(result.stdout.strip()), output)

    def test_invalid_species_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "initial_species"):
            build_payload(initial_species="chimpanzee")


if __name__ == "__main__":
    unittest.main()
