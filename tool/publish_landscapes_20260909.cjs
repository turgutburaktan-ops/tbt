'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const root = path.resolve(__dirname, '..');
const req = createRequire(path.join(root, 'functions/package.json'));
const project = 'en-iyi-cekim-noktasi', uid = 'tbt-editorial-rehber';
const bucketName = project + '.firebasestorage.app';
const batch = 'landscapes-20260909';
const check = (ok, msg) => { if (!ok) throw new Error(msg); };
async function get(url, method = 'GET') {
  for (let n = 0; n < 4; n++) {
    const r = await fetch(url, {method, signal: AbortSignal.timeout(60000)});
    if (r.ok) return r;
    if (![429,500,502,503,504].includes(r.status) || n === 3) throw new Error('HTTP ' + r.status + ' on media request');
    const delay = Math.max(15 * (n + 1), Number(r.headers.get('retry-after') || 0));
    console.log('Media source busy; waiting '+delay+' seconds.');
    check(delay <= 60, 'Provider requests longer pause; retry later');
    await r.body?.cancel();
    await new Promise(resolve => setTimeout(resolve, delay * 1000));
  }
}
async function main() {
  const prepare = process.argv.includes('--prepare');
  const publish = process.argv.includes('--publish');
  check(prepare !== publish, 'Choose --prepare or --publish');
  const data = JSON.parse(await fs.readFile(path.join(__dirname, 'editorial/landscapes-20260909.json'), 'utf8'));
  check(data.batch === batch && data.posts.length === 4 && data.media.length === 4, 'Unexpected batch');
  check(new Set(data.posts.map(p=>p.id)).size === 4, 'Duplicate IDs');
  const buffers = [];
  for (const [i,m] of data.media.entries()) {
    check(new URL(m.src).hostname === 'upload.wikimedia.org' && new URL(m.sourcePage).hostname === 'commons.wikimedia.org', 'Invalid source');
    check(m.author && m.license && /^https:\/\/creativecommons.org\/licenses\/by(-sa)?\/[34]\.0\/$/.test(m.licenseUrl), 'Missing free license');
    check(prepare || /^[a-f0-9]{64}$/.test(m.sha256 || ''), 'Missing reviewed checksum');
    const bytes = Buffer.from(await (await get(m.src)).arrayBuffer());
    check(bytes.length > 100000 && bytes.length < 15*1024*1024 && bytes[0]===255 && bytes[1]===216, 'Invalid JPEG');
    const digest = crypto.createHash('sha256').update(bytes).digest('hex');
    check(!m.sha256 || digest === m.sha256, 'Reviewed image changed');
    console.log(JSON.stringify({image:i,sha256:digest,bytes:bytes.length}));
    buffers.push(bytes);
  }
  data.posts.forEach((p,i)=>check(p.id === 'tbt-rehber-landscape-20260909-0'+(i+1) && p.photo === i && p.status === 'draft' && p.caption && p.city, 'Invalid post'));
  if (prepare) { console.log('Four licensed landscape photos prepared; no Firebase writes.'); return; }
  const admin = req('firebase-admin');
  const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  check(sa.project_id === project, 'Wrong Firebase project');
  admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName});
  const db=admin.firestore(), bucket=admin.storage().bucket();
  const userRef=db.collection('users').doc(uid), nameRef=db.collection('usernames').doc('tbt.rehber');
  const refs=data.posts.map(p=>db.collection('posts').doc(p.id));
  function guard(snaps) {
    const [u,n,...posts]=snaps;
    check(u.exists && u.data().uid===uid && u.data().isEditorial===true && n.exists && n.data().uid===uid,'Publisher mismatch');
    posts.forEach((s,i)=>check(!s.exists || (s.data().userId===uid && s.data().editorialBatch===batch && s.data().imageSha256===data.media[i].sha256),'Post collision'));
  }
  const before=await db.getAll(userRef,nameRef,...refs); guard(before);
  const avatar=before[0].data().photoURL || before[0].data().photoUrl;
  check(avatar, 'Missing existing publisher avatar');
  const existing=await db.collection('posts').where('userId','==',uid).get();
  for (const p of existing.docs) {
    if (refs.some(r=>r.id===p.id)) continue;
    check(!data.media.some(m=>m.sourcePage===p.data().imageSourcePage),'Photo already published under another ID');
  }
  const media=[];
  for(const [i,bytes] of buffers.entries()) {
    const file=bucket.file('editorial/'+batch+'/photo-'+i+'.jpg');
    let metadata;
    try { [metadata]=await file.getMetadata(); } catch(e) { if(Number(e.code)!==404) throw e; }
    if(metadata) check(metadata.metadata?.sha256===data.media[i].sha256,'Storage collision');
    else {
      await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:'image/jpeg',cacheControl:'public,max-age=31536000,immutable',metadata:{firebaseStorageDownloadTokens:crypto.randomUUID(),sha256:data.media[i].sha256,editorialBatch:batch}}});
      [metadata]=await file.getMetadata();
    }
    const token=metadata.metadata?.firebaseStorageDownloadTokens?.split(',')[0];
    check(token,'Missing media token');
    const url='https://firebasestorage.googleapis.com/v0/b/'+bucketName+'/o/'+encodeURIComponent(file.name)+'?alt=media&token='+token;
    await get(url,'HEAD'); media.push({url,storagePath:file.name});
  }
  const timestamp=admin.firestore.FieldValue.serverTimestamp();
  let created=0;
  await db.runTransaction(async tx=>{
    const snaps=await tx.getAll(userRef,nameRef,...refs);guard(snaps);created=0;
    data.posts.forEach((p,i)=>{
      if(snaps[i+2].exists) return;
      const m=data.media[i], img=media[i];
      const caption=p.title+'\n\n'+p.caption+'\n\nFotoğraf: '+m.author+' — '+m.license+'\nKaynak: '+m.sourcePage+'\nLisans: '+m.licenseUrl+'\nÇekim: '+m.date+'. Arşiv fotoğrafıdır. Kaynak dosya TBT tarafından değiştirilmeden paylaşılmıştır.';
      tx.create(refs[i],{id:p.id,userId:uid,userName:'TBT Rehber',userPhotoUrl:avatar,userEmail:'',caption,spotName:p.place,city:p.city,latitude:null,longitude:null,taggedUserIds:[],taggedUserNames:[],likesCount:0,commentsCount:0,sourceType:'post',businessVenueKey:'',businessVenueName:'',businessOfficial:false,venueKey:'',mediaType:'image',imageUrl:img.url,storagePath:img.storagePath,videoUrl:'',videoStoragePath:'',thumbnailUrl:img.url,thumbnailStoragePath:img.storagePath,durationMs:0,visibility:'public',status:'published',isEditorial:true,editorialBatch:batch,editorialKind:p.kind,relatedSpotIds:[],imageAuthor:m.author,imageLicense:m.license,imageLicenseUrl:m.licenseUrl,imageSourcePage:m.sourcePage,imageSha256:m.sha256,imageWidth:m.width,imageHeight:m.height,createdAt:timestamp,updatedAt:timestamp});
      created++;
    });
  });
  const saved=await db.getAll(...refs);
  check(saved.every((s,i)=>s.exists && s.data().imageSha256===data.media[i].sha256 && s.data().visibility==='public'),'Publication verification failed');
  const feed=await db.collection('posts').orderBy('createdAt','desc').limit(120).get();
  const explore=await db.collection('posts').limit(120).get();
  const feedIds=new Set(feed.docs.map(d=>d.id)), exploreIds=new Set(explore.docs.map(d=>d.id));
  const previousIds=existing.docs.filter(d=>!refs.some(r=>r.id===d.id));
  const after=previousIds.length ? await db.getAll(...previousIds.map(s=>s.ref)) : [];
  check(after.every((s,i)=>s.updateTime.isEqual(previousIds[i].updateTime)), 'A previous editorial post changed during publication');
  const result={published:saved.length,newlyCreated:created,publisher:uid,postIds:saved.map(s=>s.id),feedVisible:saved.every(s=>feedIds.has(s.id)),legacyExploreVisible:saved.every(s=>exploreIds.has(s.id)),previousPostsPreserved:after.length,mediaReadable:true};
  console.log(JSON.stringify(result));
  check(result.feedVisible,'Posts not visible in current feed');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
