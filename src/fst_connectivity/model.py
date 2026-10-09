"""Load the FST connectivity evidence used by the MATLAB explorer.

This module deliberately reads the source CSVs without writing derived tables.
The display-only LO merge and two macaque paper corrections mirror
``plotConnectivity.m``; the underlying review data remains untouched.
"""

from __future__ import annotations

import csv
import re
from pathlib import Path


POSITIVE_GRADES = frozenset({"weak", "moderate", "strong", "present", "broad"})
GRADED_STRENGTHS = frozenset({"weak", "moderate", "strong"})
REPORTED_GRADES = POSITIVE_GRADES | {"absent"}
STRENGTH_METHODS = frozenset({"tracer", "DTI tractography"})
REFERENCE_PATTERN = re.compile(r"(?<![A-Za-z0-9_])[A-Z][a-z]{2,3}\d{2}(?![A-Za-z0-9_])")
YEAR_PATTERN = re.compile(r"\((\d{4})\)")

OUT_GRADE = "1_main_to_affiliate_projection"
IN_GRADE = "2_affiliate_to_main_projection"
OUT_STRENGTH = "1_main_to_affiliate_projection_strength"
IN_STRENGTH = "2_affiliate_to_main_projection_strength"
OUT_REF = "1_main_to_affiliate_ref"
IN_REF = "2_affiliate_to_main_ref"


def _macaque_display_area(area: str) -> str:
    """Combine the older V3 pathway with V3d in the macaque FST view."""
    return "V3d" if area == "V3" else area


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as stream:
        return [dict(row) for row in csv.DictReader(stream)]


def _value(row: dict[str, str], column: str) -> str:
    return (row.get(column) or "").strip()


def _read_citations(path: Path) -> list[dict[str, str | int]]:
    citations: list[dict[str, str | int]] = []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if ": " not in line:
            continue
        code, citation = line.split(": ", 1)
        year_match = YEAR_PATTERN.search(citation)
        if year_match is None:
            continue
        author = (
            "Felleman & Van Essen"
            if code == "Fel91"
            else citation.split(",", 1)[0] + " et al."
        )
        citations.append(
            {
                "code": code,
                "label": f"{author} ({year_match.group(1)})",
                "year": int(year_match.group(1)),
            }
        )
    return citations


def _reference_codes(reference: str, known: set[str]) -> list[str]:
    return [code for code in REFERENCE_PATTERN.findall(reference) if code in known]


def _merge_human_lo(
    nodes: list[dict[str, str]], evidence: list[dict[str, str]]
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    """Represent LO1/LO2/LO3 by LO2's one display dot for human FST."""
    labels = {_value(node, "label") for node in nodes}
    if not {"LO1", "LO2", "LO3"}.issubset(labels):
        return nodes, evidence

    display_nodes = []
    for node in nodes:
        label = _value(node, "label")
        if label in {"LO1", "LO3"}:
            continue
        if label == "LO2":
            node["label"] = "LO1-3"
        display_nodes.append(node)

    # Retain each area's report row, as MATLAB's current StudyEvents output
    # does. The UI counts distinct papers, so these rows do not inflate the
    # displayed number of supporting studies.
    display_evidence = []
    for row in evidence:
        if _value(row, "Main") == "FST" and _value(row, "Affiliate") in {
                "LO1", "LO2", "LO3"}:
            row["Affiliate"] = "LO1-3"
        display_evidence.append(row)
    return display_nodes, display_evidence


def _correct_macaque_legacy_evidence(evidence: list[dict[str, str]]) -> None:
    """Apply the two idempotent FST corrections in ``plotConnectivity.m``."""
    for row in evidence:
        if _value(row, "Main") != "FST":
            continue
        affiliate = _value(row, "Affiliate")
        out_ref = _value(row, OUT_REF)
        in_ref = _value(row, IN_REF)
        if affiliate == "V4" and out_ref == in_ref == "Ung08":
            row[OUT_STRENGTH] = ""
            row[IN_STRENGTH] = ""
        if affiliate in {"V1", "V4"} and "Bar00" in {out_ref, in_ref}:
            row[OUT_GRADE] = "present"
            row[OUT_STRENGTH] = ""
            row[OUT_REF] = "Bar00"
            row[IN_GRADE] = ""
            row[IN_STRENGTH] = ""
            row[IN_REF] = ""


def _event_strength(grade: str, strength_text: str) -> str:
    if grade in GRADED_STRENGTHS:
        return grade
    if grade in {"present", "broad"} and strength_text in GRADED_STRENGTHS:
        return strength_text
    return ""


def _study_events(
    evidence: list[dict[str, str]],
    available_labels: set[str],
    citations: list[dict[str, str | int]],
    fel91_path: Path | None,
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    known = {str(citation["code"]) for citation in citations}
    events: list[dict[str, str]] = []
    for row in evidence:
        target = _value(row, "Affiliate")
        if target not in available_labels:
            continue
        method = _value(row, "study_type")
        if method == "inactivation":
            method = "functional inactivation"
        for direction, grade_col, strength_col, ref_col, other_ref_col in (
            ("out", OUT_GRADE, OUT_STRENGTH, OUT_REF, IN_REF),
            ("in", IN_GRADE, IN_STRENGTH, IN_REF, OUT_REF),
        ):
            grade = _value(row, grade_col).lower()
            if grade not in REPORTED_GRADES:
                continue
            strength_grade = _event_strength(
                grade, _value(row, strength_col).lower()
            )
            codes = _reference_codes(_value(row, ref_col), known)
            if not codes:
                codes = _reference_codes(_value(row, other_ref_col), known)
            for code in codes:
                events.append(
                    {
                        "study": code,
                        "target": target,
                        "direction": direction,
                        "grade": grade,
                        "type": method,
                        "strengthGrade": strength_grade,
                    }
                )

    if fel91_path is not None:
        for row in _read_csv(fel91_path):
            source = _macaque_display_area(_value(row, "from_area"))
            destination = _macaque_display_area(_value(row, "to_area"))
            if source == "FST" and destination in available_labels:
                target, direction = destination, "out"
            elif destination == "FST" and source in available_labels:
                target, direction = source, "in"
            else:
                continue
            events.append(
                {
                    "study": "Fel91",
                    "target": target,
                    "direction": direction,
                    "grade": "present",
                    "type": "literature synthesis",
                    "strengthGrade": "",
                }
            )

    unknown = {event["study"] for event in events} - known
    if unknown:
        raise ValueError(f"Event citations are missing: {', '.join(sorted(unknown))}")

    used_codes = {event["study"] for event in events}
    source_studies: list[dict[str, str]] = []
    for citation in sorted(
        (citation for citation in citations if citation["code"] in used_codes),
        key=lambda item: (int(item["year"]), str(item["code"])),
    ):
        code = str(citation["code"])
        methods = list(dict.fromkeys(
            event["type"] for event in events if event["study"] == code
        ))
        methods = [
            {"tracer": "Tracer", "inactivation": "Functional inactivation",
             "functional inactivation": "Functional inactivation",
             "literature synthesis": "Literature synthesis"}.get(method, method)
            for method in methods
        ]
        source_studies.append(
            {"code": code, "label": f"{' + '.join(methods)}: {citation['label']}"}
        )
    return events, source_studies


def _group_studies(
    source_studies: list[dict[str, str]], events: list[dict[str, str]]
) -> list[dict[str, str | list[str]]]:
    grouped: list[dict[str, str | list[str]]] = [
        {"code": study["code"], "label": study["label"],
         "detail": study["label"], "codes": [study["code"]]}
        for study in source_studies
    ]
    graded_codes = {
        event["study"] for event in events
        if event["strengthGrade"] in GRADED_STRENGTHS
        and event["type"] in STRENGTH_METHODS
    }

    def _combine(first: str, second: str, combined: dict) -> None:
        first_index = next((i for i, row in enumerate(grouped) if row["code"] == first), None)
        second_index = next((i for i, row in enumerate(grouped) if row["code"] == second), None)
        if first_index is None or second_index is None:
            return
        grouped[first_index] = combined
        del grouped[second_index]

    _combine(
        "Bou90", "Bou92",
        {
            "code": "Bou90+Bou92",
            "label": "Tracer: Boussaoud et al. (1990, 1992)",
            "detail": "Tracer: Boussaoud et al. (1990) — graded\n"
                      "Tracer: Boussaoud et al. (1992) — no graded strength",
            "codes": ["Bou90", "Bou92"],
        },
    )
    _combine(
        "Bog19", "Bog21",
        {
            "code": "Bog19+Bog21",
            "label": "Functional inactivation: Bogadhi et al. (2019, 2021)",
            "detail": "Functional inactivation: Bogadhi et al. (2019)\n"
                      "Functional inactivation: Bogadhi et al. (2021)",
            "codes": ["Bog19", "Bog21"],
        },
    )

    ungraded_indices: list[int] = []
    for index, row in enumerate(grouped):
        codes = set(row["codes"])
        source_types = {event["type"] for event in events if event["study"] in codes}
        if source_types == {"tracer"} and not (codes & graded_codes):
            ungraded_indices.append(index)
    if ungraded_indices:
        combined_codes = [
            code for index in ungraded_indices for code in grouped[index]["codes"]
        ]
        combined_detail = "\n".join(str(grouped[index]["label"])
                                    for index in ungraded_indices)
        grouped = [row for index, row in enumerate(grouped)
                   if index not in ungraded_indices]
        grouped.append(
            {"code": "mixed_tracer", "label": "Mixed tracer evidence",
             "detail": combined_detail, "codes": combined_codes}
        )
    return grouped


def load_species(species: str, data_dir: Path) -> dict:
    """Return JSON-ready FST nodes, reports and study choices for one species.

    ``data_dir`` is a folder containing ``human/`` and ``macaque/``. Its
    source CSVs are read only. Display coordinates are applied by the layout
    module. Each node carries ``native_x``/``native_y`` and initially identical
    ``x``/``y`` values; the layout module replaces only ``x``/``y``.
    """
    species = species.lower().strip()
    if species not in {"human", "macaque"}:
        raise ValueError("species must be 'human' or 'macaque'")
    species_dir = Path(data_dir) / species
    raw_nodes = _read_csv(species_dir / "nodes.csv")
    raw_evidence = _read_csv(species_dir / "evidence.csv")
    if species == "human":
        raw_nodes, raw_evidence = _merge_human_lo(raw_nodes, raw_evidence)
    else:
        _correct_macaque_legacy_evidence(raw_evidence)
        for row in raw_evidence:
            if _value(row, "Main") == "FST":
                row["Affiliate"] = _macaque_display_area(
                    _value(row, "Affiliate"))

    allowed_types = ({"tracer", "DTI tractography", "inactivation"}
                     if species == "macaque" else {"DTI tractography", "rs-fMRI"})
    evidence = [
        row for row in raw_evidence
        if _value(row, "Main") == "FST"
        and _value(row, "study_type") in allowed_types
    ]
    all_labels = {_value(node, "label") for node in raw_nodes}
    if "FST" not in all_labels:
        raise ValueError(f"FST is missing from {species_dir / 'nodes.csv'}")
    edge_targets = {
        _value(row, "Affiliate") for row in evidence
        if _value(row, "Affiliate") in all_labels
        and (_value(row, OUT_GRADE).lower() not in {"", "absent"}
             or _value(row, IN_GRADE).lower() not in {"", "absent"})
    }
    fel91_path = (species_dir / "fel91_fst_connections.csv"
                  if species == "macaque" else None)
    if fel91_path is not None:
        # Fel91's V3 pathway shares the V3d display dot with newer reports.
        for row in _read_csv(fel91_path):
            source = _macaque_display_area(_value(row, "from_area"))
            destination = _macaque_display_area(_value(row, "to_area"))
            if source == "FST" and destination in all_labels:
                edge_targets.add(destination)
            elif destination == "FST" and source in all_labels:
                edge_targets.add(source)
    nodes = [
        {
            "id": int(_value(node, "id")),
            "label": _value(node, "label"),
            "native_x": float(_value(node, "x")),
            "native_y": float(_value(node, "y")),
            "x": float(_value(node, "x")),
            "y": float(_value(node, "y")),
            "color": _value(node, "color").lower(),
        }
        for node in raw_nodes
        if _value(node, "label") in edge_targets | {"FST"}
    ]
    available_labels = {node["label"] for node in nodes}
    citations = _read_citations(species_dir / "citations.txt")
    events, source_studies = _study_events(
        evidence, available_labels, citations, fel91_path
    )
    studies = _group_studies(source_studies, events)
    return {
        "species": species,
        "nodes": nodes,
        "events": events,
        "studies": studies,
        "source_studies": source_studies,
    }
