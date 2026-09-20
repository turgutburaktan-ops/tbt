const assert = require('node:assert/strict');
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Local emulator required');
const project = 'demo-tbt';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
function token(uid) {
  const now = Math.floor(Date.now()/1000), enc = x => Buffer.from(JSON.stringify(x)).toString('base64url');
  return `${enc({alg:'none',typ:'JWT'})}.${enc({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,iat:now,exp:now+3600,auth_time:now,firebase:{sign_in_provider:'custom',identities:{}}})}.`;
}
const wrap = data => ({fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,{stringValue:v}]))});
async function req(path, uid, method='GET', data) {
  return fetch(`${base}/${path}`,{method,headers:{'Content-Type':'application/json',...(uid?{Authorization:`Bearer ${uid === 'owner' ? 'owner' : token(uid)}`}:{})},...(data?{body:JSON.stringify(wrap(data))}:{})});
}
(async()=>{
  const path='posts/comment-test/comments/c1';
  await req('posts/comment-test','owner','PATCH',{userId:'publisher'});
  const seed=()=>req(path,'owner','PATCH',{userId:'writer',text:'hello'});
  await seed();
  assert.equal((await req(path,'stranger','DELETE')).status,403);
  assert.equal((await req(path,null,'DELETE')).status,403);
  assert.equal((await req(path,'publisher','PATCH',{userId:'writer',text:'changed'})).status,403);
  assert.equal((await req(path,'publisher','DELETE')).status,200);
  await seed();
  assert.equal((await req(path,'writer','DELETE')).status,200);
  await seed();
  async function report(uid,changes={}) {
    const data={reporterId:uid,targetType:'comment',targetCollection:'posts',contentId:'comment-test',commentId:'c1',targetId:path,targetOwnerId:'writer',commentText:'hello',reason:'Spam',status:'open',...changes};
    const document={name:`projects/${project}/databases/(default)/documents/reports/${uid}`, ...wrap(data)};
    return fetch(`${base}:commit`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token(uid)}`},body:JSON.stringify({writes:[{update:document,updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}]}]})});
  }
  assert.equal((await report('stranger')).status,200);
  assert.equal((await report('publisher')).status,200);
  assert.equal((await report('writer')).status,403);
  assert.equal((await report('forger',{reporterId:'someone-else'})).status,403);
  assert.equal((await report('forger',{commentText:'fabricated'})).status,403);
  assert.equal((await report('forger',{targetId:'posts/comment-test/comments/missing'})).status,403);
  assert.equal((await req('reports/stranger','stranger')).status,403);
  console.log('Comment owner/author deletion and report integrity checks passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
