// Build-input fingerprints and verified RPM reuse. Runs on the GitHub host.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');

const definitions = JSON.parse(fs.readFileSync(path.join(__dirname, '../../packaging/build/targets.json'), 'utf8'));
const targets = Object.keys(definitions);
const common = ['packaging/build/common.sh', 'packaging/build/environment.sh'];
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
  const declared = JSON.parse(git(['show', 'HEAD:packaging/build/targets.json']).toString());
  const inputs = {};
  const safePath = value => typeof value === 'string' && /^[A-Za-z0-9_./-]+$/.test(value) &&
    !value.startsWith('/') && !value.split('/').some(part => part === '..' || part === '.');
  for (const [target, definition] of Object.entries(declared)) {
    if (!/^[a-z][a-z0-9-]*$/.test(target) ||
        !/^[a-z0-9-]+\.spec$/.test(definition.spec) || !Array.isArray(definition.inputs)) {
      throw Error('Invalid build target definition: ' + target);
    }
    const paths = [...common, 'packaging/' + definition.spec, ...definition.inputs,
      ...(definition.recipe ? [definition.recipe] : [])];
    if (!paths.every(safePath)) throw Error('Invalid build input path: ' + target);
    inputs[target] = paths;
  }
  const owned = [...Object.values(inputs).flat(), 'packaging/build/targets.json', 'packaging/build/run.sh'];
  const unassigned = git(['ls-tree', '-rz', 'HEAD', '--', 'packaging']).toString().split('\0')
    .filter(Boolean).map(row => row.slice(row.indexOf('\t') + 1))
    .filter(file => !owned.some(input => file === input || file.startsWith(input + '/')));
  if (unassigned.length) throw Error('Assign packaging files to targets in packaging/build/targets.json: ' + unassigned.join(', '));
  return Object.fromEntries(Object.entries(declared).map(([target, definition]) => [target,
    digest(Buffer.concat([Buffer.from(JSON.stringify(definition) + '\n'),
      git(['ls-tree', '-rz', 'HEAD', '--', ...inputs[target]])]))]));
}

function plan(previous, output, force) {
  fs.mkdirSync(output, {recursive: true});
  fs.rmSync(path.join(output, 'reused'), {recursive: true, force: true});
  let baseline;
  try {
    baseline = readJSON(path.join(previous, 'release-manifest.json'));
    if (baseline.schema !== 3 || baseline.fedora !== 44 || baseline.arch !== 'x86_64') {
      throw Error('incompatible manifest');
    }
  } catch {
    baseline = undefined;
    console.log('No compatible previous release manifest; build all targets.');
  }
  const hashes = fingerprints();
  const result = {schema: 3, fedora: 44, arch: 'x86_64',
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
      'has_reuse=' + targets.some(t => result.targets[t].reuse) + '\n' +
      'targets=' + JSON.stringify(targets) + '\n');
  }
}

function record(planFile, incoming, assets) {
  const current = readJSON(planFile);
  const manifest = {schema: 3, fedora: 44, arch: 'x86_64', commit: current.commit, targets: {}};
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
