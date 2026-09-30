const {test} = require('node:test');
const assert = require('node:assert/strict');
const {suspendFile,suspendUserMedia,resumeUserMedia} = require('../frozen_media');
function fixture() {
  const records = new Map(), objects = new Map();
  let profile = {accountStatus:'frozen'};
  const ref = path => ({path,set:async data=>records.set(path,data),delete:async()=>records.delete(path),
    get:async()=>({data:()=>path==='users/u'?profile:records.get(path)})});
  const db = {doc:ref,collection:path=>({limit:()=>({get:async()=>{
    const docs=[...records].filter(([key])=>key.startsWith(path+'/')).map(([key,value])=>({data:()=>value,ref:ref(key)}));
    return {empty:!docs.length,docs};
  }})})};
  function file(name, tokens='old-token') {
    let meta={generation:'1',metageneration:'1',cacheControl:'public,max-age=100',metadata:{firebaseStorageDownloadTokens:tokens,other:'keep'}};
    const f={name,getMetadata:async()=>[{...meta,metadata:{...meta.metadata}}],
      setMetadata:async (patch,opts)=>{assert.equal(opts.ifMetagenerationMatch,meta.metageneration);meta={...meta,...patch,metageneration:String(Number(meta.metageneration)+1)};},
      replace:()=>{meta.generation='2';},read:()=>meta};
    objects.set(name,f);return f;
  }
  const bucket={file:name=>objects.get(name),getFiles:async()=>[[...objects.values()],null]};
  return {db,bucket,records,file,activate:()=>{profile={accountStatus:'active'};}};
}
test('freeze revokes public tokens, preserving recovery state and unrelated metadata',async()=>{
 const f=fixture(),obj=f.file('users/u/posts/photo.jpg');
 await suspendUserMedia({...f,uid:'u'});
 assert.equal(obj.read().metadata.firebaseStorageDownloadTokens,null);
 assert.equal(obj.read().metadata.other,'keep');
 assert.equal([...f.records.values()][0].tokens,'old-token');
 await suspendUserMedia({...f,uid:'u'});
 assert.equal(f.records.size,1);
});
test('media cannot resume until the account is active; resume restores the same object only',async()=>{
 const f=fixture(),obj=f.file('users/u/posts/photo.jpg');
 await suspendUserMedia({...f,uid:'u'});
 await assert.rejects(resumeUserMedia({...f,uid:'u'}),/must be active/);
 assert.equal(obj.read().metadata.firebaseStorageDownloadTokens,null);
 f.activate();await resumeUserMedia({...f,uid:'u'});
 assert.equal(obj.read().metadata.firebaseStorageDownloadTokens,'old-token');
 assert.equal(obj.read().cacheControl,'public,max-age=100');assert.equal(f.records.size,0);
});
test('old links are never granted access to a replacement object',async()=>{
 const f=fixture(),obj=f.file('users/u/posts/photo.jpg');
 await suspendUserMedia({...f,uid:'u'});obj.replace();f.activate();
 await resumeUserMedia({...f,uid:'u'});
 assert.equal(obj.read().metadata.firebaseStorageDownloadTokens,null);assert.equal(f.records.size,0);
});
test('a failure saving recovery data leaves the token intact and reports failure',async()=>{
 const f=fixture(),obj=f.file('users/u/posts/photo.jpg');
 f.db.doc=()=>({set:async()=>{throw Error('database unavailable');}});
 await assert.rejects(suspendFile(f.db,'u',obj),/database unavailable/);
 assert.equal(obj.read().metadata.firebaseStorageDownloadTokens,'old-token');
});
test('pagination is exhausted and another owner is never touched',async()=>{
 const f=fixture(),a=f.file('users/u/posts/a.jpg'),b=f.file('users/u/posts/b.jpg');
 const queries=[];f.bucket.getFiles=async q=>{queries.push(q);return q.pageToken?[[b],null]:[[a],{...q,pageToken:'next'}];};
 await suspendUserMedia({...f,uid:'u'});assert.equal(queries.length,2);
 assert.equal(a.read().metadata.firebaseStorageDownloadTokens,null);assert.equal(b.read().metadata.firebaseStorageDownloadTokens,null);
 const other=f.file('users/other/posts/a.jpg');await assert.rejects(suspendFile(f.db,'u',other),/Unexpected/);
 assert.equal(other.read().metadata.firebaseStorageDownloadTokens,'old-token');
});
