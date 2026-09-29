const {test} = require('node:test');
const assert = require('node:assert/strict');
const {revokePrivateMedia} = require('../../tool/revoke_private_media.cjs');
const name = 'en-iyi-cekim-noktasi.firebasestorage.app';
function object(path) {
  let data = {metageneration:'1',metadata:{firebaseStorageDownloadTokens:'one,two',chatMessageId:'legacy'}};
  return {name:path,getMetadata:async()=>[data],setMetadata:async d=>{data={...d,metageneration:'2'};}};
}
test('one-shot revocation visits new and legacy chat pages and verifies every former token', async () => {
  const requests=[], checks=[], files=[object('private_chat/t/u/m/media.jpg'),object('users/u/chat/t/legacy.jpg')];
  const bucket={name,getFiles:async q=>{
    requests.push(q);
    if(q.prefix==='private_chat/')return [[files[0]],null];
    if(q.prefix==='users/'&&!q.pageToken)return [[object('users/u/posts/public.jpg')],{prefix:'users/',pageToken:'second'}];
    if(q.prefix==='users/')return [[files[1]],null];
    return [[],null];
  }};
  const result=await revokePrivateMedia(bucket,async url=>checks.push(url));
  assert.deepEqual(result,{objects:2,revokedTokens:4,anonymousAccess:'denied'});
  assert.equal(checks.length,6);
  assert.equal(requests.length,6);
  for(const file of files)assert.equal((await file.getMetadata())[0].metadata.firebaseStorageDownloadTokens,null);
});
test('unexpected bucket or reachable old token prevents success', async () => {
  await assert.rejects(revokePrivateMedia({name:'other'}),/Unexpected/);
  const file=object('private_chat/t/u/m/media.jpg');
  const bucket={name,getFiles:async()=>[[file],null]};
  await assert.rejects(revokePrivateMedia(bucket,async url=>{if(url.includes('&token='))throw Error('still reachable');}),/still reachable/);
});
