"""Bundle the repository's canonical evidence CSVs in Python builds."""

from pathlib import Path

from setuptools import setup
from setuptools.command.build_py import build_py


ROOT = Path(__file__).resolve().parent


class BuildPyWithEvidence(build_py):
    def run(self):
        super().run()
        for species in ("human", "macaque"):
            source = ROOT / species / "evidence.csv"
            target = (
                Path(self.build_lib) / "fst_connectivity" / "data"
                / species / "evidence.csv"
            )
            target.parent.mkdir(parents=True, exist_ok=True)
            self.copy_file(str(source), str(target))


setup(cmdclass={"build_py": BuildPyWithEvidence})
