# FST connectivity for Python

This package opens a macaque and human FST connectivity explorer in a browser. 

## Check Python

The ready-made [browser figure](FST_connectivity_explorer_python.html) opens without Python. To generate a new figure with this package, you need Python 3.10 or newer. Check the installed version:

| System | Command |
| --- | --- |
| Windows PowerShell | `py --version` (or `python --version` if `py` is unavailable) |
| macOS or Linux terminal | `python3 --version` |

If Python is missing or older than 3.10, install a currently supported release from [Python.org](https://www.python.org/downloads/).

## Install and open

From a downloaded copy of this repository, enter the connectivity folder first:

```bash
cd FST_Connectivity
python -m pip install .
fst-connectivity
```

Alternatively, from `FST_Connectivity/`, install the included wheel with `python -m pip install dist/fst_connectivity-0.1.23-py3-none-any.whl`, then run `fst-connectivity`.

You can also run `python -m fst_connectivity`. Both commands create one self-contained HTML file and open it in your default browser. The **Species** menu switches views without reloading. Study selections are kept separately for macaques and humans.

To save a file for a collaborator:

```bash
fst-connectivity --output FST_connectivity_explorer.html --no-open
```

The saved HTML contains the images and evidence, so the recipient can open it offline without installing Python. To start in the human view, add `--species human`.

The Python API is equally simple:

```python
from fst_connectivity import render_html

path = render_html("FST_connectivity_explorer.html", initial_species="human")
```

Use `--data-dir PATH` or `render_html(..., data_dir=PATH)` to read updated `human/` and `macaque/` CSVs from another folder. For the CSVs in this repository, pass `--data-dir .` when working in `FST_Connectivity/` or `--data-dir FST_Connectivity` when working in the repository root. The original source files are read only. When that folder contains the review's TIFFs without PNGs, the package uses its included pixel-identical PNG backgrounds.

## What the figure shows

- Paper-style lateral brain backgrounds at 30% opacity, pathway dot colors, inset areas, and hover evidence. The human dot positions match the reference-mapped MATLAB figure.
- Study checkboxes, **Only**, **Select all**, and **Clear** for each species. The macaque Boussaoud and Bogadhi papers have the same grouped options as MATLAB; Barone et al. (2000) joins the other ungraded tracer reports under **Combined tracer evidence**, with the included studies listed directly below the choice.
- Dot-color choices for both species: pathway colors by default, or grey/black conflicts when all studies are selected. Grey: A study explicitly reports no connection, whereas another reports a connection. Grey areas follow the fixed labels in the supplied Figure 3; other area dots are black in that view. Selecting a subset restores pathway colors.
- Macaque dot-size choices: **No scaling**, connection strength by afferent/efferent/unspecified projection, or the number of distinct supporting papers. Strength sizing is available only for one eligible study selection, with filled dots for graded reports and open dots where that selection has no connection strength. Boussaoud et al. (1990) uses its Table 1 median positive tracer score on a continuous 1–3 scale, including 1.5 and 2.5. For the grouped Boussaoud selection, afferent/efferent modes filter the ungraded 1992 subcortical nodes by reported direction; hover text states that direction. The human view offers **No scaling** and **Number of reporting studies**. Under **Number of reporting studies**, every shown connection dot is filled for both species, including macaque subcortical areas. Baker's DTI and rs-fMRI reports count as one paper per area.
- Human LO1, LO2, and LO3 appear as one `LO1-3` display dot. Their individual rows remain in the source `human/evidence.csv`; its `Pfop` spelling also maps to the displayed `PFop` dot. Macaque V3d remains a single dorsal-colored dot for reports from the current evidence table.

The macaque display applies prior review choices for Barone et al. (2000) V1/V4 direction and Ungerleider et al. (2008) V4 strength. Their original `evidence.csv` cells remain available for review.

The package reads only the FST evidence used by the paper-style views.
