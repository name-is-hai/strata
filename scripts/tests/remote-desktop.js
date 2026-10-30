// Exercise the real Bash handoff with an isolated compositor/IPC model.
// Never locks, blanks, starts a server or changes settings on the host desktop.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const repo = path.resolve(__dirname, '../..');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'strata-rdp-test-'));
const bin = path.join(work, 'bin');
fs.mkdirSync(bin);
const script = path.join(bin, 'strata-remote-desktop');
fs.copyFileSync(path.join(repo, 'bin/strata-remote-desktop'), script);
fs.chmodSync(script, 0o755);
const modelFile = path.join(work, 'model.json');
const mock = path.join(bin, 'mock');
fs.writeFileSync(mock + '.js', String.raw`#!/usr/bin/env node
const fs = require('node:fs'), path = require('node:path');
const file = process.env.RDP_MODEL;
const m = JSON.parse(fs.readFileSync(file));
const a = process.argv.slice(3), command = process.argv[2];
m.events.push([command,...a]);
let out='ok', status=0;
if(command==='systemd-inhibit') {
  status=m.failServer?7:0;
} else if(command==='strata-shell') {
  if(a[0]==='lock' && a[1]==='lock') m.secure=!m.failLock;
  else if(a[0]==='lock') out=JSON.stringify({secure:m.secure});
  else out=JSON.stringify({remoteDesktopActive:!m.failIdle});
} else if(command==='hyprctl') {
  if(a[0]==='monitors') out=JSON.stringify(m.monitors);
  else if(a[0]==='workspaces') out=JSON.stringify(m.workspaces);
  else if(a[0]==='getoption') out=JSON.stringify({int:a[1].includes('key_press')?0:1});
  else if(a[0]==='output' && a[1]==='create') m.monitors.push({id:2,name:'hypr-rdp-strata-1',dpmsStatus:true});
  else if(a[0]==='output' && a[1]==='remove') m.monitors=m.monitors.filter(x=>x.name!==a[2]);
  else if(a[0]==='dispatch' && a[1].includes('dpms')) {
    const [,action,name]=a[1].match(/action = "([^"]+)", monitor = "([^"]+)"/);
    m.monitors.find(x=>x.name===name).dpmsStatus=action!=='off';
  } else if(a[0]==='eval' && a[1].includes('w.transfer')) {
    const [,source,name,preferred]=a[1].match(/w.transfer\((\d+), "([^"]+)", (nil|\d+)\)/);
    const ws=m.workspaces.find(x=>x.id===Number(source));
    if(!ws) { status=1; out='missing workspace'; }
    else {
      const target=m.monitors.find(x=>x.name===name), base=(target.id+1)*100;
      let id=base+Number(source)%100;
      if(id===base || m.workspaces.some(x=>x.id===id)) {
        id=base+1; while(m.workspaces.some(x=>x.id===id)) id++;
      }
      if(preferred!=='nil' && !m.workspaces.some(x=>x.id===base+Number(preferred)&&x.windows>0)) id=base+Number(preferred);
      m.workspaces=m.workspaces.filter(x=>x===ws||x.id!==id);
      ws.id=id; ws.monitor=name;
    }
  }
}
fs.writeFileSync(file,JSON.stringify(m));
process.stdout.write(out+'\n'); process.exit(status);
`);
// The supervisor and its fake server run concurrently. Serialize the model
// recorder so they cannot truncate each other's state or lose events.
fs.writeFileSync(mock, '#!/usr/bin/env bash\nexec flock "$RDP_MODEL.lock" node "' + mock + '.js" "${0##*/}" "$@"\n');
fs.chmodSync(mock, 0o755);
for (const name of ['hyprctl', 'strata-shell', 'sleep', 'systemd-inhibit']) fs.symlinkSync(mock, path.join(bin,name));
const env = {...process.env, XDG_RUNTIME_DIR:work, HYPRLAND_INSTANCE_SIGNATURE:'test-instance', RDP_MODEL:modelFile,
  XDG_DATA_HOME:path.join(work,'data'),XDG_CONFIG_HOME:path.join(work,'config')};
function reset(extra={}) {
  fs.rmSync(path.join(work,'strata-remote-desktop'),{recursive:true,force:true});
  fs.writeFileSync(modelFile, JSON.stringify({
    monitors:[{id:0,name:'eDP-1',dpmsStatus:true},{id:1,name:'HDMI-A-1',dpmsStatus:true},{id:2,name:'hypr-rdp-strata-1',dpmsStatus:true}],
    workspaces:[{id:101,monitor:'eDP-1',windows:2},{id:201,monitor:'HDMI-A-1',windows:1},{id:301,monitor:'hypr-rdp-strata-1',windows:0}],
    secure:false,events:[],...extra,
  }));
}
const model = () => JSON.parse(fs.readFileSync(modelFile));
const state = () => JSON.parse(fs.readFileSync(path.join(work,'strata-remote-desktop/state.json')));
function run(action, success=true) {
  const r=spawnSync(script,[action],{env,encoding:'utf8',timeout:20000});
  if(success) assert.equal(r.status,0,r.stdout+r.stderr);
  else assert.notEqual(r.status,0,'expected refusal: '+r.stdout+r.stderr);
  return r;
}
try {
  reset(); run('hook-start');
  assert.deepEqual(state().moves.map(x=>[x.id,x.homeId]),[[302,101],[303,201]],'colliding local numbers allocated independently');
  assert.ok(model().monitors.filter(x=>x.name!=='hypr-rdp-strata-1').every(x=>!x.dpmsStatus));
  assert.ok(model().monitors.find(x=>x.name==='hypr-rdp-strata-1').dpmsStatus,'capture output stays on');
  assert.ok(model().workspaces.filter(x=>x.windows).every(x=>x.monitor==='hypr-rdp-strata-1'));
  run('active');
  let m=model(); m.events=[]; fs.writeFileSync(modelFile,JSON.stringify(m));
  run('hook-end');
  assert.equal(model().events[0][0],'strata-shell');
  assert.deepEqual(model().events[0].slice(1),['lock','lock'],'lock before restoring anything');
  assert.deepEqual(model().workspaces.filter(x=>x.windows).map(x=>[x.id,x.monitor]),[[101,'eDP-1'],[201,'HDMI-A-1']]);
  assert.ok(model().monitors.every(x=>x.dpmsStatus));
  assert.ok(model().events.some(x=>x[0]==='hyprctl'&&x[1]==='eval'&&x[2].includes('key_press_enables_dpms = false, mouse_move_enables_dpms = true')),'restore original wake options');
  run('active',false); run('recover');

  reset(); run('hook-start'); m=model(); m.failLock=true; m.events=[]; fs.writeFileSync(modelFile,JSON.stringify(m));
  run('hook-end',false);
  assert.ok(fs.existsSync(path.join(work,'strata-remote-desktop/state.json')),'failed lock keeps recovery journal');
  assert.ok(model().monitors.filter(x=>x.name!=='hypr-rdp-strata-1').every(x=>!x.dpmsStatus),'failed lock never wakes physical displays');
  assert.ok(!model().events.some(x=>x[0]==='hyprctl'&&x[1]==='eval'),'failed lock never moves windows or restores wake settings');
  assert.ok(fs.existsSync(path.join(work,'strata-remote-desktop/hook-failed')));
  m=model(); m.failLock=false; fs.writeFileSync(modelFile,JSON.stringify(m)); run('recover');

  reset(); run('hook-start'); m=model(); m.monitors=m.monitors.filter(x=>x.name!=='HDMI-A-1');
  m.workspaces.push({id:304,monitor:'hypr-rdp-strata-1',windows:1});
  fs.writeFileSync(modelFile,JSON.stringify(m)); run('hook-end');
  assert.ok(model().workspaces.filter(x=>x.windows).every(x=>x.monitor==='eDP-1'),'unplugged home and newly created workspaces return to an available output');

  reset({failIdle:true}); run('hook-start',false);
  assert.ok(model().monitors.every(x=>x.dpmsStatus),'unsupported idle service refuses before blanking');
  assert.ok(fs.existsSync(path.join(work,'strata-remote-desktop/hook-failed')));
  run('recover');

  reset(); run('hook-start');
  const r=spawnSync(script,['recover'],{env:{...env,HYPRLAND_INSTANCE_SIGNATURE:'other-instance'},encoding:'utf8'});
  assert.notEqual(r.status,0,'another compositor cannot consume this handoff journal');
  assert.ok(fs.existsSync(path.join(work,'strata-remote-desktop/state.json')));
  for(const failServer of [false,true]) {
    reset({failServer});
    m=model(); m.monitors=m.monitors.filter(x=>!x.name.startsWith('hypr-rdp-')); fs.writeFileSync(modelFile,JSON.stringify(m));
    const data=path.join(env.XDG_DATA_HOME,'strata/remote-desktop');
    const config=path.join(env.XDG_CONFIG_HOME,'strata/remote-desktop');
    fs.mkdirSync(data,{recursive:true}); fs.mkdirSync(config,{recursive:true});
    fs.copyFileSync('/usr/bin/true',path.join(data,'hypr-rdp')); fs.writeFileSync(path.join(config,'config.toml'),'');
    run('serve',!failServer);
    assert.ok(model().secure,'server secures the lock before listening');
    assert.ok(!model().monitors.some(x=>x.name.startsWith('hypr-rdp-')),'normal exit and startup failure clean up owned virtual output');
    assert.ok(!fs.existsSync(path.join(work,'strata-remote-desktop/output')));
  }
  console.log('PASS: workspace handoff, collision allocation, lock-before-wake, failed-lock recovery, unplugged outputs, new remote windows and session isolation');
} finally { fs.rmSync(work,{recursive:true,force:true}); }
