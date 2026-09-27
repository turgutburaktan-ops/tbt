const test=require('node:test'),assert=require('node:assert/strict');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {projectSpots}=require('./spot_batch');
initializeApp({projectId:'demo-tbt'});const db=getFirestore();
test('batch preserves spot identities, counts, approval, and city moves',async()=>{
  const ids=Array.from({length:80},(_,i)=>`batch-spot-${i}`),b=db.batch();
  for(const id of ids)b.set(db.doc(`photo_spots/${id}`),{name:id,city:'Elazığ',latitude:38.7,longitude:39.2,status:'published',coordinateVerified:true,imageVerified:true,imageUrl:'https://example.org/image.jpg'});
  await b.commit();await projectSpots(db,ids);await projectSpots(db,ids);
  const meta=db.doc('place_catalog/elazig_gezi');assert.equal((await meta.get()).data().count,80);
  assert.equal((await meta.collection('items').get()).size,80);
  await db.doc(`photo_spots/${ids[0]}`).update({status:'pending'});
  await db.doc(`photo_spots/${ids[1]}`).update({city:'Ankara',latitude:39.9,longitude:32.8});
  await projectSpots(db,ids);
  assert.equal((await meta.get()).data().count,78);
  assert.equal((await db.doc('place_catalog/ankara_gezi').get()).data().count,1);
  assert.equal((await meta.collection('items').doc(`spot:${ids[0]}`).get()).exists,false);
});
