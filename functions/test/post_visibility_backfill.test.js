const {test} = require('node:test');
const assert = require('node:assert/strict');
const {backfillPost} = require('../../tool/post_visibility_backfill.cjs');
function fixture(post,owner={}) {
 const writes=[];const ref={path:'posts/p'};
 const db={doc:path=>({path}),runTransaction:async work=>work({
  get:async r=>({exists:r.path==='posts/p'?!!post:!!owner,data:()=>r.path==='posts/p'?post:owner}),
  update:(_,patch)=>writes.push(patch),
 })};return {db,ref,writes};
}
test('dry run makes no writes; apply adds a queryable flag to active legacy posts',async()=>{
 const f=fixture({userId:'u'});
 assert.equal(await backfillPost(f),'make-queryable');assert.deepEqual(f.writes,[]);
 await backfillPost({...f,apply:true});assert.deepEqual(f.writes,[{accountFrozen:false}]);
});
test('backfill never thaws existing frozen posts or exposes restricted/missing owners',async()=>{
 for(const [post,owner] of [[{userId:'u',accountFrozen:true},{}],[{userId:'u'},{accountStatus:'frozen'}],[{userId:'u'},{banned:true}],[{userId:'u'},null]]) {
  const f=fixture(post,owner);await backfillPost({...f,apply:true});
  assert.ok(f.writes.every(p=>p.accountFrozen===true));
 }
});
test('deleted/invalid posts are never recreated and explicit visibility is idempotent',async()=>{
 for(const post of [null,{userId:'bad/path'},{userId:'u',accountFrozen:false}]) {
  const f=fixture(post);await backfillPost({...f,apply:true});assert.deepEqual(f.writes,[]);
 }
});
