// Transactional rollout for all owner-bound content. Never unfreezes existing data.
const owners = Object.freeze({posts:'userId',stories:'userId',post_reposts:'userId',social_events:'hostId',event_memories:'userId',travel_plans:'ownerId',communities:'ownerId'});
async function backfillContent({db,ref,apply=false}) {
 const collection=ref.path.split('/')[0], field=owners[collection];
 if(!field || ref.path.split('/').length!==2) throw Error('Unsupported content path');
 return db.runTransaction(async tx=>{
  const snapshot=await tx.get(ref);if(!snapshot.exists)return 'deleted';
  const data=snapshot.data(), uid=data[field];
  if(typeof uid!=='string'||!uid||uid.includes('/'))return 'invalid-owner';
  const owner=(await tx.get(db.doc(`users/${uid}`))).data();
  const frozen=data.accountFrozen===true||!owner||(owner.accountStatus||'active')!=='active'||owner.banned===true||owner.disabled===true;
  if(data.accountFrozen===frozen)return 'unchanged';
  if(apply)tx.update(ref,{accountFrozen:frozen});
  return frozen?'hide':'make-queryable';
 });
}
module.exports={owners,backfillContent};
