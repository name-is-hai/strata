const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const work=fs.mkdtempSync(path.join(os.tmpdir(),'strata-rdp-connect-'));
const bin=path.join(work,'bin');fs.mkdirSync(bin);
function executable(name,text){const file=path.join(bin,name);fs.writeFileSync(file,text);fs.chmodSync(file,0o755);}
try {
  const identity=path.join(work,'identity with spaces');fs.writeFileSync(identity,'fixture');
  executable('ssh',`#!/bin/bash
test "$1" = -G && test "$2" = -- || exit 1
printf 'hostname test.netbird.cloud\\nuser remote-user\\nport 2222\\nidentityfile %s\\n' "$TEST_IDENTITY"
`);
  executable('remmina',`#!/bin/bash
test "$1" = -c || exit 1
printf '%s' "$2" > "$TEST_PROFILE"
`);
  const script=path.resolve(__dirname,'../../bin/strata-remote-desktop-connect');
  const env={...process.env,PATH:bin+':'+process.env.PATH,HOME:work,XDG_DATA_HOME:path.join(work,'data'),
    TEST_IDENTITY:identity,TEST_PROFILE:path.join(work,'profile')};
  function run(target,ok=true){const r=spawnSync(script,[target],{env,encoding:'utf8'});if(ok)assert.equal(r.status,0,r.stderr);else assert.notEqual(r.status,0);return r;}
  run('test.alias');
  const profile=fs.readFileSync(env.TEST_PROFILE,'utf8');
  const text=fs.readFileSync(profile,'utf8');
  for(const setting of ['protocol=RDP','server=127.0.0.1:3389','username=remote-user','keyboard_grab=1',
    'ssh_tunnel_enabled=1','ssh_tunnel_loopback=1','ssh_tunnel_server=test.netbird.cloud:2222',
    'ssh_tunnel_auth=1','ssh_tunnel_privatekey='+identity]) assert.ok(text.split('\n').includes(setting),setting);
  assert.equal(fs.statSync(profile).mode&0o777,0o600);
  fs.appendFileSync(profile,'custom-setting=keep\n');
  run('test.alias');assert.ok(fs.readFileSync(profile,'utf8').endsWith('custom-setting=keep\n'),'saved profiles are preserved');
  for(const target of ['-oProxyCommand=bad','bad name','bad\nname'])run(target,false);
  env.TEST_IDENTITY=path.join(work,'not-present');run('another.alias');
  const other=fs.readFileSync(fs.readFileSync(env.TEST_PROFILE,'utf8'),'utf8');
  assert.ok(other.includes('ssh_tunnel_auth=3'),'fallback supports automatic public key or agent authentication');
  assert.ok(!other.includes('ssh_tunnel_privatekey='));
  console.log('PASS: RDP client SSH alias resolution, private profiles, keyboard capture and input validation');
} finally {fs.rmSync(work,{recursive:true,force:true});}
