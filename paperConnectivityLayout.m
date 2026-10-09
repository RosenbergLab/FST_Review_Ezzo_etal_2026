function layout = paperConnectivityLayout(nodes, imagePath)
%PAPERCONNECTIVITYLAYOUT Macaque lateral cortex in paper-figure coordinates.
%   LAYOUT = PAPERCONNECTIVITYLAYOUT(NODES, IMAGEPATH) uses the white-backed
%   veryinflated_lat_white.tif and the supplied paper figure's dot centers.
%   Areas absent from the reference retain native nodes.csv positions.
%   Paper coordinates increase to the right and downward. Box Rect values
%   are [left, top, width, height] in the same coordinates.

if ~istable(nodes) || ~all(ismember({'x', 'y', 'label'}, nodes.Properties.VariableNames))
    error('paperConnectivityLayout:InvalidNodes', ...
        'nodes must be a table with x, y, and label columns.');
end

brain = imread(imagePath);
if ndims(brain) ~= 3 || size(brain, 3) < 3
    error('paperConnectivityLayout:InvalidImage', ...
        'imagePath must contain an RGB lateral brain image.');
end
brain = brain(:, :, 1:3);
if isa(brain, 'uint16')
    brain = uint8(round(double(brain) / 257));
elseif ~isa(brain, 'uint8')
    brain = uint8(round(255 * double(brain)));
end
[height, width, ~] = size(brain);
if width ~= 2250 || height ~= 1326
    error('paperConnectivityLayout:UnexpectedImageSize', ...
        'Expected the 2250-by-1326 macaque veryinflated_lat_white.tif.');
end

% The reference brain spans about (31,29)-(478,288); its corresponding
% silhouette spans about (20,20)-(2230,1295) in the lateral TIFF.
scaleX = 447 / 2210;
scaleY = 259 / 1275;
offsetX = 31 - 20 * scaleX;
offsetY = 29 - 20 * scaleY;

labels = strtrim(string(nodes.label));
x = numericValues(nodes.x);
y = numericValues(nodes.y);
if any(~isfinite(x) | ~isfinite(y))
    error('paperConnectivityLayout:InvalidCoordinates', ...
        'Every selected node must have finite x and y coordinates.');
end
nodeX = offsetX + scaleX * x;
nodeY = offsetY + scaleY * y;

% TF is visible only in the ventral snapshot; the paper projects it to
% the inferior edge of the lateral silhouette.
[nodeX, nodeY] = placeNode(labels, nodeX, nodeY, 'TF', [257, 279]);
% These two master-list points fall just beyond the rendered upper edge.
[nodeX, nodeY] = placeNode(labels, nodeX, nodeY, '5', ...
    [offsetX + scaleX * 1200, offsetY + scaleY * 80]);
[nodeX, nodeY] = placeNode(labels, nodeX, nodeY, 'PO', ...
    [offsetX + scaleX * 1830, offsetY + scaleY * 275]);

medialNames = ["V6", "PCCa", "PCCp", "RSC", "24c", "7m", ...
    "preSMA", "BA23", "BA31"];
hasExtraMedial = any(ismember(labels, ["24c", "7m", "preSMA"]));
if hasExtraMedial
    medialRect = [36, 220, 93, 85];
    medialPoints = [51 253; 96 275; 51 297; 96 297; ...
        81 253; 113 253; 51 275; 96 275; 51 297];
else
    medialRect = [5, 5, 134, 66];
    medialPoints = [49 34; 127 34; 54 55; 120 55; ...
        49 34; 127 34; 54 55; 127 34; 54 55];
end

subcorticalNames = ["basalfore", "SC", "claustrum", "pons", ...
    "striatum", "pretectum", "thalamus", "pulvinar", "TRN"];
subcorticalPoints = [394 249; 459 249; 394 270; 459 270; ...
    394 290; 459 290; 394 310; 394 306.7; 459 306.7];
for k = 1:numel(subcorticalNames)
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        subcorticalNames(k), subcorticalPoints(k, :));
end

% Dot centers aligned to the supplied macaque panel. Areas absent from that
% panel retain their schematic positions above.
referenceLabels = ["V1"; "V2"; "V3"; "V3A"; "V4"; "V4t"; "MT"; ...
    "MSTm"; "PITv"; "PITd"; "CITd"; "CITv"; "AITd"; "AITv"; ...
    "STPp"; "STPa"; "A1"; "STGa"; "insula"; "MSTd"; "DP"; ...
    "7a"; "PF"; "AIP"; "LIP"; "VIP"; "S1"; "FEF"; "SEF"; ...
    "dlPFC"; "vlPFC"; "M1"; "PMd"; "PMv"; "TG"; "TF"; ...
    "V6"; "RSC"; "PCCa"; "PCCp"; "thalamus"; "claustrum"; ...
    "striatum"; "basalfore"; "pretectum"; "SC"; "pons"];
referenceXY = [ ...
    436.0 153.0; 395.0 154.0; 375.6 160.5; 388.0 80.0; ...
    355.0 186.0; 345.0 163.0; 332.0 134.0; 306.0 122.0; ...
    327.0 223.0; 309.0 181.0; 275.0 207.0; 280.0 239.0; ...
    239.0 222.0; 239.0 249.0; 253.0 178.0; 208.0 212.0; ...
    254.0 131.0; 210.0 189.0; 180.0 164.0; 336.0 103.0; ...
    358.8 74.7; 309.1 78.8; 275.3 108.6; 245.6 67.7; ...
    324.1 54.7; 286.7 63.6; 223.3 40.5; 124.2 122.5; ...
    122.5 93.2; 90.0 114.5; 94.0 152.9; 196.3 95.6; ...
    155.7 74.6; 162.8 127.5; 186.0 247.0; 258.0 268.0; ...
    47.1 257.7; 86.1 281.7; 86.1 257.7; 47.1 281.7; ...
    394.0 306.7; 394.0 268.5; 394.0 287.5; 394.0 248.9; ...
    457.0 287.5; 457.0 249.0; 457.0 268.5
];
for k = 1:numel(referenceLabels)
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        referenceLabels(k), referenceXY(k, :));
end
% Use the supplied inset positions after the cortical reference points.
for k = 1:numel(medialNames)
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        medialNames(k), medialPoints(k, :));
end
[nodeX, nodeY] = placeNode(labels, nodeX, nodeY, 'V3d', [390.5, 107.5]);
% V4t remains below the dark STS sulcus in the TIFF.
[nodeX, nodeY] = placeNode(labels, nodeX, nodeY, 'V4t', [345, 163]);
[nodeX, nodeY] = placeNode(labels, nodeX, nodeY, 'FST', [313, 153]);

% Keep any newly supplied node visible even when it has no named paper
% placement. The current macaque master list is covered above.
nodeX = min(max(nodeX, 5), 529);
nodeY = min(max(nodeY, 5), 323);

% Keep the TIFF pixels unchanged; the plot blends them with white at 50%.
layout.Image = brain;
layout.ImageAlpha = 0.5;
layout.NodeX = nodeX(:);
layout.NodeY = nodeY(:);
layout.ImageX = [offsetX, offsetX + scaleX * (width - 1)];
layout.ImageY = [offsetY, offsetY + scaleY * (height - 1)];
layout.XLimits = [0, 534];
layout.YLimits = [0, 328];
layout.FigureWidth = 1335;
layout.FigureHeight = 820;
layout.FSTCenter = [313, 153];
layout.Boxes = [ ...
    struct('Name', "medial cortex", 'Rect', medialRect), ...
    struct('Name', "subcortical", 'Rect', [371, 227, 107, 85])];
layout.PathLabels = [ ...
    struct('Name', "dorsal pathway", 'X', 370, 'Y', 42, ...
        'Color', [179, 228, 248] / 255), ...
    struct('Name', "lateral pathway", 'X', 95, 'Y', 200, ...
        'Color', [242, 179, 208] / 255), ...
    struct('Name', "ventral pathway", 'X', 288, 'Y', 286, ...
        'Color', [249, 243, 132] / 255)];
end

function values = numericValues(column)
if isnumeric(column)
    values = double(column);
else
    values = str2double(string(column));
end
values = values(:);
end

function [x, y] = placeNode(labels, x, y, name, point)
match = labels == string(name);
x(match) = point(1);
y(match) = point(2);
end
