# Resources

This repository provides the two resources described in the paper:

1. [Interactive connectivity figure for macaques and humans](FST_Connectivity/)
2. [GIFs of structure-from-motion stimuli](MotionStimuli/)

## FST Connectivity

This interactive connectivity figure brings together published structural and functional evidence on area **FST** in macaques and humans from anatomical tracer studies, DTI tractography, resting-state fMRI, and functional inactivation. Dots on the lateral brain views position represent areas schematically. Readers can choose to check visual pathway assignments, supporting studies, connection-strength grades where available, the number of studies reporting each connection, and conflicting findings. 

Although the figure focuses on FST, the accompanying evidence tables also cover MT, MSTd, and MSTm in macaques and MT and MST in humans. Differences in parcellation, localization, and nomenclature across studies required difficult but inevitable choices about merging or separating reported areas (e.g. Merging TPO and PGa to STPp; splitting MST to MSTd and MSTm in macaques). These choices make comparisons possible but may simplify distinctions in the original literature. The specific merging and separation of areas are listed in the evidence tables. Reconciling these labels cost the postdocs and graduate students a small piece of their souls... its anatomical location remains disputed.


### Open the FST figures

| Option | How to use it |
| --- | --- |
| **Browser — easiest** | Download [FST_connectivity_explorer_python.html](FST_Connectivity/FST_connectivity_explorer_python.html) and open it in a browser. **No Python or MATLAB installation is needed.** |
| **MATLAB** | Set MATLAB's current folder to `FST_Connectivity` and run `plotConnectivity`. |
| **Python package** | Use the package to generate your own browser file. See the [Python package guide](FST_Connectivity/PYTHON_PACKAGE.md) for installation, command-line use, and the Python API. |

### Read the figure

| Feature | Meaning |
| --- | --- |
| Brain and insets | Inset boxes hold medial areas and subcortical areas that are not shown on that surface. |
| Dot color | **Pathway colors** (default) use light blue for dorsal, pink for lateral, yellow for ventral, and black for neutral areas. With **Select all** active, choose **Grey/black conflict**. Grey: A study explicitly reports no connection, whereas another reports a connection. All other dots are black. These fixed colors follow Figure 3 of the paper for both species. |
| Study controls | Select studies to show their reported FST connections. **Only** isolates one study, **Select all** restores every option, and **Clear** hides connection dots. Macaque Boussaoud (1990, 1992) and Bogadhi (2019, 2021) papers each have a combined option. Tracer reports without a comparable displayed strength grade, including Barone (2000) and Ungerleider (2008), appear under **Combined tracer evidence**, with the included papers listed directly below that choice. |
| Dot size | **No scaling** uses a standard dot size. For an eligible single study, macaque dots can show its strength separately for afferent, efferent, or unspecified projections. Boussaoud et al. (1990) uses a numeric 1–3 tracer score; other graded studies retain weak/moderate/strong sizes. Grades cannot be merged across studies. Human studies do not offer connection-strength sizing. Area labels stay in place when dot sizes change. |
| Reporting studies | When all study options are selected, **Number of reporting studies** sizes filled dots by the number of distinct papers reporting that connection. It is available for both species, including subcortical areas. |
| Area details | Hover over a browser dot or click a MATLAB dot for the selected supporting studies and any selected reports of absence. |

### MATLAB: run the interactive figure

Set MATLAB's current folder to `FST_Connectivity`, then run:

```matlab
plotConnectivity;
```

The human view opens first; choose **Macaque** from the **Species** menu to switch views. To start with macaque, run `plotConnectivity(Species="macaque")`. The function reads the current CSV files and opens the interactive plot without writing new files. To export a PDF or regenerate `<species>/edges.csv` and `<species>/selectnodes.csv`, explicitly set `ExportPDF=true` or `WriteTables=true`. The source code is [plotConnectivity.m](FST_Connectivity/plotConnectivity.m), with display positions in [paperConnectivityLayout.m](FST_Connectivity/paperConnectivityLayout.m) and [paperHumanConnectivityLayout.m](FST_Connectivity/paperHumanConnectivityLayout.m).

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
| `<species>/edges.csv`, `<species>/selectnodes.csv` | Existing MATLAB-generated summaries. Regenerate them with `WriteTables=true`; edit `evidence.csv` and `nodes.csv` as source data instead. |

The `evidence.xlsm` files are working review spreadsheets. The `evidence.csv` and `nodes.csv` files are the inputs used to build the figures.

In generated `edges.csv`, `evidencecount` counts positive evidence rows. The interactive **Number of reporting studies** counts distinct papers, so the two numbers can differ. The edge table's `certainty` requires conflicting reports in both projection directions; the grey/black dot view uses the paper figure's study-level conflict marking.

For Boussaoud et al. (1990), four extra columns in `macaque/evidence.csv` give the median positive tracer-label score (1–3) and positive/evaluable case count for each projection direction. `+ to ++` is 1.5 and `++ to +++` is 2.5. The numeric score sets dot size for that study; the original descriptive evidence remains in its existing columns. Areas without a single score in the supplied Table 1 summary, and Boussaoud et al. (1992), remain open in strength mode.

### Rebuild the browser file with Python

Python 3.10 or newer is needed only to generate a new offline HTML file. Check your version with `py --version` in Windows PowerShell (or `python --version` if `py` is unavailable), or `python3 --version` in a macOS/Linux terminal. If Python is missing or older than 3.10, install a currently supported release from [Python.org](https://www.python.org/downloads/) on Windows or macOS, or through your Linux distribution. Open a new terminal and check again. Use the command that showed the correct version in place of `python` below if needed.

From the repository root, enter `FST_Connectivity`, install the package, and render the current CSV data with:

```bash
cd FST_Connectivity
python -m pip install .
python -m fst_connectivity --data-dir . --output FST_connectivity_explorer_python.html --no-open
```

The [prebuilt wheel](FST_Connectivity/dist/fst_connectivity-0.1.26-py3-none-any.whl) is an alternative to installing from source. It bundles the repository evidence for use outside this folder. See [PYTHON_PACKAGE.md](FST_Connectivity/PYTHON_PACKAGE.md) for more options.

## Motion stimuli

The [MotionStimuli](MotionStimuli/) folder contains GIFs illustrating **structure from motion**: moving points or contours reveal the organization of a figure over time.

- [Point-light walker](MotionStimuli/SfM_PointLightWalker.gif)
- [Rotating cylinder](MotionStimuli/SfM_RotatingCylinder.gif)
- [Wire-frame form](MotionStimuli/SfM_WireFrame.gif)
- [Stereokinetic circles](MotionStimuli/SfM_stereokinetic_circles.gif)

OpenAI Codex was used to help build this resource. 
