// Real greetd bridge against a private fake daemon; never calls PAM or logs in.
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),net=require('node:net'),vm=require('node:vm');
const {spawn}=require('node:child_process');
const {once}=require('node:events');
const repo=path.resolve(__dirname,'../..');
const work=fs.mkdtempSync(path.join(os.tmpdir(),'strata-greeter-ipc-'));
const source=fs.readFileSync(path.join(repo,'defaults/greeter/shell.qml'),'utf8');
const state={username:'sotatek',busy:false,extraPrompt:false,secretPrompt:true,message:'',notice:'',prompt:'Password',pendingPassword:'',fingerprintAvailable:true,sent:[],Qt:{quit(){}},send(event){state.sent.push(event)}};
for(const name of ['submit','startFingerprint','changeUser','handleAuthEvent','usesFingerprintPolicy']) {
  const fn=source.match(new RegExp('  function '+name+'\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}'));
  assert.ok(fn,'production controller '+name);
  vm.runInNewContext(fn[0],state);
}
assert.equal(state.usesFingerprintPolicy('[general]\nservice = "strata-greetd"\n'),true);
assert.equal(state.usesFingerprintPolicy('[general]\nservice = "custom-policy"\n'),false);
assert.equal(state.usesFingerprintPolicy('[default_session]\nservice = "strata-greetd"\n'),false);
state.startFingerprint();
assert.equal(state.sent[0].username,'sotatek');
assert.ok(!Object.hasOwn(state.sent[0],'password'),'fingerprint request has no synthetic empty password');
assert.equal(state.busy,true);
state.handleAuthEvent({type:'notice',message:'Touch the reader'});
assert.equal(state.notice,'Touch the reader');assert.equal(state.message,'','scan status is not a password error');
state.handleAuthEvent({type:'prompt',message:'Password:',secret:true});
assert.equal(state.busy,false);assert.equal(state.extraPrompt,true);
state.submit('test-password');
assert.equal(state.sent.at(-1).type,'respond','fallback answers current PAM challenge');
state.handleAuthEvent({type:'error',message:'Rejected'});
state.handleAuthEvent({type:'prompt',message:'Password:'});
state.changeUser('other');state.submit('other-password');
assert.equal(state.sent.at(-1).type,'login','changing account never answers the previous account challenge');
assert.equal(state.sent.at(-1).username,'other');
state.handleAuthEvent({type:'ready'});state.fingerprintAvailable=false;
const count=state.sent.length;state.startFingerprint();assert.equal(state.sent.length,count);

async function scenario(name,{password,failAuth=false,failStart=false,cancel=false}={}) {
  const dir=path.join(work,name);fs.mkdirSync(dir);
  const socketPath=path.join(dir,'greetd.sock');
  const requests=[],events=[],sockets=new Set();let protocolError,authenticated=false,phase='create';
  const server=net.createServer(socket=>{
    sockets.add(socket);socket.on('close',()=>sockets.delete(socket));let pending=Buffer.alloc(0);
    const reply=value=>{const body=Buffer.from(JSON.stringify(value));const header=Buffer.alloc(4);header.writeUInt32LE(body.length);socket.write(Buffer.concat([header,body]));};
    socket.on('data',data=>{
      pending=Buffer.concat([pending,data]);
      try { while(pending.length>=4 && pending.length>=4+pending.readUInt32LE(0)) {
        const length=pending.readUInt32LE(0),request=JSON.parse(pending.subarray(4,4+length));pending=pending.subarray(4+length);requests.push(request);
        if(request.type==='cancel_session') { authenticated=false;reply({type:'success'});continue; }
        if(request.type==='create_session') {
          assert.equal(request.username,'sotatek');assert.equal(phase,'create');phase='scan';
          reply({type:'auth_message',auth_message_type:'info',auth_message:'Touch your finger'});
        } else if(request.type==='post_auth_message_response' && phase==='scan') {
          assert.ok(!Object.hasOwn(request,'response'),'info acknowledgment must not supply a password');
          if(name==='fingerprint-success') {authenticated=true;phase='done';reply({type:'success'});}
          else {phase='password';reply({type:'auth_message',auth_message_type:'secret',auth_message:'Password:'});}
        } else if(request.type==='post_auth_message_response' && phase==='password') {
          assert.equal(request.response,password||'fallback-password');phase='done';
          if(failAuth)reply({type:'error',error_type:'auth_error',description:'Rejected'});
          else {authenticated=true;reply({type:'success'});}
        } else if(request.type==='start_session') {
          assert.equal(authenticated,true,'PAM success is required before starting a session');
          assert.deepEqual(request.cmd,['/usr/bin/systemd-cat','-t','strata-login-session','/usr/bin/uwsm','start','-e','-D','Hyprland','hyprland.desktop']);
          reply(failStart?{type:'error',error_type:'error',description:'Launch failed'}:{type:'success'});
        } else throw Error('Unexpected request '+JSON.stringify(request));
      }} catch(error){protocolError=error;socket.destroy();}
    });
  });
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(socketPath,resolve);});
  const child=spawn('bash',[path.join(repo,'bin/strata-greetd-ipc')],{env:{...process.env,HOME:dir,GREETD_SOCK:socketPath,STRATA_GREETER_STARTED_FILE:path.join(dir,'started')},stdio:['pipe','pipe','pipe']});
  const exited=once(child,'exit');let output='',errors='';
  child.stdout.on('data',data=>{output+=data;let i;while((i=output.indexOf('\n'))>=0){const line=output.slice(0,i);output=output.slice(i+1);events.push(JSON.parse(line));}});
  child.stderr.on('data',data=>{errors+=data;});
  const send=event=>child.stdin.write(JSON.stringify(event)+'\n');
  async function waitFor(type) {
    const end=Date.now()+6000;
    while(Date.now()<end){if(protocolError)throw protocolError;const event=events.find(e=>e.type===type);if(event)return event;if(child.exitCode!==null)throw Error('Bridge exited early: '+errors);await new Promise(resolve=>setTimeout(resolve,10));}
    throw Error('Timeout waiting for '+type+': '+errors);
  }
  try {
    send(password?{type:'login',username:'sotatek',password}:{type:'login',username:'sotatek'});
    await waitFor('notice');
    if(!password && name!=='fingerprint-success') {
      const prompt=await waitFor('prompt');assert.equal(prompt.secret,true);
      assert.ok(!requests.some(r=>r.type==='post_auth_message_response'&&Object.hasOwn(r,'response')),'no empty password submitted before user input');
      if(cancel){send({type:'cancel'});await waitFor('ready');assert.equal(requests.at(-1).type,'cancel_session');return;}
      send({type:'respond',response:'fallback-password'});
    }
    if(failAuth||failStart) {
      const error=await waitFor('error');assert.equal(error.message,failAuth?'Rejected':'Launch failed');
      assert.ok(!fs.existsSync(path.join(dir,'started')),'failed authentication or launch never reports a login');
      if(failAuth)assert.ok(!requests.some(r=>r.type==='start_session'));
    } else {
      await waitFor('started');await exited;
      assert.equal(child.exitCode,0,errors);
      assert.equal(fs.readFileSync(path.join(dir,'strata-last-user'),'utf8'),'sotatek\n');
      assert.ok(fs.existsSync(path.join(dir,'started')));
      if(password)assert.ok(!events.some(e=>e.type==='prompt'),'queued password is used at the secret prompt');
    }
    if(protocolError)throw protocolError;
  } finally {
    child.stdin.end();if(child.exitCode===null)child.kill('SIGTERM');
    for(const socket of sockets)socket.destroy();server.close();await exited;
  }
}
(async()=>{
  try {
    await scenario('fingerprint-success');
    await scenario('password-fallback');
    await scenario('queued-password',{password:'test-password'});
    await scenario('auth-rejected',{failAuth:true});
    await scenario('launch-rejected',{failStart:true});
    await scenario('cancel',{cancel:true});
    console.log('PASS: greeter controller, real IPC framing, fingerprint success, password fallback, queued passwords, cancellation and rejected authentication/session launch');
  } finally {fs.rmSync(work,{recursive:true,force:true});}
})().catch(error=>{console.error(error);process.exitCode=1;});
