const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const work=fs.mkdtempSync(path.join(os.tmpdir(),'strata-rdp-firewall-'));
try {
  // Substitute command lookup only; all service and zone logic is the real helper.
  const original=fs.readFileSync(path.resolve(__dirname,'../../bin/strata-remote-desktop-firewall'),'utf8');
  const script=path.join(work,'helper');
  fs.writeFileSync(script,original.replace('export PATH=/usr/sbin:/usr/bin:/sbin:/bin','export PATH="'+work+':$PATH"'),{mode:0o755});
  fs.writeFileSync(path.join(work,'firewall-cmd'),`#!/bin/bash
printf '%s\\n' "$*" >> "$CALLS"
case "$*" in
  --state) test "$FIREWALL_RUNNING" = yes ;;
  --get-default-zone) echo public ;;
  --get-active-zones) printf 'public (default)\\n  interfaces: eth0\\nwork\\n  interfaces: wt0\\n' ;;
  *--query-service=rdp*) test "$OPEN" = yes ;;
  *) echo 'Unexpected firewall change' >&2; exit 99 ;;
esac
`,{mode:0o755});
  const env={...process.env,CALLS:path.join(work,'calls'),FIREWALL_RUNNING:'yes',OPEN:'no'};
  function run(mode){return spawnSync(script,[mode],{env,encoding:'utf8'});}
  assert.equal(run('check').status,1,'closed RDP service requests authorization');
  env.OPEN='yes';fs.writeFileSync(env.CALLS,'');
  assert.equal(run('check').status,0);
  const calls=fs.readFileSync(env.CALLS,'utf8');
  for(const zone of ['public','work'])for(const permanent of [false,true])
    assert.ok(calls.split('\n').some(line=>line.includes('--zone='+zone)&&line.includes('--query-service=rdp')&&line.includes('--permanent')===permanent));
  assert.ok(!calls.includes('--add-service'),'checks never change firewall configuration');
  env.FIREWALL_RUNNING='no';assert.equal(run('check').status,0,'inactive firewall is not enabled');
  assert.equal(run('invalid').status,64);
  if(process.getuid()!==0)assert.equal(run('open').status,1,'opening requires administrator authorization');
  console.log('PASS: RDP firewall zone selection, runtime/permanent checks, inactive firewall and authorization');
} finally {fs.rmSync(work,{recursive:true,force:true});}
