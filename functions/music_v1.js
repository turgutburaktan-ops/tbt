const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated, onDocumentDeleted, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const fs = require('node:fs/promises'), path = require('node:path'), os = require('node:os');
const {promisify} = require('node:util');
const exec = promisify(require('node:child_process').execFile);
const {randomUUID} = require('node:crypto');
const BUCKET = 'en-iyi-cekim-noktasi.firebasestorage.app';
const options = {region:'us-central1',memory:'1GiB',timeoutSeconds:300,maxInstances:3,concurrency:1};
function check(ok, message) { if (!ok) throw new HttpsError('failed-precondition', message); }
function cleanId(value) { check(typeof value==='string' && /^[A-Za-z0-9_-]{1,180}$/.test(value),'Geçersiz kimlik.'); return value; }
function selection(track, d) {
 check(track && track.active===true && track.commercialUseAllowed===true && track.derivativesAllowed===true && track.catalogDistributionAllowed===true && track.audioStoragePath?.startsWith('music/'), 'Bu ses kullanıma açık değil.');
 const start=Number(d.startMs ?? 0), duration=Number(d.clipDurationMs ?? 15000);
 const volume=Number(d.musicVolume ?? .85), original=Number(d.originalAudioVolume ?? .25);
 check(Number.isInteger(start)&&start>=0&&Number.isInteger(duration)&&duration>=1000&&duration<=60000&&start+duration<=Number(track.durationMs)+100, 'Ses aralığı geçersiz.');
 check(Number.isFinite(volume)&&volume>=0&&volume<=1&&Number.isFinite(original)&&original>=0&&original<=1,'Ses seviyesi geçersiz.');
 return {start,duration,volume,original};
}
async function ffmpeg(args) { return exec(require('ffmpeg-static'), ['-nostdin','-y','-v','error',...args.flatMap(x=>x==='-i'?['-protocol_whitelist','file,pipe','-format_whitelist','mov,mp3,aac,wav,ogg','-i']:[x])], {timeout:240000,maxBuffer:4*1024*1024}); }
async function download(storagePath, destination, max=250*1024*1024) {
 const file=getStorage().bucket(BUCKET).file(storagePath);const [meta]=await file.getMetadata();
 check(Number(meta.size)>0&&Number(meta.size)<=max,'Dosya boyutu uygun değil.');await file.download({destination});
}
async function upload(filePath, storagePath, contentType) {
 const token=randomUUID(), bucket=getStorage().bucket(BUCKET);
 await bucket.upload(filePath,{destination:storagePath,metadata:{contentType,metadata:{firebaseStorageDownloadTokens:token}}});
 return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
}
exports.preparePostMusic = onCall(options, async request => {
 const uid=request.auth?.uid;if(!uid)throw new HttpsError('unauthenticated','Giriş yapmalısın.');
 const d=request.data||{}, postId=cleanId(d.postId), trackId=cleanId(d.trackId), db=getFirestore();
 const ref=db.doc(`music_tracks/${trackId}`), track=(await ref.get()).data(), mix=selection(track,d);
 if(track.sourcePostId){const source=(await db.doc(`posts/${track.sourcePostId}`).get()).data();check(source&&source.originalSoundConsent===true,'Orijinal ses artık kullanılamıyor.');}
 const throttle=db.doc(`music_processing_limits/${uid}`);
 await db.runTransaction(async tx=>{const recent=(await tx.get(throttle)).data();check(!recent||Date.now()-recent.startedAt>30000,'Yeni ses işlemi için 30 saniye bekle.');tx.set(throttle,{startedAt:Date.now()});});
 check(!(await db.doc(`posts/${postId}`).get()).exists,'Paylaşılmış video değiştirilemez.');
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'tbt-music-'));
 try {
  const video=path.join(dir,'video.mp4'), audio=path.join(dir,'audio.m4a'), output=path.join(dir,'mixed.mp4');
  await Promise.all([download(`users/${uid}/posts/${postId}.mp4`,video),download(track.audioStoragePath,audio,40*1024*1024)]);
  const base=['-i',video,'-ss',String(mix.start/1000),'-t',String(mix.duration/1000),'-i',audio];
  // Copy the video stream: attaching music does not resize/re-encode the image.
  const filter=`[1:a]volume=${mix.volume},apad[m];[0:a]volume=${mix.original}[o];[o][m]amix=inputs=2:duration=first:normalize=0[a]`;
  try {await ffmpeg([...base,'-filter_complex',filter,'-map','0:v:0','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k','-t','60','-movflags','+faststart',output]);}
  catch(e) {if(!String(e.stderr||'').includes('matches no streams'))throw e;await ffmpeg([...base,'-filter_complex',`[1:a]volume=${mix.volume},apad[a]`,'-map','0:v:0','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k','-shortest','-t','60','-movflags','+faststart',output]);}
  selection((await ref.get()).data(),d);
  if(track.sourcePostId) check((await db.doc(`posts/${track.sourcePostId}`).get()).data()?.originalSoundConsent===true,'Orijinal ses kaldırıldı.');
  const storagePath=`users/${uid}/posts/${postId}_music.mp4`;
  const url=await upload(output,storagePath,'video/mp4');
  const result={videoUrl:url,videoStoragePath:storagePath,musicTrackId:trackId,musicTitle:track.title,musicArtist:track.artist,musicPreviewUrl:track.audioUrl,musicStartMs:mix.start,musicDurationMs:mix.duration,musicLicense:track.license,musicSourceUrl:track.sourceUrl||'',musicVolume:mix.volume,originalAudioVolume:mix.original};
  await db.doc(`music_renders/${postId}`).set({...result,ownerId:uid,createdAt:FieldValue.serverTimestamp()});
  return result;
 } finally {await fs.rm(dir,{recursive:true,force:true});}
});
exports.registerOriginalPostSound = onDocumentCreated({...options,document:'posts/{postId}'},async event=>{
 const p=event.data?.data();if(!p||p.mediaType!=='video'||p.originalSoundConsent!==true||p.musicTrackId)return;
 const postId=cleanId(event.params.postId), uid=cleanId(p.userId), db=getFirestore(), trackRef=db.doc(`music_tracks/original_${postId}`);
 if((await trackRef.get()).exists)return;
 check(p.videoStoragePath===`users/${uid}/posts/${postId}.mp4`,'Kaynak dosya doğrulanamadı.');
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'tbt-original-'));
 try{
  const input=path.join(dir,'video.mp4'),output=path.join(dir,'audio.m4a');await download(p.videoStoragePath,input);
  let measuredDuration;
  try{const r=await ffmpeg(['-i',input,'-vn','-map','0:a:0','-t','60','-c:a','aac','-b:a','192k','-progress','pipe:1',output]); measuredDuration=Math.min(60000,Math.floor(Math.max(0,...[...r.stdout.matchAll(/out_time_us=(\d+)/g)].map(m=>Number(m[1])/1000))));check(measuredDuration>=1000,'Ses bir saniyeden kısa.');}
  catch(e){if(String(e.stderr||'').includes('matches no streams')){await event.data.ref.update({originalSoundStatus:'no_audio'});return;}throw e;}
  const audioStoragePath=`music/original/${uid}/${postId}.m4a`,audioUrl=await upload(output,audioStoragePath,'audio/mp4');
  const user=(await db.doc(`users/${uid}`).get()).data()||{}, artist='@'+(user.username||user.displayName||uid);
  await db.runTransaction(async tx=>{
   const [source,existing]=await Promise.all([tx.get(event.data.ref),tx.get(trackRef)]);
   if(!source.exists||source.data().originalSoundConsent!==true||existing.exists)return;
   tx.create(trackRef,{provider:'original',ownerId:uid,sourcePostId:postId,title:'Orijinal Ses',artist,artistUserId:uid,audioUrl,audioStoragePath,durationMs:measuredDuration,category:'Orijinal Sesler',mood:'Orijinal Sesler',license:'TBT-ORIGINAL-CONSENT-v1',sourceUrl:'',active:true,commercialUseAllowed:true,derivativesAllowed:true,catalogDistributionAllowed:true,consentVersion:'v1',consentAt:FieldValue.serverTimestamp(),createdAt:FieldValue.serverTimestamp(),usageCount:0});
   tx.update(event.data.ref,{originalSoundTrackId:trackRef.id,originalSoundStatus:'ready'});
  });
 }finally{await fs.rm(dir,{recursive:true,force:true});}
});
exports.countPostSoundUse=onDocumentCreated('posts/{postId}',async event=>{
 const id=event.data?.data()?.musicTrackId;if(!id)return;const db=getFirestore();
 await db.runTransaction(async tx=>{const ref=db.doc(`music_tracks/${cleanId(id)}`),use=db.doc(`music_usage_events/post_${event.params.postId}`);const [track,exists]=await Promise.all([tx.get(ref),tx.get(use)]);if(!track.exists||exists.exists)return;tx.create(use,{trackId:id,createdAt:FieldValue.serverTimestamp()});tx.update(ref,{usageCount:FieldValue.increment(1),lastUsedAt:FieldValue.serverTimestamp()});});
});
exports.revokeDeletedOriginalSound=onDocumentDeleted('posts/{postId}',async event=>{const ref=getFirestore().doc(`music_tracks/original_${event.params.postId}`);if((await ref.get()).exists)await ref.update({active:false,revokedAt:FieldValue.serverTimestamp()});});
exports.removeDisabledSound=onDocumentUpdated('music_tracks/{trackId}',async event=>{
 if(event.data.before.data().active!==true||event.data.after.data().active!==false)return;
 const db=getFirestore(), posts=await db.collection('posts').where('musicTrackId','==',event.params.trackId).get();
 for(let i=0;i<posts.size;i+=200){const batch=db.batch();for(const doc of posts.docs.slice(i,i+200)){const p=doc.data();if(p.originalVideoUrl)batch.update(doc.ref,{videoUrl:p.originalVideoUrl,videoStoragePath:p.originalVideoStoragePath,musicTrackId:'',musicTitle:'',musicRemoved:true});}await batch.commit();}
});
exports._selection=selection;

exports.approveMusicSubmission=onCall(options,async request=>{
 if(request.auth?.token?.admin!==true || String(request.auth?.token?.email||'').toLowerCase()!=='turgutburaktan@gmail.com') throw new HttpsError('permission-denied','Yönetici yetkisi gerekli.');
 const id=cleanId(request.data?.submissionId), db=getFirestore(), ref=db.doc(`music_submissions/${id}`), s=(await ref.get()).data();
 check(s&&s.status==='pending'&&s.commercialUseAllowed===true&&s.derivativesAllowed===true&&s.catalogDistributionAllowed===true&&s.consentVersion==='v1','Başvuru veya kullanım izinleri eksik.');
 check(typeof s.audioStoragePath==='string' && s.audioStoragePath.startsWith(`users/${cleanId(s.submittedBy)}/music_submissions/${id}/audio.`),'Ses dosyasını yeniden yükleyerek başvur.');
 check(typeof s.sourceUrl==='string'&&s.sourceUrl.startsWith('https://'),'Lisans kanıtı gerekli.');
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'tbt-artist-'));
 try{
  const input=path.join(dir,'source'),output=path.join(dir,'audio.m4a');
  await download(s.audioStoragePath,input,20*1024*1024);
  const result=await ffmpeg(['-i',input,'-vn','-map','0:a:0','-t','600','-c:a','aac','-b:a','192k','-progress','pipe:1',output]);
  const times=[...result.stdout.matchAll(/out_time_us=(\d+)/g)].map(m=>Number(m[1])/1000), durationMs=Math.floor(Math.max(0,...times));
  check(durationMs>=1000,'Ses dosyası en az bir saniye olmalı.');
  const audioStoragePath=`music/catalog/${id}.m4a`,audioUrl=await upload(output,audioStoragePath,'audio/mp4');
  await db.runTransaction(async tx=>{
   const latest=await tx.get(ref);check(latest.data()?.status==='pending','Başvuru daha önce incelenmiş.');
   tx.set(db.doc(`music_tracks/${id}`),{provider:'independent',artistUserId:s.submittedBy,title:s.title,artist:s.artist,category:s.category||'Türkçe',mood:s.mood||'Gezi',audioUrl,audioStoragePath,durationMs,sourceUrl:s.sourceUrl,license:s.licenseType,attributionText:s.attributionText||'',active:true,commercialUseAllowed:true,derivativesAllowed:true,catalogDistributionAllowed:true,usageCount:0,verifiedBy:request.auth.uid,verifiedAt:FieldValue.serverTimestamp(),createdAt:FieldValue.serverTimestamp()});
   tx.update(ref,{status:'approved',reviewedBy:request.auth.uid,reviewedAt:FieldValue.serverTimestamp()});
  });return {ok:true};
 }finally{await fs.rm(dir,{recursive:true,force:true});}
});
