// Execute the generated browser script in a small DOM stand-in. This checks
// the controls and rendering logic without a browser or network dependency.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync(process.argv[2], 'utf8');
assert.equal(html.includes('Counts distinct papers with a positive connection.'), false);
const payload = html.match(/<script id="connectivity-data"[^>]*>([\s\S]*?)<\/script>/)[1];
const config = JSON.parse(payload);
const script = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].at(-1)[1];

class Element {
  constructor(tag) {
    this.tag = tag;
    this.children = [];
    this.attributes = {};
    this.style = {};
    this.listeners = {};
    this.className = '';
    this.classList = {
      add: token => { this.className += ' ' + token; },
      toggle: () => {},
    };
    this.textContent = '';
    this.offsetWidth = 300;
    this.offsetHeight = 120;
  }
  setAttribute(key, value) { this.attributes[key] = String(value); }
  appendChild(child) { this.children.push(child); return child; }
  append(value) { this.children.push(value); }
  replaceChildren() { this.children = []; }
  addEventListener(name, callback) { this.listeners[name] = callback; }
  getBoundingClientRect() { return {right: 500, top: 300}; }
}

const elements = {
  'connectivity-data': Object.assign(new Element('script'), {textContent: payload}),
  frame: new Element('main'),
  holder: new Element('div'),
  tooltip: new Element('div'),
};
const document = {
  getElementById: id => elements[id],
  createElement: name => new Element(name),
  createElementNS: (_, name) => new Element(name),
};
vm.runInNewContext(script, {
  document, innerWidth: 1920, innerHeight: 1080,
  addEventListener: () => {},
}, {timeout: 5000});

function all(root, predicate) {
  return [root, ...root.children.filter(child => typeof child !== 'string')
    .flatMap(child => all(child, predicate))].filter(predicate);
}
function one(root, predicate) {
  const matches = all(root, predicate);
  assert.equal(matches.length, 1);
  return matches[0];
}
function selectRadio(root, radio) {
  for (const item of all(root, el => el.tag === 'input' && el.type === 'radio' &&
    el.name === radio.name)) item.checked = item === radio;
  radio.listeners.change();
}
function areaLabelPositions(root) {
  return all(root, el => el.tag === 'text' &&
    el.attributes['pointer-events'] === 'none')
    .map(label => [label.textContent, label.attributes.x, label.attributes.y]);
}

const frame = elements.frame;
assert.equal(frame.children.length, 2);
const [macaque, human] = frame.children;
const macSizeField = one(macaque, el => el.className === 'size-group');
const macLegend = one(macSizeField, el => el.className === 'legend');
const macGuidance = one(macSizeField, el => el.className === 'size-guidance');
assert.equal(macGuidance.textContent,
  'Select one study to size dots by connection strength.');
assert.ok(macSizeField.children.indexOf(macLegend) <
  macSizeField.children.indexOf(macGuidance));
assert.notEqual(macGuidance.style.display, 'none');
assert.equal(one(macSizeField, el => el.className === 'size-note').textContent, '');
assert.equal(macLegend.style.display, 'none');
for (const root of [macaque, human]) {
  assert.equal(one(root, el => el.className === 'color-note').textContent,
    'Black/Grey. Grey: A study explicitly reports no connection, whereas another reports a connection.');
  assert.equal(one(root, el => el.className === 'color-note').style.display, 'none');
  one(root, el => el.tag === 'label' &&
    el.children.includes('Conflicting studies'));
}
const macaqueLabels = areaLabelPositions(macaque);
const humanLabels = areaLabelPositions(human);
for (const [root, species] of [[macaque, 'macaque'], [human, 'human']]) {
  const labels = areaLabelPositions(root);
  config[species].nodes.forEach((node, index) => {
    assert.equal(Number(labels[index][1]), node.x);
    assert.equal(Number(labels[index][2]), node.y -
      (9 / 2 + 8) * config[species].view_box[3] / config[species].plot_size[1]);
  });
}
if (config.initial_species === 'human') {
  assert.equal(human.hidden, false);
  const select = one(human, el => el.className === 'species-choice');
  select.value = 'macaque';
  select.listeners.change();
}
assert.equal(macaque.hidden, false);
assert.equal(human.hidden, true);
assert.equal(all(macaque, el => el.tag === 'circle').length, 48);
assert.equal(all(macaque, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'V3').length, 0);
assert.equal(all(human, el => el.tag === 'circle').length, 56);
assert.equal(config.macaque.studies.length, 5);
assert.equal(config.macaque.studies.some(study => study.code === 'Fel91'), false);
assert.ok(config.macaque.studies.find(study => study.code === 'mixed_tracer')
  .codes.includes('Bar00'));
assert.match(html, /grid-template-columns: repeat\(2, minmax\(0, 1fr\)\)/);
const combinedRow = one(macaque, el => el.className === 'study-row has-detail');
assert.match(one(combinedRow, el => el.className === 'label-text').textContent,
  /Combined tracer evidence/);
assert.deepEqual(one(combinedRow, el => el.className === 'study-detail')
  .children.map(item => item.textContent),
  ['Andersen et al. (1990)', 'Boussaoud et al. (1990)',
   'Boussaoud et al. (1992)', 'Seltzer et al. (1996)',
   'Felleman et al. (1997)', 'Barone et al. (2000)',
   'Ungerleider et al. (2008)', 'Markov et al. (2014)']);
assert.deepEqual(Array.from(config.macaque.studies.find(study =>
  study.code === 'mixed_tracer').codes),
  ['And90', 'Bou90', 'Bou92', 'Sel96', 'Fel97', 'Bar00', 'Ung08', 'Mark14']);

const macStatus = one(macaque, el => el.className === 'status');
assert.match(macStatus.textContent, /47 connected regions/);
for (const circle of all(macaque, el => el.tag === 'circle')) {
  if (circle.attributes['aria-label'] === 'FST')
    assert.notEqual(circle.attributes.fill, 'none');
  else if (circle.style.display !== 'none')
    assert.equal(circle.attributes.fill, 'none');
}
const macClear = one(macaque, el => el.className === 'clear-button');
macClear.listeners.click();
assert.match(macStatus.textContent, /^0 connected regions/);
assert.equal(macLegend.style.display, 'none');
const visibleAfterClear = all(macaque, el => el.tag === 'circle')
  .filter(circle => circle.style.display !== 'none');
assert.equal(visibleAfterClear.length, 1);
assert.equal(visibleAfterClear[0].attributes['aria-label'], 'FST');

const macAll = one(macaque, el => el.className === 'all-button');
macAll.listeners.click();
assert.match(macStatus.textContent, /47 connected regions/);
assert.match(macStatus.textContent, /\(11 papers\)/);
assert.equal(macLegend.style.display, 'none');
const macRows = all(macaque, el => el.className.split(' ').includes('study-row'));
const macRowFor = phrase => macRows.find(row => all(row, el =>
  el.className === 'label-text' && el.textContent.includes(phrase)).length);
for (const name of ['Boussaoud', 'Markov']) {
  const row = macRowFor(name);
  one(row, el => el.tag === 'input' && el.type === 'checkbox').checked = false;
}
one(macRowFor('Markov'), el => el.tag === 'input' && el.type === 'checkbox')
  .listeners.change();
assert.match(macStatus.textContent, /\(11 papers\)/);
assert.equal(one(macaque, el => el.tag === 'input' && el.value === 'studycount').disabled,
  false);
assert.equal(one(macaque, el => el.tag === 'input' && el.value === 'conflict').disabled,
  false);
macAll.listeners.click();
const macColor = one(macaque, el => el.tag === 'input' && el.value === 'conflict');
const macPathway = one(macaque, el => el.tag === 'input' && el.value === 'pathway');
assert.equal(macColor.disabled, false);
assert.equal(macPathway.checked, true);
selectRadio(macaque, macColor);
assert.equal(one(macaque, el => el.className === 'color-note').style.display, '');
const greyFEF = one(macaque, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'FEF');
const blackMT = one(macaque, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'MT');
const macFST = one(macaque, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'FST');
assert.equal(greyFEF.attributes.stroke, '#A6A6A6');
assert.equal(blackMT.attributes.stroke, '#000000');
assert.equal(macFST.attributes.fill, '#000000');
assert.doesNotMatch(greyFEF._tooltip, /Grey:|A study explicitly reports no connection/);
assert.doesNotMatch(blackMT._tooltip, /Black dot:|no conflict is marked/);
selectRadio(macaque, macPathway);
assert.equal(one(macaque, el => el.className === 'color-note').style.display, 'none');
assert.equal(greyFEF.attributes.stroke, '#000000');
assert.equal(blackMT.attributes.stroke, '#B3E4F8');
const countRadio = one(macaque, el => el.tag === 'input' && el.value === 'studycount');
assert.equal(countRadio.disabled, false);
selectRadio(macaque, countRadio);
assert.equal(macLegend.style.display, '');
assert.notEqual(macGuidance.style.display, 'none');
assert.deepEqual(areaLabelPositions(macaque), macaqueLabels);
assert.equal(one(macaque, el => el.className === 'legend-title').textContent,
  'Number of studies');
for (const circle of all(macaque, el => el.tag === 'circle' &&
  el.style.display !== 'none')) assert.notEqual(circle.attributes.fill, 'none');
selectRadio(macaque, macColor);
assert.equal(greyFEF.attributes.stroke, '#A6A6A6');
selectRadio(macaque, macPathway);
const fef = one(macaque, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'FEF');
assert.match(fef._tooltip, /Supporting studies: 3/);
const pulvinar = one(macaque, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'pulvinar');
assert.match(pulvinar._tooltip, /Supporting studies: 1/);
const v3d = one(macaque, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'V3d');
assert.equal(v3d.attributes.stroke, '#B3E4F8');
assert.match(v3d._tooltip, /Supporting studies: 2/);

const macSpecies = one(macaque, el => el.className === 'species-choice');
macSpecies.value = 'human';
macSpecies.listeners.change();
assert.equal(macaque.hidden, true);
assert.equal(human.hidden, false);
const humanStatus = one(human, el => el.className === 'status');
assert.match(humanStatus.textContent, /55 connected regions/);
const humanFST = one(human, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'FST');
function assertHumanConnectionDotsOpen() {
  assert.notEqual(humanFST.attributes.fill, 'none');
  for (const circle of all(human, el => el.tag === 'circle')) {
    if (circle !== humanFST && circle.style.display !== 'none')
      assert.equal(circle.attributes.fill, 'none');
  }
}
function assertHumanConnectionDotsFilled() {
  for (const circle of all(human, el => el.tag === 'circle' &&
    el.style.display !== 'none')) assert.notEqual(circle.attributes.fill, 'none');
}
assertHumanConnectionDotsOpen();
const pfop = one(human, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'PFop');
assert.match(pfop._tooltip, /Selected reports of absence: [^\n]*Ruan et al/);
const ph = one(human, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'PH');
assert.equal(ph.attributes.stroke, '#F9F384');
const pht = one(human, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'PHT');
assert.equal(pht.attributes.stroke, '#F2B3D0');
const lo = one(human, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'LO1-3');
const uniformRadius = Number(lo.attributes.r);
const humanCount = one(human, el => el.tag === 'input' && el.value === 'studycount');
assert.equal(humanCount.disabled, false);
const humanColor = one(human, el => el.tag === 'input' && el.value === 'conflict');
const humanPathway = one(human, el => el.tag === 'input' && el.value === 'pathway');
assert.equal(humanColor.disabled, false);
selectRadio(human, humanColor);
assert.equal(one(human, el => el.className === 'color-note').style.display, '');
assertHumanConnectionDotsOpen();
const greyPMd = one(human, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'PMd');
assert.equal(greyPMd.attributes.stroke, '#A6A6A6');
assert.equal(ph.attributes.stroke, '#000000');
assert.doesNotMatch(greyPMd._tooltip, /Grey:|A study explicitly reports no connection/);
selectRadio(human, humanPathway);
assert.equal(one(human, el => el.className === 'color-note').style.display, 'none');
assert.equal(ph.attributes.stroke, '#F9F384');
selectRadio(human, humanCount);
assert.equal(one(human, el => el.className === 'size-note').textContent,
  'Baker et al. (2018) counts once across methods.');
assert.deepEqual(areaLabelPositions(human), humanLabels);
assertHumanConnectionDotsFilled();
selectRadio(human, humanColor);
assertHumanConnectionDotsFilled();
assert.equal(greyPMd.attributes.stroke, '#A6A6A6');
selectRadio(human, humanPathway);
assert.ok(Number(lo.attributes.r) > uniformRadius);
assert.match(lo._tooltip, /Supporting studies: 2/);
assert.equal(one(human, el => el.className === 'legend-title').textContent,
  'Number of studies');
assert.equal(all(human, el => el.className === 'legend-entry').length, 3);
assert.equal(all(human, el => el.className === 'legend-dot open').length, 0);
selectRadio(human, humanColor);
one(human, el => el.className === 'clear-button').listeners.click();
assert.match(humanStatus.textContent, /^0 connected regions/);
assert.equal(humanCount.disabled, true);
assert.equal(one(human, el => el.tag === 'input' && el.value === 'uniform').checked, true);
assert.equal(humanColor.disabled, true);
assert.equal(humanPathway.checked, true);
assert.equal(one(human, el => el.className === 'color-note').style.display, 'none');
assert.equal(one(human, el => el.className === 'size-note').textContent,
  'Select all to size them by reporting studies.');
assert.equal(one(human, el => el.className === 'legend').style.display, 'none');
selectRadio(human, one(human, el => el.tag === 'input' && el.value === 'uniform'));
one(human, el => el.className === 'all-button').listeners.click();
assert.equal(one(human, el => el.className === 'size-note').textContent, '');

const humanSpecies = one(human, el => el.className === 'species-choice');
humanSpecies.value = 'macaque';
humanSpecies.listeners.change();
assert.equal(macaque.hidden, false);
assert.equal(human.hidden, true);
assert.equal(macSpecies.value, 'macaque');
assert.equal(countRadio.checked, true);
const firstOnly = all(macaque, el => el.className === 'only-button')[0];
selectRadio(macaque, macColor);
firstOnly.listeners.click();
assert.notEqual(macGuidance.style.display, 'none');
assert.equal(countRadio.disabled, true);
assert.equal(macColor.disabled, true);
assert.equal(macPathway.checked, true);
assert.equal(one(macaque, el => el.className === 'color-note').style.display, 'none');
const strength = all(macaque, el => el.tag === 'input' &&
  ['afferent', 'efferent', 'unspecified'].includes(el.value) && !el.disabled)[0];
assert.ok(strength, 'A single graded study should enable a strength mode');
selectRadio(macaque, strength);
assert.notEqual(macGuidance.style.display, 'none');
assert.equal(all(macaque, el => el.tag === 'span' &&
  el.textContent === 'No connection strength reported (open)').length, 1);
const activeMarkers = all(macaque, el => el.tag === 'circle')
  .filter(circle => circle.style.display !== 'none' &&
    circle.attributes['aria-label'] !== 'FST');
assert.ok(activeMarkers.some(circle => circle.attributes.fill === 'none'));
assert.ok(activeMarkers.some(circle => circle.attributes.fill !== 'none'));
const rows = all(macaque, el => el.className.split(' ').includes('study-row'));
const rowFor = phrase => rows.find(row => all(row, el =>
  el.className === 'label-text' && el.textContent.includes(phrase)).length);
one(rowFor('Boussaoud'), el => el.className === 'only-button').listeners.click();
const bouUniform = one(macaque, el => el.tag === 'input' && el.value === 'uniform');
selectRadio(macaque, bouUniform);
assert.equal(macLegend.style.display, 'none');
const bouMarker = name => one(macaque, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === (name === 'basalfore' ? 'basal forebrain' : name));
const subcortical = ['TRN', 'pulvinar', 'claustrum', 'striatum',
  'basalfore', 'pretectum', 'SC', 'pons'];
const visibleSubcortical = () => subcortical.filter(name =>
  bouMarker(name).style.display !== 'none').sort();
assert.deepEqual(visibleSubcortical(), subcortical.filter(name => name !== 'SC').sort());
assert.match(bouMarker('basalfore')._tooltip, /basal forebrain → FST/);
assert.match(bouMarker('striatum')._tooltip, /FST → striatum/);
assert.match(bouMarker('pulvinar')._tooltip, /FST ↔ pulvinar/);
const efferent = one(macaque, el => el.tag === 'input' && el.value === 'efferent');
assert.equal(efferent.disabled, false);
selectRadio(macaque, efferent);
assert.equal(macLegend.style.display, '');
assert.deepEqual(areaLabelPositions(macaque), macaqueLabels);
assert.equal(one(macaque, el => el.className === 'legend-title').textContent,
  'Tracer score (1–3)');
assert.deepEqual(all(macaque, el => el.className === 'legend-entry')
  .map(entry => entry.children.at(-1).textContent),
  ['1 (weak)', '2 (moderate)', '3 (strong)',
   'No connection strength reported (open)']);
assert.equal(all(macaque, el => el.tag === 'span' &&
  el.textContent === 'No connection strength reported (open)').length, 1);
assert.deepEqual(visibleSubcortical(),
  ['TRN', 'pulvinar', 'claustrum', 'striatum', 'pretectum', 'pons'].sort());
assert.ok(Number(bouMarker('MT').attributes.r) > Number(bouMarker('VIP').attributes.r));
assert.ok(Number(bouMarker('VIP').attributes.r) > Number(bouMarker('V4t').attributes.r));
assert.match(bouMarker('VIP')._tooltip, /2\.5\/3/);
assert.equal(bouMarker('CITd').attributes.fill, 'none');
assert.equal(bouMarker('TRN').attributes.fill, 'none');
const afferent = one(macaque, el => el.tag === 'input' && el.value === 'afferent');
selectRadio(macaque, afferent);
assert.deepEqual(areaLabelPositions(macaque), macaqueLabels);
assert.deepEqual(visibleSubcortical(), ['pulvinar', 'claustrum', 'basalfore'].sort());
assert.notEqual(bouMarker('MT').style.display, 'none');
assert.match(bouMarker('MT')._tooltip, /2\.5\/3/);
assert.match(bouMarker('VIP')._tooltip, /1\.5\/3/);
assert.match(bouMarker('V3d')._tooltip, /1\/3/);
one(rowFor('Combined tracer evidence'), el => el.className === 'only-button').listeners.click();
assert.match(macStatus.textContent, /\(8 papers\)/);
for (const key of ['afferent', 'efferent', 'unspecified'])
  assert.equal(one(macaque, el => el.tag === 'input' && el.value === key).disabled,
    true);
assert.equal(macLegend.style.display, 'none');
const v1 = one(macaque, el => el.tag === 'circle' && el.attributes['aria-label'] === 'V1');
assert.notEqual(v1.style.display, 'none');
assert.match(v1._tooltip, /Barone et al\. \(2000\)/);
one(rowFor('Ruan et al.'), el => el.className === 'only-button').listeners.click();
assert.equal(one(macaque, el => el.tag === 'input' && el.value === 'afferent').disabled, true);
assert.equal(one(macaque, el => el.tag === 'input' && el.value === 'efferent').disabled, true);
assert.equal(one(macaque, el => el.tag === 'input' && el.value === 'unspecified').disabled, false);
console.log('FRONTEND_LOGIC_OK');
