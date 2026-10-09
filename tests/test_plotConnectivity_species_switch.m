%TEST_PLOTCONNECTIVITY_SPECIES_SWITCH Check the two cached FST views.
% Run from the repository root: run('tests/test_plotConnectivity_species_switch.m')
% Uses temporary output and closes its figures. When testing staged code,
% set FST_CONNECTIVITY_DATA_PATH to the repository containing the CSV/TIFFs.

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
    OutputDir=string(outputDir), Species="human", MainROI="FST", ...
    NodesOnly=false, StudySelector=true, WriteTables=false, ...
    ExportPDF=false, SaveFigure=false, Visible="off");
fig = result.Figure;
figureCleanup = onCleanup(@() closeFigureIfValid(fig)); %#ok<NASGU>
assert(isgraphics(fig, 'figure'));
assert(numel(findall(groot, 'Type', 'figure')) == priorFigureCount + 1);
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
verifyNoCornerLetters(fig);

switchSpecies(fig, 1); % Macaque
verifySwitch(fig, cache, originalPosition, "macaque", priorFigureCount);
verifyStudyFilters(fig, cache.macaque, 'StudySelectorState');
verifyUniformOpen(fig);
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

% The saved FIG must retain both views and their working switch callbacks.
savedFigurePath = fullfile(outputDir, 'species_switch_roundtrip.fig');
savefig(fig, savedFigurePath);
reopened = openfig(savedFigurePath, 'invisible');
reopenedCleanup = onCleanup(@() closeFigureIfValid(reopened)); %#ok<NASGU>
reopenedCache = verifyCache(reopened);
verifyActiveView(reopened, reopenedCache, "macaque");
savedPosition = reopened.Position;
switchSpecies(reopened, 2);
verifySwitch(reopened, reopenedCache, savedPosition, "human", ...
    priorFigureCount + 1);
verifyHumanFigure(reopened);

fprintf(['PASS: LO1-3, matching 1835-by-820 windows, centered human axes, ' ...
    'cached same-figure switches, retained study filters, saved FIG, ' ...
    'and no panel letters.\n']);
fprintf('Temporary output: %s\n', outputDir);

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
assert(any(humanLabels == "SMA") && ~any(humanLabels == "SEF"), ...
    'Updated human SMA label did not replace SEF.');

mac = getappdata(fig, 'StudySelectorState');
macLabels = string(mac.NodeLabels);
assert(all(ismember(["V3", "V3d"], macLabels)), ...
    'V3 and V3d should retain their distinct evidence and dot positions.');
ruan = mac.Events(mac.Events.study == "Rua25", :);
assert(any(ruan.target == "V3d") && ~any(ruan.target == "V3"), ...
    'Ruan (2025) should now report V3d, not V3.');
fel91 = mac.Events(mac.Events.study == "Fel91", :);
assert(any(fel91.target == "V3"), ...
    'The direct Felleman (1991) V3 pathway should remain available.');
assert(any(mac.EdgeTargets == "V3"), ...
    'The direct Felleman V3 pathway should retain an edge.');
assert(all(ismember(["V3d", "A1", "BA23", "BA31", "pulvinar", "TRN"], ...
    macLabels)), 'Updated macaque areas are missing.');
assert(~any(ismember(["VOT/TEO", "SEF", "STGp", "PCCa", "PCCp", ...
    "thalamus"], macLabels)), 'Old macaque FST area labels remain.');
names = ["A1", "BA23", "BA31", "pulvinar", "TRN"];
points = [268.6 156.4; 86.1 257.7; 47.1 281.7; ...
    394 306.7; 459 306.7];
for k = 1:numel(names)
    index = find(macLabels == names(k), 1);
    point = [mac.NodeHandles(index).XData, mac.NodeHandles(index).YData];
    assert(max(abs(point - points(k, :))) < 1e-9, ...
        'The current position changed for %s.', names(k));
end
for label = ["A1", "V3d"]
    index = find(macLabels == label, 1);
    assert(max(abs(mac.NodeHandles(index).MarkerEdgeColor)) < 1e-9, ...
        'The new area %s should use the neutral color.', label);
end
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
assert(strcmp(state.CountButton.Enable, 'on'));
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'uniform'));
index = find(string(state.NodeLabels) == "LO1-3", 1);
uniformSize = state.NodeHandles(index).SizeData;
uniformLabelY = state.TextHandles(index).Position(2);
state.SizeGroup.SelectedObject = state.CountButton;
callback = state.SizeGroup.SelectionChangedFcn;
callback(state.SizeGroup, []);
assert(strcmp(state.CountLegend.Visible, 'on'));
assert(state.NodeHandles(index).SizeData == (0.75 * 10)^2, ...
    'LO1-3 should count Baker and Rolls once each.');
assert(state.NodeHandles(index).SizeData > uniformSize);
assert(state.TextHandles(index).Position(2) < uniformLabelY);
state.CheckBoxes(1).Value = 0;
runCallback(state.CheckBoxes(1));
assert(strcmp(state.CountButton.Enable, 'off'));
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'uniform'));
assert(strcmp(state.CountLegend.Visible, 'off'));
runCallback(findButton(view, 'Select all'));
state.SizeGroup.SelectedObject = state.CountButton;
callback(state.SizeGroup, []);
assert(strcmp(state.SizeGroup.SelectedObject.Tag, 'studycount'));
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
