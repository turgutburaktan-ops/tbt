const {test}=require('node:test');
const assert=require('node:assert/strict');
const {_finalizePrivateMediaHandler:finalize,_privatePath}=require('../functions/chat_media_security');
const db=member=>({doc:()=>({get:async()=>({data:()=>({memberIds:member?['owner']:[],participantIds:member?['owner']:[]})})})});
function bucket(){let sealed=false;return {file:()=>({getMetadata:async()=>[{metageneration:'1',metadata:sealed?{chatSealed:'true'}:{firebaseStorageDownloadTokens:'synthetic'}}],setMetadata:async m=>{assert.equal(m.metadata.firebaseStorageDownloadTokens,null);sealed=true;}}),isSealed:()=>sealed};}
test('Finalization rejects unauthenticated, other owner, and nonmember requests',async()=>{
 for(const [auth,path,member] of [[null,'route_chat/r/owner/m/media.jpg',true],[{uid:'other'},'route_chat/r/owner/m/media.jpg',true],[{uid:'owner'},'route_chat/r/owner/m/media.jpg',false],[{uid:'owner'},'users/owner/posts/media.jpg',true]]) {
  const b=bucket();await assert.rejects(finalize({auth,data:{storagePath:path}},db(member),b));assert.equal(b.isSealed(),false);
 }
});
test('Route and event member can seal owned attachment',async()=>{
 for(const ns of ['route_chat','route_albums','event_chat']) {
  const b=bucket();await finalize({auth:{uid:'owner'},data:{storagePath:`${ns}/r/owner/m/media.jpg`}},db(true),b);assert.equal(b.isSealed(),true);
 }
});
test('Sweeper cannot select public profile or post media',()=>{
 for(const p of ['users/a/posts/p.jpg','users/a/avatar/a.jpg','admin_broadcasts/a.jpg'])assert.equal(_privatePath(p),false);
 assert.equal(_privatePath('users/a/business_claims/cafe:abc/evidence.jpg'),true);
});
