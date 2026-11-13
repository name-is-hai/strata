const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require.resolve('../../shell/plugins/bar/Bar.qml'), 'utf8');
let refreshes = 0;
const context = vm.createContext({
  requestedTransparent: false, transparent: false,
  foregroundAnimationEnabled: true, foregroundRequestTransparent: true,
  themeForeground: '#ffffff', shell: null,
  restoreForegroundAnimation() {},
  scheduleTransparentForegroundRefresh() { refreshes++; },
  console
});
context.root = context;
for (const name of ['setRequestedTransparency', 'toggleTransparency']) {
  const match = source.match(new RegExp('  function ' + name + '\\([^]*?\\n  \\}'));
  assert.ok(match, name);
  vm.runInContext(match[0], context);
}
const reader = source.match(/      onRead: function\(line\) \{([\s\S]*?)\n      \}/);
assert.ok(reader, 'contrast sample reader');
vm.runInContext('function receiveSample(line) {' + reader[1] + '\n}', context);

// No sampler response: slow, missing or failed helpers must not block toggles.
context.toggleTransparency();
assert.equal(context.transparent, true, 'show transparency before any samples arrive');
context.toggleTransparency();
assert.equal(context.transparent, false, 'a second toggle responds while sampling is pending');
context.receiveSample('{"samples":{"eDP-1":["#000000"]}}');
assert.equal(context.transparent, false, 'late samples cannot undo an opaque toggle');
context.toggleTransparency();
assert.equal(context.transparent, true);
context.receiveSample('invalid output');
assert.equal(context.transparent, true, 'bad sampler output cannot block transparency');
context.receiveSample('{"samples":{"eDP-1":["#ffffff"]}}');
assert.equal(context.localForegroundSamples['eDP-1'][0], '#ffffff', 'contrast still refreshes');
assert.equal(refreshes, 3);
console.log('PASS: immediate bar transparency, repeated toggles, delayed contrast and invalid sampler output');
