// Run the actual expanded RPM %install with fixture build outputs, without
// compiling upstream projects or touching the host installation.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const {spawnSync} = require('node:child_process');
const repo = path.resolve(__dirname, '../..');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'strata-command-layout-'));
function run(command, args, options={}) {
  const result = spawnSync(command,args,{encoding:'utf8',...options});
  assert.equal(result.status,0,result.stdout+'\n'+result.stderr);
  return result.stdout;
}
function put(file, text) {
  fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,text);
}
try {
  for(const dir of ['bin','config','defaults','shell','docs','systemd'])
    fs.cpSync(path.join(repo,dir),path.join(work,dir),{recursive:true});
  fs.cpSync(path.join(repo,'packaging/casting'),path.join(work,'packaging/casting'),{recursive:true});
  fs.copyFileSync(path.join(repo,'runtime-version'),path.join(work,'runtime-version'));
  put(path.join(work,'themes/lawson-night/backgrounds/wallhaven-1k6ljv.jpg'),'fixture wallpaper');
  const helper='third_party/wiggle/scripts/wiggle-discover-cursor';
  fs.mkdirSync(path.dirname(path.join(work,helper)),{recursive:true});
  fs.copyFileSync(path.join(repo,helper),path.join(work,helper));
  for(const file of ['strata-font-ink','strata-wiggle-monitor','casting-target/release/waycast-networkd',
    'casting-target/release/strata-castd','waycast-v0.6.1-linux-amd64/waycast',
    'doubletake-v0.4.0-alchemy.5-linux-amd64/doubletake','doubletake-v0.4.0-alchemy.5-linux-amd64/doubletake-ctl']) {
    fs.mkdirSync(path.dirname(path.join(work,file)),{recursive:true});
    fs.copyFileSync('/usr/bin/true',path.join(work,file));
  }
  put(path.join(work,'tools/cmake'),'#!/bin/bash\ninstall -Dpm755 /usr/bin/true "$DESTDIR/usr/share/strata/bin/strata-snip"\n');
  fs.chmodSync(path.join(work,'tools/cmake'),0o755);
  const spec=run('rpmspec',['--define',`_topdir ${work}/rpmbuild`,'--parse',path.join(repo,'packaging/strata-config.spec')]);
  assert.ok(spec.includes('-DCMAKE_INSTALL_BINDIR=share/strata/bin'),'native screenshot command uses canonical directory');
  const install=spec.match(/\n%install\n([\s\S]*?)\n%post\n/)[1];
  const buildroot=install.match(/^DESTDIR=(\S+)/m)[1];
  assert.ok(buildroot.startsWith(work+'/'),'isolated buildroot');
  run('bash',['-euo','pipefail','-c',install],{cwd:work,env:{...process.env,PATH:path.join(work,'tools')+':'+process.env.PATH}});
  const bindir=path.join(buildroot,'usr/share/strata/bin');
  assert.equal(fs.existsSync(path.join(buildroot,'usr/bin')),false,'no command copies or links in /usr/bin');
  assert.equal(fs.existsSync(path.join(buildroot,'usr/libexec')),false,'no separate Strata helper executable directory');
  for(const name of fs.readdirSync(path.join(repo,'bin'))) {
    const target=path.join(bindir,name);
    assert.equal(fs.lstatSync(target).isFile(),true,name);
    assert.equal(fs.statSync(target).mode&0o777,0o755,name);
    assert.ok(fs.readFileSync(target).equals(fs.readFileSync(path.join(repo,'bin',name))),name);
  }
  for(const name of ['strata-snip','strata-font-ink','strata-wiggle-monitor','strata-wiggle-discover-cursor',
    'strata-castd','strata-waycast-networkd','waycast','doubletake','doubletake-ctl'])
    assert.ok(fs.statSync(path.join(bindir,name)).mode&0o111,name+' executable');
  assert.match(run(path.join(bindir,'strata'),['commands','--check']),/metadata check passed/);
  for(const file of ['greeter/config.toml','greeter/hyprland.lua','greeter/shell.qml',
    'default/polkit-1/rules.d/49-strata-greeter.rules'])
    assert.doesNotMatch(fs.readFileSync(path.join(buildroot,'usr/share/strata',file),'utf8'),/\/usr\/(?:bin|libexec)\/strata-/);
  for(const name of ['strata-castd','strata-waycast-networkd'])
    assert.match(spec,new RegExp('/usr/share/strata/bin/'+name));
  const post=spec.match(/\n%post\n([\s\S]*?)(?=\n%[a-z])/)[1];
  const greetd=path.join(work,'greetd.toml');
  put(greetd,'[default_session]\ncommand = "/usr/bin/strata-greeter-session"\nuser = "greetd"\n');
  run('bash',['-eu','-c',post.replaceAll('/etc/greetd/config.toml',greetd)]);
  assert.match(fs.readFileSync(greetd,'utf8'),/command = "\/usr\/share\/strata\/bin\/strata-greeter-session"/);
  put(greetd,'command = "/custom/login"\n');
  run('bash',['-eu','-c',post.replaceAll('/etc/greetd/config.toml',greetd)]);
  assert.equal(fs.readFileSync(greetd,'utf8'),'command = "/custom/login"\n');
  let rule;
  vm.runInNewContext(fs.readFileSync(path.join(repo,'defaults/polkit-1/rules.d/49-strata-greeter.rules'),'utf8'),
    {polkit:{addRule:fn=>rule=fn,Result:{YES:'yes'}}});
  const action=program=>({id:'org.freedesktop.policykit.exec',lookup:()=>program});
  for(const name of ['strata-greeter-background-install','strata-greeter-theme-install','strata-greeter-monitors-install','strata-main-monitor-install']) {
    assert.equal(rule(action('/usr/share/strata/bin/'+name),{local:true,active:true}),'yes');
    assert.equal(rule(action('/tmp/'+name),{local:true,active:true}),undefined);
    assert.equal(rule(action('/usr/share/strata/bin/'+name),{local:false,active:true}),undefined);
  }
  run('bash',['-eu','-c','source "$1"; export STRATA_PATH="$2"; strata_security_require_source_root "$2/bin/strata-plugin"',
    'test',path.join(repo,'bin/strata-security-functions'),path.join(buildroot,'usr/share/strata')]);
  console.log('PASS: real RPM install layout, script/native commands, dispatcher metadata, greeter/Polkit paths and targeted greetd upgrade migration');
} finally { fs.rmSync(work,{recursive:true,force:true}); }
