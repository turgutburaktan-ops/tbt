'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync,spawnSync}=require('node:child_process');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'..');
const uid='tbt-editorial-rehber', project='en-iyi-cekim-noktasi';
const bucketName=`${project}.firebasestorage.app`;
const check=(ok,message)=>{if(!ok)throw Error(message);};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function main(){
 const data=JSON.parse(await fs.readFile(path.join(__dirname,'editorial/original-sound-20260910.json'),'utf8'));
 check(data.batch==='original-sound-20260910'&&data.posts.length===2,'Unexpected batch');
 check(new Set(data.posts.map(p=>p.id)).size===2,'Duplicate IDs');
 const dir=await fs.mkdtemp('/tmp/tbt-videos-');
 const prepared=[];
 for(const p of data.posts){
  check(/^tbt-rehber-originalsound-20260910-0[1-2]$/.test(p.id)&&/^[a-z]+$/.test(p.key),'Unexpected ID');
  check(new URL(p.src).hostname==='upload.wikimedia.org'&&new URL(p.sourcePage).hostname==='commons.wikimedia.org'&&p.author&&p.licenseUrl==='https://creativecommons.org/licenses/by-sa/4.0/'&&p.caption&&['İstanbul','Ankara'].includes(p.city),'Unreviewed source');
  const original=path.join(dir,p.key+'-original.mp4');
  if(process.env.EDITORIAL_LOCAL_VIDEO_DIR)await fs.copyFile(path.join(process.env.EDITORIAL_LOCAL_VIDEO_DIR,p.key+'.mp4'),original);
  else execFileSync('curl',['-fL','--retry','3','--retry-delay','15','--max-time','120','-sS','-o',original,p.src]);
  check(hash(await fs.readFile(original))===p.sha256,'Source checksum mismatch');
  const video=path.join(dir,p.key+'.mp4'),thumb=path.join(dir,p.key+'.jpg');
  execFileSync('ffmpeg',['-v','error','-i',original,'-map','0:v:0','-map','0:a:0','-c:a','aac','-b:a','192k','-r','30','-c:v','libx264','-preset','fast','-crf','22','-maxrate','6M','-bufsize','12M','-pix_fmt','yuv420p','-movflags','+faststart',video]);
  execFileSync('ffmpeg',['-v','error','-ss','1','-i',video,'-frames:v','1','-vf','scale=640:-2',thumb]);
  const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_name,codec_type,width,height','-of','json',video],{encoding:'utf8'}));
  const durationMs=Math.round(Number(probe.format.duration)*1000);
  check(durationMs>1000&&durationMs<60000&&probe.streams[0].codec_name==='h264','Invalid video');
  check(probe.streams.some(s=>s.codec_type==='audio'&&s.codec_name==='aac'),'Missing original audio');
  const level=spawnSync('ffmpeg',['-hide_banner','-i',video,'-vn','-af','volumedetect','-f','null','-'],{encoding:'utf8'});
  const mean=level.stderr.match(/mean_volume: ([-0-9.]+) dB/);
  check(level.status===0&&mean&&Number(mean[1])>-65,'Silent or invalid audio');
  const bytes=await fs.readFile(video),thumbnail=await fs.readFile(thumb);
  check(bytes.length<15*1024*1024&&thumbnail.length>1000,'Invalid media size');
  prepared.push({p,bytes,thumbnail,durationMs});
  console.log(JSON.stringify({prepared:p.id,durationMs,bytes:bytes.length,audioMeanDb:Number(mean[1]),reviewFile:video}));
 }
 if(process.argv.includes('--validate'))return;
 check(process.argv.includes('--publish'),'Use --validate or --publish');
 const admin=createRequire(path.join(root,'functions/package.json'))('firebase-admin');
 const sa=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}');check(sa.project_id===project,'Wrong project');
 admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName});
 const db=admin.firestore(),bucket=admin.storage().bucket();
 const user=db.collection('users').doc(uid),name=db.collection('usernames').doc('tbt.rehber');
 const refs=data.posts.map(p=>db.collection('posts').doc(p.id));
 function guard(snaps){
  const [u,n,...posts]=snaps;
  check(u.exists&&u.data().uid===uid&&u.data().isEditorial===true&&u.data().editorialBatch==='elazig-first-five-20260908','Publisher mismatch');
  check(n.exists&&n.data().uid===uid,'Username mismatch');
  posts.forEach((s,i)=>check(!s.exists||(s.data().userId===uid&&s.data().editorialBatch===data.batch&&s.data().videoSourceSha256===data.posts[i].sha256),'Post collision'));
 }
 const before=await db.getAll(user,name,...refs);guard(before);
 const existing=await db.collection('posts').where('userId','==',uid).get();
 const previous=existing.docs.filter(d=>!refs.some(r=>r.id===d.id));
 check(previous.every(d=>!data.posts.some(p=>p.sourcePage===d.data().videoSourcePage)), 'Video already published under another ID');
 async function upload(bytes,key,contentType){
  const file=bucket.file(`editorial/${data.batch}/${key}`);let meta;
  try{[meta]=await file.getMetadata();}catch(e){if(Number(e.code)!==404)throw e;}
  if(meta)check(meta.metadata?.sha256===hash(bytes),'Storage collision');
  else{await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType,cacheControl:'public,max-age=31536000,immutable',metadata:{sha256:hash(bytes),firebaseStorageDownloadTokens:crypto.randomUUID()}}});[meta]=await file.getMetadata();}
  const token=meta.metadata?.firebaseStorageDownloadTokens?.split(',')[0];check(token,'Missing token');
  const url=`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(file.name)}?alt=media&token=${token}`;
  const response=await fetch(url,{headers:{Range:'bytes=0-1023'},signal:AbortSignal.timeout(30000)});check(response.ok,'Public media unreadable');await response.body?.cancel();
  return {url,path:file.name};
 }
 for(const entry of prepared){entry.video=await upload(entry.bytes,entry.p.key+'.mp4','video/mp4');entry.thumb=await upload(entry.thumbnail,entry.p.key+'.jpg','image/jpeg');}
 await db.runTransaction(async tx=>{
  const snaps=await tx.getAll(user,name,...refs);guard(snaps);
  const timestamp=admin.firestore.FieldValue.serverTimestamp();
  prepared.forEach((e,i)=>{
   if(snaps[i+2].exists)return;
   const p=e.p;
   tx.create(refs[i],{id:p.id,userId:uid,userName:'TBT Rehber',userPhotoUrl:snaps[0].data().photoURL,userEmail:'',caption:`${p.title}\n\n${p.caption}\n\nVideo: ${p.author} / Wikimedia Commons\n${p.sourcePage}\nLisans: CC BY-SA 4.0 — ${p.licenseUrl}\nÇekim: ${p.recordedDate}. Arşiv görüntüsüdür.\nOrijinal ses korunarak MP4/AAC biçimine dönüştürülmüştür. Bu sürüm de CC BY-SA 4.0 lisansıyla paylaşılmıştır.`,spotName:p.place,city:p.city,latitude:null,longitude:null,taggedUserIds:[],taggedUserNames:[],likesCount:0,commentsCount:0,sourceType:'post',businessVenueKey:'',businessVenueName:'',businessOfficial:false,venueKey:'',mediaType:'video',imageUrl:e.thumb.url,storagePath:'',videoUrl:e.video.url,videoStoragePath:e.video.path,thumbnailUrl:e.thumb.url,thumbnailStoragePath:e.thumb.path,durationMs:e.durationMs,visibility:'public',status:'published',isEditorial:true,editorialBatch:data.batch,editorialKind:'Video',hasAudio:true,audioSource:'original',videoAuthor:p.author,videoLicense:p.license,videoSourcePage:p.sourcePage,videoLicenseUrl:p.licenseUrl,videoSourceSha256:p.sha256,createdAt:timestamp,updatedAt:timestamp});
  });
 });
 const saved=await db.getAll(...refs);
 check(saved.every(s=>s.exists&&s.data().mediaType==='video'&&s.data().videoUrl&&s.data().hasAudio&&s.data().audioSource==='original'),'Publication failed');
 const [explore,reels,feed]=await Promise.all([db.collection('posts').limit(120).get(),db.collection('posts').where('mediaType','==','video').limit(100).get(),db.collection('posts').orderBy('createdAt','desc').limit(120).get()]);
 const visible=q=>refs.every(r=>q.docs.some(d=>d.id===r.id));
 const preserved=previous.length?await db.getAll(...previous.map(d=>d.ref)):[];
 check(preserved.every((s,i)=>s.updateTime.isEqual(previous[i].updateTime)), 'Previous editorial posts changed');
 console.log(JSON.stringify({published:saved.length,newlyCreated:before.slice(2).filter(s=>!s.exists).length,previousPostsPreserved:preserved.length,mediaReadable:true,audioVerified:true,feedVisible:visible(feed),exploreVisible:visible(explore),reelsVisible:visible(reels),ids:refs.map(r=>r.id)}));
 check(visible(explore)&&visible(reels)&&visible(feed),'Published but missing from client query');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
