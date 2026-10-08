// Execute the generated browser script in a small DOM stand-in. This checks
// the controls and rendering logic without a browser or network dependency.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync(process.argv[2], 'utf8');
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
    this.classList = {toggle: () => {}};
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

const frame = elements.frame;
assert.equal(frame.children.length, 2);
const [macaque, human] = frame.children;
if (config.initial_species === 'human') {
  assert.equal(human.hidden, false);
  const select = one(human, el => el.className === 'species-choice');
  select.value = 'macaque';
  select.listeners.change();
}
assert.equal(macaque.hidden, false);
assert.equal(human.hidden, true);
assert.equal(all(macaque, el => el.tag === 'circle').length, 49);
assert.equal(all(human, el => el.tag === 'circle').length, 56);
assert.equal(config.macaque.studies.length, 6);
assert.ok(config.macaque.studies.find(study => study.code === 'mixed_tracer')
  .codes.includes('Bar00'));

const macStatus = one(macaque, el => el.className === 'status');
assert.match(macStatus.textContent, /48 connected regions/);
for (const circle of all(macaque, el => el.tag === 'circle')) {
  if (circle.attributes['aria-label'] === 'FST')
    assert.notEqual(circle.attributes.fill, 'none');
  else if (circle.style.display !== 'none')
    assert.equal(circle.attributes.fill, 'none');
}
const macClear = one(macaque, el => el.className === 'clear-button');
macClear.listeners.click();
assert.match(macStatus.textContent, /^0 connected regions/);
const visibleAfterClear = all(macaque, el => el.tag === 'circle')
  .filter(circle => circle.style.display !== 'none');
assert.equal(visibleAfterClear.length, 1);
assert.equal(visibleAfterClear[0].attributes['aria-label'], 'FST');

const macAll = one(macaque, el => el.className === 'all-button');
macAll.listeners.click();
assert.match(macStatus.textContent, /48 connected regions/);
const countRadio = one(macaque, el => el.tag === 'input' && el.value === 'studycount');
assert.equal(countRadio.disabled, false);
for (const radio of all(macaque, el => el.tag === 'input' && el.type === 'radio'))
  radio.checked = radio === countRadio;
countRadio.listeners.change();
assert.equal(one(macaque, el => el.className === 'legend-title').textContent,
  'Number of studies');

const macSpecies = one(macaque, el => el.className === 'species-choice');
macSpecies.value = 'human';
macSpecies.listeners.change();
assert.equal(macaque.hidden, true);
assert.equal(human.hidden, false);
const humanStatus = one(human, el => el.className === 'status');
assert.match(humanStatus.textContent, /55 connected regions/);
const lo = one(human, el => el.tag === 'circle' &&
  el.attributes['aria-label'] === 'LO1-3');
const uniformRadius = Number(lo.attributes.r);
const humanCount = one(human, el => el.tag === 'input' && el.value === 'studycount');
assert.equal(humanCount.disabled, false);
for (const radio of all(human, el => el.tag === 'input' && el.type === 'radio'))
  radio.checked = radio === humanCount;
humanCount.listeners.change();
assert.ok(Number(lo.attributes.r) > uniformRadius);
assert.match(lo._tooltip, /Supporting studies: 2/);
assert.equal(one(human, el => el.className === 'legend-title').textContent,
  'Number of studies');
assert.equal(all(human, el => el.className === 'legend-entry').length, 3);
one(human, el => el.className === 'clear-button').listeners.click();
assert.match(humanStatus.textContent, /^0 connected regions/);
assert.equal(humanCount.disabled, true);
assert.equal(one(human, el => el.tag === 'input' && el.value === 'uniform').checked, true);
assert.equal(one(human, el => el.className === 'legend').style.display, 'none');

const humanSpecies = one(human, el => el.className === 'species-choice');
humanSpecies.value = 'macaque';
humanSpecies.listeners.change();
assert.equal(macaque.hidden, false);
assert.equal(human.hidden, true);
assert.equal(macSpecies.value, 'macaque');
assert.equal(countRadio.checked, true);
const firstOnly = all(macaque, el => el.className === 'only-button')[0];
firstOnly.listeners.click();
assert.equal(countRadio.disabled, true);
const strength = all(macaque, el => el.tag === 'input' &&
  ['afferent', 'efferent', 'unspecified'].includes(el.value) && !el.disabled)[0];
assert.ok(strength, 'A single graded study should enable a strength mode');
for (const radio of all(macaque, el => el.tag === 'input' && el.type === 'radio'))
  radio.checked = radio === strength;
strength.listeners.change();
const activeMarkers = all(macaque, el => el.tag === 'circle')
  .filter(circle => circle.style.display !== 'none' &&
    circle.attributes['aria-label'] !== 'FST');
assert.ok(activeMarkers.some(circle => circle.attributes.fill === 'none'));
assert.ok(activeMarkers.some(circle => circle.attributes.fill !== 'none'));
const rows = all(macaque, el => el.className === 'study-row');
const rowFor = phrase => rows.find(row => all(row, el =>
  el.className === 'label-text' && el.textContent.includes(phrase)).length);
one(rowFor('Mixed tracer evidence'), el => el.className === 'only-button').listeners.click();
const v1 = one(macaque, el => el.tag === 'circle' && el.attributes['aria-label'] === 'V1');
assert.notEqual(v1.style.display, 'none');
assert.match(v1._tooltip, /Barone et al\. \(2000\)/);
one(rowFor('Ruan et al.'), el => el.className === 'only-button').listeners.click();
assert.equal(one(macaque, el => el.tag === 'input' && el.value === 'afferent').disabled, true);
assert.equal(one(macaque, el => el.tag === 'input' && el.value === 'efferent').disabled, true);
assert.equal(one(macaque, el => el.tag === 'input' && el.value === 'unspecified').disabled, false);
console.log('FRONTEND_LOGIC_OK');
