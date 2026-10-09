function result = plotConnectivity(options)
%PLOTCONNECTIVITY Build and explore the connectivity diagram in MATLAB.
%   RESULT = plotConnectivity() opens a human FST figure over the lateral
%   TIFF rendered at 50% opacity, with pathway color carried by the dots.
%
%   RESULT = plotConnectivity(DataPath=ROOT, Species="human", MainROI="FST", ...)
%   reads ROOT/<species>/evidence.csv and nodes.csv. By default ROOT is the
%   folder containing this function. OutputDir defaults to ROOT. The function
%   writes <OutputDir>/<species>/edges.csv and selectnodes.csv, plus a MATLAB
%   .fig and PDF. HTML export for the new paper layout will follow later.
%   For macaque and human FST, StudySelector=true adds study controls and a
%   species menu that switches views in the same MATLAB figure window.
%   Study checkboxes control which reports are shown. The dot-size selector
%   can encode afferent, efferent, or unspecified connection strength.
%   The FST figures use one lateral brain image and compact inset boxes.
%   Dorsal, lateral, and ventral dot colors come from nodes.csv. Macaque
%   strength-based dot sizing requires one selected study and never averages
%   across studies. Uniform macaque connection dots are open because no
%   strength grade is displayed. Human FST dots are uniformly sized. Human LO1-LO3 share
%   one display dot while source evidence.csv keeps the three areas apart.
%
%   Examples:
%     plotConnectivity;
%     plotConnectivity(Species="human", NodesOnly=false);
%     plotConnectivity(Species="human", MainROI="MST", IncludeStudies="all", ...
%         OutputDir="C:\EM\Connectivity");
%     plotConnectivity(MainROI="MSTd");  % macaque labels are MSTd and MSTm
%
%   Click nodes in the MATLAB figure for evidence data tips. Human MST/MT
%   plots retain their previous surface layout.
%   Roicoarse, rotateon, and subcortical in the notebook have no implemented
%   behavior and are therefore omitted here.

arguments
    options.DataPath (1,1) string = ""
    options.OutputDir (1,1) string = ""
    options.Species (1,1) string = "human"
    options.MainROI (1,1) string = "FST"
    options.IncludeStudies string = "default"
    options.EdgeWeight (1,1) string = "evidencecount"
    options.EdgeColor (1,1) string = "hierarchy"
    options.NodeSizeSource (1,1) string = "auto"
    options.NodesOnly (1,1) logical = true
    options.DisplayBrain (1,1) logical = true
    options.Medial (1,1) logical = true
    options.RemoveUnconnectedNodes (1,1) logical = true
    options.StudySelector (1,1) logical = true
    options.ExportPDF (1,1) logical = true
    options.ExportHTML (1,1) logical = false
    options.SaveFigure (1,1) logical = true
    options.WriteTables (1,1) logical = true
    options.Visible (1,1) string = "on"
    options.ReuseFigure = []
    options.PreloadSpecies (1,1) logical = true
    options.ActivateView (1,1) logical = true
end

species = lower(options.Species);
roi = options.MainROI;
paperMode = species == "macaque" || ...
    (species == "human" && strcmpi(roi, "FST"));
mustBeMember(species, ["macaque", "human"]);
mustBeMember(options.EdgeWeight, ["evidencecount", "connectivitystrength"]);
mustBeMember(options.EdgeColor, ["hierarchy", "projections"]);
mustBeMember(options.NodeSizeSource, ...
    ["auto", "uniform", "connectionstrength", "tracer_strength", "edgeweight"]);
mustBeMember(options.Visible, ["on", "off"]);

dataPath = options.DataPath;
if dataPath == ""
    dataPath = string(fileparts(mfilename('fullpath')));
end
outputDir = options.OutputDir;
if outputDir == ""
    outputDir = dataPath;
end
speciesDir = fullfile(dataPath, species);
outputSpeciesDir = fullfile(outputDir, species);
if ~isfolder(speciesDir)
    error('plotConnectivity:MissingSpeciesDir', 'Missing data folder: %s', speciesDir);
end
if options.WriteTables && ~isfolder(outputSpeciesDir)
    mkdir(outputSpeciesDir);
end

nodeSizeSource = options.NodeSizeSource;
if nodeSizeSource == "auto"
    if paperMode
        nodeSizeSource = "uniform";
    else
        nodeSizeSource = "edgeweight";
    end
end
if paperMode && ismember(nodeSizeSource, ["tracer_strength", "edgeweight"])
    nodeSizeSource = "connectionstrength";
end

evidence = readtable(fullfile(speciesDir, 'evidence.csv'), ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
nodes = readtable(fullfile(speciesDir, 'nodes.csv'), ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
if species == "human" && strcmpi(roi, "FST")
    [nodes, evidence] = mergeHumanLOAreas(nodes, evidence);
end
allLabels = cleanColumn(nodes, "label");
allIDs = numericColumn(nodes, "id");
seedIndex = find(strcmpi(allLabels, roi), 1);
if isempty(seedIndex)
    error('plotConnectivity:MissingROI', '%s is missing from %s/nodes.csv.', roi, species);
end
roi = allLabels(seedIndex);
seedID = allIDs(seedIndex);
enableStudySelector = options.StudySelector && roi == "FST";
if species == "macaque" && roi == "FST"
    evidence = correctLegacyFSTEvidence(evidence);
end

studyTypes = cleanColumn(evidence, "study_type");
studies = options.IncludeStudies;
studies(studies == "functional inactivation") = "inactivation";
if isscalar(studies) && studies == "default"
    if species == "macaque"
        studies = ["tracer", "DTI tractography", "inactivation"];
    else
        studies = ["DTI tractography", "rs-fMRI"];
    end
end
inROI = cleanColumn(evidence, "Main") == roi;
if isscalar(studies) && studies == "all"
    keepEvidence = inROI & studyTypes ~= "";
else
    keepEvidence = inROI & ismember(studyTypes, studies);
end
evidence = evidence(keepEvidence, :);
if isempty(evidence)
    warning('plotConnectivity:NoEvidence', ...
        'No evidence rows match %s %s and the requested study types.', species, roi);
end

affiliate = cleanColumn(evidence, "Affiliate");
toAffiliate = lower(cleanColumn(evidence, "1_main_to_affiliate_projection"));
toMain = lower(cleanColumn(evidence, "2_affiliate_to_main_projection"));
positiveRow = ~((toAffiliate == "" | toAffiliate == "absent") & ...
    (toMain == "" | toMain == "absent"));
edgeTargets = unique(affiliate(positiveRow & affiliate ~= ""), 'sorted');
fel91Targets = strings(0, 1);
if enableStudySelector && species == "macaque"
    fel91 = readtable(fullfile(speciesDir, 'fel91_fst_connections.csv'), ...
        'TextType', 'string', 'VariableNamingRule', 'preserve');
    fromArea = cleanColumn(fel91, "from_area");
    toArea = cleanColumn(fel91, "to_area");
    fel91Targets = unique([toArea(fromArea == roi); ...
        fromArea(toArea == roi)], 'sorted');
    fel91Targets = fel91Targets(ismember(fel91Targets, allLabels));
end
edgeTargets = unique([edgeTargets; fel91Targets], 'sorted');
missingTargets = edgeTargets(~ismember(edgeTargets, allLabels));
if ~isempty(missingTargets)
    warning('plotConnectivity:MissingAffiliates', ...
        'Skipping affiliates without coordinates in %s/nodes.csv: %s', ...
        species, strjoin(missingTargets, ', '));
    edgeTargets = edgeTargets(ismember(edgeTargets, allLabels));
end

edgeCount = numel(edgeTargets);
source = repmat(seedID, edgeCount, 1);
targetid = zeros(edgeCount, 1);
targetname = edgeTargets(:);
evidencecount = zeros(edgeCount, 1);
projections = strings(edgeCount, 1);
connectivitystrength = strings(edgeCount, 1);
certainty = strings(edgeCount, 1);
hierarchy = strings(edgeCount, 1);

for k = 1:edgeCount
    label = edgeTargets(k);
    nodeIndex = find(allLabels == label, 1);
    targetid(k) = allIDs(nodeIndex);
    group = affiliate == label;
    evidencecount(k) = nnz(group & positiveRow);
    [sendStrength, sendCertainty] = summarizeDirection(toAffiliate(group), false);
    [receiveStrength, receiveCertainty] = summarizeDirection(toMain(group), false);
    if sendStrength ~= "" && receiveStrength ~= ""
        projections(k) = "bidirectional";
    elseif sendStrength ~= ""
        projections(k) = "mainsend";
    elseif receiveStrength ~= ""
        projections(k) = "mainreceive";
    end
    if projectionRank(sendStrength, false) >= projectionRank(receiveStrength, false)
        connectivitystrength(k) = sendStrength;
    else
        connectivitystrength(k) = receiveStrength;
    end
    if evidencecount(k) == 0 && any(fel91Targets == label)
        % The direct Felleman table can be the sole source for an area.
        % Preserve its V3 edge when Ruan's report moves to V3d.
        hasOut = any(fromArea == roi & toArea == label);
        hasIn = any(toArea == roi & fromArea == label);
        evidencecount(k) = 1;
        if hasOut && hasIn
            projections(k) = "bidirectional";
        elseif hasOut
            projections(k) = "mainsend";
        else
            projections(k) = "mainreceive";
        end
        connectivitystrength(k) = "present";
    end
    if sendCertainty == "conflicting" && receiveCertainty == "conflicting"
        certainty(k) = "conflicting";
    else
        certainty(k) = "certain";
    end
    levels = lower(cleanColumn(evidence(group, :), "hierarchichy_level_rel_to_main"));
    levels = levels(levels ~= "");
    if ~isempty(levels)
        candidates = unique(levels, 'stable');
        counts = arrayfun(@(s) nnz(levels == s), candidates);
        [~, winner] = max(counts);
        hierarchy(k) = candidates(winner);
    end
end
edges = table(source, targetid, targetname, evidencecount, projections, ...
    connectivitystrength, certainty, hierarchy);
edges = sortrows(edges, 'targetid');

commentColumn = roi + "comments";
comments = strings(height(nodes), 1);
ref1 = cleanColumn(evidence, "1_main_to_affiliate_ref");
ref2 = cleanColumn(evidence, "2_affiliate_to_main_ref");
for k = 1:height(nodes)
    rows = find(affiliate == allLabels(k));
    words = strings(0, 1);
    for j = rows(:)'
        cleaned = regexprep(ref1(j) + " " + ref2(j), '[^a-zA-Z0-9 ]', '');
        tokens = split(cleaned);
        words = [words; tokens(tokens ~= "")]; %#ok<AGROW>
    end
    if ~isempty(words)
        comments(k) = strjoin(unique(words, 'stable'), ' ');
    end
end
nodes.(char(commentColumn)) = comments;
if options.RemoveUnconnectedNodes
    % Keep direct Felleman pathways even when the updated evidence table
    % assigns its other reports to a more specific area (V3 versus V3d).
    keepNodes = ismember(allLabels, [edgeTargets; fel91Targets; roi]);
    nodes = nodes(keepNodes, :);
end
studyEvents = table(strings(0, 1), strings(0, 1), strings(0, 1), ...
    strings(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'study', 'target', 'direction', 'grade', ...
    'type', 'strengthGrade'});
studies = table(strings(0, 1), strings(0, 1), ...
    'VariableNames', {'code', 'label'});
if enableStudySelector
    fel91Path = "";
    if species == "macaque"
        fel91Path = fullfile(speciesDir, 'fel91_fst_connections.csv');
    end
    [studyEvents, studies] = buildStudyEvents(evidence, ...
        cleanColumn(nodes, "label"), ...
        fullfile(speciesDir, 'citations.txt'), fel91Path);
end
displayStudies = studies;
if enableStudySelector
    displayStudies = groupRelatedStudies(studies, studyEvents, ...
        ["tracer", "DTI tractography"]);
end

edgeCsv = fullfile(outputSpeciesDir, 'edges.csv');
nodeCsv = fullfile(outputSpeciesDir, 'selectnodes.csv');
if options.WriteTables
    writetable(edges, edgeCsv);
    writetable(nodes, nodeCsv);
end

selectedIDs = numericColumn(nodes, "id");
selectedLabels = cleanColumn(nodes, "label");
selectedColors = lower(cleanColumn(nodes, "color"));
if paperMode
    imagePath = fullfile(speciesDir, 'surface_snapshots', ...
        'veryinflated_lat_white.tif');
    if species == "macaque"
        layout = paperConnectivityLayout(nodes, imagePath);
    else
        layout = paperHumanConnectivityLayout(nodes, imagePath);
    end
    brainImage = layout.Image;
    figureWidth = layout.FigureWidth;
    figureHeight = layout.FigureHeight;
    nodeX = layout.NodeX;
    nodeY = layout.NodeY;
    xLimits = layout.XLimits;
    yLimits = layout.YLimits;
    selectedColors(selectedColors == "blue") = "#B3E4F8";
    selectedColors(selectedColors == "red") = "#F2B3D0";
    selectedColors(selectedColors == "green") = "#F9F384";
else
    if options.Medial
        imageName = 'veryinflated_montage_nolabels_subcort.tif';
        shiftX = 1.8;
        shiftY = 0.85;
    else
        imageName = 'veryinflated_lat_white.tif';
        shiftX = 1;
        shiftY = 1;
    end
    imagePath = fullfile(speciesDir, 'surface_snapshots', imageName);
    if ~isfile(imagePath)
        error('plotConnectivity:MissingImage', 'Missing cortical image: %s', imagePath);
    end
    brainImage = imread(imagePath);
    if size(brainImage, 3) == 4
        whiteLevel = double(intmax(class(brainImage)));
        alpha = double(brainImage(:, :, 4)) / whiteLevel;
        rgb = double(brainImage(:, :, 1:3));
        brainImage = cast(rgb .* alpha + whiteLevel * (1 - alpha), ...
            class(brainImage));
    end
    [imageHeight, imageWidth, ~] = size(brainImage);
    figureWidth = floor(imageWidth / 2);
    figureHeight = floor(imageHeight / 2);
    nodeX = numericColumn(nodes, "x") - floor(imageWidth / 2 * shiftX);
    nodeY = -(numericColumn(nodes, "y") - floor(imageHeight / 2 * shiftY));
    if options.Medial
        xLimits = [-2 * figureWidth, 2 * figureWidth];
        yLimits = [-2 * figureHeight, 2 * figureHeight];
    else
        xLimits = [-figureWidth, figureWidth];
        yLimits = [-figureHeight, figureHeight];
    end
end
nodeAlpha = ones(height(nodes), 1);
nodeSize = ones(height(nodes), 1);
if paperMode
    nodeOutline = selectedColors;
else
    nodeOutline = repmat("black", height(nodes), 1);
end
nodeComments = cleanColumn(nodes, commentColumn);

plotEdges = repmat(struct('x0', 0, 'y0', 0, 'x1', 0, 'y1', 0, ...
    'color', '', 'width', 0, 'dash', false, 'target', ''), height(edges), 1);
for k = 1:height(edges)
    srcIndex = find(selectedIDs == edges.source(k), 1);
    tgtIndex = find(selectedIDs == edges.targetid(k), 1);
    if isempty(srcIndex) || isempty(tgtIndex)
        error('plotConnectivity:UnmappedEdge', ...
            'Edge to %s has no matching selected node.', edges.targetname(k));
    end
    if options.EdgeWeight == "evidencecount"
        if edges.evidencecount(k) > 1
            width = 0.9;
        else
            width = 0.3;
        end
        nodeSize(tgtIndex) = 5 * edges.evidencecount(k);
    else
        width = edgeWeightForStrength(edges.connectivitystrength(k));
        nodeSize(tgtIndex) = width;
    end
    color = edgeColorForRow(edges(k, :), options.EdgeColor);
    nodeAlpha(tgtIndex) = 1;
    if edges.certainty(k) ~= "certain"
        nodeAlpha(tgtIndex) = 0.2;
    end
    plotEdges(k).x0 = nodeX(srcIndex);
    plotEdges(k).y0 = nodeY(srcIndex);
    plotEdges(k).x1 = nodeX(tgtIndex);
    plotEdges(k).y1 = nodeY(tgtIndex);
    plotEdges(k).color = char(color);
    plotEdges(k).width = 3 * width;
    plotEdges(k).dash = edges.certainty(k) ~= "certain";
    plotEdges(k).target = char(edges.targetname(k));
end

legendLabels = strings(0, 1);
legendSizes = zeros(0, 1);
openMarker = false(height(nodes), 1);
strengthSize = nodeSize;
hasAnyStrength = false;
strengthTypes = ["tracer", "DTI tractography"];
if paperMode
    uniformSize = 9;
    nodeSize(:) = uniformSize;
    strengthSize = uniformSize * ones(height(nodes), 1);
    nodeSizeSource = "uniform";
    if species == "macaque"
        strengthRows = ismember(cleanColumn(evidence, "study_type"), strengthTypes);
        gradedGrades = ["weak", "moderate", "strong"];
        strengthOut = lower(cleanColumn(evidence, ...
            "1_main_to_affiliate_projection_strength"));
        strengthIn = lower(cleanColumn(evidence, ...
            "2_affiliate_to_main_projection_strength"));
        for k = 1:height(nodes)
            label = selectedLabels(k);
            if label == roi
                note = "Seed region " + roi + "; dot size does not represent a connection";
            else
                % Uniform size does not display a strength grade.
                openMarker(k) = true;
                group = affiliate == label & strengthRows;
                hasGrade = any(ismember(toAffiliate(group), gradedGrades) | ...
                    ismember(toMain(group), gradedGrades) | ...
                    (toAffiliate(group) == "present" & ...
                    ismember(strengthOut(group), gradedGrades)) | ...
                    (toMain(group) == "present" & ...
                    ismember(strengthIn(group), gradedGrades)));
                if ~hasGrade
                    note = "No graded connection strength";
                else
                    note = "Graded reports available; select one study to size dots";
                end
            end
            if nodeComments(k) == ""
                nodeComments(k) = note;
            else
                nodeComments(k) = nodeComments(k) + newline + note;
            end
        end
    end
    nodeAlpha(:) = 1;
elseif nodeSizeSource == "tracer_strength"
    legendLabels = ["Weak (small)"; "Moderate (medium)"; ...
        "Strong (large)"; "No grade (open)"];
    legendSizes = [11; 18; 26; 6];
    tracerRows = lower(cleanColumn(evidence, "study_type")) == "tracer";
    for k = 1:height(nodes)
        label = selectedLabels(k);
        if label == roi
            nodeSize(k) = 6;
            note = "Seed region " + roi + "; dot size does not represent a connection";
        else
            group = affiliate == label & tracerRows;
            [outStrength, ~] = summarizeDirection(toAffiliate(group), true);
            [inStrength, ~] = summarizeDirection(toMain(group), true);
            rank = max(projectionRank(outStrength, true), ...
                projectionRank(inStrength, true));
            if rank == 0
                nodeSize(k) = 6;
                openMarker(k) = true;
                note = "No graded anatomical tracer strength";
            else
                sizeByRank = [11, 18, 26];
                nodeSize(k) = sizeByRank(rank);
                strengthName = ["weak", "moderate", "strong"];
                note = "Anatomical tracer strength, " + roi + " and " + label + ...
                    ": " + strengthName(rank);
            end
            if any(toAffiliate(group) == "absent" | toMain(group) == "absent")
                note = note + "; some tracer reports describe absence";
            end
        end
        if nodeComments(k) == ""
            nodeComments(k) = note;
        else
            nodeComments(k) = nodeComments(k) + newline + note;
        end
    end
end

interactiveFST = paperMode && enableStudySelector;
if interactiveFST
    canvasWidth = 1335;
    canvasHeight = 820;
    sidePanelWidth = 500;
elseif paperMode && species == "macaque"
    canvasWidth = figureWidth;
    canvasHeight = figureHeight;
    sidePanelWidth = 260;
else
    canvasWidth = figureWidth;
    canvasHeight = figureHeight;
    sidePanelWidth = 0;
end
windowWidth = canvasWidth + sidePanelWidth;
if isempty(options.ReuseFigure)
    fig = figure('Name', sprintf('%s %s connectivity', species, roi), ...
        'Color', 'w', 'Units', 'pixels', ...
        'Position', [80, 80, windowWidth, canvasHeight], ...
        'Visible', char(options.Visible));
else
    fig = options.ReuseFigure;
    if ~isgraphics(fig, 'figure') || ~isscalar(fig)
        error('plotConnectivity:InvalidReuseFigure', ...
            'ReuseFigure must be an existing MATLAB figure.');
    end
    if ~interactiveFST
        oldPosition = get(fig, 'Position');
        datacursormode(fig, 'off');
        clf(fig, 'reset');
        set(fig, 'Color', 'w', 'Units', 'pixels', ...
            'Position', [oldPosition(1:2), windowWidth, canvasHeight], ...
            'Visible', char(options.Visible));
    end
end
if paperMode
    viewVisible = 'on';
    if interactiveFST && ~isempty(options.ReuseFigure)
        viewVisible = 'off';
    end
    viewRoot = uipanel('Parent', fig, 'Units', 'pixels', ...
        'Position', [0, 0, windowWidth, canvasHeight], ...
        'BorderType', 'none', 'BackgroundColor', 'white', ...
        'Visible', viewVisible);
    setappdata(fig, 'ConnectivityBuildingViewRoot', viewRoot);
    plotLeft = 0;
    plotBottom = 0;
    if interactiveFST && species == "human"
        plotLeft = round((canvasWidth - figureWidth) / 2);
        plotBottom = round((canvasHeight - figureHeight) / 2);
    end
    ax = axes('Parent', viewRoot, 'Units', 'pixels', ...
        'Position', [plotLeft, plotBottom, figureWidth, figureHeight]);
else
    viewRoot = fig;
    ax = axes('Parent', fig, 'Position', [0, 0, 1, 1]);
end
hold(ax, 'on');
if options.DisplayBrain
    if paperMode
        image(ax, layout.ImageX, layout.ImageY, brainImage, ...
            'AlphaData', layout.ImageAlpha, 'HitTest', 'off');
    else
        image(ax, xLimits, fliplr(yLimits), brainImage, 'HitTest', 'off');
    end
end
if paperMode
    drawPaperDecorations(ax, layout, roi, species);
end
edgeHandles = gobjects(0, 1);
if ~options.NodesOnly
    edgeHandles = gobjects(numel(plotEdges), 1);
    for k = 1:numel(plotEdges)
        edge = plotEdges(k);
        if edge.dash
            lineStyle = '--';
        else
            lineStyle = '-';
        end
        edgeHandles(k) = plot(ax, [edge.x0, edge.x1], [edge.y0, edge.y1], ...
            'Color', colorRGB(string(edge.color)), 'LineWidth', edge.width, ...
            'LineStyle', lineStyle, 'HitTest', 'off');
    end
end
markerHandles = gobjects(height(nodes), 1);
dataUnitsPerPixel = diff(yLimits) / figureHeight;
if paperMode
    dataUnitsPerPixel = -dataUnitsPerPixel;
end
for k = 1:height(nodes)
    markerHandles(k) = scatter(ax, nodeX(k), nodeY(k), ...
        (0.75 * max(nodeSize(k), 0.3))^2, ...
        colorRGB(selectedColors(k)), 'filled', ...
        'MarkerEdgeColor', colorRGB(nodeOutline(k)), ...
        'MarkerFaceAlpha', nodeAlpha(k), 'MarkerEdgeAlpha', nodeAlpha(k), ...
        'LineWidth', 1);
    if openMarker(k)
        markerHandles(k).MarkerFaceColor = 'none';
        if paperMode
            markerHandles(k).MarkerEdgeColor = colorRGB(selectedColors(k));
            markerHandles(k).LineWidth = 1.8;
        else
            markerHandles(k).MarkerEdgeColor = [0, 0, 0];
            markerHandles(k).LineWidth = 1.2;
        end
    end
    markerHandles(k).DataTipTemplate.DataTipRows = ...
        wrappedDataTipRows(displayAreaLabel(selectedLabels(k)), ...
        nodeComments(k));
end
% Draw every label after every dot so later dots cannot cover earlier text.
textHandles = gobjects(height(nodes), 1);
for k = 1:height(nodes)
    labelY = labelPositionY(nodeY(k), nodeSize(k), dataUnitsPerPixel);
    textHandles(k) = text(ax, nodeX(k), labelY, ...
        displayAreaLabel(selectedLabels(k)), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
        'FontSize', 10, 'Color', [42, 63, 95] / 255, 'Interpreter', 'none', ...
        'HitTest', 'off');
end
if paperMode
    drawPaperInsetTitles(ax, layout);
end
legendAx = [];
if ~isempty(legendLabels)
    legendAx = axes('Parent', viewRoot, 'Units', 'normalized', ...
        'Position', [0.765, 0.845, 0.23, 0.145], ...
        'Color', 'white', 'Box', 'on', 'XLim', [0, 1], 'YLim', [0, 1], ...
        'XTick', [], 'YTick', [], 'FontSize', 8);
    hold(legendAx, 'on');
    text(legendAx, 0.03, 0.9, 'Anatomical tracer strength', ...
        'FontSize', 9, 'Color', [42, 63, 95] / 255);
    for k = 1:numel(legendLabels)
        rowY = 0.72 - (k - 1) * 0.21;
        legendMarker = scatter(legendAx, 0.1, rowY, ...
            (0.75 * legendSizes(k))^2, 'black', 'filled');
        if k == numel(legendLabels)
            legendMarker.MarkerFaceColor = 'none';
            legendMarker.MarkerEdgeColor = [0, 0, 0];
            legendMarker.LineWidth = 1.2;
        end
        text(legendAx, 0.19, rowY, legendLabels(k), ...
            'VerticalAlignment', 'middle', 'FontSize', 8, ...
            'Color', [42, 63, 95] / 255);
    end
    hold(legendAx, 'off');
end
if paperMode
    yDirection = 'reverse';
else
    yDirection = 'normal';
end
set(ax, 'YDir', yDirection, 'XColor', 'none', 'YColor', 'none', ...
    'Color', 'white');
if paperMode && species == "human"
    % Fix the canvas limits after equal scaling so moving an inset does not
    % translate the whole lateral brain in the exported figure.
    axis(ax, 'equal');
    xlim(ax, xLimits);
    ylim(ax, yLimits);
    axis(ax, 'manual');
else
    xlim(ax, xLimits);
    ylim(ax, yLimits);
    axis(ax, 'equal');
end
axis(ax, 'off');
hold(ax, 'off');
if options.Visible == "on"
    datacursormode(fig, 'on');
end

if paperMode
    baseName = sprintf('%s_%s_paper_lateral', species, roi);
else
    baseName = sprintf('%s_%s_displaybrain%d', species, roi, options.DisplayBrain);
end
basePath = fullfile(outputDir, baseName);
figurePath = "";
pdfPath = "";
htmlPath = "";
studyHTMLPath = "";
studyControls = struct('Panel', [], 'CheckBoxes', gobjects(0, 1), ...
    'OnlyButtons', gobjects(0, 1), 'ProjectionGroup', [], ...
    'ProjectionButtons', gobjects(0, 1), 'SizeGroup', [], ...
    'SizeButtons', gobjects(0, 1), 'SpeciesPopup', []);
if options.ExportPDF
    pdfPath = basePath + ".pdf";
    if paperMode
        % Export the species' original plot canvas, without the wider UI frame.
        pdfFig = figure('Visible', 'off', 'Color', 'w', ...
            'Units', 'pixels', 'Position', [80, 80, figureWidth, figureHeight]);
        pdfAx = copyobj(ax, pdfFig);
        set(pdfAx, 'Units', 'pixels', ...
            'Position', [0, 0, figureWidth, figureHeight]);
        exportgraphics(pdfFig, pdfPath, ...
            'ContentType', 'image', 'Resolution', 200);
        close(pdfFig);
    else
        exportgraphics(fig, pdfPath, ...
            'ContentType', 'image', 'Resolution', 200);
    end
end
if enableStudySelector
    if species == "human"
        studyControls = addHumanStudyControls(fig, ax, figureWidth, ...
            figureHeight, selectedLabels, nodeY, dataUnitsPerPixel, ...
            markerHandles, textHandles, edgeHandles, edges, studyEvents, ...
            displayStudies, studies, roi);
    else
        studyControls = addStudyControls(fig, ax, legendAx, figureWidth, ...
            figureHeight, selectedLabels, nodeX, nodeY, markerHandles, ...
            textHandles, edgeHandles, edges, studyEvents, displayStudies, ...
            studies, ...
            dataUnitsPerPixel, roi, selectedColors, nodeOutline, ...
            paperMode, nodeSizeSource, strengthTypes);
    end
elseif paperMode && species == "macaque"
    studyControls = addPaperSizeControls(fig, ax, legendAx, ...
        figureWidth, figureHeight, ...
        markerHandles, textHandles, nodeY, strengthSize, ...
        dataUnitsPerPixel, nodeSizeSource, roi, selectedLabels, ...
        hasAnyStrength);
end
if paperMode && ~isempty(studyControls.Panel)
    if enableStudySelector
        studyControls.SpeciesPopup = addSpeciesSwitchControl( ...
            studyControls.Panel, species, canvasHeight);
    end
    studyControls.Panel.FontSize = 11;
    set(findall(studyControls.Panel, 'Type', 'uibuttongroup'), ...
        'FontSize', 11);
    set(findall(studyControls.Panel, 'Type', 'uicontrol'), ...
        'FontSize', 10);
end
if paperMode
    rmappdata(fig, 'ConnectivityBuildingViewRoot');
end
setappdata(fig, 'ConnectivitySourceOptions', struct( ...
    'DataPath', options.DataPath, 'OutputDir', options.OutputDir, ...
    'IncludeStudies', options.IncludeStudies, ...
    'NodesOnly', options.NodesOnly, 'DisplayBrain', options.DisplayBrain, ...
    'Medial', options.Medial));
if interactiveFST
    views = getappdata(fig, 'ConnectivityViewCache');
    if ~isstruct(views)
        views = struct;
    end
    views.(char(species)) = viewRoot;
    setappdata(fig, 'ConnectivityViewCache', views);
    if options.ActivateView
        activateCachedSpecies(fig, species);
    end
elseif paperMode
    setappdata(fig, 'ConnectivityViewRoot', viewRoot);
    setappdata(fig, 'ConnectivitySpecies', species);
end
if interactiveFST && isempty(options.ReuseFigure) && options.PreloadSpecies
    otherSpecies = "human";
    if species == "human"
        otherSpecies = "macaque";
    end
    plotConnectivity(DataPath=options.DataPath, OutputDir=options.OutputDir, ...
        Species=otherSpecies, MainROI=roi, ...
        IncludeStudies=options.IncludeStudies, NodesOnly=options.NodesOnly, ...
        DisplayBrain=options.DisplayBrain, Medial=options.Medial, ...
        StudySelector=true, ExportPDF=false, ExportHTML=false, ...
        SaveFigure=false, WriteTables=false, Visible=options.Visible, ...
        ReuseFigure=fig, PreloadSpecies=false, ActivateView=false);
end
if options.SaveFigure
    figurePath = basePath + ".fig";
    savefig(fig, figurePath);
end
if options.ExportHTML && paperMode
    warning('plotConnectivity:HTMLPending', ...
        'HTML export for the paper layout is deferred; MATLAB FIG and PDF were saved.');
elseif options.ExportHTML
    payload = makeInteractivePayload(brainImage, options.DisplayBrain, ...
        figureWidth, figureHeight, xLimits, yLimits, nodeX, nodeY, ...
        selectedLabels, selectedColors, nodeAlpha, nodeSize, nodeOutline, ...
        nodeComments, plotEdges, options.NodesOnly, legendLabels, legendSizes);
    htmlPath = basePath + ".html";
    writeHTML(htmlPath, payload, 'plotConnectivity_template.html');
    if enableStudySelector
        payload.events = table2struct(studyEvents);
        payload.studies = table2struct(studies);
        payload.seed = char(roi);
        studyHTMLPath = basePath + "_by_study.html";
        writeHTML(studyHTMLPath, payload, ...
            'plotConnectivity_study_template.html');
    end
end

result = struct('Figure', fig, 'Axes', ax, 'Edges', edges, 'Nodes', nodes, ...
    'EdgeCSV', edgeCsv, 'NodeCSV', nodeCsv, 'FigurePath', figurePath, ...
    'PDFPath', pdfPath, 'HTMLPath', htmlPath, ...
    'StudyHTMLPath', studyHTMLPath, 'StudyEvents', studyEvents, ...
    'Studies', displayStudies, 'SourceStudies', studies, ...
    'StudyControls', studyControls, ...
    'NodeHandles', markerHandles, 'PaperMode', paperMode, ...
    'StrengthSize', strengthSize);
end

function [nodes, evidence] = mergeHumanLOAreas(nodes, evidence)
% Combine the three identically reported FST LO areas for display only.
labels = cleanColumn(nodes, "label");
loNames = ["LO1", "LO2", "LO3"];
if ~all(ismember(loNames, labels))
    return
end
representative = find(labels == "LO2", 1);
nodes.label(representative) = "LO1-3";
nodes(ismember(labels, ["LO1", "LO3"]), :) = [];

main = cleanColumn(evidence, "Main");
affiliate = cleanColumn(evidence, "Affiliate");
mergedRows = main == "FST" & ismember(affiliate, loNames);
evidence.Affiliate(mergedRows) = "LO1-3";
mergedIndices = find(mergedRows);
[~, uniqueRows] = unique(evidence(mergedRows, :), 'rows', 'stable');
keepRows = ~mergedRows;
keepRows(mergedIndices(uniqueRows)) = true;
evidence = evidence(keepRows, :);
end

function evidence = correctLegacyFSTEvidence(evidence)
% Apply the source-paper interpretation while legacy evidence.csv is in use.
% These corrections are idempotent if the CSV has already been updated.
main = cleanColumn(evidence, "Main");
affiliate = cleanColumn(evidence, "Affiliate");
outRef = cleanColumn(evidence, "1_main_to_affiliate_ref");
inRef = cleanColumn(evidence, "2_affiliate_to_main_ref");

% Ungerleider 2008 Table 1 grades individual V4 injections, not a single
% strong FST-V4 connection in each direction.
ungerleider = main == "FST" & affiliate == "V4" & ...
    outRef == "Ung08" & inRef == "Ung08";
evidence = setEvidenceValues(evidence, ...
    "1_main_to_affiliate_projection_strength", ungerleider, "");
evidence = setEvidenceValues(evidence, ...
    "2_affiliate_to_main_projection_strength", ungerleider, "");

% Barone 2000 injected V1/V4 and labeled cells in FST: FST projects to
% the injected areas. Its density comparison does not define weak and
% moderate strength grades for these two connections.
barone = main == "FST" & ismember(affiliate, ["V1", "V4"]) & ...
    (inRef == "Bar00" | outRef == "Bar00");
evidence = setEvidenceValues(evidence, ...
    "1_main_to_affiliate_projection", barone, "present");
evidence = setEvidenceValues(evidence, ...
    "1_main_to_affiliate_projection_strength", barone, "");
evidence = setEvidenceValues(evidence, ...
    "1_main_to_affiliate_ref", barone, "Bar00");
evidence = setEvidenceValues(evidence, ...
    "2_affiliate_to_main_projection", barone, "");
evidence = setEvidenceValues(evidence, ...
    "2_affiliate_to_main_projection_strength", barone, "");
evidence = setEvidenceValues(evidence, ...
    "2_affiliate_to_main_ref", barone, "");
end

function evidence = setEvidenceValues(evidence, columnName, rows, value)
column = evidence.(char(columnName));
column(rows) = value;
evidence.(char(columnName)) = column;
end

function value = cleanColumn(tbl, name)
if ~ismember(name, string(tbl.Properties.VariableNames))
    error('plotConnectivity:MissingColumn', 'Missing column "%s".', name);
end
value = strtrim(string(tbl.(char(name))));
value(ismissing(value)) = "";
end

function value = numericColumn(tbl, name)
if ~ismember(name, string(tbl.Properties.VariableNames))
    error('plotConnectivity:MissingColumn', 'Missing column "%s".', name);
end
value = tbl.(char(name));
if ~isnumeric(value)
    value = str2double(string(value));
end
value = double(value);
if any(~isfinite(value))
    error('plotConnectivity:InvalidNumber', 'Column "%s" contains invalid numbers.', name);
end
end

function [strength, certainty] = summarizeDirection(labels, tracerOnly)
labels = lower(strtrim(string(labels)));
ranks = arrayfun(@(s) projectionRank(s, tracerOnly), labels);
valid = ranks > 0;
if any(valid) && any(labels == "absent")
    certainty = "conflicting";
else
    certainty = "certain";
end
strength = "";
if any(valid)
    meanRank = mean(ranks(valid));
    rounded = roundHalfToEven(meanRank);
    strength = ["weak", "moderate", "strong"];
    strength = strength(max(1, min(3, rounded)));
end
end

function rank = projectionRank(label, tracerOnly)
switch char(label)
    case 'weak'
        rank = 1;
    case 'moderate'
        rank = 2;
    case 'strong'
        rank = 3;
    case 'present'
        rank = 2 * ~tracerOnly;
    case 'broad'
        rank = 3 * ~tracerOnly;
    otherwise
        rank = 0;
end
end

function rounded = roundHalfToEven(value)
lower = floor(value);
fraction = value - lower;
if abs(fraction - 0.5) < 1e-12
    rounded = lower + mod(lower, 2);
else
    rounded = round(value);
end
end

function width = edgeWeightForStrength(strength)
switch char(strength)
    case 'weak'
        width = 0.3;
    case 'moderate'
        width = 0.6;
    case 'strong'
        width = 0.9;
    otherwise
        width = 0;
end
end

function color = edgeColorForRow(row, colorMode)
if colorMode == "hierarchy"
    switch char(row.hierarchy)
        case 'higher'
            color = "black";
        case 'lower'
            color = "white";
        otherwise
            color = "grey";
    end
else
    switch char(row.projections)
        case 'mainreceive'
            color = "white";
        case 'mainsend'
            color = "black";
        otherwise
            color = "grey";
    end
end
end

function rgb = colorRGB(color)
color = lower(strtrim(string(color)));
if startsWith(color, '#') && strlength(color) == 7
    hex = char(extractAfter(color, 1));
    rgb = [hex2dec(hex(1:2)), hex2dec(hex(3:4)), hex2dec(hex(5:6))] / 255;
    return
end
switch char(color)
    case 'black'
        rgb = [0, 0, 0];
    case 'white'
        rgb = [1, 1, 1];
    case {'gray', 'grey'}
        rgb = [0.5, 0.5, 0.5];
    case 'blue'
        rgb = [0, 0, 1];
    case 'red'
        rgb = [1, 0, 0];
    case 'green'
        rgb = [0, 0.5, 0];
    otherwise
        error('plotConnectivity:UnknownColor', 'Unsupported node color: %s', color);
end
end

function payload = makeInteractivePayload(brainImage, displayBrain, width, height, ...
    xLimits, yLimits, nodeX, nodeY, labels, fills, alphas, sizes, outlines, ...
    comments, edges, nodesOnly, legendLabels, legendSizes)
payload = struct();
payload.width = width;
payload.height = height;
payload.xLimits = xLimits;
payload.yLimits = yLimits;
payload.nodesOnly = nodesOnly;
payload.displayBrain = displayBrain;
payload.image = '';
if displayBrain
    imageTemp = [tempname, '.png'];
    cleanup = onCleanup(@() deleteIfPresent(imageTemp));
    imwrite(brainImage, imageTemp);
    fid = fopen(imageTemp, 'rb');
    if fid < 0
        error('plotConnectivity:ImageEncode', 'Cannot read temporary PNG.');
    end
    fileCleanup = onCleanup(@() fclose(fid));
    bytes = fread(fid, Inf, '*uint8');
    payload.image = ['data:image/png;base64,', matlab.net.base64encode(bytes)];
    clear fileCleanup cleanup
end
payload.nodes = repmat(struct('x', 0, 'y', 0, 'label', '', 'fill', '', ...
    'alpha', 1, 'size', 0, 'outline', '', 'comment', ''), numel(labels), 1);
for k = 1:numel(labels)
    payload.nodes(k).x = nodeX(k);
    payload.nodes(k).y = nodeY(k);
    payload.nodes(k).label = char(labels(k));
    payload.nodes(k).fill = char(fills(k));
    payload.nodes(k).alpha = alphas(k);
    payload.nodes(k).size = sizes(k);
    payload.nodes(k).outline = char(outlines(k));
    payload.nodes(k).comment = char(comments(k));
end
payload.edges = edges;
payload.legend = repmat(struct('label', '', 'size', 0), numel(legendLabels), 1);
for k = 1:numel(legendLabels)
    payload.legend(k).label = char(legendLabels(k));
    payload.legend(k).size = legendSizes(k);
end
end

function writeHTML(path, payload, templateName)
templatePath = fullfile(fileparts(mfilename('fullpath')), templateName);
if ~isfile(templatePath)
    error('plotConnectivity:MissingTemplate', 'Missing HTML template: %s', templatePath);
end
encoded = strrep(jsonencode(payload), '</', '<\/');
html = strrep(fileread(templatePath), '__CONNECTIVITY_DATA__', encoded);
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0
    error('plotConnectivity:HTMLWrite', 'Cannot write HTML: %s', path);
end
fileCleanup = onCleanup(@() fclose(fid));
fwrite(fid, html, 'char');
end

function deleteIfPresent(path)
if isfile(path)
    delete(path);
end
end

function [events, studies] = buildStudyEvents(evidence, availableLabels, ...
    citationsPath, fel91Path)
if ~isfile(citationsPath) || (fel91Path ~= "" && ~isfile(fel91Path))
    error('plotConnectivity:MissingStudySource', ...
        'Study selection is missing citations.txt or a required study source.');
end
lines = readlines(citationsPath);
citationCodes = strings(0, 1);
citationLabels = strings(0, 1);
citationYears = zeros(0, 1);
for k = 1:numel(lines)
    line = char(erase(lines(k), char(65279)));
    separator = strfind(line, ': ');
    if isempty(separator)
        continue
    end
    code = string(line(1:separator(1)-1));
    citation = string(line(separator(1)+2:end));
    yearToken = regexp(char(citation), '\((\d{4})\)', 'tokens', 'once');
    if isempty(yearToken)
        continue
    end
    year = str2double(yearToken{1});
    if code == "Fel91"
        author = "Felleman & Van Essen";
    else
        comma = strfind(char(citation), ',');
        if isempty(comma)
            author = citation + " et al.";
        else
            author = string(extractBefore(citation, comma(1))) + " et al.";
        end
    end
    citationCodes(end+1, 1) = code; %#ok<AGROW>
    citationLabels(end+1, 1) = author + ...
        " (" + yearToken{1} + ")"; %#ok<AGROW>
    citationYears(end+1, 1) = year; %#ok<AGROW>
end

eventStudy = strings(0, 1);
eventTarget = strings(0, 1);
eventDirection = strings(0, 1);
eventGrade = strings(0, 1);
eventType = strings(0, 1);
eventStrength = strings(0, 1);
affiliates = cleanColumn(evidence, "Affiliate");
types = cleanColumn(evidence, "study_type");
types(types == "inactivation") = "functional inactivation";
gradesOut = lower(cleanColumn(evidence, "1_main_to_affiliate_projection"));
gradesIn = lower(cleanColumn(evidence, "2_affiliate_to_main_projection"));
strengthsOut = lower(cleanColumn(evidence, ...
    "1_main_to_affiliate_projection_strength"));
strengthsIn = lower(cleanColumn(evidence, ...
    "2_affiliate_to_main_projection_strength"));
refsOut = cleanColumn(evidence, "1_main_to_affiliate_ref");
refsIn = cleanColumn(evidence, "2_affiliate_to_main_ref");
allowedGrades = ["weak", "moderate", "strong", "present", "broad", "absent"];
for r = 1:height(evidence)
    if ~ismember(affiliates(r), availableLabels)
        continue
    end
    for d = 1:2
        if d == 1
            grade = gradesOut(r);
            strengthText = strengthsOut(r);
            direction = "out";
            ref = refsOut(r);
            otherRef = refsIn(r);
        else
            grade = gradesIn(r);
            strengthText = strengthsIn(r);
            direction = "in";
            ref = refsIn(r);
            otherRef = refsOut(r);
        end
        if ~ismember(grade, allowedGrades)
            continue
        end
        strengthGrade = "";
        if ismember(grade, ["weak", "moderate", "strong"])
            strengthGrade = grade;
        elseif ismember(grade, ["present", "broad"]) && ...
                ismember(strengthText, ["weak", "moderate", "strong"])
            strengthGrade = strengthText;
        end
        codes = referenceCodes(ref, citationCodes);
        if isempty(codes)
            codes = referenceCodes(otherRef, citationCodes);
        end
        for c = codes(:)'
            eventStudy(end+1, 1) = c; %#ok<AGROW>
            eventTarget(end+1, 1) = affiliates(r); %#ok<AGROW>
            eventDirection(end+1, 1) = direction; %#ok<AGROW>
            eventGrade(end+1, 1) = grade; %#ok<AGROW>
            eventType(end+1, 1) = types(r); %#ok<AGROW>
            eventStrength(end+1, 1) = strengthGrade; %#ok<AGROW>
        end
    end
end

if fel91Path ~= ""
    fel = readtable(fel91Path, 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
    fromArea = cleanColumn(fel, "from_area");
    toArea = cleanColumn(fel, "to_area");
    for r = 1:height(fel)
        if fromArea(r) == "FST" && ismember(toArea(r), availableLabels)
            target = toArea(r);
            direction = "out";
        elseif toArea(r) == "FST" && ismember(fromArea(r), availableLabels)
            target = fromArea(r);
            direction = "in";
        else
            continue
        end
        eventStudy(end+1, 1) = "Fel91"; %#ok<AGROW>
        eventTarget(end+1, 1) = target; %#ok<AGROW>
        eventDirection(end+1, 1) = direction; %#ok<AGROW>
        eventGrade(end+1, 1) = "present"; %#ok<AGROW>
        eventType(end+1, 1) = "literature synthesis"; %#ok<AGROW>
        eventStrength(end+1, 1) = ""; %#ok<AGROW>
    end
end
events = table(eventStudy, eventTarget, eventDirection, eventGrade, ...
    eventType, eventStrength, ...
    'VariableNames', {'study', 'target', 'direction', 'grade', ...
    'type', 'strengthGrade'});

used = ismember(citationCodes, unique(eventStudy));
if any(~ismember(unique(eventStudy), citationCodes))
    error('plotConnectivity:UnknownStudy', ...
        'An event refers to a study missing from citations.txt.');
end
usedCodes = citationCodes(used);
displayLabels = citationLabels(used);
for k = 1:numel(usedCodes)
    methods = unique(eventType(eventStudy == usedCodes(k)), 'stable');
    methods(methods == "tracer") = "Tracer";
    methods(methods == "inactivation") = "Functional inactivation";
    methods(methods == "functional inactivation") = "Functional inactivation";
    methods(methods == "literature synthesis") = "Literature synthesis";
    displayLabels(k) = strjoin(methods, ' + ') + ": " + displayLabels(k);
end
ordered = table(usedCodes, displayLabels, citationYears(used), ...
    'VariableNames', {'code', 'label', 'year'});
ordered = sortrows(ordered, {'year', 'code'});
studies = ordered(:, {'code', 'label'});
end

function grouped = groupRelatedStudies(studies, events, strengthTypes)
grouped = studies;
grouped.codes = cell(height(studies), 1);
for k = 1:height(studies)
    grouped.codes{k} = studies.code(k);
end
grouped.detail = grouped.label;
gradedCodes = unique(events.study( ...
    ismember(events.strengthGrade, ["weak", "moderate", "strong"]) & ...
    ismember(events.type, strengthTypes)));
bou90 = find(grouped.code == "Bou90", 1);
bou92 = find(grouped.code == "Bou92", 1);
if ~isempty(bou90) && ~isempty(bou92)
    grouped.code(bou90) = "Bou90+Bou92";
    grouped.label(bou90) = "Tracer: Boussaoud et al. (1990, 1992)";
    grouped.codes{bou90} = ["Bou90"; "Bou92"];
    grouped.detail(bou90) = strjoin([ ...
        "Tracer: Boussaoud et al. (1990) — graded"; ...
        "Tracer: Boussaoud et al. (1992) — no graded strength"], newline);
    grouped(bou92, :) = [];
end
bog19 = find(grouped.code == "Bog19", 1);
bog21 = find(grouped.code == "Bog21", 1);
if ~isempty(bog19) && ~isempty(bog21)
    grouped.code(bog19) = "Bog19+Bog21";
    grouped.label(bog19) = ...
        "Functional inactivation: Bogadhi et al. (2019, 2021)";
    grouped.codes{bog19} = ["Bog19"; "Bog21"];
    grouped.detail(bog19) = strjoin([ ...
        "Functional inactivation: Bogadhi et al. (2019)"; ...
        "Functional inactivation: Bogadhi et al. (2021)"], newline);
    grouped(bog21, :) = [];
end
ungraded = false(height(grouped), 1);
for k = 1:height(grouped)
    sourceTypes = unique(events.type( ...
        ismember(events.study, grouped.codes{k})));
    % Group all tracer studies without a graded connection-strength report.
    ungraded(k) = ~isempty(sourceTypes) && all(sourceTypes == "tracer") && ...
        ~any(ismember(grouped.codes{k}, gradedCodes));
end
if any(ungraded)
    sourceCodes = vertcat(grouped.codes{ungraded});
    sourceLabels = grouped.label(ungraded);
    row = grouped(find(ungraded, 1), :);
    row.code = "mixed_tracer";
    row.label = "Mixed tracer evidence";
    row.codes{1} = sourceCodes;
    row.detail = strjoin(sourceLabels, newline);
    grouped(ungraded, :) = [];
    grouped = [grouped; row];
end
end

function codes = referenceCodes(reference, known)
matches = regexp(char(reference), ...
    '(?<![A-Za-z0-9_])[A-Z][a-z]{2,3}\d{2}(?![A-Za-z0-9_])', 'match');
codes = string(matches(:));
codes = codes(ismember(codes, known));
end

function controls = addHumanStudyControls(fig, ax, width, plotHeight, ...
    nodeLabels, nodeY, dataUnitsPerPixel, nodeHandles, textHandles, ...
    edgeHandles, edges, ...
    events, studies, sourceStudies, seed)
panelWidth = 500;
panelHeight = 820;
canvasWidth = 1335;
set(ax, 'Units', 'pixels', 'Position', ...
    [round((canvasWidth - width) / 2), ...
    round((panelHeight - plotHeight) / 2), width, plotHeight]);
panel = uipanel('Parent', getappdata(fig, 'ConnectivityBuildingViewRoot'), ...
    'Units', 'pixels', ...
    'Position', [canvasWidth, 0, panelWidth, panelHeight], ...
    'Title', 'Show results from studies', 'FontWeight', 'bold', ...
    'BackgroundColor', [0.975, 0.985, 1]);
uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'Position', [12, panelHeight - 82, 100, 28], 'String', 'Select all', ...
    'Callback', @(src, ~) selectEveryHumanStudy(ancestor(src, 'figure'), true));
uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'Position', [122, panelHeight - 82, 70, 28], 'String', 'Clear', ...
    'Callback', @(src, ~) selectEveryHumanStudy(ancestor(src, 'figure'), false));
checkboxes = gobjects(height(studies), 1);
onlyButtons = gobjects(height(studies), 1);
firstY = panelHeight - 126;
for k = 1:height(studies)
    y = firstY - (k - 1) * 34;
    checkboxes(k) = uicontrol('Parent', panel, 'Style', 'checkbox', ...
        'Position', [12, y, panelWidth - 98, 27], ...
        'String', char(studies.label(k)), ...
        'TooltipString', char(studies.detail(k)), ...
        'Value', 1, 'BackgroundColor', [0.975, 0.985, 1], ...
        'Callback', @(src, ~) refreshHumanStudySelector(ancestor(src, 'figure')));
    onlyButtons(k) = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
        'Position', [panelWidth - 70, y, 55, 26], 'String', 'Only', ...
        'Callback', @(src, ~) selectOnlyHumanStudy(ancestor(src, 'figure'), k));
end
note = sprintf(['Choose studies to show their FST connections.\n' ...
    'Select all to enable study-count dot sizes.']);
uicontrol('Parent', panel, 'Style', 'text', ...
    'Position', [12, panelHeight - 278, panelWidth - 24, 52], ...
    'String', note, 'HorizontalAlignment', 'left', ...
    'BackgroundColor', [0.975, 0.985, 1]);
status = uicontrol('Parent', panel, 'Style', 'text', ...
    'Position', [12, panelHeight - 332, panelWidth - 24, 42], ...
    'String', '', 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', [0.975, 0.985, 1]);
sizeGroup = uibuttongroup('Parent', panel, 'Units', 'pixels', ...
    'Position', [12, 362, panelWidth - 24, 112], 'Title', 'Dot size', ...
    'BackgroundColor', [0.975, 0.985, 1]);
uniformButton = uicontrol('Parent', sizeGroup, 'Style', 'radiobutton', ...
    'Position', [10, 54, 440, 26], 'String', 'Uniform', ...
    'Tag', 'uniform', 'BackgroundColor', [0.975, 0.985, 1]);
countButton = uicontrol('Parent', sizeGroup, 'Style', 'radiobutton', ...
    'Position', [10, 22, 440, 26], ...
    'String', 'Number of reporting studies', 'Tag', 'studycount', ...
    'TooltipString', ['Each paper with a positive connection counts once, ' ...
    'including Baker''s DTI and rs-fMRI reports.'], ...
    'BackgroundColor', [0.975, 0.985, 1]);
sizeGroup.SelectedObject = uniformButton;
sizeNote = uicontrol('Parent', panel, 'Style', 'text', ...
    'Position', [12, 318, panelWidth - 24, 34], ...
    'String', '', 'HorizontalAlignment', 'left', ...
    'BackgroundColor', [0.975, 0.985, 1]);
countLegend = addDotSizeLegend(panel, ...
    [12, 222, panelWidth - 24, 82], false, "count", ...
    height(sourceStudies));
countLegend.Visible = 'off';
state = struct('Events', events, 'Studies', studies, ...
    'SourceStudies', sourceStudies, 'CheckBoxes', checkboxes, ...
    'NodeLabels', nodeLabels, 'NodeY', nodeY, ...
    'Scale', dataUnitsPerPixel, 'NodeHandles', nodeHandles, ...
    'TextHandles', textHandles, 'EdgeHandles', edgeHandles, ...
    'EdgeTargets', edges.targetname, 'Seed', seed, 'Status', status, ...
    'SizeGroup', sizeGroup, 'UniformButton', uniformButton, ...
    'CountButton', countButton, 'SizeNote', sizeNote, ...
    'CountLegend', countLegend);
setappdata(fig, 'HumanStudySelectorState', state);
sizeGroup.SelectionChangedFcn = ...
    @(src, ~) refreshHumanStudySelector(ancestor(src, 'figure'));
refreshHumanStudySelector(fig);
controls = struct('Panel', panel, 'CheckBoxes', checkboxes, ...
    'OnlyButtons', onlyButtons, 'ProjectionGroup', [], ...
    'ProjectionButtons', gobjects(0, 1), 'SizeGroup', sizeGroup, ...
    'SizeButtons', [uniformButton; countButton]);
end

function popup = addSpeciesSwitchControl(panel, species, plotHeight)
% Both FST views rebuild inside their current figure when species changes.
panelWidth = panel.Position(3);
uicontrol('Parent', panel, 'Style', 'text', ...
    'Position', [panelWidth - 195, plotHeight - 78, 58, 22], ...
    'String', 'Species:', 'HorizontalAlignment', 'right', ...
    'BackgroundColor', [0.975, 0.985, 1]);
popup = uicontrol('Parent', panel, 'Style', 'popupmenu', ...
    'Position', [panelWidth - 132, plotHeight - 82, 120, 28], ...
    'String', {'Macaque', 'Human'}, ...
    'Value', 1 + (species == "human"), ...
    'Tag', 'ConnectivitySpeciesSelector', ...
    'Callback', @(src, ~) switchConnectivitySpecies(src));
end

function switchConnectivitySpecies(popup)
fig = ancestor(popup, 'figure');
speciesNames = ["macaque", "human"];
target = speciesNames(popup.Value);
current = getappdata(fig, 'ConnectivitySpecies');
if target == current
    return
end
if activateCachedSpecies(fig, target)
    return
end
source = getappdata(fig, 'ConnectivitySourceOptions');
oldPointer = fig.Pointer;
fig.Pointer = 'watch';
drawnow limitrate;
try
    plotConnectivity(DataPath=source.DataPath, OutputDir=source.OutputDir, ...
        Species=target, MainROI="FST", IncludeStudies=source.IncludeStudies, ...
        NodesOnly=source.NodesOnly, DisplayBrain=source.DisplayBrain, ...
        Medial=source.Medial, StudySelector=true, ...
        ExportPDF=false, ExportHTML=false, SaveFigure=false, ...
        WriteTables=false, Visible=string(fig.Visible), ...
        ReuseFigure=fig, PreloadSpecies=false);
catch cause
    unfinished = getappdata(fig, 'ConnectivityBuildingViewRoot');
    if ~isempty(unfinished) && isgraphics(unfinished, 'uipanel')
        delete(unfinished);
    end
    if isappdata(fig, 'ConnectivityBuildingViewRoot')
        rmappdata(fig, 'ConnectivityBuildingViewRoot');
    end
    fig.Pointer = oldPointer;
    rethrow(cause);
end
fig.Pointer = oldPointer;
end

function activated = activateCachedSpecies(fig, target)
activated = false;
views = getappdata(fig, 'ConnectivityViewCache');
if ~isstruct(views) || ~isfield(views, char(target))
    return
end
nextView = views.(char(target));
if ~isgraphics(nextView, 'uipanel')
    return
end
currentView = getappdata(fig, 'ConnectivityViewRoot');
if ~isempty(currentView) && isgraphics(currentView, 'uipanel') && ...
        ~isequal(currentView, nextView)
    currentView.Visible = 'off';
end
nextView.Visible = 'on';
speciesPopup = findobj(nextView, 'Tag', 'ConnectivitySpeciesSelector');
if isscalar(speciesPopup)
    speciesPopup.Value = 1 + (target == "human");
end
setappdata(fig, 'ConnectivityViewRoot', nextView);
setappdata(fig, 'ConnectivitySpecies', target);
fig.Name = sprintf('%s FST connectivity', target);
drawnow limitrate;
activated = true;
end

function selectEveryHumanStudy(fig, selected)
state = getappdata(fig, 'HumanStudySelectorState');
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = selected;
end
refreshHumanStudySelector(fig);
end

function selectOnlyHumanStudy(fig, studyIndex)
state = getappdata(fig, 'HumanStudySelectorState');
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = k == studyIndex;
end
refreshHumanStudySelector(fig);
end

function refreshHumanStudySelector(fig)
state = getappdata(fig, 'HumanStudySelectorState');
checked = false(numel(state.CheckBoxes), 1);
for k = 1:numel(state.CheckBoxes)
    checked(k) = state.CheckBoxes(k).Value ~= 0;
end
canSizeByCount = ~isempty(checked) && all(checked);
if canSizeByCount
    state.CountButton.Enable = 'on';
else
    state.CountButton.Enable = 'off';
end
sizeMode = string(state.SizeGroup.SelectedObject.Tag);
if sizeMode == "studycount" && ~canSizeByCount
    state.SizeGroup.SelectedObject = state.UniformButton;
    sizeMode = "uniform";
end
if sizeMode == "studycount"
    state.CountLegend.Visible = 'on';
    state.SizeNote.String = sprintf(['Dots count distinct papers with a positive connection.\n' ...
        'Baker et al. (2018) counts once across methods.']);
else
    state.CountLegend.Visible = 'off';
    state.SizeNote.String = ...
        'Select all studies to size dots by number of reporting studies.';
end
selectedCodes = strings(0, 1);
for k = find(checked(:))'
    selectedCodes = [selectedCodes; state.Studies.codes{k}(:)]; %#ok<AGROW>
end
reports = state.Events(ismember(state.Events.study, selectedCodes), :);
positiveGrades = ["weak", "moderate", "strong", "present", "broad"];
connected = 0;
for k = 1:numel(state.NodeLabels)
    label = state.NodeLabels(k);
    nodeReports = reports(reports.target == label, :);
    positive = ismember(nodeReports.grade, positiveGrades);
    shown = label == state.Seed || any(positive);
    if ~shown
        state.NodeHandles(k).Visible = 'off';
        state.TextHandles(k).Visible = 'off';
        continue
    end
    state.NodeHandles(k).Visible = 'on';
    state.TextHandles(k).Visible = 'on';
    size = 9;
    if label == state.Seed
        description = "Seed region";
    else
        connected = connected + 1;
        sources = sort(unique(nodeReports.study(positive)));
        sourceNames = displayStudyNames(sources, state.SourceStudies);
        description = "Reported by: " + strjoin(sourceNames, ', ');
        if sizeMode == "studycount"
            studyCount = numel(unique(nodeReports.study(positive)));
            size = max(9, 5 * studyCount);
            description = description + newline + ...
                "Supporting studies: " + string(studyCount);
        end
        absent = sort(unique(nodeReports.study(nodeReports.grade == "absent")));
        if ~isempty(absent)
            absentNames = displayStudyNames(absent, state.SourceStudies);
            description = description + newline + ...
                "Selected reports of absence: " + strjoin(absentNames, ', ');
        end
        if label == "LO1-3"
            description = "LO1, LO2, and LO3 shown as one dot." + ...
                newline + description;
        end
    end
    state.NodeHandles(k).SizeData = (0.75 * size)^2;
    position = state.TextHandles(k).Position;
    position(2) = labelPositionY(state.NodeY(k), size, state.Scale);
    state.TextHandles(k).Position = position;
    state.NodeHandles(k).DataTipTemplate.DataTipRows = ...
        wrappedDataTipRows(displayAreaLabel(label), description);
end
for k = 1:numel(state.EdgeHandles)
    target = state.EdgeTargets(k);
    active = any(reports.target == target & ...
        ismember(reports.grade, positiveGrades));
    if active
        state.EdgeHandles(k).Visible = 'on';
    else
        state.EdgeHandles(k).Visible = 'off';
    end
end
state.Status.String = sprintf('%d connected regions from %d selected studies.', ...
    connected, nnz(checked));
end

function controls = addStudyControls(fig, ax, legendAx, width, plotHeight, ...
    nodeLabels, nodeX, nodeY, nodeHandles, textHandles, edgeHandles, ...
    edges, events, studies, sourceStudies, dataUnitsPerPixel, ...
    seed, nodeColors, nodeOutlines, ...
    paperMode, nodeSizeSource, strengthTypes)
panelWidth = 500;
set(ax, 'Units', 'pixels', 'Position', [0, 0, width, plotHeight]);
if ~isempty(legendAx)
    set(legendAx, 'Units', 'pixels', ...
        'Position', [0.765 * width, 0.845 * plotHeight, ...
        0.23 * width, 0.145 * plotHeight]);
end
panel = uipanel('Parent', getappdata(fig, 'ConnectivityBuildingViewRoot'), ...
    'Units', 'pixels', ...
    'Position', [width, 0, panelWidth, plotHeight], ...
    'Title', 'Show results from studies', 'FontWeight', 'bold', ...
    'BackgroundColor', [0.975, 0.985, 1]);
uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'Position', [12, plotHeight - 82, 100, 28], 'String', 'Select all', ...
    'Callback', @(src, ~) selectEveryStudy(ancestor(src, 'figure'), true));
uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'Position', [122, plotHeight - 82, 70, 28], 'String', 'Clear', ...
    'Callback', @(src, ~) selectEveryStudy(ancestor(src, 'figure'), false));
checkboxes = gobjects(height(studies), 1);
onlyButtons = gobjects(height(studies), 1);
firstY = plotHeight - 126;
rowHeight = 31;
for k = 1:height(studies)
    y = firstY - (k - 1) * rowHeight;
    checkboxes(k) = uicontrol('Parent', panel, 'Style', 'checkbox', ...
        'Position', [12, y, 410, 26], 'String', char(studies.label(k)), ...
        'TooltipString', char(studies.detail(k)), ...
        'Value', 1, 'BackgroundColor', [0.975, 0.985, 1], ...
        'Callback', @(src, ~) refreshStudySelector(ancestor(src, 'figure')));
    onlyButtons(k) = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
        'Position', [430, y, 55, 25], 'String', 'Only', ...
        'Callback', @(src, ~) selectOnlyStudy(ancestor(src, 'figure'), k));
end
ungradedDetail = studies.detail(studies.code == "mixed_tracer");
if ~isempty(ungradedDetail)
    uicontrol('Parent', panel, 'Style', 'text', ...
        'Position', [12, 360, panelWidth - 24, 104], ...
        'String', char(ungradedDetail), 'FontSize', 8, ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.975, 0.985, 1]);
end
sizeGroup = uibuttongroup('Parent', panel, 'Units', 'pixels', ...
    'Position', [12, 180, panelWidth - 24, 170], 'Title', 'Dot size', ...
    'BackgroundColor', [0.975, 0.985, 1]);
uniformButton = uicontrol('Parent', sizeGroup, 'Style', 'radiobutton', ...
    'Position', [10, 120, 440, 26], 'String', 'Uniform', ...
    'Tag', 'uniform', 'BackgroundColor', [0.975, 0.985, 1]);
afferentButton = uicontrol('Parent', sizeGroup, 'Style', 'radiobutton', ...
    'Position', [10, 92, 440, 26], ...
    'String', 'Connection strength (afferent)', ...
    'Tag', 'afferent', 'BackgroundColor', [0.975, 0.985, 1]);
efferentButton = uicontrol('Parent', sizeGroup, 'Style', 'radiobutton', ...
    'Position', [10, 64, 440, 26], ...
    'String', 'Connection strength (efferent)', ...
    'Tag', 'efferent', 'BackgroundColor', [0.975, 0.985, 1]);
unspecifiedButton = uicontrol('Parent', sizeGroup, 'Style', 'radiobutton', ...
    'Position', [10, 36, 440, 26], ...
    'String', 'Connection strength (unspecified)', ...
    'Tag', 'unspecified', 'BackgroundColor', [0.975, 0.985, 1]);
countButton = uicontrol('Parent', sizeGroup, 'Style', 'radiobutton', ...
    'Position', [10, 8, 440, 26], ...
    'String', 'Number of reporting studies', 'Tag', 'studycount', ...
    'TooltipString', ['Each paper with a positive connection counts once, ' ...
    'including papers inside grouped study options.'], ...
    'BackgroundColor', [0.975, 0.985, 1]);
sizeGroup.SelectedObject = uniformButton;
note = sprintf(['Dots remain visible for all selected studies.\n' ...
    'Select one study to size dots by connection strength.']);
noteControl = uicontrol('Parent', panel, 'Style', 'text', ...
    'Position', [12, 140, panelWidth - 24, 34], 'String', note, ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.975, 0.985, 1]);
strengthLegend = addDotSizeLegend(panel, ...
    [12, 53, panelWidth - 24, 82], false);
countLegend = addDotSizeLegend(panel, ...
    [12, 53, panelWidth - 24, 82], false, "count");
countLegend.Visible = 'off';
status = uicontrol('Parent', panel, 'Style', 'text', ...
    'Position', [12, 7, panelWidth - 24, 40], 'String', '', ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
    'BackgroundColor', [0.975, 0.985, 1]);
state = struct('Events', events, 'Studies', studies, ...
    'SourceStudies', sourceStudies, 'CheckBoxes', checkboxes, ...
    'NodeLabels', nodeLabels, 'NodeX', nodeX, 'NodeY', nodeY, ...
    'NodeColors', nodeColors, 'NodeOutlines', nodeOutlines, ...
    'NodeHandles', nodeHandles, 'TextHandles', textHandles, ...
    'EdgeHandles', edgeHandles, 'EdgeTargets', edges.targetname, ...
    'Scale', dataUnitsPerPixel, 'Seed', seed, 'Status', status, ...
    'Note', noteControl, 'StrengthLegend', strengthLegend, ...
    'CountLegend', countLegend, 'SizeGroup', sizeGroup, ...
    'UniformButton', uniformButton, 'CountButton', countButton, ...
    'StrengthButtons', [afferentButton; efferentButton; unspecifiedButton], ...
    'StrengthTypes', strengthTypes, 'PaperMode', paperMode);
setappdata(fig, 'StudySelectorState', state);
sizeGroup.SelectionChangedFcn = ...
    @(src, ~) refreshStudySelector(ancestor(src, 'figure'));
refreshStudySelector(fig);
controls = struct('Panel', panel, 'CheckBoxes', checkboxes, ...
    'OnlyButtons', onlyButtons, 'ProjectionGroup', [], ...
    'ProjectionButtons', gobjects(0, 1), ...
    'SizeGroup', sizeGroup, ...
    'SizeButtons', [uniformButton; afferentButton; ...
    efferentButton; unspecifiedButton; countButton]);
end

function selectEveryStudy(fig, selected)
state = getappdata(fig, 'StudySelectorState');
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = selected;
end
refreshStudySelector(fig);
end

function selectOnlyStudy(fig, studyIndex)
state = getappdata(fig, 'StudySelectorState');
for k = 1:numel(state.CheckBoxes)
    state.CheckBoxes(k).Value = k == studyIndex;
end
refreshStudySelector(fig);
end

function refreshStudySelector(fig)
state = getappdata(fig, 'StudySelectorState');
checked = false(numel(state.CheckBoxes), 1);
for k = 1:numel(state.CheckBoxes)
    checked(k) = state.CheckBoxes(k).Value ~= 0;
end
selectedCodes = strings(0, 1);
for k = find(checked(:))'
    selectedCodes = [selectedCodes; state.Studies.codes{k}(:)]; %#ok<AGROW>
end
reports = state.Events(ismember(state.Events.study, selectedCodes), :);
reportClasses = projectionClasses(reports);
gradedGrades = ["weak", "moderate", "strong"];
positiveGrades = ["weak", "moderate", "strong", "present", "broad"];
eligibleStrength = ismember(reports.strengthGrade, gradedGrades) & ...
    ismember(reports.type, state.StrengthTypes) & ...
    ismember(reports.grade, positiveGrades);
strengthModes = ["afferent", "efferent", "unspecified"];
availableSources = cell(numel(strengthModes), 1);
canSizeByMode = false(numel(strengthModes), 1);
for modeIndex = 1:numel(strengthModes)
    sources = unique(reports.study(eligibleStrength & ...
        reportClasses == strengthModes(modeIndex)));
    availableSources{modeIndex} = sources;
    canSizeByMode(modeIndex) = nnz(checked) == 1 && numel(sources) == 1;
    if canSizeByMode(modeIndex)
        state.StrengthButtons(modeIndex).Enable = 'on';
    else
        state.StrengthButtons(modeIndex).Enable = 'off';
    end
end
canSizeByCount = ~isempty(checked) && all(checked);
if canSizeByCount
    state.CountButton.Enable = 'on';
else
    state.CountButton.Enable = 'off';
end
sizeMode = string(state.SizeGroup.SelectedObject.Tag);
if sizeMode == "studycount"
    if ~canSizeByCount
        state.SizeGroup.SelectedObject = state.UniformButton;
        sizeMode = "uniform";
    end
elseif sizeMode ~= "uniform"
    selectedModeIndex = find(strengthModes == sizeMode, 1);
    if isempty(selectedModeIndex) || ~canSizeByMode(selectedModeIndex)
        state.SizeGroup.SelectedObject = state.UniformButton;
        sizeMode = "uniform";
    end
end
if sizeMode == "uniform"
    selectedModeIndex = [];
end
if sizeMode == "studycount"
    state.StrengthLegend.Visible = 'off';
    state.CountLegend.Visible = 'on';
    state.Note.String = sprintf(['Counts distinct papers with a positive connection.\n' ...
        'More studies make a larger dot; open = no graded strength.']);
else
    state.StrengthLegend.Visible = 'on';
    state.CountLegend.Visible = 'off';
    if sizeMode == "uniform"
        state.Note.String = sprintf(['Uniform dots are open; no strength grade is shown.\n' ...
            'Select one study to size dots by connection strength.']);
    else
        state.Note.String = sprintf(['Dots remain visible for all selected studies.\n' ...
            'Filled dots show graded connection strength.']);
    end
end
connected = 0;
for k = 1:numel(state.NodeLabels)
    label = state.NodeLabels(k);
    nodeMatch = reports.target == label;
    nodeReports = reports(nodeMatch, :);
    nodeClasses = reportClasses(nodeMatch);
    positive = ismember(nodeReports.grade, positiveGrades);
    shown = label == state.Seed || any(positive);
    if ~shown
        state.NodeHandles(k).Visible = 'off';
        state.TextHandles(k).Visible = 'off';
        continue
    end
    state.NodeHandles(k).Visible = 'on';
    state.TextHandles(k).Visible = 'on';
    if label == state.Seed
        size = 9;
        alpha = 1;
        description = "Seed region";
    else
        connected = connected + 1;
        if sizeMode == "uniform"
            size = 9;
            hasNodeGrade = false;
            strength = "not encoded by size (uniform)";
        elseif sizeMode == "studycount"
            studyCount = numel(unique(nodeReports.study(positive)));
            % Use the Python plot's proportional scale, with a readable
            % minimum for one-study open circles.
            size = max(9, 5 * studyCount);
            hasNodeGrade = any(positive & ...
                ismember(nodeReports.strengthGrade, gradedGrades) & ...
                ismember(nodeReports.type, state.StrengthTypes));
            strength = "not encoded by size (study count)";
        else
            activeCode = availableSources{selectedModeIndex}(1);
            graded = positive & nodeClasses == sizeMode & ...
                nodeReports.study == activeCode & ...
                ismember(nodeReports.strengthGrade, gradedGrades) & ...
                ismember(nodeReports.type, state.StrengthTypes);
            hasNodeGrade = any(graded);
            size = 9;
            strength = "not reported for " + sizeMode;
            if hasNodeGrade
                ranks = arrayfun(@(s) projectionRank(s, true), ...
                    nodeReports.strengthGrade(graded));
                score = roundHalfToEven(mean(ranks));
                sizeByRank = [9, 15, 22];
                strengthNames = ["weak", "moderate", "strong"];
                size = sizeByRank(score);
                strength = strengthNames(score) + " (" + sizeMode + ...
                    "; " + displayStudyNames(activeCode, ...
                    state.SourceStudies) + ")";
            end
        end
        isOpen = ~hasNodeGrade;
        conflicts = false(1, 2);
        directions = ["out", "in"];
        for d = 1:2
            inDirection = nodeReports.direction == directions(d);
            conflicts(d) = any(positive & inDirection) && ...
                any(nodeReports.grade == "absent" & inDirection);
        end
        if all(conflicts)
            alpha = 0.2;
        else
            alpha = 1;
        end
        if state.PaperMode
            alpha = 1;
        end
        sources = sort(unique(nodeReports.study(positive)));
        sourceNames = unique(displayStudyNames(sources, ...
            state.SourceStudies), 'stable');
        description = "Reported by: " + ...
            strjoin(sourceNames, ', ');
        if sizeMode == "studycount"
            description = description + newline + ...
                "Supporting studies: " + string(studyCount);
        end
        description = description + newline + ...
            "Graded connection strength: " + strength;
        absentSources = sort(unique(nodeReports.study(nodeReports.grade == "absent")));
        if ~isempty(absentSources)
            absentNames = unique(displayStudyNames(absentSources, ...
                state.SourceStudies), 'stable');
            description = description + newline + ...
                "Selected reports of absence: " + ...
                strjoin(absentNames, ', ');
        end
    end
    marker = state.NodeHandles(k);
    marker.SizeData = (0.75 * size)^2;
    marker.MarkerFaceAlpha = alpha;
    marker.MarkerEdgeAlpha = alpha;
    if label == state.Seed
        marker.MarkerFaceColor = colorRGB(state.NodeColors(k));
        marker.MarkerEdgeColor = colorRGB(state.NodeOutlines(k));
        marker.LineWidth = 1;
    elseif isOpen
        marker.MarkerFaceColor = 'none';
        if state.PaperMode
            marker.MarkerEdgeColor = colorRGB(state.NodeColors(k));
            marker.LineWidth = 1.8;
        else
            marker.MarkerEdgeColor = [0, 0, 0];
            marker.LineWidth = 1.2;
        end
    else
        marker.MarkerFaceColor = colorRGB(state.NodeColors(k));
        marker.MarkerEdgeColor = colorRGB(state.NodeOutlines(k));
        marker.LineWidth = 1;
    end
    marker.DataTipTemplate.DataTipRows = ...
        wrappedDataTipRows(displayAreaLabel(label), description);
    position = state.TextHandles(k).Position;
    position(2) = labelPositionY(state.NodeY(k), size, state.Scale);
    state.TextHandles(k).Position = position;
end
for k = 1:numel(state.EdgeHandles)
    target = state.EdgeTargets(k);
    active = any(reports.target == target & ismember(reports.grade, positiveGrades));
    if active
        state.EdgeHandles(k).Visible = 'on';
    else
        state.EdgeHandles(k).Visible = 'off';
    end
end
regionWord = 'regions';
if connected == 1
    regionWord = 'region';
end
selectionWord = 'selections';
if nnz(checked) == 1
    selectionWord = 'selection';
end
state.Status.String = sprintf('%d connected %s from %d study %s (%d papers).', ...
    connected, regionWord, nnz(checked), selectionWord, ...
    numel(unique(selectedCodes)));
end

function classes = projectionClasses(events)
% Afferent reports target FST; efferent reports originate at FST.
% DTI and functional inactivation do not establish an anatomical projection direction.
classes = repmat("unspecified", height(events), 1);
for k = 1:height(events)
    method = lower(events.type(k));
    if method ~= "tracer" && method ~= "literature synthesis"
        continue
    end
    direction = events.direction(k);
    if direction == "in"
        classes(k) = "afferent";
    elseif direction == "out"
        classes(k) = "efferent";
    end
end
end

function names = displayStudyNames(codes, studies)
names = strings(size(codes));
hasGroups = ismember('codes', studies.Properties.VariableNames);
for k = 1:numel(codes)
    row = [];
    for j = 1:height(studies)
        if hasGroups && any(studies.codes{j} == codes(k))
            row = j;
            break
        elseif ~hasGroups && studies.code(j) == codes(k)
            row = j;
            break
        end
    end
    if isempty(row)
        names(k) = codes(k);
    else
        names(k) = studies.label(row);
    end
end
end

function name = displayAreaLabel(rawName)
% Keep data keys unchanged; expand abbreviated names only in the figure.
name = string(rawName);
name(name == "basalfore") = "basal forebrain";
end

function rows = wrappedDataTipRows(region, description)
% Separate rows keep MATLAB data tips narrow even with many study sources.
maxCharacters = 44;
parts = splitlines(string(description));
wrapped = strings(0, 1);
for k = 1:numel(parts)
    remaining = strtrim(char(parts(k)));
    while numel(remaining) > maxCharacters
        splitAt = find(isspace(remaining(1:maxCharacters)), 1, 'last');
        if isempty(splitAt)
            splitAt = maxCharacters;
        end
        wrapped(end+1, 1) = string(strtrim(remaining(1:splitAt))); %#ok<AGROW>
        remaining = strtrim(remaining(splitAt+1:end));
    end
    if ~isempty(remaining)
        wrapped(end+1, 1) = string(remaining); %#ok<AGROW>
    end
end
if isempty(wrapped)
    wrapped = "";
end
rows = dataTipTextRow('Region', region);
for k = 1:numel(wrapped)
    if k == 1
        rowLabel = 'Evidence';
    else
        rowLabel = ' ';
    end
    rows(end+1) = dataTipTextRow(rowLabel, wrapped(k)); %#ok<AGROW>
end
end

function y = labelPositionY(nodeY, markerDiameterPixels, dataUnitsPerPixel)
% Keep the bottom of the label above the marker with a small visible gap.
y = nodeY + (markerDiameterPixels / 2 + 8) * dataUnitsPerPixel;
end

function drawPaperDecorations(ax, layout, roi, species)
if species == "human"
    speciesTitle = "humans";
else
    speciesTitle = "macaques";
end
text(ax, 266, 18, "Connectivity in " + speciesTitle + " — " + roi, ...
    'HorizontalAlignment', 'center', 'FontSize', 13, ...
    'Color', [0.15, 0.15, 0.15], 'Interpreter', 'none', 'HitTest', 'off');
for k = 1:numel(layout.Boxes)
    box = layout.Boxes(k);
    rectangle(ax, 'Position', box.Rect, 'Curvature', 0.07, ...
        'FaceColor', [237, 235, 219] / 255, ...
        'EdgeColor', [0.35, 0.35, 0.35], 'LineWidth', 1, 'HitTest', 'off');
end
for k = 1:numel(layout.PathLabels)
    item = layout.PathLabels(k);
    text(ax, item.X, item.Y, item.Name, ...
        'BackgroundColor', item.Color, 'EdgeColor', [0.3, 0.3, 0.3], ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 11, 'Margin', 2, 'Interpreter', 'none', 'HitTest', 'off');
end
end

function drawPaperInsetTitles(ax, layout)
% Draw titles last so dots and area labels cannot cover them.
for k = 1:numel(layout.Boxes)
    box = layout.Boxes(k);
    text(ax, box.Rect(1) + box.Rect(3) / 2, box.Rect(2) + 3, ...
        box.Name, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', 'FontSize', 11, ...
        'Color', [0.16, 0.2, 0.27], 'Interpreter', 'none', ...
        'HitTest', 'off');
end
end

function controls = addPaperSizeControls(fig, ax, legendAx, width, plotHeight, ...
    nodeHandles, textHandles, nodeY, strengthSize, scale, initialMode, ...
    roi, nodeLabels, hasAnyStrength)
panelWidth = 260;
set(ax, 'Units', 'pixels', 'Position', [0, 0, width, plotHeight]);
if ~isempty(legendAx)
    set(legendAx, 'Units', 'pixels', ...
        'Position', [0.765 * width, 0.845 * plotHeight, ...
        0.23 * width, 0.145 * plotHeight]);
end
panel = uipanel('Parent', getappdata(fig, 'ConnectivityBuildingViewRoot'), ...
    'Units', 'pixels', ...
    'Position', [width, 0, panelWidth, plotHeight], ...
    'Title', 'Connectivity view', 'FontWeight', 'bold', ...
    'BackgroundColor', [0.975, 0.985, 1]);
group = uibuttongroup('Parent', panel, 'Units', 'pixels', ...
    'Position', [12, plotHeight - 145, panelWidth - 24, 112], ...
    'Title', 'Dot size', 'BackgroundColor', [0.975, 0.985, 1]);
uniformButton = uicontrol('Parent', group, 'Style', 'radiobutton', ...
    'Position', [10, 52, 200, 26], 'String', 'Uniform', ...
    'Tag', 'uniform', 'BackgroundColor', [0.975, 0.985, 1]);
strengthButton = uicontrol('Parent', group, 'Style', 'radiobutton', ...
    'Position', [10, 15, 200, 26], 'String', 'Connection strength', ...
    'Tag', 'strength', 'BackgroundColor', [0.975, 0.985, 1]);
if initialMode == "uniform" || ~hasAnyStrength
    group.SelectedObject = uniformButton;
else
    group.SelectedObject = strengthButton;
end
if ~hasAnyStrength
    strengthButton.Enable = 'off';
end
note = sprintf(['When Connection strength is selected, dot size uses\n' ...
    'graded tracer or DTI reports.']);
uicontrol('Parent', panel, 'Style', 'text', ...
    'Position', [12, plotHeight - 245, panelWidth - 24, 78], ...
    'String', note, 'HorizontalAlignment', 'left', ...
    'BackgroundColor', [0.975, 0.985, 1]);
addDotSizeLegend(panel, ...
    [12, plotHeight - 400, panelWidth - 24, 135], true);
state = struct('SizeGroup', group, 'NodeHandles', nodeHandles, ...
    'TextHandles', textHandles, 'NodeY', nodeY, ...
    'StrengthSize', strengthSize, 'Scale', scale, ...
    'SeedIndex', find(roi == "FST" & nodeLabels == "FST", 1));
setappdata(fig, 'PaperSizeState', state);
group.SelectionChangedFcn = @(src, ~) refreshPaperSizeMode(ancestor(src, 'figure'));
refreshPaperSizeMode(fig);
controls = struct('Panel', panel, 'CheckBoxes', gobjects(0, 1), ...
    'OnlyButtons', gobjects(0, 1), 'ProjectionGroup', [], ...
    'ProjectionButtons', gobjects(0, 1), 'SizeGroup', group, ...
    'SizeButtons', [uniformButton; strengthButton]);
end

function key = addDotSizeLegend(parent, position, singleColumn, kind, maxCount)
if nargin < 4
    kind = "strength";
end
if nargin < 5
    maxCount = 4;
end
if kind == "count"
    legendTitle = 'Number of studies';
    legendTag = 'StudyCountLegend';
    countValues = 1:min(maxCount, 4);
    labels = string(countValues) + " studies";
    labels(1) = "1 study";
    diameters = max(9, 5 * countValues);
    openIndex = 0;
else
    legendTitle = 'Dot size legend';
    legendTag = 'DotSizeLegend';
    labels = ["Weak (small)", "Moderate (medium)", ...
        "Strong (large)", "No grade (open)"];
    diameters = [9, 15, 22, 9];
    openIndex = numel(labels);
end
background = [0.975, 0.985, 1];
key = uipanel('Parent', parent, 'Units', 'pixels', 'Position', position, ...
    'Title', legendTitle, 'Tag', legendTag, ...
    'FontSize', 11, 'BackgroundColor', background);
plotWidth = position(3) - 16;
plotHeight = position(4) - 30;
keyAx = axes('Parent', key, 'Units', 'pixels', ...
    'Position', [8, 6, plotWidth, plotHeight], ...
    'XLim', [0, plotWidth], 'YLim', [0, plotHeight], ...
    'Color', background, 'XColor', 'none', 'YColor', 'none', ...
    'HitTest', 'off');
if singleColumn
    markerX = [18, 18, 18, 18];
    labelX = [40, 40, 40, 40];
    rowY = [91, 64, 37, 10];
else
    markerX = [18, 248, 18, 248];
    labelX = [40, 272, 40, 272];
    rowY = [42, 42, 14, 14];
end
hold(keyAx, 'on');
for k = 1:numel(labels)
    marker = scatter(keyAx, markerX(k), rowY(k), ...
        (0.75 * diameters(k))^2, [0.25, 0.25, 0.25], 'filled', ...
        'HitTest', 'off');
    if k == openIndex
        marker.MarkerFaceColor = 'none';
        marker.MarkerEdgeColor = [0.25, 0.25, 0.25];
        marker.LineWidth = 1.3;
    end
    text(keyAx, labelX(k), rowY(k), labels(k), ...
        'VerticalAlignment', 'middle', 'FontSize', 10, ...
        'Color', [0.16, 0.2, 0.27], 'Interpreter', 'none', ...
        'HitTest', 'off');
end
axis(keyAx, 'off');
hold(keyAx, 'off');
end

function refreshPaperSizeMode(fig)
state = getappdata(fig, 'PaperSizeState');
mode = string(state.SizeGroup.SelectedObject.Tag);
if mode == "uniform"
    sizes = 9 * ones(size(state.StrengthSize));
else
    sizes = state.StrengthSize;
end
for k = 1:numel(state.NodeHandles)
    if ~isempty(state.SeedIndex) && k == state.SeedIndex
        continue
    end
    state.NodeHandles(k).SizeData = (0.75 * sizes(k))^2;
    position = state.TextHandles(k).Position;
    position(2) = labelPositionY(state.NodeY(k), sizes(k), state.Scale);
    state.TextHandles(k).Position = position;
end
end
