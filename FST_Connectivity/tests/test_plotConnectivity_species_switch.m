%TEST_PLOTCONNECTIVITY_SPECIES_SWITCH Check the two cached FST views.
% Run from the repository root:
%   run('FST_Connectivity/tests/test_plotConnectivity_species_switch.m')
% Uses temporary output and closes its figures. When testing staged code,
% set FST_CONNECTIVITY_DATA_PATH to the FST_Connectivity folder.

scriptDir = fileparts(mfilename('fullpath'));
sourceDir = fileparts(scriptDir);
codeDir = sourceDir;
if isfile(fullfile(scriptDir, 'plotConnectivity.m'))
    codeDir = scriptDir;
end
dataDir = sourceDir;
if ~isfile(fullfile(dataDir, 'human', 'evidence.csv'))
    dataDir = getenv('FST_CONNECTIVITY_DATA_PATH');
end
assert(isfile(fullfile(codeDir, 'plotConnectivity.m')), ...
    'Cannot find plotConnectivity.m beside the test or in its parent.');
assert(isfile(fullfile(dataDir, 'human', 'evidence.csv')), ...
    'Cannot find human/evidence.csv. Set FST_CONNECTIVITY_DATA_PATH for staged tests.');
addpath(dataDir, '-end');
addpath(codeDir, '-begin');
outputDir = tempname(tempdir);
mkdir(outputDir);
priorFigureCount = numel(findall(groot, 'Type', 'figure'));

result = plotConnectivity(DataPath=string(dataDir), ...
    OutputDir=string(outputDir), NodesOnly=false, Visible="off");
fig = result.Figure;
figureCleanup = onCleanup(@() closeFigureIfValid(fig)); %#ok<NASGU>
assert(isgraphics(fig, 'figure'));
assert(numel(findall(groot, 'Type', 'figure')) == priorFigureCount + 1);
assert(result.FigurePath == "" && result.PDFPath == "", ...
    'A default call should not save a FIG or PDF.');
assertNoOutputFiles(outputDir);
originalPosition = fig.Position;
assert(isequal(originalPosition(3:4), [1835 820]), ...
    'Both species must use the same 1835-by-820 window.');
cache = verifyCache(fig);
verifyViewGeometry(fig, cache);
verifyUpdatedAreaMapping(fig);
verifyActiveView(fig, cache, "human");
assert(nnz(string(result.Nodes.label) == "LO1-3") == 1);
assert(~any(ismember(string(result.Nodes.label), ["LO1", "LO2", "LO3"])));
verifyHumanFigure(fig);
verifyStudyFilters(fig, cache.human, 'HumanStudySelectorState');
verifyHumanCount(fig, cache.human);
verifyConflictColorToggle(fig, 'HumanStudySelectorState');
verifyNoCornerLetters(fig);

switchSpecies(fig, 1); % Macaque
verifySwitch(fig, cache, originalPosition, "macaque", priorFigureCount);
verifyStudyFilters(fig, cache.macaque, 'StudySelectorState');
verifyUniformOpen(fig);
verifyBoussaoudNumericStrength(fig);
verifyMacaqueCount(fig);
verifyMacaqueCombinedOverlap(fig);
verifyConflictColorToggle(fig, 'StudySelectorState');
verifyNoCornerLetters(fig);

switchSpecies(fig, 2); % Human, in the same figure again
verifySwitch(fig, cache, originalPosition, "human", priorFigureCount);
humanCount = getappdata(fig, 'HumanStudySelectorState');
assert(strcmp(humanCount.SizeGroup.SelectedObject.Tag, 'studycount'), ...
    'Human study-count selection was lost during a species switch.');
verifyHumanFigure(fig);
verifyStudyFilters(fig, cache.human, 'HumanStudySelectorState');
verifyNoCornerLetters(fig);

% Each cached view keeps its own study selection across species switches.
human = getappdata(fig, 'HumanStudySelectorState');
runCallback(findButton(cache.human, 'Clear'));
assert(all(arrayfun(@(h) h.Value == 0, human.CheckBoxes)));
switchSpecies(fig, 1);
verifySwitch(fig, cache, originalPosition, "macaque", priorFigureCount);
mac = getappdata(fig, 'StudySelectorState');
runCallback(findButton(cache.macaque, 'Clear'));
assert(all(arrayfun(@(h) h.Value == 0, mac.CheckBoxes)));
switchSpecies(fig, 2);
verifySwitch(fig, cache, originalPosition, "human", priorFigureCount);
assert(all(arrayfun(@(h) h.Value == 0, human.CheckBoxes)), ...
    'Human study selection was lost while its view was hidden.');
switchSpecies(fig, 1);
assert(all(arrayfun(@(h) h.Value == 0, mac.CheckBoxes)), ...
    'Macaque study selection was lost while its view was hidden.');

% A species switch also must not write figure exports or summary tables.
assertNoOutputFiles(outputDir);

% Unsupported projection labels cannot inflate the computed edge counts.
macaqueResult = plotConnectivity(DataPath=string(dataDir), ...
    OutputDir=string(outputDir), Species="macaque", MainROI="FST", ...
    NodesOnly=true, StudySelector=true, WriteTables=false, ...
    ExportPDF=false, SaveFigure=false, Visible="off", ...
    PreloadSpecies=false);
macaqueEdges = macaqueResult.Edges;
for area = ["STPa", "DP"]
    row = macaqueEdges(macaqueEdges.targetname == area, :);
    assert(height(row) == 1 && row.evidencecount == 1, ...
        '%s should count its one positive report, excluding unknown/tentative.', ...
        area);
end
v3dEdge = macaqueEdges(macaqueEdges.targetname == "V3d", :);
assert(height(v3dEdge) == 1 && v3dEdge.evidencecount == 2, ...
    'V3d should retain the numerically scored Boussaoud report.');
close(macaqueResult.Figure);

% The simpler macaque paper view has its own dot-size controls.
paperResult = plotConnectivity(DataPath=string(dataDir), ...
    OutputDir=string(outputDir), Species="macaque", MainROI="FST", ...
    StudySelector=false, NodeSizeSource="uniform", Visible="off", ...
    PreloadSpecies=false);
paperState = getappdata(paperResult.Figure, 'PaperSizeState');
assert(isstruct(paperState) && ...
    strcmp(paperState.SizeGroup.SelectedObject.Tag, 'uniform') && ...
    strcmp(paperState.SizeLegend.Visible, 'off'), ...
    'The paper-view legend must be hidden with No scaling.');
strengthButton = findall(paperState.SizeGroup, ...
    'Style', 'radiobutton', 'Tag', 'strength');
assert(isscalar(strengthButton));
if strcmp(strengthButton.Enable, 'on')
    paperState.SizeGroup.SelectedObject = strengthButton;
    paperState.SizeGroup.SelectionChangedFcn(paperState.SizeGroup, []);
    assert(strcmp(paperState.SizeLegend.Visible, 'on'), ...
        'The paper-view legend must appear with strength scaling.');
    uniformButton = findall(paperState.SizeGroup, ...
        'Style', 'radiobutton', 'Tag', 'uniform');
    paperState.SizeGroup.SelectedObject = uniformButton;
    paperState.SizeGroup.SelectionChangedFcn(paperState.SizeGroup, []);
    assert(strcmp(paperState.SizeLegend.Visible, 'off'), ...
        'Returning to No scaling must hide the paper-view legend.');
end
close(paperResult.Figure);

fprintf(['PASS: LO1-3, matching 1835-by-820 windows, centered human axes, ' ...
    'cached same-figure switches, retained study filters, no default exports, ' ...
    'and no panel letters.\n']);
fprintf('Temporary output: %s\n', outputDir);

function assertNoOutputFiles(outputDir)
contents = dir(outputDir);
names = string({contents.name});
contents = contents(~ismember(names, [".", ".."]));
assert(isempty(contents), ...
    'Plotting and switching species should not create output files.');
end

function cache = verifyCache(fig)
cache = getappdata(fig, 'ConnectivityViewCache');
assert(isstruct(cache) && all(isfield(cache, {'macaque', 'human'})), ...
    'The figure did not cache both species views.');
assert(isgraphics(cache.macaque, 'uipanel') && ...
    isgraphics(cache.human, 'uipanel'));
assert(isequal(cache.macaque.Position, [0 0 1835 820]) && ...
    isequal(cache.human.Position, [0 0 1835 820]), ...
    'The two cached views have different panel geometry.');
end

function verifyViewGeometry(fig, cache)
human = getappdata(fig, 'HumanStudySelectorState');
mac = getappdata(fig, 'StudySelectorState');
assert(isstruct(human) && isstruct(mac), ...
    'Both species must have study selector state.');
humanAxes = ancestor(human.NodeHandles(1), 'axes');
macAxes = ancestor(mac.NodeHandles(1), 'axes');
assert(isequal(humanAxes.Position, [128 46 1080 728]), ...
    'Human axes are not centered in the shared canvas.');
assert(isequal(macAxes.Position, [0 0 1335 820]), ...
    'Macaque axes moved in the shared canvas.');
end

function verifyUpdatedAreaMapping(fig)
human = getappdata(fig, 'HumanStudySelectorState');
humanLabels = string(human.NodeLabels);
assert(any(humanLabels == "V3"), 'The human V3 dot should remain separate.');
ph = find(humanLabels == "PH", 1);
assert(max(abs(human.NodeHandles(ph).MarkerEdgeColor - ...
    [249 243 132] / 255)) < 1e-9, ...
    'Human PH should use the ventral pathway color.');
pht = find(humanLabels == "PHT", 1);
assert(max(abs(human.NodeHandles(pht).MarkerEdgeColor - ...
    [242 179 208] / 255)) < 1e-9, ...
    'Human PHT should remain in the lateral pathway.');
assert(any(humanLabels == "SMA") && ~any(humanLabels == "SEF"), ...
    'Updated human SMA label did not replace SEF.');
assert(any(humanLabels == "MCC") && ~any(humanLabels == "mPFC"), ...
    'Updated human MCC label did not replace mPFC.');
assert(any(human.Events.target == "MCC" & ...
    human.Events.study == "Bak18"), ...
    'The MCC inset dot is missing Baker evidence.');
pfopAbsent = human.Events(human.Events.target == "PFop" & ...
    human.Events.study == "Rua25" & human.Events.grade == "absent", :);
assert(height(pfopAbsent) == 2 && ...
    all(ismember(["out", "in"], pfopAbsent.direction)), ...
    'The Rua25 Pfop absence must attach to the canonical PFop dot in both directions.');
humanInsetNames = ["MCC", "BA23", "V6", "preSMA", ...
    "RSC", "BA7", "precuneus"];
humanInsetPoints = [56 256; 102 256; 56 275; 102 275; ...
    56 294; 79 275; 102 294];
for k = 1:numel(humanInsetNames)
    index = find(humanLabels == humanInsetNames(k), 1);
    point = [human.NodeHandles(index).XData, ...
        human.NodeHandles(index).YData];
    assert(isequal(point, humanInsetPoints(k, :)), ...
        'Human inset grid misaligned at %s.', humanInsetNames(k));
end

mac = getappdata(fig, 'StudySelectorState');
macLabels = string(mac.NodeLabels);
assert(any(macLabels == "V3d") && ~any(macLabels == "V3"), ...
    'Macaque V3 and V3d should share one V3d display dot.');
ruan = mac.Events(mac.Events.study == "Rua25", :);
assert(any(ruan.target == "V3d") && ~any(ruan.target == "V3"), ...
    'Ruan (2025) should now report V3d, not V3.');
assert(~any(mac.Events.study == "Fel91") && ...
    ~any(contains(mac.Studies.label, "Felleman")), ...
    'Felleman (1991) should not appear as a connectivity study.');
v3d = mac.Events(mac.Events.target == "V3d" & ...
    ismember(mac.Events.grade, ["weak", "moderate", "strong", ...
    "present", "broad"]), :);
assert(numel(unique(v3d.study)) == 2 && ...
    all(ismember(["Bou90", "Rua25"], v3d.study)), ...
    'The merged V3d dot should count two distinct studies.');
assert(any(v3d.study == "Bou90" & v3d.direction == "in" & ...
    v3d.grade == "present" & v3d.strengthGrade == "1"), ...
    'The numerically scored Bou90 tentative afferent report must remain positive.');
assert(any(mac.EdgeTargets == "V3d") && ~any(mac.EdgeTargets == "V3"), ...
    'Macaque V3 should not retain a separate display edge.');
assert(all(ismember(["V3d", "A1", "BA23", "BA31", "pulvinar", "TRN"], ...
    macLabels)), 'Updated macaque areas are missing.');
assert(~any(ismember(["VOT/TEO", "SEF", "STGp", "PCCa", "PCCp", ...
    "thalamus"], macLabels)), 'Old macaque FST area labels remain.');
names = ["A1", "V6", "BA23", "BA31", "RSC", ...
    "basalfore", "SC", "claustrum", "pons", "striatum", ...
    "pretectum", "pulvinar", "TRN", ...
    "S1", "AIP", "VIP", "V3A", "V3d"];
points = [254 131; 28 34; 68 34; 28 54; 68 54; ...
    406 254; 449 254; 406 270; 449 270; 406 286; ...
    449 286; 406 302; 449 302; ...
    223.3 40.5; 245.6 67.7; 286.7 63.6; 388 80; 390.5 107.5];
for k = 1:numel(names)
    index = find(macLabels == names(k), 1);
    point = [mac.NodeHandles(index).XData, mac.NodeHandles(index).YData];
    assert(max(abs(point - points(k, :))) < 1e-9, ...
        'The current position changed for %s.', names(k));
end
for label = "A1"
    index = find(macLabels == label, 1);
    assert(max(abs(mac.NodeHandles(index).MarkerEdgeColor)) < 1e-9, ...
        'The new area %s should use the neutral color.', label);
end
index = find(macLabels == "V3d", 1);
assert(max(abs(mac.NodeHandles(index).MarkerEdgeColor - ...
    [179 228 248] / 255)) < 1e-9, ...
    'Macaque V3d should use the dorsal pathway color.');
end

function verifyActiveView(fig, cache, species)
assert(string(getappdata(fig, 'ConnectivitySpecies')) == species);
assert(isequal(getappdata(fig, 'ConnectivityViewRoot'), ...
    cache.(char(species))));
assert(strcmp(cache.(char(species)).Visible, 'on'));
popup = findobj(cache.(char(species)), ...
    'Tag', 'ConnectivitySpeciesSelector');
assert(isscalar(popup) && popup.Value == 1 + (species == "human"), ...
    'The visible species menu does not match the active view.');
other = "human";
if species == "human"
    other = "macaque";
end
assert(strcmp(cache.(char(other)).Visible, 'off'));
end

function verifyUniformOpen(fig)
state = getappdata(fig, 'StudySelectorState');
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'uniform'));
assert(strcmp(state.StrengthLegend.Visible, 'off') && ...
    strcmp(state.NumericStrengthLegend.Visible, 'off') && ...
    strcmp(state.CountLegend.Visible, 'off'), ...
    'No scaling must hide every macaque dot-size legend.');
for k = 1:numel(state.NodeLabels)
    if strcmp(state.NodeHandles(k).Visible, 'off')
        continue
    end
    face = state.NodeHandles(k).MarkerFaceColor;
    if state.NodeLabels(k) == "FST"
        assert(~isequal(face, 'none'), 'The FST seed must remain filled.');
    else
        assert(isequal(face, 'none'), ...
            'Uniform macaque connection dots must be open.');
    end
end
end

function verifyBoussaoudNumericStrength(fig)
state = getappdata(fig, 'StudySelectorState');
originalLabels = areaLabelPositions(state);
studyIndex = find(state.Studies.code == "Bou90+Bou92", 1);
assert(~isempty(studyIndex), 'Boussaoud grouped study is missing.');
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = k == studyIndex;
end
runCallback(state.CheckBoxes(studyIndex));
assertAreaLabelsFixed(state, originalLabels, 'Boussaoud study selection');
labels = string(state.NodeLabels);
isVisible = @(name) strcmp(state.NodeHandles(find(labels == name, 1)).Visible, 'on');
assert(isVisible("basalfore") && isVisible("striatum") && ...
    ~isVisible("SC"), 'Uniform Boussaoud mode should show both directions.');

state.SizeGroup.SelectedObject = state.StrengthButtons(2); % efferent
callback = state.SizeGroup.SelectionChangedFcn;
callback(state.SizeGroup, []);
assertAreaLabelsFixed(state, originalLabels, 'efferent strength');
assert(strcmp(state.NumericStrengthLegend.Visible, 'on'));
assert(strcmp(state.StrengthLegend.Visible, 'off'));
assertLegendTextFits(state.NumericStrengthLegend);
assertNumericLegendReadable(state.NumericStrengthLegend);
assert(any(contains(string(state.Note.String), "1990 tracer score")), ...
    'The numeric-strength context should remain above its legend.');
for area = ["TRN", "pulvinar", "claustrum", "striatum", ...
        "pretectum", "pons"]
    assert(isVisible(area), 'Missing efferent Bou92 area %s.', area);
end
assert(~isVisible("basalfore") && ~isVisible("SC") && isVisible("MT"));
basalEdge = state.EdgeHandles(find(state.EdgeTargets == "basalfore", 1));
assert(strcmp(basalEdge.Visible, 'off'));
sizeOf = @(name) state.NodeHandles(find(labels == name, 1)).SizeData;
assert(abs(sizeOf("MT") - (0.75 * 22)^2) < 1e-9);
assert(abs(sizeOf("VIP") - (0.75 * 18.5)^2) < 1e-9);
assert(abs(sizeOf("V4t") - (0.75 * 9)^2) < 1e-9);
assert(isequal(state.NodeHandles(find(labels == "CITd", 1)).MarkerFaceColor, 'none'));
assert(isequal(state.NodeHandles(find(labels == "TRN", 1)).MarkerFaceColor, 'none'));

state.SizeGroup.SelectedObject = state.StrengthButtons(1); % afferent
callback(state.SizeGroup, []);
assertAreaLabelsFixed(state, originalLabels, 'afferent strength');
for area = ["basalfore", "pulvinar", "claustrum"]
    assert(isVisible(area), 'Missing afferent Bou92 area %s.', area);
end
for area = ["TRN", "striatum", "pretectum", "pons", "SC"]
    assert(~isVisible(area), 'Unexpected afferent Bou92 area %s.', area);
end
assert(isVisible("MT") && strcmp(basalEdge.Visible, 'on'));
assert(abs(sizeOf("MT") - (0.75 * 18.5)^2) < 1e-9);
assert(abs(sizeOf("VIP") - (0.75 * 12)^2) < 1e-9);
assert(abs(sizeOf("V3d") - (0.75 * 9)^2) < 1e-9);
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = 1;
end
runCallback(state.CheckBoxes(1));
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'uniform'));
assertAreaLabelsFixed(state, originalLabels, 'return to no scaling');
end

function verifyConflictColorToggle(fig, stateName)
state = getappdata(fig, stateName);
colorNote = findall(state.ColorGroup, 'Style', 'text');
assert(numel(colorNote) == 1);
assert(isequal(colorNote, state.ConflictCaption));
assert(strcmp(state.ConflictButton.String, 'Conflicting studies'));
noteLines = strtrim(splitlines(strjoin(string(colorNote.String), newline)));
noteLines(noteLines == "") = [];
assert(strjoin(noteLines, " ") == ...
    "Black/Grey. Grey: A study explicitly reports no connection, whereas another reports a connection.");
assert(colorNote.Extent(3) <= colorNote.Position(3), ...
    'The conflict explanation extends beyond its control.');
assert(strcmp(colorNote.Visible, 'off'), ...
    'The conflict explanation should be hidden in pathway-color mode.');
assert(all(arrayfun(@(h) h.Value ~= 0, state.CheckBoxes)), ...
    'Conflict colors should be tested with all studies selected.');
assert(strcmp(state.ConflictButton.Enable, 'on'));
assert(strcmp(state.ColorGroup.SelectedObject.Tag, 'pathway'), ...
    'Pathway colors should be the default.');
if strcmp(stateName, 'StudySelectorState')
    greyLabel = "FEF";
    blackLabel = "VIP";
else
    greyLabel = "PMd";
    blackLabel = "VIP";
end
labels = string(state.NodeLabels);
greyIndex = find(labels == greyLabel, 1);
blackIndex = find(labels == blackLabel, 1);
seedIndex = find(labels == "FST", 1);
assert(~isempty(greyIndex) && ~isempty(blackIndex) && ...
    state.GreyConflictDots(greyIndex) && ...
    ~state.GreyConflictDots(blackIndex));
grey = state.NodeHandles(greyIndex);
black = state.NodeHandles(blackIndex);
seed = state.NodeHandles(seedIndex);
assert(strcmp(grey.Visible, 'on') && strcmp(black.Visible, 'on'));
pathwayEdge = grey.MarkerEdgeColor;
originalSizeMode = string(state.SizeGroup.SelectedObject.Tag);
originalSize = grey.SizeData;
state.ColorGroup.SelectedObject = state.ConflictButton;
callback = state.ColorGroup.SelectionChangedFcn;
callback(state.ColorGroup, []);
assert(strcmp(colorNote.Visible, 'on'), ...
    'The conflict explanation should appear in conflicting-studies mode.');
assert(colorNote.Extent(3) <= colorNote.Position(3) && ...
    colorNote.Extent(4) <= colorNote.Position(4), ...
    'The selected conflict explanation must fit inside its text control: extent %s, position %s.', ...
    mat2str(colorNote.Extent), mat2str(colorNote.Position));
assert(colorNote.Position(2) > 0 && ...
    colorNote.Position(2) + colorNote.Position(4) < ...
    state.ConflictButton.Position(2) && ...
    state.ColorGroup.Position(2) >= ...
    state.SizeGroup.Position(2) + state.SizeGroup.Position(4), ...
    'The conflict explanation overlaps an option or the Dot size box.');
for marker = [grey, black]
    rows = marker.DataTipTemplate.DataTipRows;
    values = strings(numel(rows), 1);
    for row = 1:numel(rows)
        values(row) = string(rows(row).Value);
    end
    assert(~contains(strjoin(values, " "), ...
        "Grey: A study explicitly reports no connection"), ...
        'Dot data tips should not repeat the Dot color explanation.');
end
assert(strcmp(state.SizeGroup.SelectedObject.Tag, originalSizeMode), ...
    'Dot color changed the dot-size selection.');
assert(grey.SizeData == originalSize, ...
    'Dot color changed a dot size.');
assert(max(abs(grey.MarkerEdgeColor - [166, 166, 166] / 255)) < 1e-9, ...
    'Conflicting dot did not become grey.');
assert(isequal(black.MarkerEdgeColor, [0, 0, 0]) && ...
    isequal(seed.MarkerFaceColor, [0, 0, 0]), ...
    'Nonconflicting dots and FST should become black.');
if originalSizeMode == "studycount"
    assert(~isequal(grey.MarkerFaceColor, 'none') && ...
        ~isequal(black.MarkerFaceColor, 'none'), ...
        'Study-count dots must stay filled in conflict colors.');
elseif strcmp(stateName, 'HumanStudySelectorState')
    assert(isequal(grey.MarkerFaceColor, 'none') && ...
        isequal(black.MarkerFaceColor, 'none'), ...
        'Human connection dots must stay open in conflict colors.');
else
    assert(isequal(grey.MarkerFaceColor, 'none') && ...
        isequal(black.MarkerFaceColor, 'none'), ...
        'Uniform macaque dots should remain open.');
end
state.ColorGroup.SelectedObject = state.PathwayButton;
callback(state.ColorGroup, []);
assert(strcmp(colorNote.Visible, 'off') && ...
    isequal(grey.MarkerEdgeColor, pathwayEdge), ...
    'Returning to pathway colors should hide the conflict explanation.');
state.ColorGroup.SelectedObject = state.ConflictButton;
callback(state.ColorGroup, []);
assert(strcmp(colorNote.Visible, 'on'));
subsetIndex = 1;
if strcmp(stateName, 'StudySelectorState')
    % An individual scored paper is redundant with Combined; remove the
    % Combined choice so this subset truly omits source papers.
    subsetIndex = find(state.Studies.code == "mixed_tracer", 1);
end
state.CheckBoxes(subsetIndex).Value = 0;
runCallback(state.CheckBoxes(subsetIndex));
assert(strcmp(state.ConflictButton.Enable, 'off') && ...
    strcmp(state.ColorGroup.SelectedObject.Tag, 'pathway'), ...
    'A study subset must reset conflict colors to pathway colors.');
assert(strcmp(colorNote.Visible, 'off'), ...
    'A study subset should hide the conflict explanation.');
assert(isequal(grey.MarkerEdgeColor, pathwayEdge));
state.CheckBoxes(subsetIndex).Value = 1;
runCallback(state.CheckBoxes(subsetIndex));
assert(strcmp(state.ConflictButton.Enable, 'on') && ...
    strcmp(state.ColorGroup.SelectedObject.Tag, 'pathway'));
if originalSizeMode == "studycount"
    state.SizeGroup.SelectedObject = state.CountButton;
    sizeCallback = state.SizeGroup.SelectionChangedFcn;
    sizeCallback(state.SizeGroup, []);
end
end

function verifySwitch(fig, cache, originalPosition, species, priorFigureCount)
assert(isgraphics(fig, 'figure'), 'Species switch destroyed the figure.');
assert(numel(findall(groot, 'Type', 'figure')) == priorFigureCount + 1, ...
    'Species switch opened an extra figure.');
assert(isequal(fig.Position, originalPosition), ...
    'Species switch changed the window size or position.');
newCache = verifyCache(fig);
assert(isequal(newCache.macaque, cache.macaque) && ...
    isequal(newCache.human, cache.human), ...
    'Species switch rebuilt or replaced a cached view.');
verifyActiveView(fig, cache, species);
assert(contains(lower(string(fig.Name)), species));
end

function verifyHumanFigure(fig)
state = getappdata(fig, 'HumanStudySelectorState');
assert(isstruct(state), 'Human study controls are missing.');
assert(strcmp(state.UniformButton.String, 'No scaling'));
if strcmp(state.SizeGroup.SelectedObject.Tag, 'uniform') && ...
        all(arrayfun(@(h) h.Value ~= 0, state.CheckBoxes))
    assert(isempty(char(state.SizeNote.String)), ...
        'The all-studies human view should not show no-scaling guidance.');
end
assert(isequal(state.SizeNote.Parent, state.SizeGroup) && ...
    isequal(state.CountLegend.Parent, state.SizeGroup), ...
    'Human dot-size guidance and legend must be inside the Dot size box.');
for k = 1:numel(state.NodeLabels)
    if state.NodeLabels(k) == "FST"
        assert(~isequal(state.NodeHandles(k).MarkerFaceColor, 'none'), ...
            'The human FST seed must stay filled.');
    elseif strcmp(state.NodeHandles(k).Visible, 'on')
        if strcmp(state.SizeGroup.SelectedObject.Tag, 'studycount')
            assert(~isequal(state.NodeHandles(k).MarkerFaceColor, 'none'), ...
                'Human study-count dots must be filled.');
        else
            assert(isequal(state.NodeHandles(k).MarkerFaceColor, 'none'), ...
                'Human no-scaling dots must be open.');
        end
    end
end
colorPosition = state.ColorGroup.Position;
sizePosition = state.SizeGroup.Position;
statusPosition = state.Status.Position;
pathwayPosition = state.PathwayButton.Position;
assert(colorPosition(2) >= sizePosition(2) + sizePosition(4) + 8 && ...
    colorPosition(2) + colorPosition(4) <= statusPosition(2) - 8, ...
    'Human Dot color must sit between the status and Dot size without overlap.');
assert(colorPosition(4) - pathwayPosition(2) - pathwayPosition(4) >= 24, ...
    'Human Dot color title needs clearance above its first option.');
labels = string(state.NodeLabels);
index = find(labels == "LO1-3");
assert(numel(index) == 1, 'Human LO1-3 must have one node.');
assert(~any(ismember(labels, ["LO1", "LO2", "LO3"])));
marker = state.NodeHandles(index);
assert(isgraphics(marker, 'scatter') && ...
    isscalar(marker.XData) && isscalar(marker.YData));
ax = ancestor(marker, 'axes');
markers = findall(ax, 'Type', 'scatter');
atSamePosition = 0;
for k = 1:numel(markers)
    if isscalar(markers(k).XData) && isscalar(markers(k).YData) && ...
            abs(markers(k).XData - marker.XData) < 1e-9 && ...
            abs(markers(k).YData - marker.YData) < 1e-9
        atSamePosition = atSamePosition + 1;
    end
end
assert(atSamePosition == 1, 'LO1-3 has overlapping duplicate dots.');
areaText = findall(ax, 'Type', 'text');
matches = arrayfun(@(h) isequal(strtrim(string(h.String)), "LO1-3"), areaText);
assert(nnz(matches) == 1, 'LO1-3 must have one visible area label.');
end

function verifyHumanCount(fig, view)
state = getappdata(fig, 'HumanStudySelectorState');
originalLabels = areaLabelPositions(state);
assert(strcmp(state.CountButton.Enable, 'on'));
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'uniform'));
assert(isempty(char(state.SizeNote.String)));
index = find(string(state.NodeLabels) == "LO1-3", 1);
uniformSize = state.NodeHandles(index).SizeData;
state.SizeGroup.SelectedObject = state.CountButton;
callback = state.SizeGroup.SelectionChangedFcn;
callback(state.SizeGroup, []);
assertAreaLabelsFixed(state, originalLabels, 'human study count');
assert(strcmp(state.CountLegend.Visible, 'on'));
assert(~any(contains(string(state.SizeNote.String), ...
    'Select all to size them by reporting studies.')));
assert(~isequal(state.NodeHandles(index).MarkerFaceColor, 'none'));
legendMarkers = findall(state.CountLegend, 'Type', 'scatter');
assert(~isempty(legendMarkers) && all(arrayfun(@(h) ...
    ~isequal(h.MarkerFaceColor, 'none'), legendMarkers)), ...
    'Human study-count legend dots must be filled.');
assert(state.NodeHandles(index).SizeData == (0.75 * 10)^2, ...
    'LO1-3 should count Baker and Rolls once each.');
assert(state.NodeHandles(index).SizeData > uniformSize);
state.CheckBoxes(1).Value = 0;
runCallback(state.CheckBoxes(1));
assertAreaLabelsFixed(state, originalLabels, 'human study subset');
assert(strcmp(state.CountButton.Enable, 'off'));
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'uniform'));
assert(strcmp(state.CountLegend.Visible, 'off'));
assert(strcmp(state.SizeNote.String, ...
    'Select all to size them by reporting studies.'));
runCallback(findButton(view, 'Select all'));
assert(isempty(char(state.SizeNote.String)), ...
    'Selecting all studies should hide the Select all instruction.');
state.SizeGroup.SelectedObject = state.CountButton;
callback(state.SizeGroup, []);
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'studycount'));
assert(~any(contains(string(state.SizeNote.String), ...
    'Select all to size them by reporting studies.')));
assertAreaLabelsFixed(state, originalLabels, 'human study count restored');
end

function verifyMacaqueCount(fig)
state = getappdata(fig, 'StudySelectorState');
originalLabels = areaLabelPositions(state);
assert(strcmp(state.UniformButton.String, 'No scaling'));
assert(isequal(state.Note.Parent, state.SizeGroup) && ...
    isequal(state.Guidance.Parent, state.SizeGroup) && ...
    isequal(state.StrengthLegend.Parent, state.SizeGroup) && ...
    isequal(state.NumericStrengthLegend.Parent, state.SizeGroup) && ...
    isequal(state.CountLegend.Parent, state.SizeGroup), ...
    'Macaque dot-size guidance and legends must be inside one box.');
assert(strcmp(state.Guidance.String, ...
    'Select one study to size dots by connection strength.'), ...
    'The one-study instruction is missing.');
legendPanels = [state.StrengthLegend, state.NumericStrengthLegend, ...
    state.CountLegend];
for legendPanel = legendPanels
    assert(state.Guidance.Position(2) + state.Guidance.Position(4) < ...
        legendPanel.Position(2) && ...
        legendPanel.Position(2) + legendPanel.Position(4) < ...
        state.Note.Position(2), ...
        'The guidance must sit below the legend and its mode note.');
end
assert(state.Note.Position(2) + state.Note.Position(4) < ...
    state.CountButton.Position(2), ...
    'The mode note overlaps the study-count choice.');
for key = [state.StrengthLegend, state.NumericStrengthLegend]
    assert(any(legendText(key) == "No connection strength reported (open)"), ...
        'The MATLAB strength legend must use the full open-circle description.');
end
assertLegendTextFits(state.StrengthLegend);
combined = find(state.Studies.code == "mixed_tracer", 1);
assert(~isempty(combined) && ...
    strcmp(state.Studies.label(combined), "Combined tracer evidence"));
expectedCodes = ["And90"; "Bou90"; "Bou92"; "Sel96"; ...
    "Fel97"; "Bar00"; "Ung08"; "Mark14"];
expectedNames = ["Andersen et al. (1990)"; ...
    "Boussaoud et al. (1990)"; "Boussaoud et al. (1992)"; ...
    "Seltzer et al. (1996)"; "Felleman et al. (1997)"; ...
    "Barone et al. (2000)"; "Ungerleider et al. (2008)"; ...
    "Markov et al. (2014)"];
assert(isequal(state.Studies.codes{combined}, expectedCodes), ...
    'Combined tracer evidence must include all eight source papers.');
detail = findall(state.CheckBoxes(combined).Parent, ...
    'Tag', 'CombinedTracerStudyList');
assert(numel(detail) == 2, 'Combined papers should fit in two columns.');
[~, order] = sort(arrayfun(@(h) h.Position(1), detail));
detail = detail(order);
actualNames = strings(0, 1);
for column = 1:2
    actualNames = [actualNames; splitlines(string(detail(column).String))]; %#ok<AGROW>
end
actualNames = strtrim(actualNames(:));
actualNames(actualNames == "") = [];
assert(isequal(actualNames, expectedNames), ...
    'Combined tracer paper names should appear without repeated method prefixes.');
for column = 1:2
    assert(detail(column).Position(2) + detail(column).Position(4) <= ...
        state.CheckBoxes(combined).Position(2) && ...
        detail(column).Position(2) > state.ColorGroup.Position(2) + ...
        state.ColorGroup.Position(4) && ...
        detail(column).Position(1) + detail(column).Position(3) <= ...
        state.CheckBoxes(combined).Parent.Position(3), ...
        'Combined paper names must fit between the option and Dot color.');
    assert(detail(column).Extent(3) <= detail(column).Position(3) + 1, ...
        'Combined paper text is clipped horizontally.');
end
assert(detail(1).Position(1) + detail(1).Position(3) < ...
    detail(2).Position(1), 'Combined paper columns overlap.');
state.SizeGroup.SelectedObject = state.CountButton;
callback = state.SizeGroup.SelectionChangedFcn;
callback(state.SizeGroup, []);
assert(~any(contains(string(state.Note.String), ...
    'Counts distinct papers with a positive connection.')), ...
    'The redundant study-count sentence should be removed.');
assertAreaLabelsFixed(state, originalLabels, 'macaque study count');
assert(strcmp(state.CountLegend.Visible, 'on'));
for label = ["basalfore", "SC", "pulvinar", "TRN"]
    index = find(state.NodeLabels == label, 1);
    assert(~isempty(index) && strcmp(state.NodeHandles(index).Visible, 'on') && ...
        ~isequal(state.NodeHandles(index).MarkerFaceColor, 'none'), ...
        'The %s study-count dot must be filled.', label);
end
legendMarkers = findall(state.CountLegend, 'Type', 'scatter');
assert(~isempty(legendMarkers) && all(arrayfun(@(h) ...
    ~isequal(h.MarkerFaceColor, 'none'), legendMarkers)), ...
    'Macaque study-count legend dots must be filled.');
state.SizeGroup.SelectedObject = state.UniformButton;
callback(state.SizeGroup, []);
assertAreaLabelsFixed(state, originalLabels, 'macaque no scaling');
assert(strcmp(state.StrengthLegend.Visible, 'off') && ...
    strcmp(state.NumericStrengthLegend.Visible, 'off') && ...
    strcmp(state.CountLegend.Visible, 'off'));
end

function verifyMacaqueCombinedOverlap(fig)
state = getappdata(fig, 'StudySelectorState');
combined = find(state.Studies.code == "mixed_tracer", 1);
boussaoud = find(state.Studies.code == "Bou90+Bou92", 1);
markov = find(state.Studies.code == "Mark14", 1);
assert(isscalar(combined) && isscalar(boussaoud) && isscalar(markov), ...
    'Combined, Boussaoud, and Markov must each have a choice.');
assert(all(ismember(["Bou90"; "Bou92"; "Mark14"], ...
    state.Studies.codes{combined})), ...
    'Combined must include both Boussaoud papers and Markov.');
refresh = state.CheckBoxes(1).Callback;
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = k == combined;
end
refresh(state.CheckBoxes(1), []);
assert(all(arrayfun(@(h) strcmp(h.Enable, 'off'), ...
    state.StrengthButtons)), ...
    'Combined alone must not unlock one-study strength scaling.');
assert(strcmp(state.CountButton.Enable, 'off'));
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'uniform'));
assert(contains(string(state.Status.String), '(8 papers)'), ...
    'Combined selection should represent eight distinct papers.');
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = 1;
end
refresh(state.CheckBoxes(1), []);
state.SizeGroup.SelectedObject = state.CountButton;
sizeRefresh = state.SizeGroup.SelectionChangedFcn;
sizeRefresh(state.SizeGroup, []);
allSizes = arrayfun(@(h) h.SizeData, state.NodeHandles);
allVisible = string(arrayfun(@(h) h.Visible, state.NodeHandles, ...
    'UniformOutput', false));
allPapers = numel(unique(vertcat(state.Studies.codes{:})));
assert(contains(string(state.Status.String), ...
    "(" + allPapers + " papers)"));
state.CheckBoxes(boussaoud).Value = 0;
state.CheckBoxes(markov).Value = 0;
refresh(state.CheckBoxes(1), []);
assert(strcmp(state.CountButton.Enable, 'on') && ...
    strcmp(state.ConflictButton.Enable, 'on') && ...
    strcmp(state.SizeGroup.SelectedObject.Tag, 'studycount'), ...
    'Combined must cover all distinct papers without redundant checkboxes.');
assert(isequal(allSizes, arrayfun(@(h) h.SizeData, state.NodeHandles)) && ...
    isequal(allVisible, string(arrayfun(@(h) h.Visible, ...
    state.NodeHandles, 'UniformOutput', false))), ...
    'Overlapping options must not duplicate reporting-study counts.');
assert(contains(string(state.Status.String), ...
    "(" + allPapers + " papers)"), ...
    'The selected paper count must ignore overlapping choices.');
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = k == boussaoud;
end
refresh(state.CheckBoxes(1), []);
assert(strcmp(state.CountButton.Enable, 'off') && ...
    any(arrayfun(@(h) strcmp(h.Enable, 'on'), ...
    state.StrengthButtons)), ...
    'The individual Boussaoud choice must retain strength scaling.');
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = 1;
end
refresh(state.CheckBoxes(1), []);
end

function positions = areaLabelPositions(state)
positions = struct;
positions.Text = zeros(numel(state.TextHandles), 3);
for k = 1:numel(state.TextHandles)
    positions.Text(k, :) = state.TextHandles(k).Position;
end
ax = ancestor(state.TextHandles(1), 'axes');
positions.AxisPosition = ax.Position;
positions.XLim = ax.XLim;
positions.YLim = ax.YLim;
positions.XDir = ax.XDir;
positions.YDir = ax.YDir;
positions.DataAspectRatio = ax.DataAspectRatio;
end

function assertAreaLabelsFixed(state, originalPositions, mode)
assert(isequal(areaLabelPositions(state), originalPositions), ...
    'Area labels moved when changing %s.', mode);
end

function labels = legendText(legendPanel)
textHandles = findall(legendPanel, 'Type', 'text');
labels = strings(numel(textHandles), 1);
for k = 1:numel(textHandles)
    labels(k) = string(textHandles(k).String);
end
end

function assertLegendTextFits(legendPanel)
drawnow;
textHandles = findall(legendPanel, 'Type', 'text');
for k = 1:numel(textHandles)
    label = textHandles(k);
    if strlength(string(label.String)) == 0
        continue
    end
    ax = ancestor(label, 'axes');
    bounds = label.Extent;
    xBounds = xlim(ax);
    yBounds = ylim(ax);
    assert(bounds(1) >= xBounds(1) - 1 && ...
        bounds(1) + bounds(3) <= xBounds(2) + 1 && ...
        bounds(2) >= yBounds(1) - 1 && ...
        bounds(2) + bounds(4) <= yBounds(2) + 1, ...
        'Legend text "%s" is clipped by its axes.', string(label.String));
end
end

function assertNumericLegendReadable(legendPanel)
% The three anchor scores and the open-circle explanation must fit without
% touching one another. Intermediate scores still size real data points.
expected = sort(["1 (weak)"; "2 (moderate)"; "3 (strong)"; ...
    "No connection strength reported (open)"]);
actual = legendText(legendPanel);
actual(strlength(actual) == 0) = [];
assert(isequal(sort(actual), expected), ...
    'The numeric legend should list only scores 1, 2, 3, and no strength.');
ax = findall(legendPanel, 'Type', 'axes');
assert(isscalar(ax));
markers = findall(ax, 'Type', 'scatter');
assert(numel(markers) == 4, 'Expected four numeric legend markers.');
drawnow;
scaleX = ax.Position(3) / diff(ax.XLim);
scaleY = ax.Position(4) / diff(ax.YLim);
pixelsPerPoint = get(groot, 'ScreenPixelsPerInch') / 72;
radii = arrayfun(@(h) sqrt(h.SizeData) * pixelsPerPoint / 2, markers);
for k = 1:numel(markers)
    x = markers(k).XData;
    y = markers(k).YData;
    radius = radii(k);
    assert(x * scaleX - radius >= 0 && ...
        (ax.XLim(2) - x) * scaleX - radius >= 0 && ...
        y * scaleY - radius >= 0 && ...
        (ax.YLim(2) - y) * scaleY - radius >= 0, ...
        'A numeric legend marker is clipped by the axes.');
    for j = k + 1:numel(markers)
        distance = hypot((x - markers(j).XData) * scaleX, ...
            (y - markers(j).YData) * scaleY);
        assert(distance >= radius + radii(j) + 2, ...
            'Numeric legend marker circles overlap.');
    end
end
labels = findall(ax, 'Type', 'text');
labels = labels(arrayfun(@(h) strlength(string(h.String)) > 0, labels));
for k = 1:numel(labels)
    one = labels(k).Extent;
    for j = k + 1:numel(labels)
        two = labels(j).Extent;
        separated = one(1) + one(3) + 1 < two(1) || ...
            two(1) + two(3) + 1 < one(1) || ...
            one(2) + one(4) + 1 < two(2) || ...
            two(2) + two(4) + 1 < one(2);
        assert(separated, 'Numeric legend labels overlap.');
    end
end
end

function verifyStudyFilters(fig, view, stateName)
state = getappdata(fig, stateName);
assert(isstruct(state) && ~isempty(state.CheckBoxes));
panel = findall(view, 'Type', 'uipanel', ...
    'Title', 'Show results from studies');
assert(numel(panel) == 1);
onlyButtons = findall(panel, 'Style', 'pushbutton', 'String', 'Only');
[~, order] = sort(arrayfun(@(h) h.Position(2), onlyButtons), 'descend');
onlyButtons = onlyButtons(order);
assert(all(isgraphics(state.CheckBoxes)) && ...
    numel(onlyButtons) == numel(state.CheckBoxes));

for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = 0;
end
runCallback(state.CheckBoxes(1));
visible = arrayfun(@(h) strcmp(h.Visible, 'on'), state.NodeHandles);
seed = find(string(state.NodeLabels) == "FST");
assert(numel(seed) == 1 && visible(seed) && nnz(visible) == 1, ...
    'Clear should leave only FST visible.');
assert(all(arrayfun(@(h) strcmp(h.Visible, 'off'), state.EdgeHandles)), ...
    'Clear should hide every edge.');

positiveGrades = ["weak", "moderate", "strong", "present", "broad"];
candidate = [];
for k = 1:numel(onlyButtons)
    reports = state.Events(ismember(state.Events.study, ...
        state.Studies.codes{k}), :);
    if any(ismember(reports.grade, positiveGrades))
        candidate = k;
        break
    end
end
assert(~isempty(candidate), 'No study with a positive FST connection.');
runCallback(onlyButtons(candidate));
assert(nnz(arrayfun(@(h) h.Value ~= 0, state.CheckBoxes)) == 1);
visible = arrayfun(@(h) strcmp(h.Visible, 'on'), state.NodeHandles);
assert(nnz(visible) > 1, 'Only did not restore study-specific nodes.');

selectAll = findall(panel, 'Style', 'pushbutton', ...
    'String', 'Select all');
assert(numel(selectAll) == 1);
runCallback(selectAll);
assert(all(arrayfun(@(h) h.Value ~= 0, state.CheckBoxes)));
if strcmp(stateName, 'HumanStudySelectorState')
    index = find(string(state.NodeLabels) == "LO1-3");
    assert(strcmp(state.NodeHandles(index).Visible, 'on'), ...
        'Selecting all human studies did not show LO1-3.');
end
end

function switchSpecies(fig, value)
cache = getappdata(fig, 'ConnectivityViewCache');
activeSpecies = string(getappdata(fig, 'ConnectivitySpecies'));
popup = findall(cache.(char(activeSpecies)), ...
    'Tag', 'ConnectivitySpeciesSelector');
assert(numel(popup) == 1, 'Expected one Macaque/Human species popup.');
popup.Value = value;
runCallback(popup);
drawnow;
end

function button = findButton(view, caption)
buttons = findall(view, 'Style', 'pushbutton', ...
    'String', caption);
assert(numel(buttons) == 1, 'Expected one %s button.', caption);
button = buttons(1);
end

function runCallback(control)
callback = control.Callback;
assert(~isempty(callback), 'Control callback is missing.');
if iscell(callback)
    feval(callback{1}, control, [], callback{2:end});
else
    feval(callback, control, []);
end
drawnow;
end

function verifyNoCornerLetters(fig)
labels = findall(fig, 'Type', 'text');
for k = 1:numel(labels)
    content = strtrim(string(labels(k).String));
    assert(~any(ismember(content, ["(A)", "(B)"])), ...
        'A corner panel letter is still present.');
end
end

function closeFigureIfValid(fig)
if isgraphics(fig, 'figure')
    close(fig);
end
end
