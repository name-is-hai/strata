// Build-input fingerprints and verified RPM reuse. Runs on the GitHub host.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');

const inputs = {
  config: ['LICENSE', 'bin', 'config', 'defaults', 'docs', 'native',
    'packaging/strata-config.spec', 'packaging/casting',
    'runtime-version', 'scripts', 'shell', 'systemd', 'third_party', 'themes'],
  desktop: ['packaging/hyprland-desktop.spec', 'packaging/hyprland-desktop-LICENSE'],
  ghostty: ['packaging/ghostty.spec'],
  zen: ['packaging/zen-browser.spec', 'packaging/zen-browser', 'packaging/zen-browser.desktop'],
  uwsm: ['packaging/uwsm.spec'],
  'lock-auth': ['packaging/strata-lock-auth.spec', 'packaging/strata-lock-password',
    'packaging/hyprland-desktop-LICENSE'],
  hyprland: ['packaging/hyprland-minimal.spec'],
  utilities: ['packaging/hyprland-utilities.spec'],
  fonts: ['packaging/jetbrains-mono-nerd-fonts.spec']
};
const common = ['bin/strata-build-rpms', '.github/scripts/release-plan.js',
  '.github/workflows/release.yml'];
const targets = Object.keys(inputs);
const digest = data => crypto.createHash('sha256').update(data).digest('hex');
const readJSON = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const writeJSON = (file, value) => fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
const safeRPM = name => typeof name === 'string' && /^[A-Za-z0-9][A-Za-z0-9+_.~-]*\.rpm$/.test(name);

function git(args) {
  const result = spawnSync('git', args, {maxBuffer: 32 * 1024 * 1024});
  if (result.status !== 0) throw Error(`git ${args[0]} failed: ${result.stderr}`);
  return result.stdout;
}

function fingerprints() {
  // Unknown packaging files may be patches or local sources referenced by a
  // spec. Include them for every target rather than risk missing a dependency.
  const knownPackaging = new Set([
    'packaging/strata-config.spec', 'packaging/strata-lock-auth.spec',
    'packaging/hyprland-desktop.spec', 'packaging/hyprland-minimal.spec',
    'packaging/hyprland-utilities.spec', 'packaging/jetbrains-mono-nerd-fonts.spec',
    'packaging/hyprland-desktop-LICENSE', 'packaging/zen-browser',
    'packaging/zen-browser.desktop', 'packaging/strata-lock-password',
    'packaging/ghostty.spec', 'packaging/zen-browser.spec', 'packaging/uwsm.spec'
  ]);
  const extraPackaging = git(['ls-tree', '-rz', 'HEAD', '--', 'packaging']).toString()
    .split('\0').filter(row => row && !knownPackaging.has(row.slice(row.indexOf('\t') + 1)) &&
      !row.slice(row.indexOf('\t') + 1).startsWith('packaging/casting/')).join('\0');
  return Object.fromEntries(targets.map(target => [target,
    digest(Buffer.concat([git(['ls-tree', '-rz', 'HEAD', '--', ...common, ...inputs[target]]),
      Buffer.from(extraPackaging)]))]));
}

function plan(previous, output, force) {
  fs.mkdirSync(output, {recursive: true});
  fs.rmSync(path.join(output, 'reused'), {recursive: true, force: true});
  let baseline;
  try {
    baseline = readJSON(path.join(previous, 'release-manifest.json'));
    if (baseline.schema !== 2 || baseline.fedora !== 44 || baseline.arch !== 'x86_64') {
      throw Error('incompatible manifest');
    }
  } catch {
    baseline = undefined;
    console.log('No compatible previous release manifest; build all targets.');
  }
  const hashes = fingerprints();
  const result = {schema: 2, fedora: 44, arch: 'x86_64',
    commit: git(['rev-parse', 'HEAD']).toString().trim(), targets: {}};
  for (const target of targets) {
    const prior = baseline?.targets?.[target];
    let reuse = false;
    let reason = force ? 'forced full build' : 'inputs changed or no baseline';
    if (!force && prior?.fingerprint === hashes[target]) {
      try {
        if (!Array.isArray(prior.rpms) || prior.rpms.length === 0) throw Error('no RPMs');
        const names = new Set();
        for (const rpm of prior.rpms) {
          if (!safeRPM(rpm.file) || names.has(rpm.file) || !/^[a-f0-9]{64}$/.test(rpm.sha256)) {
            throw Error('invalid RPM manifest');
          }
          names.add(rpm.file);
          const file = path.join(previous, 'packages', rpm.file);
          if (!fs.lstatSync(file).isFile() || digest(fs.readFileSync(file)) !== rpm.sha256) {
            throw Error('RPM checksum mismatch');
          }
        }
        const destination = path.join(output, 'reused', target);
        fs.mkdirSync(destination, {recursive: true});
        for (const rpm of prior.rpms) fs.copyFileSync(path.join(previous, 'packages', rpm.file),
          path.join(destination, rpm.file));
        reuse = true;
        reason = 'identical tracked build inputs and verified RPM checksums';
      } catch (error) {
        // Remove any partial copy: the whole target must be built together.
        fs.rmSync(path.join(output, 'reused', target), {recursive: true, force: true});
        reason = `previous RPMs unavailable: ${error.message}`;
      }
    }
    result.targets[target] = {fingerprint: hashes[target], reuse, reason};
    console.log(`${target}: ${reuse ? 'reuse' : 'build'} (${reason})`);
  }
  writeJSON(path.join(output, 'plan.json'), result);
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT,
      'reuse=' + JSON.stringify(Object.fromEntries(targets.map(t => [t, result.targets[t].reuse]))) + '\n' +
      'has_reuse=' + targets.some(t => result.targets[t].reuse) + '\n');
  }
}

function record(planFile, incoming, assets) {
  const current = readJSON(planFile);
  const manifest = {schema: 2, fedora: 44, arch: 'x86_64', commit: current.commit, targets: {}};
  const owned = new Set();
  for (const target of targets) {
    const dir = path.join(incoming, `rpms-${target}`);
    const rpms = fs.readdirSync(dir).filter(safeRPM).filter(file => fs.existsSync(path.join(assets, file)))
      .sort().map(file => {
        if (owned.has(file)) throw Error(`RPM belongs to multiple targets: ${file}`);
        owned.add(file);
        const bytes = fs.readFileSync(path.join(assets, file));
        if (digest(bytes) !== digest(fs.readFileSync(path.join(dir, file)))) throw Error(`RPM changed: ${file}`);
        return {file, sha256: digest(bytes)};
      });
    if (!rpms.length) throw Error(`No final RPMs for ${target}`);
    manifest.targets[target] = {fingerprint: current.targets[target].fingerprint, rpms};
  }
  const files = fs.readdirSync(assets).filter(safeRPM);
  if (files.some(file => !owned.has(file))) throw Error('Unassigned release RPM');
  const file = path.join(assets, 'release-manifest.json');
  writeJSON(file, manifest);
  fs.appendFileSync(path.join(assets, 'SHA256SUMS'), `${digest(fs.readFileSync(file))}  release-manifest.json\n`);
}

if (require.main === module) {
  const [mode, ...args] = process.argv.slice(2);
  if (mode === 'plan' && args.length === 2) plan(...args, process.env.FORCE_FULL === 'true');
  else if (mode === 'record' && args.length === 3) record(...args);
  else throw Error('Usage: release-plan.js plan PREVIOUS_DIRECTORY OUTPUT_DIRECTORY | record PLAN INCOMING ASSETS');
}
module.exports = {plan, record, fingerprints, targets};
