const {test}=require('node:test');const assert=require('node:assert/strict');
const {owners,backfillContent}=require('../content_visibility');
test('all owner-bound types migrate transactionally and fail closed for missing or restricted owners',async()=>{
 for(const [type,field] of Object.entries(owners))for(const owner of [{},{accountStatus:'frozen'},{disabled:true},null]){
  const ref={path:`${type}/x`},writes=[];
  const db={doc:path=>({path}),runTransaction:async f=>f({get:async r=>({exists:true,data:()=>r.path===ref.path?{[field]:'u'}:owner}),update:(_,v)=>writes.push(v)})};
  await backfillContent({db,ref});assert.equal(writes.length,0);
  await backfillContent({db,ref,apply:true});assert.deepEqual(writes,[{accountFrozen:owner===null||owner.accountStatus==='frozen'||owner.disabled===true}]);
 }
});
test('unrelated and nested collections cannot be migrated accidentally',async()=>{
 for(const path of ['users/u','stories/s/interactions/u','private_users/u'])await assert.rejects(backfillContent({db:{},ref:{path},apply:true}),/Unsupported/);
});
