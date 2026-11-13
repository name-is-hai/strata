const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const work=fs.mkdtempSync(path.join(os.tmpdir(),'strata-video-'));
const bin=path.join(work,'bin'),pci=path.join(work,'pci'),dri=path.join(work,'dri');
for(const dir of [bin,pci,dri])fs.mkdirSync(dir);
function put(name,text){const file=path.join(bin,name);fs.writeFileSync(file,text,{mode:0o755});}
try {
  const source=fs.readFileSync(path.resolve(__dirname,'../../bin/strata-video-acceleration'),'utf8');
  const script=path.join(work,'helper');
  const fixture=source.replaceAll('/sys/bus/pci/devices',pci).replaceAll('/dev/dri',dri);
  fs.writeFileSync(script,fixture,{mode:0o755});
  const admin=path.join(work,'admin');fs.writeFileSync(admin,fixture.replace('[[ $EUID == 0 ]]','true'),{mode:0o755});
  put('rpm',`#!/bin/bash
if [[ $1 == -E ]]; then echo 44; exit; fi
for argument in "$@"; do package=$argument; done
case " $TEST_INSTALLED " in *" $package "*) exit 0 ;; *) exit 1 ;; esac
`);
  put('vainfo','#!/bin/bash\nprintf "%s\\n" "$TEST_CAPS"\nexit "${TEST_VA_STATUS:-0}"\n');
  put('ffmpeg','#!/bin/bash\nprintf "%s\\n" "$*" >> "$TEST_CALLS"\nexit "${TEST_ENCODE_STATUS:-0}"\n');
  put('dnf','#!/bin/bash\nprintf "%s\\n" "$*" >> "$TEST_DNF"\nexit "${TEST_DNF_STATUS:-0}"\n');
  const env={...process.env,PATH:bin+':'+process.env.PATH,TEST_INSTALLED:'',TEST_CAPS:'',
    TEST_CALLS:path.join(work,'encode'),TEST_DNF:path.join(work,'dnf')};
  function run(mode,file=script){return spawnSync(file,[mode],{env,encoding:'utf8',timeout:5000});}
  function gpu(vendor,cls='0x030000'){fs.rmSync(pci,{recursive:true,force:true});fs.mkdirSync(pci);const dev=path.join(pci,'gpu');fs.mkdirSync(dev);fs.writeFileSync(path.join(dev,'vendor'),vendor);fs.writeFileSync(path.join(dev,'class'),cls);}
  gpu('0x8086');assert.equal(run('check').status,1);
  env.TEST_INSTALLED='libva-intel-media-driver';assert.equal(run('check').status,1,'free Intel build is not assumed to provide H.264');
  env.TEST_INSTALLED='intel-media-driver';assert.equal(run('check').status,0);
  gpu('0x1002');assert.equal(run('check').status,1);env.TEST_INSTALLED='mesa-va-drivers-freeworld';assert.equal(run('check').status,0);
  gpu('0x10de');env.TEST_INSTALLED='';assert.equal(run('check').status,0,'NVIDIA-only hosts do not install a decode-only driver as an encoder');
  gpu('0x8086','0x040300');assert.equal(run('check').status,0,'non-GPU PCI devices are ignored');
  function probe(){const r=run('probe');assert.equal(r.status,0,r.stderr);return JSON.parse(r.stdout);}
  assert.equal(probe().hardware,false,'machines without render nodes remain usable');
  fs.writeFileSync(path.join(dri,'renderD128'),'');
  env.TEST_CAPS='VAProfileH264High : VAEntrypointEncSliceLP';
  assert.equal(probe().hardware,false,'low-power-only mode is unsupported by this RDP backend');
  assert.equal(fs.existsSync(env.TEST_CALLS),false,'unsupported modes never run an encode');
  env.TEST_CAPS='VAProfileH264High : VAEntrypointVLD\nVAProfileH264Main : VAEntrypointEncSlice';
  assert.equal(probe().hardware,false,'mirror the backend preference for High over Main');
  env.TEST_CAPS='VAProfileH264High : VAEntrypointEncSlice';
  let result=probe();assert.equal(result.hardware,true);assert.equal(result.fps,60);assert.equal(result.backend,'auto');
  const calls=fs.readFileSync(env.TEST_CALLS,'utf8');assert.ok(calls.includes('-low_power 0')&&calls.includes('-frames:v 3')&&calls.includes('color=c=black'));
  env.TEST_ENCODE_STATUS='1';result=probe();assert.equal(result.hardware,false);assert.equal(result.fps,30);assert.equal(result.backend,'software');
  env.TEST_VA_STATUS='1';assert.equal(probe().hardware,false,'driver initialization failure falls back');
  gpu('0x8086');env.TEST_INSTALLED='libva-intel-media-driver rpmfusion-free-release';
  const install=run('install',admin);assert.equal(install.status,0,install.stderr);
  const dnf=fs.readFileSync(env.TEST_DNF,'utf8');assert.ok(dnf.includes('rpmfusion-nonfree-release-44.noarch.rpm'));assert.ok(dnf.includes('libva-intel-media-driver intel-media-driver'));
  assert.ok(!dnf.includes('--allowerasing'));
  gpu('0x1002');env.TEST_INSTALLED='mesa-va-drivers-free rpmfusion-free-release';fs.writeFileSync(env.TEST_DNF,'');
  assert.equal(run('install',admin).status,0);
  assert.ok(fs.readFileSync(env.TEST_DNF,'utf8').includes('mesa-va-drivers-free mesa-va-drivers-freeworld'));
  env.TEST_DNF_STATUS='1';assert.notEqual(run('install',admin).status,0,'package failure is reported for caller fallback');
  if(process.getuid()!==0)assert.notEqual(run('install').status,0,'package installation requires root');
  console.log('PASS: GPU detection, codec driver selection, repository setup, real encode gating, backend compatibility and software fallback');
} finally {fs.rmSync(work,{recursive:true,force:true});}
