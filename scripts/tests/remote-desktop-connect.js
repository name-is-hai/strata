const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const work=fs.mkdtempSync(path.join(os.tmpdir(),'strata-rdp-connect-'));
const bin=path.join(work,'bin');fs.mkdirSync(bin);
function executable(name,text){const file=path.join(bin,name);fs.writeFileSync(file,text);fs.chmodSync(file,0o755);}
try {
  executable('ssh','#!/bin/bash\necho "SSH must not be used" >&2\nexit 99\n');
  executable('remmina',`#!/bin/bash
test "$1" = -c || exit 1
printf '%s' "$2" > "$TEST_PROFILE"
`);
  const script=path.resolve(__dirname,'../../bin/strata-remote-desktop-connect');
  const env={...process.env,PATH:bin+':'+process.env.PATH,HOME:work,XDG_DATA_HOME:path.join(work,'data'),TEST_PROFILE:path.join(work,'profile')};
  function run(target,ok=true){const r=spawnSync(script,[target],{env,encoding:'utf8'});if(ok)assert.equal(r.status,0,r.stderr);else assert.notEqual(r.status,0);return r;}
  for(const [target,server,user] of [['example.netbird.cloud','example.netbird.cloud:3389',''],
    ['remote-user@192.168.1.10:3390','192.168.1.10:3390','remote-user'],
    ['[fd00::1]:3391','[fd00::1]:3391',''],['fd00::1','[fd00::1]:3389','']]) {
    run(target);
    const profile=fs.readFileSync(env.TEST_PROFILE,'utf8');
    const text=fs.readFileSync(profile,'utf8');
    for(const setting of ['protocol=RDP','server='+server,'username='+user,'keyboard_grab=1','ssh_tunnel_enabled=0'])
      assert.ok(text.split('\n').includes(setting),setting);
    assert.ok(!text.includes('ssh_tunnel_server='));
    assert.equal(fs.statSync(profile).mode&0o777,0o600);
    fs.appendFileSync(profile,'custom-setting=keep\n');
    run(target);assert.ok(fs.readFileSync(profile,'utf8').endsWith('custom-setting=keep\n'),'saved profiles are preserved');
  }
  for(const target of ['-bad','bad name','bad\nname','host:0','host:65536','host:abc','[bad','@',''])run(target,false);
  console.log('PASS: direct RDP hostnames, IPv4/IPv6, ports, keyboard capture, saved profiles and input validation');
} finally {fs.rmSync(work,{recursive:true,force:true});}
