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

% Dot centers digitized from the supplied 909-by-681 human paper figure.
% Register its lateral outline to the TIFF outline in plot coordinates.
% Native nodes.csv coordinates remain the fallback for future areas.
paperBounds = [33, 62, 865, 648];  % left, top, right, bottom in paper pixels
lateralBounds = [43.6, 28, 466.2, 326.4];  % same outline in plot units
paperScaleX = (lateralBounds(3) - lateralBounds(1)) / ...
    (paperBounds(3) - paperBounds(1));
paperScaleY = (lateralBounds(4) - lateralBounds(2)) / ...
    (paperBounds(4) - paperBounds(2));
referenceNames = ["PMd"; "SMA"; "FEF"; "M1"; "55b"; "3a/3b"; ...
    "BA1/2"; "AIP"; "VIP"; "LIP"; "MIP"; "IPS0/1"; "PFm"; "V7"; ...
    "V3A/B"; "BA8"; "PMv"; "op"; "PFop"; "BA44"; "aud"; "insula"; ...
    "TPOJ1"; "TPOJ2"; "TPOJ3"; "STSp"; "STSa"; "TE1a"; "TE1m"; ...
    "TE1p"; "TE2a"; "TE2p"; "TG"; "PHT"; "MST"; "MT"; "LO1-3"; ...
    "PH"; "PIT"; "FFC"; "V4t"; "V4"; "V3"; "V1"; "V2"; "V8"; ...
    "VMV"; "VVC"; "FST"];
referencePixels = [ ...
    354 130; 354 92; 344 184; 405 165; 355 232; 469 179; ...
    529 145; 592 162; 654 117; 675 162; 711 151; 740 193; ...
    666 260; 812 285; 835 347; 249 299; 325 327; 382 356; ...
    441 342; 255 376; 470 418; 265 503; 587 363; 648 389; ...
    692 352; 522 452; 402 521; 449 577; 515 551; 579 522; ...
    461 615; 592 576; 339 628; 619 439; 675 439; 724 425; ...
    772 432; 647 512; 705 521; 672 554; 767 477; 813 460; ...
    845 444; 882 435; 876 475; 768 553; 731 591; 637 606; ...
    707 477];
assert(numel(referenceNames) == size(referencePixels, 1));
for k = 1:numel(referenceNames)
    paperX = referencePixels(k, 1);
    paperY = referencePixels(k, 2);
    point = [lateralBounds(1) + (paperX - paperBounds(1)) * paperScaleX, ...
        lateralBounds(2) + (paperY - paperBounds(2)) * paperScaleY];
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        referenceNames(k), point);
end

% Align medial areas on a compact display grid inside the inset.
medialNames = ["MCC", "BA23", "V6", "preSMA", "RSC", "BA7", ...
    "precuneus"];
medialPoints = [56 256; 102 256; 56 275; 102 275; ...
    56 294; 79 275; 102 294];
medialRect = [40, 228, 80, 72];
for k = 1:numel(medialNames)
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        medialNames(k), medialPoints(k, :));
end
if any(labels == "BA31")
    % No BA31 dot is supplied in the reference figure.
    [nodeX, nodeY] = placeNode(labels, nodeX, nodeY, ...
        "BA31", [79, 294]);
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
