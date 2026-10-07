function layout = paperHumanConnectivityLayout(nodes, imagePath)
%PAPERHUMANCONNECTIVITYLAYOUT Human FST on one lateral cortical surface.
%   Lateral node coordinates come from human/nodes.csv. The display moves
%   them slightly toward the center of the TIFF so edge labels remain on
%   visible cortex. Medial areas use one inset; ventral areas sit on or near
%   the inferior edge of the lateral view.

if ~istable(nodes) || ~all(ismember({'x', 'y', 'label'}, ...
        nodes.Properties.VariableNames))
    error('paperHumanConnectivityLayout:InvalidNodes', ...
        'nodes must be a table with x, y, and label columns.');
end

brain = imread(imagePath);
if ndims(brain) ~= 3 || size(brain, 3) < 3
    error('paperHumanConnectivityLayout:InvalidImage', ...
        'imagePath must contain an RGB lateral brain image.');
end
brain = brain(:, :, 1:3);
if isa(brain, 'uint16')
    brain = uint8(round(double(brain) / 257));
elseif ~isa(brain, 'uint8')
    brain = uint8(round(255 * double(brain)));
end
[height, width, ~] = size(brain);
if width ~= 2250 || height ~= 1523
    error('paperHumanConnectivityLayout:UnexpectedImageSize', ...
        'Expected the 2250-by-1523 human veryinflated_lat_white.tif.');
end

labels = strtrim(string(nodes.label));
x = numericValues(nodes.x);
y = numericValues(nodes.y);
if any(~isfinite(x) | ~isfinite(y))
    error('paperHumanConnectivityLayout:InvalidCoordinates', ...
        'Every selected node must have finite x and y coordinates.');
end

scale = 0.20;
offsetX = 30;
offsetY = 25;
centerX = width / 2;
centerY = height / 2;
inward = 0.90;
nodeX = offsetX + scale * (centerX + inward * (x - centerX));
nodeY = offsetY + scale * (centerY + inward * (y - centerY));

% Keep the tightly packed early visual areas on the posterior surface.
earlyNames = ["V1", "V2", "V3"];
earlyNative = [2120 920; 2085 945; 2050 975];
for k = 1:numel(earlyNames)
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        earlyNames(k), [offsetX, offsetY] + scale * earlyNative(k, :));
end

% Display-only spacing keeps LO1–LO3 in the ventral cluster and PIT below
% FST on the lateral surface; native nodes.csv coordinates are unchanged.
adjustedNames = ["LO1", "LO2", "LO3", "PIT"];
adjustedPoints = [416.1 220; 408 238; 412.5 207; 388 245.4];
for k = 1:numel(adjustedNames)
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        adjustedNames(k), adjustedPoints(k, :));
end

medialNames = ["V6", "BA7", "BA23", "BA31", ...
    "precuneus", "RSC", "mPFC", "preSMA"];
medialRect = [8, 198, 122, 104];
if any(labels == "BA31")
    medialPoints = [37 230; 98 230; 37 250; 98 250; ...
        98 270; 37 270; 37 290; 98 290];
else
    medialPoints = [37 230; 98 230; 37 250; 98 250; ...
        98 250; 37 270; 98 270; 67 290];
end
for k = 1:numel(medialNames)
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        medialNames(k), medialPoints(k, :));
end

ventralNames = ["V8", "VMV", "VVC", "FFC", "TF"];
ventralPoints = [430 264; 400 274; 344 294; 365 277; 270 307];
for k = 1:numel(ventralNames)
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        ventralNames(k), ventralPoints(k, :));
end

nodeX = min(max(nodeX, 5), 529);
nodeY = min(max(nodeY, 5), 425);
layout.Image = brain;
layout.ImageAlpha = 0.5;
layout.NodeX = nodeX(:);
layout.NodeY = nodeY(:);
layout.ImageX = [offsetX, offsetX + scale * (width - 1)];
layout.ImageY = [offsetY, offsetY + scale * (height - 1)];
layout.XLimits = [0, 534];
layout.YLimits = [0, 360];
layout.FigureWidth = 1080;
layout.FigureHeight = 728;
layout.FSTCenter = [nodeX(labels == "FST"), nodeY(labels == "FST")];
layout.Boxes = struct('Name', "medial cortex", 'Rect', medialRect);
layout.PathLabels = [ ...
    struct('Name', "dorsal pathway", 'X', 411, 'Y', 48, ...
        'Color', [179, 228, 248] / 255), ...
    struct('Name', "lateral pathway", 'X', 190, 'Y', 278, ...
        'Color', [242, 179, 208] / 255), ...
    struct('Name', "ventral pathway", 'X', 356, 'Y', 333, ...
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
