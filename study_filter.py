"""Build a self-contained study filter for the macaque FST Plotly figure."""

from __future__ import annotations

import csv
import html
import json
import re
from collections import defaultdict
from pathlib import Path

import plotly.io as pio

POSITIVE = {"weak", "moderate", "strong", "present", "broad"}
GRADED = {"weak": 1, "moderate": 2, "strong": 3}
CODES = re.compile(r"\b[A-Z][a-z]{2,3}\d{2}\b")


def _references(value: object, known: set[str]) -> list[str]:
    return [code for code in CODES.findall(str(value)) if code in known]


def _citation_labels(path: Path) -> dict[str, str]:
    labels = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if ": " not in line:
            continue
        code, citation = line.split(": ", 1)
        year = re.search(r"\((\d{4})\)", citation)
        if not year:
            continue
        if code == "Fel91":
            author = "Felleman & Van Essen"
        else:
            author = citation.split(",", 1)[0] + " et al."
        labels[code] = f"{code} — {author} ({year.group(1)})"
    return labels


def study_events(evidence, citations_path: Path, fel91_path: Path, available_labels: set[str]) -> tuple[list[dict], list[dict]]:
    """Return direction-specific reports with their actual projection citations."""
    citations = _citation_labels(citations_path)
    known = set(citations)
    events = []

    for row in evidence.to_dict("records"):
        target = str(row["Affiliate"])
        if target not in available_labels:
            continue
        for direction, ref_col, grade_col, other_ref_col in (
            ("out", "1_main_to_affiliate_ref", "1_main_to_affiliate_projection", "2_affiliate_to_main_ref"),
            ("in", "2_affiliate_to_main_ref", "2_affiliate_to_main_projection", "1_main_to_affiliate_ref"),
        ):
            grade = str(row[grade_col]).strip().lower()
            if grade not in POSITIVE | {"absent"}:
                continue
            refs = _references(row[ref_col], known)
            if not refs:
                # Some rows cite a study once for both reported directions.
                refs = _references(row[other_ref_col], known)
            for code in refs:
                events.append({
                    "study": code,
                    "target": target,
                    "direction": direction,
                    "grade": grade,
                    "type": str(row["study_type"]),
                })

    # Fel91 is a hierarchy citation in evidence.csv. Its direct FST pathways
    # come from the plus-sign cells of Table 3, transcribed separately.
    with fel91_path.open(newline="", encoding="utf-8-sig") as stream:
        for row in csv.DictReader(stream):
            source, target = row["from_area"], row["to_area"]
            if source == "FST" and target in available_labels:
                affiliate, direction = target, "out"
            elif target == "FST" and source in available_labels:
                affiliate, direction = source, "in"
            else:
                continue
            events.append({
                "study": "Fel91",
                "target": affiliate,
                "direction": direction,
                "grade": "present",
                "type": "literature synthesis",
            })

    used = {event["study"] for event in events}
    studies = [
        {"code": code, "label": citations[code]}
        for code in used
    ]
    studies.sort(key=lambda study: (int(re.search(r"\((\d{4})\)", study["label"]).group(1)), study["code"]))
    return events, studies


def write_study_filter_html(
    figure,
    output_path: Path,
    *,
    evidence,
    nodes_df,
    node_trace_index: int,
    edge_targets: list[str],
    citations_path: Path,
    fel91_path: Path,
) -> None:
    """Write offline HTML with a multi-select study panel and one recomputed node trace."""
    labels = nodes_df["label"].astype(str).tolist()
    trace = figure.data[node_trace_index]
    marker_colors = list(trace.marker.color)
    outline_colors = list(trace.marker.line.color)
    node_records = []
    for i, label in enumerate(labels):
        color = re.sub(r",\s*(?:0(?:\.\d+)?|1(?:\.0+)?)\s*\)$", ", 1)", str(marker_colors[i]))
        node_records.append({
            "label": label,
            "x": float(trace.x[i]),
            "y": float(trace.y[i]),
            "color": color,
            "outline": str(outline_colors[i]),
        })

    events, studies = study_events(
        evidence, citations_path, fel91_path, set(labels)
    )
    payload = {
        "nodes": node_records,
        "events": events,
        "studies": studies,
        "nodeTraceIndex": node_trace_index,
        "edgeTargets": edge_targets,
    }
    payload_json = json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")
    study_rows = "\n".join(
        '<div class="study-row"><label><input class="study-choice" type="checkbox" value="'
        + html.escape(study["code"], quote=True)
        + '" checked> '
        + html.escape(study["label"])
        + '</label><button type="button" class="only-study" data-study="'
        + html.escape(study["code"], quote=True)
        + '">Only</button></div>'
        for study in studies
    )

    plot_html = pio.to_html(
        figure, include_plotlyjs=True, full_html=False, div_id="connectivity-plot"
    )
    document = (
        '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<title>Macaque FST connectivity by study</title>'
        '<style>'
        'body{font-family:Arial,sans-serif;color:#1f2937;margin:0;background:#fff}'
        '.study-panel{padding:12px 18px;border-bottom:1px solid #bbb;background:#f9fbfd}'
        '.study-controls{display:flex;gap:8px;align-items:center;margin:8px 0}'
        '.study-controls button,.only-study{cursor:pointer}'
        '.study-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:4px 12px}'
        '.study-row{display:flex;justify-content:space-between;gap:10px;align-items:center}'
        '.study-row label{white-space:nowrap}'
        '.study-note,.study-status{font-size:13px;margin:7px 0 0}'
        '.study-status{font-weight:bold}'
        '</style></head><body>'
        '<div class="study-panel"><strong>Show results from studies</strong>'
        '<div class="study-controls"><button type="button" id="select-all-studies">Select all</button>'
        '<button type="button" id="clear-studies">Clear</button>'
        '<span>Check several studies to see their combined connections.</span></div>'
        '<div class="study-grid">'
        + study_rows +
        '</div><p class="study-note">Fel91 uses reported FST pathways in Table 3; its hierarchy citations in evidence.csv are not treated as connection reports. Fel91 does not grade connection strength, so its dots are small unless another selected tracer study supplies a grade.</p>'
        '<p id="study-status" class="study-status" aria-live="polite"></p></div>'
        + plot_html +
        '<script id="connectivity-data" type="application/json">' + payload_json + '</script>'
        '<script>'
        '(function(){'
        'const cfg=JSON.parse(document.getElementById("connectivity-data").textContent);'
        'const plot=document.getElementById("connectivity-plot");'
        'const choices=Array.from(document.querySelectorAll(".study-choice"));'
        'const status=document.getElementById("study-status");'
        'const positive=new Set(["weak","moderate","strong","present","broad"]);'
        'const ranks={weak:1,moderate:2,strong:3};'
        'const sizes={1:11,2:18,3:26};'
        'function escaped(value){return String(value).replace(/[&<>"\\x27]/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'
        '"\\x22":"&quot;","\\x27":"&#39;"}[c]});}'
        'function halfEvenMean(numbers){const m=numbers.reduce((a,b)=>a+b,0)/numbers.length;'
        'const lo=Math.floor(m),f=m-lo;return f>0.5?lo+1:f<0.5?lo:(lo%2?lo+1:lo);}'
        'function alphaColor(color,alpha){return color.replace(/,\\s*(?:0(?:\\.\\d+)?|1(?:\\.0+)?)\\s*\\)$/,", "+alpha+")");}'
        'function selectedCodes(){return new Set(choices.filter(c=>c.checked).map(c=>c.value));}'
        'function view(){'
        'const selected=selectedCodes();const byTarget=new Map();'
        'for(const event of cfg.events){if(!selected.has(event.study))continue;'
        'if(!byTarget.has(event.target))byTarget.set(event.target,[]);'
        'byTarget.get(event.target).push(event);}'
        'const xs=[],ys=[],texts=[],hovers=[],fills=[],sizesOut=[],outlines=[];'
        'let connected=0;'
        'for(const node of cfg.nodes){const reports=byTarget.get(node.label)||[];'
        'const present=reports.filter(e=>positive.has(e.grade));'
        'if(node.label!=="FST" && present.length===0)continue;'
        'if(node.label!=="FST")connected++;'
        'const graded={out:[],in:[]};'
        'for(const e of present){if(e.type==="tracer" && ranks[e.grade])graded[e.direction].push(ranks[e.grade]);}'
        'const scores=Object.values(graded).filter(a=>a.length).map(halfEvenMean);'
        'const score=scores.length?Math.max(...scores):null;'
        'const conflicts=["out","in"].every(d=>reports.some(e=>e.direction===d&&positive.has(e.grade))'
        '&&reports.some(e=>e.direction===d&&e.grade==="absent"));'
        'const alpha=conflicts?0.2:1;'
        'const studies=Array.from(new Set(present.map(e=>e.study))).sort();'
        'const absent=reports.filter(e=>e.grade==="absent");'
        'let hover="<b>"+escaped(node.label)+"</b>";'
        'if(node.label==="FST"){hover+="<br>Seed region";}'
        'else{hover+="<br>Reported by: "+studies.map(escaped).join(", ");'
        'hover+="<br>Graded tracer strength: "+(score===null?"not reported":({1:"weak",2:"moderate",3:"strong"}[score]));'
        'if(absent.length)hover+="<br>Selected reports of absence: "+Array.from(new Set(absent.map(e=>e.study))).sort().map(escaped).join(", ");}'
        'xs.push(node.x);ys.push(node.y);texts.push(node.label);hovers.push(hover);'
        'fills.push(alphaColor(node.color,alpha));sizesOut.push(node.label==="FST"?6:(sizes[score]||6));'
        'outlines.push(node.outline);}'
        'Plotly.restyle(plot,{"x":[xs],"y":[ys],"text":[texts],"hovertext":[hovers],'
        '"marker.color":[fills],"marker.size":[sizesOut],"marker.line.color":[outlines]},[cfg.nodeTraceIndex]);'
        'if(cfg.edgeTargets.length){'
        'const indices=cfg.edgeTargets.map((_,i)=>i);'
        'const shown=cfg.edgeTargets.map(target=>(byTarget.get(target)||[]).some(e=>positive.has(e.grade)));'
        'Plotly.restyle(plot,{"visible":shown},indices);}'
        'status.textContent=connected+" connected regions shown from "+selected.size+" selected "+(selected.size===1?"study":"studies")+".";'
        '}'
        'choices.forEach(c=>c.addEventListener("change",view));'
        'document.getElementById("select-all-studies").addEventListener("click",function(){choices.forEach(c=>c.checked=true);view()});'
        'document.getElementById("clear-studies").addEventListener("click",function(){choices.forEach(c=>c.checked=false);view()});'
        'document.querySelectorAll(".only-study").forEach(b=>b.addEventListener("click",function(){'
        'choices.forEach(c=>c.checked=(c.value===b.dataset.study));view()}));'
        'status.textContent=(cfg.nodes.length-1)+" connected regions shown from "+choices.length+" selected studies.";}());'
        '</script></body></html>'
    )
    output_path.write_text(document, encoding="utf-8")
