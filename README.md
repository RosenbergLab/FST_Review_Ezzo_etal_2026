# CorticalConnectivity

Generates schematic diagrams of structural/functional connectivity for a chosen region of interest (currently **FST**, **MST**, or **MT**), built from a literature review of human and macaque tracer, DTI tractography, rs-fMRI, and inactivation studies. Node positions are plotted on top of a cortical surface snapshot, with edge/node styling (line weight, color, dashing) driven by the evidence behind each connection.

The whole pipeline lives in a single notebook: [network_diagram.ipynb](network_diagram.ipynb).

## View the diagrams online

No setup required — the interactive figures are hosted via GitHub Pages and update automatically whenever the `.html` outputs are regenerated and pushed to `main`:

- **[All diagrams](https://raniaezzo.github.io/CorticalConnectivity/)**
- [Human — FST connectivity](https://raniaezzo.github.io/CorticalConnectivity/human_FST_displaybrain1.html)
- [Macaque — FST connectivity](https://raniaezzo.github.io/CorticalConnectivity/macaque_FST_displaybrain1.html)

(GitHub's own file browser can't preview these — they're too large for that viewer and will show "View raw" instead. Use the links above, not the `blob/main/...` links on github.com.)

## Requirements

Python 3, Jupyter Notebook (or an equivalent like JupyterLab or VS Code's Jupyter extension) to open `network_diagram.ipynb`, and:

```bash
pip install notebook pandas numpy plotly pillow matplotlib kaleido
```

`kaleido` is required by plotly's `fig.write_image(...)` call used to export the final PDF. Once installed, launch it from the repo root with:

```bash
jupyter notebook
```

## Before you run it

**Run the notebook from the repo root.** All paths in the notebook are resolved dynamically from `datapath = os.getcwd()`, so there's nothing to hard-code — just make sure Jupyter's working directory is this repo's root folder (the folder containing `network_diagram.ipynb`) when you launch it, not a subfolder like `human/` or `macaque/`.

## Important flags

The first markdown cell in the notebook summarizes these, but here's what each one actually controls:

### Data selection

| Flag | Values | Effect |
|---|---|---|
| `species` | `"human"` or `"macaque"` | Which subfolder (`human/` or `macaque/`) to read data from and which surface image to plot on. |
| `mainROI` | `"FST"`, `"MST"`, or `"MT"` | The seed region — all edges/nodes are computed relative to this region's row in `evidence.csv`. |
| `includestudies` | `"all"` or a set, e.g. `{"tracer"}` | Restricts which `study_type` rows from `evidence.csv` are used. Defaults differ by species in the notebook (macaque includes `tracer`, `DTI tractography`, `inactivation`; human includes `DTI tractography`, `rs-fMRI`, since tracer/inactivation data isn't available in humans). |

### Edge/node styling

| Flag | Values | Effect |
|---|---|---|
| `edgeweight` | `"evidencecount"` or `"connectivitystrength"` | Controls line thickness and, outside the macaque FST view, dot size. |
| `node_size_source` | `"tracer_strength"` for macaque FST by default | Sizes macaque FST dots by weak/moderate/strong anatomical tracer labels from evidence.csv. Positive reports are averaged within each projection direction, and the larger direction summary is shown. Absence and ungraded presence do not count as weak; areas without a graded tracer report use a fixed small dot. Fel91 supplies relative hierarchy, not connection strength. |
| `edgecolor` | `"hierarchy"` or `"projections"` | Controls line/node edge color: hierarchical relationship to the main ROI (higher/lower/equal/unknown, based on Felleman & Van Essen-style hierarchy) or projection direction relative to the main ROI (sends/receives/bidirectional). |
| `edgedashed` | `"certainty"` | Determines solid vs. dashed styling: `"certain"` (positive evidence, or absence not explicitly tested) vs. `"conflicting"` (some studies find the connection, others explicitly test for and don't find it). |
| `comment` | `"evidencesource"` | Populates the hover text for each node with the abbreviated study codes that support connections to it (defined in `citations.txt`). |
| `remove_unconnected_nodes` | `0` or `1` | If `1`, drops nodes from `selectnodes.csv`/the plot that have no surviving connection to the main ROI after filtering. |

For macaque marker colors, the existing blue, red, and green node categories are rendered as dorsal light blue (#B3E4F8), lateral light red (#F2B3D0), and ventral light yellow (#F9F384). Black nodes remain neutral.

### Plot layout (final cell)

| Flag | Values | Effect |
|---|---|---|
| `nodesOnly` | `0` or `1` | If `1`, skips drawing connection lines and plots nodes only. |
| `roi` | `"FST"`, `"MST"`, `"MT"` | Should match `mainROI` above — used to look up the right `{roi}comments` column and label the output file. |
| `roicoarse` | `0` or `1` | Intended to toggle coarse vs. fine-grained ROI selection. **Not yet implemented** — currently has no effect. |
| `displaybrain` | `0` or `1` | If `1`, overlays the node/edge plot on the cortical surface image. If `0`, nodes are drawn on a blank canvas (a schematic/hierarchy-style layout). |
| `rotateon` | `0` or `1` | Only read when `displaybrain == 0`; rotates the layout to be vertical (hierarchy-style). |
| `medial` | `0` or `1` | Only read when `displaybrain == 0`; additionally plots the medial surface view. When plotting on the brain image, also selects which surface snapshot image is loaded (`veryinflated_montage_nolabels_subcort.tif` vs. `veryinflated_lat_white.tif`). |
| `subcortical` | `0` or `1` | Only read when `displaybrain == 0`; additionally plots subcortical regions. |

Known regions that currently can't be displayed on the surface image: for macaque — TF, TH, PIP, PO (V6/V6A), MDP (7m), and medial parietal areas (BA23, RSC, BA31); for human — V6 and RSC (too medial/ventral to appear on the chosen surface view).

## Output

Running the full pipeline for a given `species`/`mainROI`:

1. Rewrites `<species>/edges.csv` — the computed connection list for the current settings.
2. Rewrites `<species>/selectnodes.csv` — the node list filtered/annotated for the current settings.
3. Displays an interactive Plotly figure.
4. Saves the figure to the repo root as both a static `<species>_<roi>_displaybrain<0|1>.pdf` (e.g. `human_FST_displaybrain0.pdf`) and an interactive, self-contained `<species>_<roi>_displaybrain<0|1>.html` (e.g. `human_FST_displaybrain0.html`) that preserves hover tooltips (`comment`/`evidencesource`) and can be opened directly in a browser.

The macaque FST notebook saves its study-filtered view as macaque_FST_displaybrain1_by_study.html. Open that file for the controls.

In the macaque FST HTML, check multiple studies to display the union of their reported connections. Dot sizes are recomputed from graded tracer results in the chosen studies; Fel91 alone supplies no graded strength. Use **Only** beside a study to isolate it, **Select all** to restore every study, or **Clear** to hide connections. The notebook shows a link to this interactive HTML after running. The Fel91 option uses positive FST pathways transcribed from Table 3 of Felleman and Van Essen (1991) in macaque/fel91_fst_connections.csv, because Fel91 is otherwise recorded only as a hierarchy reference in evidence.csv. Paper labels VP, PIT, and MSTl have no exact node-name match and are not shown in the current plot.

Because `edges.csv` and `selectnodes.csv` are regenerated (and overwritten) each run, treat them as build artifacts of `evidence.csv` and `nodes.csv` rather than source data to hand-edit.

## Repository structure

```
FST_Review_Ezzo_etal_2026/
├── network_diagram.ipynb   # main notebook — see above
├── study_filter.py        # offline study-selector HTML generator
├── human/                  # human data + assets
└── macaque/                # macaque data + assets
```

Running the notebook (see [Output](#output) below) will also produce a `<species>_<roi>_displaybrain<0|1>.pdf` file at the repo root.

Both species folders share the following core files; the Fel91 connection table is macaque-specific:

| File | Description |
|---|---|
| `nodes.csv` | Master list of all candidate ROIs for the species: id, plot coordinates (`x`,`y`, and normalized `center_x`,`center_y`), display `label`, `color`, marker `size`, and a `{roi}comments` column populated per run with hover-text citations. |
| `evidence.csv` | The literature review itself — one row per study/finding relating `Main` (the seed ROI, e.g. FST/MST/MT) to an `Affiliate` region. Columns capture wake state, study type, projection presence/strength in each direction with references, hierarchical level relative to `Main`, and free-text notes. This is the source data the notebook reads to build everything else. |
| `fel91_fst_connections.csv` | Macaque only: positive, directed FST pathways transcribed from Table 3 of Felleman and Van Essen (1991). Paper area labels without an exact node-name match are kept in this source file but omitted from the plot. |
| `edges.csv` | **Generated** by the notebook — the filtered/summarized connection list (evidence count, strength, hierarchy, certainty, projection direction) for the current `mainROI`/flag settings. Overwritten on each run. |
| `selectnodes.csv` | **Generated** by the notebook — `nodes.csv` filtered down to nodes actually used/connected for the current run (if `remove_unconnected_nodes = 1`), plus hover-text comments. Overwritten on each run. |
| `abbreviations.csv` | Expands ROI/region abbreviations (e.g. `FST` → fundus of the superior temporal area) used throughout the other files. |
| `citations.txt` | Maps the short reference codes used in `evidence.csv` (e.g. `Bak18`, `Rol23`) to full citations. |
| `evidence.xlsm` | Working spreadsheet version of `evidence.csv`, used for editing/curating the review data before exporting to CSV. |
| `surface_snapshots/` | Cortical surface renderings (`.tif` images, plus an `.ai` source file) at different inflation levels (`white`, `midthickness`, `inflated`, `veryinflated`) and views (`lat`, `med`, `dor`, `ven`, and combined montages), used as the background image in the plots. These are pre-rendered assets — no need to regenerate them to use the notebook. |

The species folders share the core nodes and evidence schema. The Fel91 connection table is specific to macaque FST.
