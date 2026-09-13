'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const root = path.resolve(__dirname, '..');
const requireFunctions = createRequire(path.join(root, 'functions/package.json'));
const dir = path.join(__dirname, 'editorial/promotion-20260913');
const uid = 'tbt-editorial-rehber', username = 'tbt.rehber';
const project = 'en-iyi-cekim-noktasi', batch = 'tbt-promotion-20260913';
const bucketName = `${project}.firebasestorage.app`;
const check = (ok, msg) => { if (!ok) throw new Error(msg); };
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
async function main() {
  const data = JSON.parse(await fs.readFile(path.join(dir, 'manifest.json'), 'utf8'));
  check(data.batch === batch && data.posts.length === 8, 'Unexpected batch');
  const images = [];
  for (const [i,p] of data.posts.entries()) {
    const n = String(i+7).padStart(2, '0');
    check(p.id === `${batch}-${n}` && p.file === `${n}.jpg` && p.caption && p.title, 'Invalid post');
    const bytes = await fs.readFile(path.join(dir, p.file));
    check(bytes.length > 10000 && bytes.length < 4000000 && hash(bytes) === p.sha256, 'Image checksum mismatch');
    check(bytes[0] === 255 && bytes[1] === 216, 'Expected JPEG');
    images.push(bytes);
  }
  console.log('Validated 8 reviewed promotional images and captions.');
  if (process.argv.includes('--validate')) return;
  check(process.argv.includes('--publish'), 'Use --validate or --publish');
  const admin = requireFunctions('firebase-admin');
  const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  check(sa.project_id === project, 'Wrong Firebase project');
  admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName});
  const db = admin.firestore(), bucket = admin.storage().bucket();
  const userRef = db.collection('users').doc(uid), nameRef = db.collection('usernames').doc(username);
  const refs = data.posts.map(p => db.collection('posts').doc(p.id));
  function guard(snaps) {
    const [u,n,...posts] = snaps;
    check(u.exists && u.data().uid === uid && u.data().isEditorial === true, 'Existing editorial publisher required');
    check(n.exists && n.data().uid === uid, 'Publisher username mismatch');
    posts.forEach((s,i)=>check(!s.exists || (s.data().userId===uid && s.data().editorialBatch===batch && s.data().mediaSha256===data.posts[i].sha256 && s.data().caption===data.posts[i].caption), 'Existing post collision'));
  }
  const before = await db.getAll(userRef,nameRef,...refs); guard(before);
  const user = before[0].data(), avatar = user.photoURL || user.photoUrl || '';
  const existing = await db.collection('posts').where('userId','==',uid).get();
  const otherPromotions = existing.docs.filter(s=> !s.id.startsWith(batch) && (s.data().editorialKind === 'promotion' || s.data().editorialBatch?.includes('promotion')));
  check(otherPromotions.length === 0, 'Other promotional batch exists; inspect before publishing duplicates');
  const media=[];
  for(const [i,p] of data.posts.entries()) {
    const key=`editorial/${batch}/${p.file}`, file=bucket.file(key);
    let metadata;
    try { [metadata]=await file.getMetadata(); } catch(e) { if(Number(e.code)!==404) throw e; }
    if(metadata) check(metadata.metadata?.sha256===p.sha256, 'Storage collision');
    else {
      await file.save(images[i], {resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:'image/jpeg',cacheControl:'public,max-age=31536000,immutable',metadata:{firebaseStorageDownloadTokens:crypto.randomUUID(),sha256:p.sha256,editorialBatch:batch}}});
      [metadata]=await file.getMetadata();
    }
    const token=metadata.metadata?.firebaseStorageDownloadTokens?.split(',')[0]; check(token,'Missing download token');
    const url=`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(key)}?alt=media&token=${token}`;
    const response=await fetch(url,{signal:AbortSignal.timeout(30000)});
    check(response.ok && hash(Buffer.from(await response.arrayBuffer()))===p.sha256, 'Public media verification failed');
    media.push({url,key});
  }
  await db.runTransaction(async tx=>{
    const snaps=await tx.getAll(userRef,nameRef,...refs);guard(snaps);
    const now=admin.firestore.FieldValue.serverTimestamp();
    data.posts.forEach((p,i)=>{
      if(snaps[i+2].exists) return;
      const {url,key}=media[i];
      tx.create(refs[i],{id:p.id,userId:uid,userName:'TBT',userPhotoUrl:avatar,userEmail:'',caption:p.caption,
        spotName:'',city:'',latitude:null,longitude:null,taggedUserIds:[],taggedUserNames:[],likesCount:0,commentsCount:0,
        sourceType:'post',businessVenueKey:'',businessVenueName:'',businessOfficial:false,venueKey:'',mediaType:'image',
        imageUrl:url,storagePath:key,videoUrl:'',videoStoragePath:'',thumbnailUrl:url,thumbnailStoragePath:key,durationMs:0,
        visibility:'public',status:'published',isEditorial:true,editorialBatch:batch,editorialKind:'promotion',
        relatedSpotIds:[],mediaSha256:p.sha256,createdAt:now,updatedAt:now});
    });
  });
  const saved=await db.getAll(...refs);
  check(saved.every((s,i)=>s.exists && s.data().caption===data.posts[i].caption && s.data().imageUrl===media[i].url && s.data().visibility==='public' && s.data().userName==='TBT'),'Publication verification failed');
  const after=await db.getAll(userRef,nameRef);
  check(after[0].updateTime.isEqual(before[0].updateTime) && after[1].updateTime.isEqual(before[1].updateTime),'Publisher profile changed concurrently; inspect');
  const summary={published:saved.length,newPosts:before.slice(2).filter(s=>!s.exists).length,publisher:uid,displayName:'TBT',profilePreserved:true,mediaVerified:media.length,postIds:saved.map(s=>s.id)};
  console.log(JSON.stringify(summary));
  await fs.writeFile('promotion-publication-result.json',JSON.stringify(summary,null,2));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
