// Run only against the Firestore emulator; never reads production records.
const assert = require('node:assert/strict');
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Local Firestore emulator required');
}
const project = 'demo-tbt';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({iss: `https://securetoken.google.com/${project}`, aud: project, sub: uid, user_id: uid, iat: now, exp: now + 3600, auth_time: now, firebase: {sign_in_provider: 'custom', identities: {}}})}.`;
}
async function request(path, credential, method = 'GET', body) {
  return fetch(`${base}/${path}`, {method, headers: {
    'Content-Type': 'application/json',
    ...(credential ? {Authorization: `Bearer ${credential}`} : {}),
  }, ...(body ? {body: JSON.stringify(body)} : {})});
}
(async () => {
  const root='social_events/hub-test', member=token('member'), outsider=token('outsider'), hostToken=token('host');
  const wrap=value=>({fields:Object.fromEntries(Object.entries(value).map(([k,v])=>[k, typeof v==='string'?{stringValue:v}:Array.isArray(v)?{arrayValue:{values:v.map(x=>({stringValue:x}))}}:{integerValue:String(v)}]))});
  assert.equal((await request(root,'owner','PATCH',wrap({hostId:'host',status:'open',visibility:'public',participantIds:['host','member'],capacity:10}))).status,200);
  const info=root+'/info/main',chat=root+'/chat/message';
  // Server timestamps use transforms, exactly as the clients do.
  async function write(path,uid,data){
    const document={name:`projects/${project}/databases/(default)/documents/${path}`,...wrap(data)};
    return fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents:commit`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${uid}`},body:JSON.stringify({writes:[{update:document,updateTransforms:[{fieldPath:path.includes('/chat/')?'createdAt':'updatedAt',setToServerValue:'REQUEST_TIME'}]}]})});
  }
  assert.equal((await write(info,hostToken,{program:'10:00 Buluşma',announcement:'Girişte buluşalım'})).status,200,'host can publish programme');
  assert.equal((await request(info)).status,200,'public can read programme');
  assert.equal((await write(info,member,{program:'forged'})).status,403,'member cannot edit programme');
  assert.equal((await write(chat,member,{senderId:'member',senderName:'Member',text:'Merhaba'})).status,200,'participant can chat');
  assert.equal((await request(chat,member)).status,200);
  assert.equal((await request(chat,outsider)).status,403,'outsider cannot read chat');
  assert.equal((await write(root+'/chat/forged',member,{senderId:'host',senderName:'Host',text:'forged'})).status,403,'cannot forge sender');
  assert.equal((await write(root+'/chat/outsider',outsider,{senderId:'outsider',senderName:'Guest',text:'hello'})).status,403);
  await request(root,'owner','PATCH',wrap({hostId:'host',status:'open',visibility:'public',participantIds:['host'],capacity:10}));
  assert.equal((await request(chat,member)).status,403,'leaving revokes access');
  console.log('Event hub rules: programme ownership, participant chat and revocation passed.');
})().catch(error=>{console.error(error);process.exitCode=1;});
