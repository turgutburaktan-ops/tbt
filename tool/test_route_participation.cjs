const assert=require('node:assert/strict');
if(!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||''))throw Error('Local emulator required');
const req=require('node:module').createRequire(require('node:path').resolve(__dirname,'../functions/package.json'));
const {initializeApp}=req('firebase-admin/app');const {getFirestore,Timestamp}=req('firebase-admin/firestore');initializeApp({projectId:'demo-tbt'});const db=getFirestore();
const encode=v=>Buffer.from(JSON.stringify(v)).toString('base64url'),now=Math.floor(Date.now()/1000);
const token=uid=>`${encode({alg:'none',typ:'JWT'})}.${encode({iss:'https://securetoken.google.com/demo-tbt',aud:'demo-tbt',sub:uid,user_id:uid,iat:now,exp:now+3600,firebase:{sign_in_provider:'custom'}})}.`;
const root=`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/demo-tbt/databases/(default)/documents`;
const string=v=>({stringValue:v});
async function write(uid,path,fields){return fetch(`${root}:commit`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({writes:[{update:{name:`projects/demo-tbt/databases/(default)/documents/${path}`,fields},updateMask:{fieldPaths:Object.keys(fields)},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]}]})});}
(async()=>{
 const ref=db.doc('travel_plans/route-rules');
 await ref.set({ownerId:'owner',memberIds:['owner'],spotIds:['custom-1','custom-2'],title:'Rota',isPublic:true,joinEnabled:true,participantLimit:2,startAt:Timestamp.fromMillis(Date.now()+3600000),meetingPoint:{label:'İskele',latitude:41,longitude:29}});
 const fields={userId:string('applicant'),name:string('Applicant'),status:string('pending')};
 assert.equal((await write('applicant',`${ref.path}/join_requests/applicant`,fields)).status,200,'public route accepts a request');
 assert.equal((await write('other',`${ref.path}/join_requests/applicant`,fields)).status,403,'cannot impersonate another user');
 assert.equal((await write('applicant',ref.path,{memberIds:{arrayValue:{values:[string('owner'),string('applicant')]}}})).status,403,'requester cannot self-enroll');
 assert.equal((await write('applicant',`${ref.path}/join_requests/applicant`,{status:string('accepted')})).status,403,'requester cannot approve');
 assert.equal((await fetch(`${root}/${ref.path}/join_requests/applicant`,{headers:{Authorization:`Bearer ${token('other')}`}})).status,403,'requests are private');
 assert.equal((await write('owner',ref.path,{memberIds:{arrayValue:{values:[string('owner'),string('applicant')]}}})).status,200);
 assert.equal((await write('owner',`${ref.path}/join_requests/applicant`,{status:string('accepted')})).status,200);
 assert.equal((await write('owner',ref.path,{memberIds:{arrayValue:{values:[string('owner'),string('applicant'),string('extra')]}}})).status,403,'capacity is enforced by rules');
 await ref.update({isPublic:false,joinEnabled:false,memberIds:['owner']});
 assert.equal((await write('applicant',`${ref.path}/join_requests/applicant`,fields)).status,403,'private route cannot receive requests');
 await ref.update({isPublic:true,joinEnabled:true,startAt:Timestamp.fromMillis(Date.now()-60000)});
 assert.equal((await write('applicant',`${ref.path}/join_requests/applicant`,fields)).status,403,'past route cannot receive requests');
 console.log('Route participation: requests, owner approval, privacy, capacity and expiry passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
