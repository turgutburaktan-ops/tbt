const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {insightsQueries, totalOrUnavailable} = require('../insights_queries');

function handler(fail = []) {
  const calls = [];
  const query = name => ({
    where() { return this; }, orderBy() { return this; }, limit() { return this; },
    count() { return {get: async () => { calls.push(name); if(fail.includes(name)) throw {code:9}; return {data:()=>({count:2})}; }}; },
    async get() { calls.push(name); if(fail.includes(name)) throw {code:9}; return {docs:[]}; },
  });
  const db = {collection: query, collectionGroup: query};
  const exports = {};
  vm.runInNewContext(fs.readFileSync(require.resolve('../admin_console'),'utf8'), {
    exports, console, require: name => {
      if(name === 'firebase-admin/storage') return {};
      if(name === 'firebase-functions/v2/https') return {onCall:(_,fn)=>fn,HttpsError:class extends Error{constructor(code,message){super(message);this.code=code;}}};
      if(name === 'firebase-admin/firestore') return {getFirestore:()=>db,Timestamp:{fromMillis:x=>x,now:()=>0}};
      if(name === './broadcast_policy') return {isNamedAdmin:a=>a.token?.admin===true};
      if(name === './admin_user_contacts') return {adminUserEmails:async ids=>{assert.equal(ids.length,0);return new Map();}};
      if(name === './insights_queries') return {insightsQueries,totalOrUnavailable};
      throw Error(name);
    },
  });
  return {run:exports.getAdminInsights,calls};
}
const request={auth:{uid:'admin',token:{admin:true}},data:{scope:'health'}};
test('health does not query unrelated users or posts; returns deletion count',async()=>{
  const {run,calls}=handler();const data=await run(request);
  assert(!calls.includes('users'));assert(!calls.includes('posts'));
  assert.equal(data.counts.deleteRequests,2);assert.equal(data.counts.openReports,10);
  assert.equal(data.unavailable.length,0);
});
test('failed counts and lists remain unavailable while other metrics load',async()=>{
  const {run}=handler(['trust_reports','app_errors','verification_email_deliveries']);
  const data=await run(request);
  assert.equal(data.counts.openReports,null);assert.equal(data.counts.appErrors,null);
  assert.equal(data.counts.verificationEmails,null);assert.equal(data.counts.analyticsEvents,2);
  assert(data.unavailable.includes('errors'));assert(data.unavailable.includes('verificationEmails'));
});
test('authorization fails before querying data',async()=>{
  const {run,calls}=handler();
  await assert.rejects(run({data:{scope:'health'}}),{code:'unauthenticated'});
  await assert.rejects(run({auth:{uid:'user',token:{}},data:{scope:'health'}}),{code:'permission-denied'});
  assert.equal(calls.length,0);
});
