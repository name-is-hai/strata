// Isolated Git histories and fake RPM bytes exercise planning without builds.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {plan, record, targets} = require('../../.github/scripts/release-plan.js');
const original = process.cwd();
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'strata-release-plan-'));
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
function put(file, content) {
  fs.mkdirSync(path.dirname(file), {recursive: true});
  fs.writeFileSync(file, content);
}
function git(...args) {
  const result = spawnSync('git', args, {encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
}
function commit() {
  git('add', '.');
  git('-c', 'user.name=Release test', '-c', 'user.email=test@example.invalid',
    '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-qm', 'fixture');
}
function choices() {
  plan('previous', 'out', false);
  return Object.fromEntries(targets.map(t => [t, read('out/plan.json').targets[t].reuse]));
}
const all = value => Object.fromEntries(targets.map(t => [t, value]));

try {
  process.chdir(fixture);
  git('init', '-q');
  put('.gitignore', '/out/\n/previous/\n/incoming/\n/assets/\n');
  for (const file of ['LICENSE', 'runtime-version', 'shell/shell.qml', 'docs/guide.md',
    'bin/strata-build-rpms', '.github/scripts/release-plan.js', '.github/workflows/release.yml',
    'packaging/strata-config.spec', 'packaging/strata-lock-auth.spec',
    'packaging/hyprland-desktop.spec', 'packaging/hyprland-minimal.spec',
    'packaging/hyprland-utilities.spec', 'packaging/jetbrains-mono-nerd-fonts.spec',
    'packaging/zen-browser', 'packaging/zen-browser.desktop',
    'packaging/hyprland-desktop-LICENSE', 'packaging/strata-lock-password']) put(file, 'original\n');
  commit();
  assert.deepEqual(choices(), all(false), 'first release builds everything');

  // Produce the same manifest that assembly records, including an extra config RPM.
  for (const target of targets) {
    const names = target === 'config' ? ['config', 'lock-auth'] : [target];
    for (const name of names) {
      put(`incoming/rpms-${target}/${name}.rpm`, `RPM bytes for ${name}`);
      put(`assets/${name}.rpm`, `RPM bytes for ${name}`);
      put(`previous/packages/${name}.rpm`, `RPM bytes for ${name}`);
    }
  }
  put('assets/SHA256SUMS', '');
  record('out/plan.json', 'incoming', 'assets');
  fs.copyFileSync('assets/release-manifest.json', 'previous/release-manifest.json');
  assert.deepEqual(choices(), all(true), 'unchanged targets reuse every package');
  plan('previous', 'out', true);
  assert.ok(targets.every(t => !read('out/plan.json').targets[t].reuse), 'force rebuild');
  assert.ok(!fs.existsSync('out/reused'), 'force rebuild clears stale reused packages');

  put('shell/shell.qml', 'new widget'); commit();
  assert.deepEqual(choices(), {...all(true), config: false}, 'shell affects config');
  put('shell/shell.qml', 'original\n'); commit();
  put('packaging/zen-browser', 'new launcher'); commit();
  assert.deepEqual(choices(), {...all(true), config: false, desktop: false}, 'launcher affects desktop and config archive');
  put('packaging/zen-browser', 'original\n'); commit();
  put('packaging/hyprland-minimal.spec', 'new source version'); commit();
  assert.deepEqual(choices(), {...all(true), config: false, hyprland: false}, 'spec version is a build input');
  put('packaging/hyprland-minimal.spec', 'original\n'); commit();
  put('packaging/strata-lock-password', 'new PAM policy'); commit();
  assert.deepEqual(choices(), {...all(true), config: false}, 'PAM policy affects config target');
  put('packaging/strata-lock-password', 'original\n'); commit();
  put('packaging/new-fix.patch', 'patch'); commit();
  assert.deepEqual(choices(), all(false), 'unmapped packaging inputs conservatively rebuild all targets');
  fs.unlinkSync('packaging/new-fix.patch'); commit();
  put('bin/strata-build-rpms', 'new compiler flags'); commit();
  assert.deepEqual(choices(), all(false), 'builder changes rebuild all targets');
  put('bin/strata-build-rpms', 'original\n'); commit();

  put('previous/packages/fonts.rpm', 'corrupt');
  assert.deepEqual(choices(), {...all(true), fonts: false}, 'corrupt package rebuilds its target');
  fs.unlinkSync('previous/packages/fonts.rpm');
  assert.deepEqual(choices(), {...all(true), fonts: false}, 'missing package rebuilds its target');
  put('previous/packages/lock-auth.rpm', 'corrupt');
  assert.equal(choices().config, false, 'one corrupt RPM prevents reuse of the entire target');
  assert.ok(!fs.existsSync('out/reused/config'));
  put('previous/release-manifest.json', '{}');
  assert.deepEqual(choices(), all(false), 'old or malformed manifest builds all targets');

  put('assets/unowned.rpm', 'unexpected');
  assert.throws(() => record('out/plan.json', 'incoming', 'assets'), /Unassigned release RPM/);
  console.log('PASS: release planning, target inputs, checksums, fallback, force rebuild and manifest coverage');
} finally {
  process.chdir(original);
  fs.rmSync(fixture, {recursive: true, force: true});
}
