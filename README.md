# CorticalConnectivity

This repository contains a literature-based review of human and macaque cortical connectivity. The current paper-style explorer focuses on **FST** and lets you switch species, choose studies, and inspect the evidence behind each area. The original notebook also supports other seed regions, including MST and MT.

## Open the current FST explorer

| Option | How to open it |
| --- | --- |
| MATLAB | Set MATLAB's current folder to this repository, then open [FST_connectivity_explorer.fig](FST_connectivity_explorer.fig). The [human](human_FST_paper_lateral.fig) and [macaque](macaque_FST_paper_lateral.fig) FIGs are also available separately. Keep the `.m` files and species data folders with the FIG so its controls can run. |
| Browser, no installation | Download [FST_connectivity_explorer_python.html](FST_connectivity_explorer_python.html) and open it locally. It contains both species, images, and evidence, and works offline. GitHub's file viewer does not run the interactive HTML. |
| Python package | From the repository folder, run `python -m pip install .`, then `python -m fst_connectivity`. Python 3.10 or newer is required. On Windows, `py -m` can replace `python -m`. No separate plotting libraries are needed at runtime. |

The [prebuilt Python wheel](dist/fst_connectivity-0.1.2-py3-none-any.whl) is another installation option. See the [Python package guide](PYTHON_PACKAGE.md) for its API, output-file command, and use with updated data.

The MATLAB and Python explorers use the same curated evidence and study controls. **The MATLAB human FIG has the latest dot positions mapped from the paper reference; the Python human view still uses the earlier arrangement.**

## Use the controls

- **Species** switches between macaque and human without opening another window. Study selections are retained separately for each species. **Select all**, **Clear**, and **Only** control which papers contribute visible connections.
- Dot colors mark dorsal, lateral, and ventral pathways; black dots are neutral. The paper views use one lateral brain image at 50% opacity, with inset boxes for areas off that surface. The latest MATLAB human layout deliberately places V1, V2, V8, VMV, and VVC outside the brain outline.
- The macaque panel combines Boussaoud et al. (1990, 1992), combines Bogadhi et al. (2019, 2021), and places ungraded tracer reports—including Barone et al. (2000) and Ungerleider et al. (2008)—under **Mixed tracer evidence**.
- Macaque **Uniform** connection dots are open because size does not show a strength grade; the FST seed stays filled. With one eligible study selection, the afferent, efferent, or unspecified strength mode uses that study's weak/moderate/strong reports. It does not average grades across papers. In a strength mode, dots without a grade are open.
- Both species offer **Number of reporting studies** when all study options are selected. It sizes each area by the number of distinct papers with a positive report, not by CSV row count. Human Baker et al. (2018) counts once even where DTI and rs-fMRI each have a row. Human LO1, LO2, and LO3 share one display dot labeled `LO1-3`; their source rows remain separate.

Hover over a dot to see the selected supporting papers and any selected reports of absence.

## Evidence and rebuilding

The [human/evidence.csv](human/evidence.csv) and [macaque/evidence.csv](macaque/evidence.csv) files record the seed area (`Main`), partner area (`Affiliate`), method, reports in each projection direction, and study reference codes. The matching [human/nodes.csv](human/nodes.csv) and [macaque/nodes.csv](macaque/nodes.csv) files supply area labels and native coordinates; each species folder also has `citations.txt`. The macaque Felleman and Van Essen (1991) FST pathways additionally come from [macaque/fel91_fst_connections.csv](macaque/fel91_fst_connections.csv).

The current MATLAB explorer reads the repository CSVs. From MATLAB with this repository as the current folder, rebuild either species with:

```matlab
plotConnectivity(Species="macaque");
plotConnectivity(Species="human");
```

These calls save the paper FIG and PDF and update `<species>/edges.csv` and `<species>/selectnodes.csv`. Those two CSVs are **generated outputs**; edit `evidence.csv` and `nodes.csv` as source data. Pass `WriteTables=false` to rebuild figures without rewriting the generated tables.

The installed Python package uses bundled copies of the CSVs by default. To use the current repository data and write a new offline HTML file, run from the repository folder:

```bash
python -m fst_connectivity --data-dir . --output FST_connectivity_explorer_python.html --no-open
```

## Original Plotly notebook

[network_diagram.ipynb](network_diagram.ipynb) and [study_filter.py](study_filter.py) are the earlier workflow for FST, MST, and MT. Its `*_displaybrain*.html` outputs and any older hosted Plotly pages are separate from the current paper-style explorer; the current MATLAB and Python commands do not refresh those pages. Run the notebook from the repository root so its relative data paths resolve correctly. Its additional dependencies are:

```bash
python -m pip install notebook pandas numpy plotly pillow matplotlib kaleido
```

## Repository map

- [plotConnectivity.m](plotConnectivity.m), [paperConnectivityLayout.m](paperConnectivityLayout.m), and [paperHumanConnectivityLayout.m](paperHumanConnectivityLayout.m): MATLAB FST explorer and display coordinates.
- [src/fst_connectivity](src/fst_connectivity) and [pyproject.toml](pyproject.toml): installable Python package, bundled evidence, and offline browser interface.
- [human](human) and [macaque](macaque): source evidence, citations, node lists, and cortical surface images. The `evidence.xlsm` files are working review spreadsheets; export their curated changes to `evidence.csv` before rebuilding.
- [tests](tests): MATLAB and Python checks for study controls, evidence handling, layout, and saved FIG behavior.
