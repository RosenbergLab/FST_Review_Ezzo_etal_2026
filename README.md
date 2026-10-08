# CorticalConnectivity

This repository collects published evidence about structural and functional connectivity in human and macaque brains, including anatomical tracer, DTI tractography, rs-fMRI, and functional inactivation studies. The current interactive figures focus on **FST** (fundus of the superior temporal area). They place areas reported in the literature on a lateral brain view, show their pathway category by dot color, and let readers inspect which studies support each connection. The evidence tables also contain reports for other seed areas; the figures described here are the current FST views.

## Open the FST figures

| Option | How to use it |
| --- | --- |
| **Browser — easiest** | Download [FST_connectivity_explorer_python.html](FST_connectivity_explorer_python.html) and open it in a browser. It includes both species, the brain images, and the evidence in one offline file. **No Python or MATLAB installation is needed.** The filename reflects how the file was generated. GitHub's file viewer does not run the interactive figure, so download the HTML before opening it. |
| **MATLAB** | Set MATLAB's current folder to this repository and open [FST_connectivity_explorer.fig](FST_connectivity_explorer.fig). Its **Species** menu switches between macaque and human in one window. Keep the `.m` files and the `human/` and `macaque/` folders with the FIG so the controls can load their data. Separate [human](human_FST_paper_lateral.fig) and [macaque](macaque_FST_paper_lateral.fig) FIGs are also available. |
| **Python package** | Use the package to generate your own browser file. See the [Python package guide](PYTHON_PACKAGE.md) for installation, command-line use, and the Python API. |

## Read the figure

| Feature | Meaning |
| --- | --- |
| Brain and insets | Each species uses one lateral brain image at 50% opacity. Inset boxes hold areas that are not shown on that surface. In the human view, V1, V2, V8, VMV, and VVC are placed just outside the brain outline, following the supplied figure. |
| Dot color | Light blue marks the dorsal pathway, pink the lateral pathway, and yellow the ventral pathway. Black dots are neutral. Color identifies the area category; it does not encode connection strength. |
| Study controls | Select studies to show their reported FST connections. **Only** isolates one study, **Select all** restores every option, and **Clear** hides connection dots. Macaque Boussaoud (1990, 1992) and Bogadhi (2019, 2021) papers each have a combined option. Ungraded tracer reports, including Barone (2000) and Ungerleider (2008), appear under **Mixed tracer evidence**. |
| Dot size | **Uniform** shows no strength grade. Macaque connection dots are open in this mode; the FST seed stays filled. For an eligible single study, macaque dots can show its weak, moderate, and strong reports separately for afferent, efferent, or unspecified projections. An open dot in a strength view has no grade from that selection. Grades are not averaged across studies. |
| Reporting studies | When all study options are selected, **Number of reporting studies** sizes a dot by the number of distinct papers reporting that connection. It is available for both species. |
| Area details | Hover over a browser dot or click a MATLAB dot for the selected supporting studies and any selected reports of absence. Human LO1, LO2, and LO3 share one display dot labeled `LO1-3`; their evidence rows remain separate. |

## MATLAB: open or rebuild

To use the saved interactive figure, open [FST_connectivity_explorer.fig](FST_connectivity_explorer.fig) from MATLAB with this repository as the current folder. To rebuild a species view from the current CSV files, run:

```matlab
plotConnectivity(Species="macaque");
plotConnectivity(Species="human");
```

These calls save `<species>_FST_paper_lateral.fig` and `.pdf` in the repository folder. They also update `<species>/edges.csv` and `<species>/selectnodes.csv`, which are generated tables. Use `WriteTables=false` if you want to rebuild figures without rewriting those tables. The source code is [plotConnectivity.m](plotConnectivity.m), with display positions in [paperConnectivityLayout.m](paperConnectivityLayout.m) and [paperHumanConnectivityLayout.m](paperHumanConnectivityLayout.m).

## Evidence and source files

The `human/` and `macaque/` folders hold the literature review data and brain images. These files are the sources used to build the FST views:

| File | Purpose |
| --- | --- |
| [human/evidence.csv](human/evidence.csv), [macaque/evidence.csv](macaque/evidence.csv) | One row per literature finding. `Main` is the seed area and `Affiliate` is the partner. Columns record study method, reports and grades for `Main → Affiliate` and `Affiliate → Main`, reference codes, and notes. For FST, those directions are efferent and afferent, respectively. |
| [human/nodes.csv](human/nodes.csv), [macaque/nodes.csv](macaque/nodes.csv) | Area labels, native coordinates, and pathway colors. MATLAB and Python map these to the paper-style display positions for FST. |
| `human/citations.txt`, `macaque/citations.txt` | Full citations for the reference codes in the evidence tables. |
| `human/abbreviations.csv`, `macaque/abbreviations.csv` | Expansions of area abbreviations. |
| `human/surface_snapshots/`, `macaque/surface_snapshots/` | Cortical surface images used behind the dots. |
| [macaque/fel91_fst_connections.csv](macaque/fel91_fst_connections.csv) | FST pathways transcribed from Felleman and Van Essen (1991). |
| `<species>/edges.csv`, `<species>/selectnodes.csv` | Generated summaries from MATLAB; edit `evidence.csv` and `nodes.csv` as source data instead. |

The `evidence.xlsm` files are working review spreadsheets. The CSV files are the inputs used to build the figures.

## Rebuild the browser file with Python

Python 3.10 or newer is needed only to generate a new offline HTML file. From this repository, install the package and render the current CSV data with:

```bash
python -m pip install .
python -m fst_connectivity --data-dir . --output FST_connectivity_explorer_python.html --no-open
```

The [prebuilt wheel](dist/fst_connectivity-0.1.4-py3-none-any.whl) is an alternative to installing from source. It bundles the repository evidence for use outside this folder. See [PYTHON_PACKAGE.md](PYTHON_PACKAGE.md) for more options.
