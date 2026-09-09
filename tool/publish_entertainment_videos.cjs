'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'..');
const uid='tbt-editorial-eglence', username='tbt.eglence', displayName='TBT Eğlence';
const templateUid='tbt-editorial-rehber', project='en-iyi-cekim-noktasi', bucketName=`${project}.firebasestorage.app`;
const check=(ok,m)=>{if(!ok)throw Error(m)};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function main(){
 const data=JSON.parse(await fs.readFile(path.join(__dirname,'editorial/entertainment-videos.json'),'utf8'));
 check(/^tbt-entertainment-\d{8}-b\d+$/.test(data.batch)&&data.posts.length>=1&&data.posts.length<=6,'Unexpected batch');
 check(new Set(data.posts.map(p=>p.id)).size===data.posts.length,'Duplicate IDs');
 const starter=JSON.parse(await fs.readFile(path.join(__dirname,'editorial/starter-music.json'),'utf8'));
 const musicById=new Map(starter.map(t=>[t.id,t]));
 const dir=await fs.mkdtemp('/tmp/tbt-ent-'), prepared=[], musicFiles=new Map();
 async function getMusic(id){if(musicFiles.has(id))return musicFiles.get(id);const t=musicById.get(id);check(t&&t.license==='CC-BY-4.0'&&new URL(t.downloadUrl).hostname==='incompetech.com','Unreviewed music');const f=path.join(dir,id+'.mp3');execFileSync('curl',['-fL','--retry','3','--max-time','120','-sS','-o',f,t.downloadUrl]);check(hash(await fs.readFile(f))===t.sha256,'Music checksum mismatch');const v={t,f};musicFiles.set(id,v);return v;}
 for(const p of data.posts){
  check(/^tbt-eglence-reel-\d{2,}$/.test(p.id)&&/^[a-z0-9]+$/.test(p.key),'Unexpected ID');
  check(['commons.wikimedia.org','upload.wikimedia.org'].includes(new URL(p.src).hostname)&&p.author&&p.licenseUrl&&p.caption,'Unreviewed source');
  const original=path.join(dir,p.key+'-original.webm');execFileSync('curl',['-fL','--retry','3','--max-time','240','-sS','-o',original,p.src]);
  check(hash(await fs.readFile(original))===p.sha256,'Source checksum mismatch');
  const sourceProbe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_name,codec_type,width,height','-of','json',original],{encoding:'utf8'}));
  const sourceVideo=sourceProbe.streams.find(s=>s.codec_type==='video');check(sourceVideo&&Math.min(sourceVideo.width,sourceVideo.height)>=1080,'Source resolution too low');
  const start=Number(p.clipStartSec||0),duration=Number(p.clipDurationSec||20);check(start>=0&&duration>5&&duration<60&&start+duration<=Number(sourceProbe.format.duration)+0.25,'Invalid clip window');
  const music=await getMusic(p.musicId),video=path.join(dir,p.key+'.mp4'),thumb=path.join(dir,p.key+'.jpg');
  const args=['-v','error','-ss',String(start),'-i',original,'-ss',String(Number(p.musicStartSec||0)),'-i',music.f,'-t',String(duration),'-map','0:v:0','-map','1:a:0','-c:a','aac','-b:a','192k','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p'];
  if(sourceVideo.width>1920)args.push('-vf','scale=1920:-2');args.push('-movflags','+faststart',video);execFileSync('ffmpeg',args);
  execFileSync('ffmpeg',['-v','error','-ss','1','-i',video,'-frames:v','1','-vf','scale=640:-2',thumb]);
  const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_name,codec_type,width,height','-of','json',video],{encoding:'utf8'}));
  check(probe.streams.some(s=>s.codec_type==='audio'&&s.codec_name==='aac'),'Missing AAC');check(probe.streams.some(s=>s.codec_type==='video'&&s.codec_name==='h264'),'Missing H264');
  const bytes=await fs.readFile(video),thumbnail=await fs.readFile(thumb),durationMs=Math.round(Number(probe.format.duration)*1000);check(bytes.length<100*1024*1024&&thumbnail.length>1000,'Invalid media size');
  prepared.push({p,bytes,thumbnail,durationMs,music});console.log(JSON.stringify({prepared:p.id,durationMs,bytes:bytes.length,clipStart:start,music:p.musicId}));
 }
 if(process.argv.includes('--validate'))return;check(process.argv.includes('--publish'),'Use --validate or --publish');
 const admin=createRequire(path.join(root,'functions/package.json'))('firebase-admin'),sa=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}');check(sa.project_id===project,'Wrong project');
 admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName});const db=admin.firestore(),bucket=admin.storage().bucket();
 const user=db.collection('users').doc(uid),nameRef=db.collection('usernames').doc(username),template=db.collection('users').doc(templateUid),refs=data.posts.map(p=>db.collection('posts').doc(p.id));
 const [templateSnap,userSnap,nameSnap,...postSnaps]=await db.getAll(template,user,nameRef,...refs);check(templateSnap.exists&&templateSnap.data().isEditorial===true,'Editorial template missing');
 if(userSnap.exists)check(userSnap.data().uid===uid&&userSnap.data().isEditorial===true,'Publisher mismatch');if(nameSnap.exists)check(nameSnap.data().uid===uid,'Username collision');postSnaps.forEach(s=>check(!s.exists||(s.data().userId===uid&&s.data().editorialBatch===data.batch),'Post collision'));
 const now=admin.firestore.FieldValue.serverTimestamp();if(!userSnap.exists||!nameSnap.exists){const batch=db.batch();if(!userSnap.exists){const t=templateSnap.data();batch.create(user,{uid,userName:displayName,displayName,username,usernameLower:username,handle:username,email:'',photoURL:t.photoURL||t.userPhotoUrl||'',bio:'TBT’nin eğlenceli ve şaşırtıcı Reels seçkisi.',isEditorial:true,editorialBatch:'tbt-eglence-20260909',createdAt:now,updatedAt:now});}if(!nameSnap.exists)batch.create(nameRef,{uid});await batch.commit();}
 async function upload(bytes,key,type){const file=bucket.file(`editorial/${data.batch}/${key}`);let meta;try{[meta]=await file.getMetadata();}catch(e){if(Number(e.code)!==404)throw e;}if(meta)check(meta.metadata?.sha256===hash(bytes),'Storage collision');else{await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:type,cacheControl:'public,max-age=31536000,immutable',metadata:{sha256:hash(bytes),firebaseStorageDownloadTokens:crypto.randomUUID()}}});[meta]=await file.getMetadata();}const token=meta.metadata?.firebaseStorageDownloadTokens?.split(',')[0];check(token,'Missing token');return {url:`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(file.name)}?alt=media&token=${token}`,path:file.name};}
 for(const e of prepared){e.video=await upload(e.bytes,e.p.key+'.mp4','video/mp4');e.thumb=await upload(e.thumbnail,e.p.key+'.jpg','image/jpeg');}
 await db.runTransaction(async tx=>{const snaps=await tx.getAll(user,nameRef,...refs);check(snaps[0].exists&&snaps[0].data().uid===uid&&snaps[1].exists&&snaps[1].data().uid===uid,'Entertainment publisher unavailable');prepared.forEach((e,i)=>{if(snaps[i+2].exists)return;const p=e.p,m=e.music.t;tx.create(refs[i],{id:p.id,userId:uid,userName:displayName,userPhotoUrl:snaps[0].data().photoURL||'',userEmail:'',caption:`${p.title}\n\n${p.caption}\n\nVideo: ${p.author} / Wikimedia Commons\n${p.sourcePage}\nVideo lisansı: ${p.license} — ${p.licenseUrl}\nMüzik: ${m.title} — ${m.artist}\n${m.sourceUrl}\nMüzik lisansı: ${m.license} — ${m.licenseUrl}\nTBT Eğlence için ${p.clipStartSec}. saniyeden ${p.clipDurationSec} saniyelik bölüm seçilip kaynak ses kaldırılarak MP4/H.264 + AAC biçimine dönüştürülmüştür.`,spotName:'',city:'',latitude:null,longitude:null,taggedUserIds:[],taggedUserNames:[],likesCount:0,commentsCount:0,sourceType:'post',businessVenueKey:'',businessVenueName:'',businessOfficial:false,venueKey:'',mediaType:'video',imageUrl:e.thumb.url,storagePath:'',videoUrl:e.video.url,videoStoragePath:e.video.path,thumbnailUrl:e.thumb.url,thumbnailStoragePath:e.thumb.path,durationMs:e.durationMs,visibility:'public',status:'published',isEditorial:true,editorialBatch:data.batch,editorialKind:'EntertainmentVideo',videoAuthor:p.author,videoLicense:p.license,videoSourcePage:p.sourcePage,musicId:p.musicId,createdAt:now,updatedAt:now});});});
 const saved=await db.getAll(...refs);check(saved.every(s=>s.exists&&s.data().userId===uid&&s.data().mediaType==='video'),'Publication failed');const [explore,reels]=await Promise.all([db.collection('posts').limit(120).get(),db.collection('posts').where('mediaType','==','video').limit(100).get()]);const visible=q=>refs.every(r=>q.docs.some(d=>d.id===r.id));console.log(JSON.stringify({publisher:username,published:saved.length,exploreVisible:visible(explore),reelsVisible:visible(reels),ids:refs.map(r=>r.id)}));check(visible(explore)&&visible(reels),'Published but missing from client query');
}
main().catch(e=>{console.error(e.stack||e.message);process.exitCode=1});
