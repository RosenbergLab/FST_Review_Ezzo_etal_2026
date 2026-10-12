# Resources

This repository provides the two resources described in the paper:

1. [Interactive connectivity figure for macaques and humans](FST_Connectivity/)
2. [Four GIFs of structure-from-motion stimuli](MotionStimuli/)

## CorticalConnectivity

This interactive connectivity figure brings together published structural and functional evidence on area **FST** in macaques and humans from anatomical tracer studies, DTI tractography, resting-state fMRI, and functional inactivation. Dots on the lateral brain views position represent areas schematically. Readers can choose to check visual pathway assignments, supporting studies, connection-strength grades where available, the number of studies reporting each connection, and conflicting findings. 

Although the figure focuses on FST, the accompanying evidence tables also cover MT, MSTd, and MSTm in macaques and MT and MST in humans. Differences in parcellation, localization, and nomenclature across studies required difficult but inevitable choices about when to merge or separate reported areas. These choices make comparisons possible but may simplify distinctions in the original literature. The specific merging and separation of areas are listed in the evidence tables. Reconciling these labels cost the postdocs and graduate students a small piece of their souls; its anatomical location remains disputed.


### Open the FST figures

| Option | How to use it |
| --- | --- |
| **Browser — easiest** | Download [FST_connectivity_explorer_python.html](FST_Connectivity/FST_connectivity_explorer_python.html) and open it in a browser. **No Python or MATLAB installation is needed.** |
| **MATLAB** | Set MATLAB's current folder to `FST_Connectivity` and open [FST_connectivity_explorer.fig](FST_Connectivity/FST_connectivity_explorer.fig). |
| **Python package** | Use the package to generate your own browser file. See the [Python package guide](FST_Connectivity/PYTHON_PACKAGE.md) for installation, command-line use, and the Python API. |

### Read the figure

| Feature | Meaning |
| --- | --- |
| Brain and insets | Inset boxes hold medial areas and subcortical areas that are not shown on that surface. |
| Dot color | **Pathway colors** (default) use light blue for dorsal, pink for lateral, yellow for ventral, and black for neutral areas. With **Select all** active, choose **Grey/black conflict**. Grey means at least one study reports no FST connection in either direction while another reports a connection; all other dots are black. These fixed colors follow Figure 3 of the paper for both species. |
| Study controls | Select studies to show their reported FST connections. **Only** isolates one study, **Select all** restores every option, and **Clear** hides connection dots. Macaque Boussaoud (1990, 1992) and Bogadhi (2019, 2021) papers each have a combined option. Ungraded tracer reports, including Barone (2000) and Ungerleider (2008), appear under **Mixed tracer evidence**. |
| Dot size | **Uniform** shows no strength grade. For an eligible single study, macaque dots can show its strength separately for afferent, efferent, or unspecified projections. Boussaoud et al. (1990) uses a numeric 1–3 tracer score; other graded studies retain weak/moderate/strong sizes. Grades cannot be merged across studies. Human connection dots remain open in both size modes because strength and direction are not encoded; the study-count mode changes size by the number of supporting papers. |
| Reporting studies | When all study options are selected, **Number of reporting studies** sizes a dot by the number of distinct papers reporting that connection. It is available for both species. |
| Area details | Hover over a browser dot or click a MATLAB dot for the selected supporting studies and any selected reports of absence. |

### MATLAB: open or rebuild

To use the saved interactive figure, set MATLAB's current folder to `FST_Connectivity` and open [FST_connectivity_explorer.fig](FST_Connectivity/FST_connectivity_explorer.fig). To rebuild a species view from the current CSV files, run:

```matlab
plotConnectivity(Species="macaque");
plotConnectivity(Species="human");
```

Each call saves a species-named `.fig` with the menu to switch between both species, plus a `.pdf` showing the selected species. Only [FST_connectivity_explorer.fig](FST_Connectivity/FST_connectivity_explorer.fig) is distributed as a prebuilt MATLAB figure. The calls also update `<species>/edges.csv` and `<species>/selectnodes.csv` inside `FST_Connectivity`, which are generated tables. Use `WriteTables=false` to rebuild the figures without rewriting those tables. The source code is [plotConnectivity.m](FST_Connectivity/plotConnectivity.m), with display positions in [paperConnectivityLayout.m](FST_Connectivity/paperConnectivityLayout.m) and [paperHumanConnectivityLayout.m](FST_Connectivity/paperHumanConnectivityLayout.m).

### Evidence and source files

Inside `FST_Connectivity`, the `human/` and `macaque/` folders hold the literature review data and brain images. These files are the sources used to build the FST views:

| File | Purpose |
| --- | --- |
| [human/evidence.csv](FST_Connectivity/human/evidence.csv), [macaque/evidence.csv](FST_Connectivity/macaque/evidence.csv) | One row per literature finding. `Main` is the seed area and `Affiliate` is the partner. Columns record study method, reports and grades for `Main → Affiliate` and `Affiliate → Main`, reference codes, and notes. For FST, those directions are efferent and afferent, respectively. |
| [human/nodes.csv](FST_Connectivity/human/nodes.csv), [macaque/nodes.csv](FST_Connectivity/macaque/nodes.csv) | Area labels, native coordinates, and pathway colors. MATLAB and Python map these to the paper-style display positions for FST. |
| [paper_conflict_dots.json](FST_Connectivity/src/fst_connectivity/data/paper_conflict_dots.json) | Grey area labels transcribed from Figure 3 of the paper for the optional grey/black view. |
| [human/citations.txt](FST_Connectivity/human/citations.txt), [macaque/citations.txt](FST_Connectivity/macaque/citations.txt) | Full citations for the reference codes in the evidence tables. |
| [human/abbreviations.csv](FST_Connectivity/human/abbreviations.csv), [macaque/abbreviations.csv](FST_Connectivity/macaque/abbreviations.csv) | Expansions of area abbreviations. |
| [human/surface_snapshots/veryinflated_lat_white.tif](FST_Connectivity/human/surface_snapshots/veryinflated_lat_white.tif), [macaque/surface_snapshots/veryinflated_lat_white.tif](FST_Connectivity/macaque/surface_snapshots/veryinflated_lat_white.tif) | The TIFF files used as the lateral background in MATLAB. The Python package contains matching PNG backgrounds. |
| [macaque/fel91_fst_connections.csv](FST_Connectivity/macaque/fel91_fst_connections.csv) | FST pathways transcribed from Felleman and Van Essen (1991). |
| `<species>/edges.csv`, `<species>/selectnodes.csv` | Generated summaries from MATLAB; edit `evidence.csv` and `nodes.csv` as source data instead. |

The `evidence.xlsm` files are working review spreadsheets. The CSV files are the inputs used to build the figures.

In generated `edges.csv`, `evidencecount` counts positive evidence rows, with a value of 1 for an edge found only in the Felleman (1991) table. The interactive **Number of reporting studies** counts distinct papers, so the two numbers can differ. The edge table's `certainty` requires conflicting reports in both projection directions; the grey/black dot view uses the paper figure's study-level conflict marking.

For Boussaoud et al. (1990), four extra columns in `macaque/evidence.csv` give the median positive tracer-label score (1–3) and positive/evaluable case count for each projection direction. `+ to ++` is 1.5 and `++ to +++` is 2.5. The numeric score sets dot size for that study; the original descriptive evidence remains in its existing columns. Areas without a single score in the supplied Table 1 summary, and Boussaoud et al. (1992), remain open in strength mode.

### Rebuild the browser file with Python

Python 3.10 or newer is needed only to generate a new offline HTML file. From the repository root, enter `FST_Connectivity`, install the package, and render the current CSV data with:

```bash
cd FST_Connectivity
python -m pip install .
python -m fst_connectivity --data-dir . --output FST_connectivity_explorer_python.html --no-open
```

The [prebuilt wheel](FST_Connectivity/dist/fst_connectivity-0.1.21-py3-none-any.whl) is an alternative to installing from source. It bundles the repository evidence for use outside this folder. See [PYTHON_PACKAGE.md](FST_Connectivity/PYTHON_PACKAGE.md) for more options.

## Motion stimuli

The [MotionStimuli](MotionStimuli/) folder contains four animated examples illustrating **structure from motion**: moving points or contours reveal the organization of a figure over time.

- [Point-light walker](MotionStimuli/SfM_PointLightWalker.gif)
- [Rotating cylinder](MotionStimuli/SfM_RotatingCylinder.gif)
- [Wire-frame form](MotionStimuli/SfM_WireFrame.gif)
- [Stereokinetic circles](MotionStimuli/SfM_stereokinetic_circles.gif)

Two `Frames_` GIFs provide brief frame examples for the point-light walker and wire-frame animations.

OpenAI Codex was used to help build this resource. 
