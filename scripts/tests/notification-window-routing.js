const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const Routing = require('../../shell/plugins/notifications/WindowRouting.js');
const entries = [
  {id:'org.wails.netbird', name:'NetBird', startupClass:'org.wails.netbird'},
  {id:'com.mitchellh.ghostty', name:'Ghostty', startupClass:'com.mitchellh.ghostty'},
  {id:'code', name:'Visual Studio Code', startupClass:'Code'},
  {id:'firefox', name:'Firefox', startupClass:'firefox'}
];
const windows = [
  {wmClass:'org.wails.netbird', pid:12, focusOrder:4},
  {wmClass:'com.mitchellh.ghostty', pid:13, focusOrder:1},
  {wmClass:'Code', pid:14, focusOrder:2},
  {wmClass:'org.wails.netbird', pid:15, focusOrder:0},
  {wmClass:'netbird-helper', title:'NetBird', pid:16, focusOrder:0},
  {wmClass:'chrome-chat.example.com__-Default', pid:17, focusOrder:3}
];
// Exercise the actual service function with desktop and window APIs supplied.
const service = fs.readFileSync(require.resolve('../../shell/plugins/notifications/Service.qml'), 'utf8');
const body = service.match(/  function windowForSource\(source\) \{[\s\S]*?\n  \}/)[0];
const context = {WindowRouting: Routing, DesktopEntries:{applications:{values:entries}},
  openWindows:()=>windows, smartRaise:false,
  mostRecent:list=>list.slice().sort((a,b)=>a.focusOrder-b.focusOrder)[0] || null};
vm.createContext(context);
vm.runInContext(body, context);
for (const name of ['NetBird', 'NETBIRD', 'org.wails.netbird', 'org.wails.netbird.desktop']) {
  assert.equal(context.windowForSource(name).pid, 15, 'resolve NetBird and choose most recently focused window');
}
assert.equal(context.windowForSource('Ghostty').pid, 13);
assert.equal(context.windowForSource('Visual Studio Code').pid, 14);
assert.equal(context.windowForSource('code.desktop').pid, 14);
assert.equal(context.windowForSource('chat.example.com').pid, 17, 'preserve browser host routing');
assert.equal(context.windowForSource('chat').pid, 17, 'preserve web-app label routing');
assert.equal(context.windowForSource('NetBird update available'), null, 'do not match arbitrary title substrings');
assert.equal(context.windowForSource('Bird'), null);
assert.equal(context.windowForSource(''), null);
assert.equal(context.windowForSource('Firefox'), null, 'installed or tray-running apps may have no window');
assert.equal(Routing.nativeMatches([{wmClass:'org.wails.netbird-helper'}], entries, 'NetBird').length, 0);
console.log('PASS: notification window routing for native app names, desktop IDs, browser sources and absent windows');
