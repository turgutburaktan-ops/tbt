'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const photos = require(process.env.ROUTE_PHOTO_MANIFEST || './elazig_route_photos.json');
const routes = require(process.env.ROUTE_MANIFEST || './elazig_external_routes.json');
const creditLine = '\nKapak fotoğrafı: Fırat’ı Keşfet (rota kaynak sayfası).';
const hash = b => crypto.createHash('sha256').update(b).digest('hex');

async function main() {
  assert.equal(photos.length, routes.length);
  assert(photos.length > 0 && photos.length <= 30);
  assert.equal(new Set(photos.map(p=>p.id)).size,photos.length);
  for (const p of photos) {
    assert(routes.some(r=>r.id===p.id));
    assert.equal(new URL(p.sourceUrl).origin,'https://firatikesfet.com');
    assert(new URL(p.sourceUrl).pathname.startsWith('/BackOffice/UploadImage/gallery/'));
    assert.match(p.sha256,/^[a-f0-9]{64}$/);
  }
  if (process.env.PUBLISH_ROUTE_PHOTOS !== 'true') {
    console.log('VERIFIED_ROUTE_PHOTO_MANIFEST '+photos.length); return;
  }
  const admin = require('firebase-admin');
  const account = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  assert.equal(account.project_id,'en-iyi-cekim-noktasi');
  const bucketName='en-iyi-cekim-noktasi.firebasestorage.app';
  admin.initializeApp({credential:admin.credential.cert(account),storageBucket:bucketName});
  const db=admin.firestore(), bucket=admin.storage().bucket();
  const owner=await admin.auth().getUserByEmail('turgutburaktan@gmail.com');
  const prepared=[];
  // Verify every download before changing any route document.
  for (const p of photos) {
    const response=await fetch(p.sourceUrl,{signal:AbortSignal.timeout(60000)});
    assert(response.ok,`Photo download failed: ${p.id}`);
    assert(response.headers.get('content-type')?.startsWith('image/'));
    const bytes=Buffer.from(await response.arrayBuffer());
    assert(bytes.length>10000 && bytes.length<2*1024*1024);
    assert.equal(bytes.readUInt16BE(0),0xffd8);
    assert.equal(hash(bytes),p.sha256,'Source photo has changed; review it again');
    const storagePath=`users/${owner.uid}/ready_route_covers/${p.id}/${p.sha256}.jpg`;
    const file=bucket.file(storagePath);
    let token;
    if ((await file.exists())[0]) {
      const [meta]=await file.getMetadata();
      assert.equal(meta.metadata?.sourceSha256,p.sha256);
      token=meta.metadata.firebaseStorageDownloadTokens?.split(',')[0];
      assert(token);
    } else {
      token=crypto.randomUUID();
      await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{
        contentType:'image/jpeg',cacheControl:'public,max-age=31536000,immutable',
        metadata:{firebaseStorageDownloadTokens:token,sourceSha256:p.sha256,sourceUrl:p.sourceUrl,credit:p.credit}
      }});
    }
    const imageUrl=`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
    const check=await fetch(imageUrl,{signal:AbortSignal.timeout(30000)});
    assert(check.ok,'Uploaded image is not readable');
    assert.equal(hash(Buffer.from(await check.arrayBuffer())),p.sha256);
    prepared.push({...p,imageUrl,storagePath});
  }
  const refs=photos.map(p=>db.collection('travel_plans').doc(p.id));
  const before=[];
  await db.runTransaction(async tx=>{
    const docs=await tx.getAll(...refs);
    before.length=0;
    for (let i=0;i<docs.length;i++) {
      assert(docs[i].exists,'Route missing');
      const data=docs[i].data(), photo=prepared[i], definition=routes.find(r=>r.id===photo.id);
      assert.equal(data.ownerId,owner.uid);
      assert.equal(data.externalImportHash,hash(JSON.stringify(definition)));
      const originalStops=data.stopSnapshots.map((s,n)=>({...s,imageUrl:definition.stopSnapshots[n].imageUrl}));
      assert.deepEqual(originalStops,definition.stopSnapshots);
      assert(!data.stopSnapshots[0].imageUrl || data.stopSnapshots[0].imageUrl===photo.imageUrl,'Existing cover conflict');
      assert([definition.dayPlan.description,definition.dayPlan.description+creditLine].includes(data.dayPlan.description));
      before.push(data);
      tx.update(refs[i],{
        stopSnapshots:data.stopSnapshots.map((s,n)=>n===0?{...s,imageUrl:photo.imageUrl}:s),
        'dayPlan.description':definition.dayPlan.description+creditLine,
        externalRoutePhoto:{...photo,role:'route-cover',version:1},
        updatedAt:admin.firestore.Timestamp.now()
      });
    }
  });
  const live=await db.getAll(...refs);
  for (let i=0;i<live.length;i++) {
    const data=live[i].data(), old=before[i];
    assert.equal(data.stopSnapshots[0].imageUrl,prepared[i].imageUrl);
    assert.deepEqual(data.externalRoutePhoto,{...prepared[i],role:'route-cover',version:1});
    const restored={...data,stopSnapshots:old.stopSnapshots,dayPlan:{...data.dayPlan,description:old.dayPlan.description},updatedAt:old.updatedAt};
    if (old.externalRoutePhoto) restored.externalRoutePhoto=old.externalRoutePhoto;
    else delete restored.externalRoutePhoto;
    assert.deepEqual(restored,old,'An unrelated route field changed');
    console.log('ROUTE_PHOTO_LIVE '+JSON.stringify({id:live[i].id,title:data.title,sha256:prepared[i].sha256}));
  }
  console.log('PUBLISHED_AND_VERIFIED_ROUTE_PHOTOS '+photos.length);
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
