// Isolated Git histories and fake RPM bytes exercise planning without builds.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {plan, record, targets} = require('../../.github/scripts/release-plan.js');
const workflow = fs.readFileSync(path.join(__dirname, '../../.github/workflows/release.yml'), 'utf8');
assert.ok(workflow.includes('target: $' + '{{ fromJSON(needs.plan.outputs.targets) }}'), 'CI uses declared target matrix');
const buildDefinitions = fs.readFileSync(path.join(__dirname, '../../packaging/build/targets.json'), 'utf8');
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
    'packaging/hyprland-desktop-LICENSE', 'packaging/strata-lock-password',
    'packaging/ghostty.spec', 'packaging/uwsm.spec',
    'packaging/casting/strata-castd.service', 'VERSION', '.github/release-notes.md']) put(file, 'original\n');
  put('packaging/build/targets.json', buildDefinitions);
  for (const file of ['common.sh', 'environment.sh', 'config-source.sh', 'run.sh']) {
    put('packaging/build/' + file, 'original\n');
  }
  commit();
  assert.deepEqual(choices(), all(false), 'first release builds everything');

  // Produce the same manifest that assembly records, including an extra config RPM.
  for (const target of targets) {
    const names = target === 'config' ? ['config', 'casting'] : [target];
    for (const name of names) {
      put(`incoming/rpms-${target}/${name}.rpm`, `RPM bytes for ${name}`);
      put(`assets/${name}.rpm`, `RPM bytes for ${name}`);
      put(`previous/packages/${name}.rpm`, `RPM bytes for ${name}`);
    }
  }
  put('assets/SHA256SUMS', '');
  record('out/plan.json', 'incoming', 'assets');
  fs.copyFileSync('assets/release-manifest.json', 'previous/release-manifest.json');
  process.env.GITHUB_OUTPUT = path.join(fixture, 'out/github-output');
  assert.deepEqual(choices(), all(true), 'unchanged targets reuse every package');
  assert.ok(fs.readFileSync(process.env.GITHUB_OUTPUT, 'utf8').includes('targets=' + JSON.stringify(targets)), 'matrix output matches targets');
  delete process.env.GITHUB_OUTPUT;
  plan('previous', 'out', true);
  assert.ok(targets.every(t => !read('out/plan.json').targets[t].reuse), 'force rebuild');
  assert.ok(!fs.existsSync('out/reused'), 'force rebuild clears stale reused packages');

  put('VERSION', '1.2.0'); put('.github/release-notes.md', 'New release'); commit();
  assert.deepEqual(choices(), all(true), 'release tag and notes do not rebuild RPMs');
  put('runtime-version', '1.2.0'); commit();
  assert.deepEqual(choices(), {...all(true), config: false}, 'runtime version belongs to config');
  put('runtime-version', 'original\n'); commit();
  put('packaging/ghostty.spec', 'new Ghostty version'); commit();
  assert.deepEqual(choices(), {...all(true), ghostty: false}, 'Ghostty update rebuilds only Ghostty');
  put('packaging/ghostty.spec', 'original\n'); commit();
  put('packaging/uwsm.spec', 'new UWSM version'); commit();
  assert.deepEqual(choices(), {...all(true), uwsm: false}, 'UWSM builds independently');
  put('packaging/uwsm.spec', 'original\n'); commit();
  put('packaging/hyprland-desktop.spec', 'new dependency'); commit();
  assert.deepEqual(choices(), {...all(true), desktop: false}, 'desktop dependencies build independently');
  put('packaging/hyprland-desktop.spec', 'original\n'); commit();
  put('shell/shell.qml', 'new widget'); commit();
  assert.deepEqual(choices(), {...all(true), config: false}, 'shell affects config');
  put('shell/shell.qml', 'original\n'); commit();
  put('bin/strata-launch-browser', 'new user browser launcher'); commit();
  assert.deepEqual(choices(), {...all(true), config: false}, 'Browser launcher ships with config, not a browser RPM');
  fs.unlinkSync('bin/strata-launch-browser'); commit();
  put('packaging/hyprland-minimal.spec', 'new source version'); commit();
  assert.deepEqual(choices(), {...all(true), hyprland: false}, 'Hyprland spec affects only Hyprland');
  put('packaging/hyprland-minimal.spec', 'original\n'); commit();
  put('packaging/strata-lock-password', 'new PAM policy'); commit();
  assert.deepEqual(choices(), {...all(true), 'lock-auth': false}, 'PAM policy has its own target');
  put('packaging/strata-lock-password', 'original\n'); commit();
  put('packaging/casting/strata-castd.service', 'new service'); commit();
  assert.deepEqual(choices(), {...all(true), config: false}, 'casting assets affect only config');
  put('packaging/casting/strata-castd.service', 'original\n'); commit();
  put('packaging/new-fix.patch', 'patch'); commit();
  assert.throws(choices, /Assign packaging files/, 'unmapped packaging sources must have an owner');
  const declared = JSON.parse(buildDefinitions);
  declared.ghostty.inputs.push('packaging/new-fix.patch');
  put('packaging/build/targets.json', JSON.stringify(declared)); commit();
  assert.deepEqual(choices(), {...all(true), ghostty: false}, 'declared patch and definition affect only owner');
  fs.unlinkSync('packaging/new-fix.patch');
  put('packaging/build/targets.json', buildDefinitions); commit();
  for (const file of ['.github/workflows/release.yml', '.github/scripts/release-plan.js', 'packaging/build/run.sh']) {
    put(file, 'changed dispatch'); commit();
    assert.deepEqual(choices(), all(true), file + ' does not change binary inputs');
    put(file, 'original\n'); commit();
  }
  for (const file of ['bin/strata-build-rpms', 'packaging/build/config-source.sh']) {
    put(file, 'changed config input'); commit();
    assert.deepEqual(choices(), {...all(true), config: false}, file + ' affects only config');
    put(file, 'original\n'); commit();
  }
  for (const file of ['packaging/build/common.sh', 'packaging/build/environment.sh']) {
    put(file, 'changed shared settings'); commit();
    assert.deepEqual(choices(), all(false), file + ' rebuilds every target');
    put(file, 'original\n'); commit();
  }

  put('previous/packages/fonts.rpm', 'corrupt');
  assert.deepEqual(choices(), {...all(true), fonts: false}, 'corrupt package rebuilds its target');
  fs.unlinkSync('previous/packages/fonts.rpm');
  assert.deepEqual(choices(), {...all(true), fonts: false}, 'missing package rebuilds its target');
  put('previous/packages/casting.rpm', 'corrupt');
  assert.equal(choices().config, false, 'one corrupt RPM prevents reuse of the entire target');
  assert.ok(!fs.existsSync('out/reused/config'));
  const legacy = read('previous/release-manifest.json');
  legacy.schema = 2;
  put('previous/release-manifest.json', JSON.stringify(legacy));
  assert.deepEqual(choices(), all(false), 'old broad-input manifests require a fresh baseline');
  put('previous/release-manifest.json', '{}');
  assert.deepEqual(choices(), all(false), 'old or malformed manifest builds all targets');

  put('assets/unowned.rpm', 'unexpected');
  assert.throws(() => record('out/plan.json', 'incoming', 'assets'), /Unassigned release RPM/);
  console.log('PASS: release planning, target inputs, checksums, fallback, force rebuild and manifest coverage');
} finally {
  process.chdir(original);
  fs.rmSync(fixture, {recursive: true, force: true});
}
