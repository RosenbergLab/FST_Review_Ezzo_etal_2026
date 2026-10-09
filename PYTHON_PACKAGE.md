# FST connectivity for Python

This package opens a macaque and human FST connectivity explorer in a browser. It includes the curated evidence tables, study citations, paper coordinates, and lateral brain backgrounds. It has no runtime plotting dependencies and does not require MATLAB.

## Install and open

From a downloaded copy of this repository:

```bash
python -m pip install .
fst-connectivity
```

If you received only the built wheel, install it with `python -m pip install fst_connectivity-0.1.6-py3-none-any.whl` and then run `fst-connectivity`.

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

Use `--data-dir PATH` or `render_html(..., data_dir=PATH)` to read updated `human/` and `macaque/` CSVs from another folder. The original source files are read only. When that folder contains the review's TIFFs without PNGs, the package uses its included pixel-identical PNG backgrounds.

## What the figure shows

- Paper-style lateral brain backgrounds at 50% opacity, pathway dot colors, inset areas, and hover evidence. The human dot positions match the reference-mapped MATLAB figure.
- Study checkboxes, **Only**, **Select all**, and **Clear** for each species. The macaque Boussaoud and Bogadhi papers have the same grouped options as MATLAB; Barone et al. (2000) joins the other ungraded tracer reports under **Mixed tracer evidence**.
- Macaque dot-size choices: uniform, connection strength by afferent/efferent/unspecified projection, or the number of distinct supporting papers. Uniform connection dots are open because no strength grade is displayed; FST stays filled. Strength sizing is available only for one eligible study selection, with filled dots for graded reports and open dots where that selection has no grade. The human view offers Uniform and Number of reporting studies; Baker's DTI and rs-fMRI reports count as one paper per area.
- Human LO1, LO2, and LO3 appear as one `LO1-3` display dot. Their individual rows remain in the source `human/evidence.csv`.

The package reads only the FST evidence used by the paper-style views.
