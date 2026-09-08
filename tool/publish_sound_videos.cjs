'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'..');
const uid='tbt-editorial-rehber', project='en-iyi-cekim-noktasi';
const bucketName=`${project}.firebasestorage.app`;
const check=(ok,message)=>{if(!ok)throw Error(message);};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function main(){
 const data=JSON.parse(await fs.readFile(path.join(__dirname,'editorial/sound-videos.json'),'utf8'));
 check(/^city-sound-videos-\d{8}(?:-b\d+)?$/.test(data.batch)&&data.posts.length>=1&&data.posts.length<=6,'Unexpected batch');
 check(new Set(data.posts.map(p=>p.id)).size===data.posts.length,'Duplicate IDs');
 const starter=JSON.parse(await fs.readFile(path.join(__dirname,'editorial/starter-music.json'),'utf8'));
 const musicById=new Map(starter.map(t=>[t.id,t]));
 const dir=await fs.mkdtemp('/tmp/tbt-videos-');
 const prepared=[];
 const musicFiles=new Map();
 async function getMusic(id){
  if(musicFiles.has(id))return musicFiles.get(id);
  const t=musicById.get(id);check(t&&t.license==='CC-BY-4.0'&&new URL(t.downloadUrl).hostname==='incompetech.com','Unreviewed music');
  const f=path.join(dir,id+'.mp3');execFileSync('curl',['-fL','--retry','3','--max-time','120','-sS','-o',f,t.downloadUrl]);
  check(hash(await fs.readFile(f))===t.sha256,'Music checksum mismatch');
  const value={t,f};musicFiles.set(id,value);return value;
 }
 for(const p of data.posts){
  check(/^tbt-rehber-city-sound-\d{2,}$/.test(p.id)&&/^[a-z0-9]+$/.test(p.key),'Unexpected ID');
  const host=new URL(p.src).hostname;
  check((host==='upload.wikimedia.org'||host==='commons.wikimedia.org')&&p.author&&p.licenseUrl&&p.caption,'Unreviewed source');
  const original=path.join(dir,p.key+'-original.webm');
  if(process.env.EDITORIAL_LOCAL_VIDEO_DIR)await fs.copyFile(path.join(process.env.EDITORIAL_LOCAL_VIDEO_DIR,p.key+'.webm'),original);
  else execFileSync('curl',['-fL','--retry','3','--max-time','240','-sS','-o',original,p.src]);
  check(hash(await fs.readFile(original))===p.sha256,'Source checksum mismatch');
  const sourceProbe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_name,codec_type,width,height','-of','json',original],{encoding:'utf8'}));
  const sourceVideo=sourceProbe.streams.find(s=>s.codec_type==='video');check(sourceVideo&&Math.min(sourceVideo.width,sourceVideo.height)>=1080,'Source resolution too low');
  const clipStart=Number(p.clipStartSec||0),clipDuration=Number(p.clipDurationSec||sourceProbe.format.duration);
  check(clipStart>=0&&clipDuration>1&&clipDuration<60&&clipStart+clipDuration<=Number(sourceProbe.format.duration)+0.25,'Invalid clip window');
  const sourceHasAudio=sourceProbe.streams.some(s=>s.codec_type==='audio');
  let music=null;if(p.musicId)music=await getMusic(p.musicId);
  check(sourceHasAudio||music,'Missing sound source');
  const video=path.join(dir,p.key+'.mp4'),thumb=path.join(dir,p.key+'.jpg');
  const args=['-v','error','-ss',String(clipStart),'-i',original];
  if(music)args.push('-ss',String(Number(p.musicStartSec||0)),'-i',music.f);
  args.push('-t',String(clipDuration),'-map','0:v:0','-map',music?'1:a:0':'0:a:0','-c:a','aac','-b:a','192k','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p');
  if(sourceVideo.width>1920)args.push('-vf','scale=1920:-2');
  args.push('-movflags','+faststart',video);
  execFileSync('ffmpeg',args);
  execFileSync('ffmpeg',['-v','error','-ss','1','-i',video,'-frames:v','1','-vf','scale=640:-2',thumb]);
  const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_name,codec_type,width,height','-of','json',video],{encoding:'utf8'}));
  check(probe.streams.some(s=>s.codec_type==='audio'&&s.codec_name==='aac'),'Missing sound');
  check(Math.min(probe.streams[0].width,probe.streams[0].height)>=1080,'Resolution reduced');
  const durationMs=Math.round(Number(probe.format.duration)*1000);
  check(durationMs>1000&&durationMs<60000&&probe.streams[0].codec_name==='h264','Invalid video');
  const bytes=await fs.readFile(video),thumbnail=await fs.readFile(thumb);
  check(bytes.length<100*1024*1024&&thumbnail.length>1000,'Invalid media size');
  prepared.push({p,bytes,thumbnail,durationMs,music});
  console.log(JSON.stringify({prepared:p.id,durationMs,bytes:bytes.length,clipStart,music:p.musicId||'source'}));
 }
 if(process.argv.includes('--validate'))return;
 check(process.argv.includes('--publish'),'Use --validate or --publish');
 const admin=createRequire(path.join(root,'functions/package.json'))('firebase-admin');
 const sa=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}');check(sa.project_id===project,'Wrong project');
 admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName});
 const db=admin.firestore(),bucket=admin.storage().bucket();
 const user=db.collection('users').doc(uid),name=db.collection('usernames').doc('tbt.rehber');
 const refs=data.posts.map(p=>db.collection('posts').doc(p.id));
 function guard(snaps){const [u,n,...posts]=snaps;check(u.exists&&u.data().uid===uid&&u.data().isEditorial===true&&u.data().editorialBatch==='elazig-first-five-20260908','Publisher mismatch');check(n.exists&&n.data().uid===uid,'Username mismatch');posts.forEach(s=>check(!s.exists||(s.data().userId===uid&&s.data().editorialBatch===data.batch),'Post collision'));}
 const before=await db.getAll(user,name,...refs);guard(before);
 async function upload(bytes,key,contentType){const file=bucket.file(`editorial/${data.batch}/${key}`);let meta;try{[meta]=await file.getMetadata();}catch(e){if(Number(e.code)!==404)throw e;}if(meta)check(meta.metadata?.sha256===hash(bytes),'Storage collision');else{await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType,cacheControl:'public,max-age=31536000,immutable',metadata:{sha256:hash(bytes),firebaseStorageDownloadTokens:crypto.randomUUID()}}});[meta]=await file.getMetadata();}const token=meta.metadata?.firebaseStorageDownloadTokens?.split(',')[0];check(token,'Missing token');const url=`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(file.name)}?alt=media&token=${token}`;const response=await fetch(url,{headers:{Range:'bytes=0-1023'},signal:AbortSignal.timeout(30000)});check(response.ok,'Public media unreadable');await response.body?.cancel();return {url,path:file.name};}
 for(const entry of prepared){entry.video=await upload(entry.bytes,entry.p.key+'.mp4','video/mp4');entry.thumb=await upload(entry.thumbnail,entry.p.key+'.jpg','image/jpeg');}
 await db.runTransaction(async tx=>{const snaps=await tx.getAll(user,name,...refs);guard(snaps);const timestamp=admin.firestore.FieldValue.serverTimestamp();prepared.forEach((e,i)=>{if(snaps[i+2].exists)return;const p=e.p;const musicText=e.music?`\nMüzik: ${e.music.t.title} — ${e.music.t.artist}\n${e.music.t.sourceUrl}\nMüzik lisansı: ${e.music.t.license} — ${e.music.t.licenseUrl}`:'';tx.create(refs[i],{id:p.id,userId:uid,userName:'TBT Rehber',userPhotoUrl:snaps[0].data().photoURL,userEmail:'',caption:`${p.title}\n\n${p.caption}\n\nVideo: ${p.author} / Wikimedia Commons\n${p.sourcePage}\nVideo lisansı: ${p.license} — ${p.licenseUrl}${musicText}\nTBT için ${p.clipStartSec||0}. saniyeden ${p.clipDurationSec||Math.round(e.durationMs/1000)} saniyelik bölüm seçilip MP4/H.264 + AAC biçimine dönüştürülmüştür.`,spotName:p.place,city:p.city,latitude:null,longitude:null,taggedUserIds:[],taggedUserNames:[],likesCount:0,commentsCount:0,sourceType:'post',businessVenueKey:'',businessVenueName:'',businessOfficial:false,venueKey:'',mediaType:'video',imageUrl:e.thumb.url,storagePath:'',videoUrl:e.video.url,videoStoragePath:e.video.path,thumbnailUrl:e.thumb.url,thumbnailStoragePath:e.thumb.path,durationMs:e.durationMs,visibility:'public',status:'published',isEditorial:true,editorialBatch:data.batch,editorialKind:'Video',videoAuthor:p.author,videoLicense:p.license,videoSourcePage:p.sourcePage,musicId:p.musicId||'',createdAt:timestamp,updatedAt:timestamp});});});
 const saved=await db.getAll(...refs);check(saved.every(s=>s.exists&&s.data().mediaType==='video'&&s.data().videoUrl),'Publication failed');
 const [explore,reels]=await Promise.all([db.collection('posts').limit(120).get(),db.collection('posts').where('mediaType','==','video').limit(100).get()]);const visible=q=>refs.every(r=>q.docs.some(d=>d.id===r.id));console.log(JSON.stringify({published:saved.length,exploreVisible:visible(explore),reelsVisible:visible(reels),ids:refs.map(r=>r.id)}));check(visible(explore)&&visible(reels),'Published but missing from client query');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
