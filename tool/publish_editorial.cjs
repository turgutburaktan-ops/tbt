'use strict';
// Publishes only the five reviewed TBT Rehber drafts. No client access or rule changes.
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const root = path.resolve(__dirname, '..');
const requireFunctions = createRequire(path.join(root, 'functions/package.json'));
const uid = 'tbt-editorial-rehber';
const username = 'tbt.rehber';
const project = 'en-iyi-cekim-noktasi';
const bucketName = `${project}.firebasestorage.app`;
function check(ok, text) { if (!ok) throw new Error(text); }
async function main() {
  const data = JSON.parse(await fs.readFile(path.join(__dirname, 'editorial/elazig-first-five.json'), 'utf8'));
  check(data.posts.length === 5 && new Set(data.posts.map(p=>p.id)).size === 5, 'Expected exactly five unique drafts');
  for (const p of data.posts) {
    check(/^tbt-rehber-elazig-0[1-5]$/.test(p.id) && p.status === 'draft', 'Unexpected draft');
    check(p.caption && p.title && data.media[p.photo] && p.spotIds.length, 'Incomplete draft');
  }
  const buffers = [];
  for (const m of data.media) {
    check(m.author && m.licenseUrl && m.sourcePage && (/^[a-f0-9]{64}$/.test(m.sha256 || '') || /^[a-f0-9]{40}$/.test(m.sha1 || '')), 'Missing attribution or checksum');
    let bytes;
    if (m.src.startsWith('https://')) {
      check(new URL(m.src).hostname === 'upload.wikimedia.org', 'Unexpected media host');
      const res = await fetch(m.src, {signal: AbortSignal.timeout(60000)});
      check(res.ok, `Media download failed: ${res.status}`);
      bytes = Buffer.from(await res.arrayBuffer());
    } else {
      check(m.src.startsWith('assets/spots/') && !m.src.includes('..'), 'Invalid media path');
      bytes = await fs.readFile(path.join(root, m.src));
    }
    check(bytes.length > 1000 && bytes.length < 20 * 1024 * 1024, 'Invalid media size');
    check(crypto.createHash(m.sha256 ? 'sha256' : 'sha1').update(bytes).digest('hex') === (m.sha256 || m.sha1), `Reviewed image checksum mismatch: ${m.src}`);
    buffers.push(bytes);
  }
  console.log('Validated five drafts and three reviewed images.');
  if (process.argv.includes('--validate')) return;
  check(process.argv.includes('--publish'), 'Use --validate or --publish');
  const admin = requireFunctions('firebase-admin');
  const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  check(sa.project_id === project, 'Wrong Firebase project');
  admin.initializeApp({credential: admin.credential.cert(sa), projectId: project, storageBucket: bucketName});
  const db=admin.firestore(), bucket=admin.storage().bucket();
  const userRef=db.collection('users').doc(uid), nameRef=db.collection('usernames').doc(username);
  const refs=data.posts.map(p=>db.collection('posts').doc(p.id));
  function guard(snaps) {
    const [u,n,...ps]=snaps;
    check(!u.exists || u.data().editorialBatch === data.batch, 'Publisher profile collision');
    check(!n.exists || n.data().uid === uid, 'Username is already owned');
    ps.forEach(p=>check(!p.exists || (p.data().editorialBatch === data.batch && p.data().userId === uid), 'Post ID collision'));
  }
  guard(await db.getAll(userRef,nameRef,...refs));
  const timestamp=admin.firestore.FieldValue.serverTimestamp();
  async function upload(bytes, key, contentType) {
    const file=bucket.file(`editorial/${data.batch}/${key}`);
    let metadata;
    try { [metadata]=await file.getMetadata(); } catch(e) { if(Number(e.code)!==404) throw e; }
    const digest=crypto.createHash('sha256').update(bytes).digest('hex');
    if(metadata) check(metadata.metadata?.sha256 === digest, 'Storage object collision');
    else {
      const token=crypto.randomUUID();
      await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType,cacheControl:'public,max-age=31536000,immutable',metadata:{firebaseStorageDownloadTokens:token,sha256:digest,editorialBatch:data.batch}}});
      [metadata]=await file.getMetadata();
    }
    const token=metadata.metadata?.firebaseStorageDownloadTokens?.split(',')[0];
    check(token,'Missing image download token');
    return {url:`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(file.name)}?alt=media&token=${token}`,storagePath:file.name};
  }
  const media=[];
  for(let i=0;i<buffers.length;i++) media.push(await upload(buffers[i],`photo-${i}.${data.media[i].contentType === 'image/webp'?'webp':'jpg'}`,data.media[i].contentType));
  const icon=await upload(await fs.readFile(path.join(root,'assets/spot_thumbnails/tbt_app_icon.png')),'avatar.png','image/png');
  for(const m of [...media,icon]) { const r=await fetch(m.url,{method:'HEAD',signal:AbortSignal.timeout(30000)});check(r.ok,'Uploaded media is not readable'); }
  const coords=[[38.703389,39.257389],[38.706111,39.255139],[38.702333,39.250528]];
  await db.runTransaction(async tx=>{
    const snaps=await tx.getAll(userRef,nameRef,...refs);guard(snaps);
    if(!snaps[0].exists) tx.create(userRef,{uid,displayName:'TBT Rehber',name:'TBT Rehber',username,usernameLower:username,photoURL:icon.url,photoUrl:icon.url,bio:'TBT’nin editör hesabı. Gezi rehberleri, mekan önerileri ve rotalar. Bu hesap üzerinden mesaj desteği verilmez.',accountType:'editorial',isEditorial:true,editorialBatch:data.batch,isOnline:false,showOnlineStatus:false,showReadReceipts:false,city:'Elazığ',createdAt:timestamp,updatedAt:timestamp});
    if(!snaps[1].exists) tx.create(nameRef,{uid,username,createdAt:timestamp});
    data.posts.forEach((p,i)=>{
      if(snaps[i+2].exists) return;
      const m=data.media[p.photo], img=media[p.photo], [latitude,longitude]=coords[p.photo];
      const caption=`TBT Rehber · ${p.kind}\n${p.title}\n\n${p.caption}\n\nFotoğraf: ${m.author} — ${m.license}\n${m.sourcePage}\nLisans: ${m.licenseUrl}\n${m.date}. Görsel kadrajı değiştirilmedi; gösterim boyutu küçültüldü.\nBilgi: ${p.source}`;
      tx.create(refs[i],{id:p.id,userId:uid,userName:'TBT Rehber',userPhotoUrl:icon.url,userEmail:'',caption,spotName:p.place,city:'Elazığ',latitude,longitude,taggedUserIds:[],taggedUserNames:[],likesCount:0,commentsCount:0,sourceType:'post',businessVenueKey:'',businessVenueName:'',businessOfficial:false,venueKey:'',mediaType:'image',imageUrl:img.url,storagePath:img.storagePath,videoUrl:'',videoStoragePath:'',thumbnailUrl:img.url,thumbnailStoragePath:img.storagePath,durationMs:0,visibility:'public',status:'published',isEditorial:true,editorialBatch:data.batch,editorialKind:p.kind,relatedSpotIds:p.spotIds,imageAuthor:m.author,imageLicense:m.license,imageSourcePage:m.sourcePage,createdAt:timestamp,updatedAt:timestamp});
    });
  });
  const saved=await db.getAll(...refs);
  check(saved.every(d=>d.exists && d.data().imageUrl && d.data().editorialBatch===data.batch),'Publication verification failed');
  const explore=await db.collection('posts').limit(120).get();
  const shown=new Set(explore.docs.map(d=>d.id));
  const visible=data.posts.filter(p=>shown.has(p.id)).length;
  console.log(JSON.stringify({published:saved.length,visibleInCurrentExploreQuery:visible,publisher:uid,postIds:saved.map(d=>d.id)}));
  check(visible===5,'Published, but some posts fall outside the installed app query; follow-up required');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
