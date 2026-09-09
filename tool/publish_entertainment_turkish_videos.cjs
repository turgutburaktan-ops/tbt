'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'..');
const uid='tbt-editorial-eglence',username='tbt.eglence',displayName='TBT Eğlence';
const templateUid='tbt-editorial-rehber',project='en-iyi-cekim-noktasi',bucketName=`${project}.firebasestorage.app`;
const check=(ok,m)=>{if(!ok)throw Error(m)};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function main(){
 const data=JSON.parse(await fs.readFile(path.join(__dirname,'editorial/entertainment-videos.json'),'utf8'));
 check(/^tbt-entertainment-\d{8}-b\d+$/.test(data.batch)&&data.posts.length>=1&&data.posts.length<=6,'Unexpected batch');
 check(new Set(data.posts.map(p=>p.id)).size===data.posts.length,'Duplicate IDs');
 const dir=await fs.mkdtemp('/tmp/tbt-ent-tr-'),prepared=[];
 for(const p of data.posts){
  check(/^tbt-eglence-reel-\d{2,}$/.test(p.id)&&/^[a-z0-9]+$/.test(p.key),'Unexpected ID');
  check(['commons.wikimedia.org','upload.wikimedia.org'].includes(new URL(p.src).hostname)&&p.author&&p.license&&p.licenseUrl&&p.sourcePage&&p.caption,'Unreviewed source');
  const sourceKind=p.sourceKind==='image'?'image':'video';
  const ext=sourceKind==='image'?'.jpg':'.webm';
  const original=path.join(dir,p.key+'-original'+ext);
  execFileSync('curl',['-fL','--retry','3','--max-time','240','-sS','-o',original,p.src]);
  check(hash(await fs.readFile(original))===p.sha256,'Source checksum mismatch');
  const sourceProbe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_name,codec_type,width,height','-of','json',original],{encoding:'utf8'}));
  const sourceVideo=sourceProbe.streams.find(s=>s.codec_type==='video');
  const sourceAudio=sourceProbe.streams.find(s=>s.codec_type==='audio');
  check(sourceVideo&&Math.min(sourceVideo.width,sourceVideo.height)>=1080,'Source resolution too low');
  const video=path.join(dir,p.key+'.mp4'),thumb=path.join(dir,p.key+'.jpg');
  let start=0,duration=Number(p.clipDurationSec||15),audioMode='silent';
  if(sourceKind==='image'){
    check(duration>=10&&duration<=20,'Invalid image reel duration');
    execFileSync('ffmpeg',['-v','error','-loop','1','-i',original,'-f','lavfi','-i','anullsrc=channel_layout=stereo:sample_rate=48000','-t',String(duration),'-filter_complex',"[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,zoompan=z='min(zoom+0.00016,1.06)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=375:s=1080x1920:fps=25,format=yuv420p[v]",'-map','[v]','-map','1:a:0','-c:v','libx264','-preset','medium','-crf','20','-c:a','aac','-b:a','96k','-shortest','-movflags','+faststart',video]);
  } else {
    check(sourceAudio,'Turkish source audio missing');
    start=Number(p.clipStartSec||0);duration=Number(p.clipDurationSec||sourceProbe.format.duration);audioMode='source';
    check(start>=0&&duration>5&&duration<60&&start+duration<=Number(sourceProbe.format.duration)+0.25,'Invalid clip window');
    const args=['-v','error','-ss',String(start),'-i',original,'-t',String(duration),'-map','0:v:0','-map','0:a:0','-c:a','aac','-b:a','192k','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p'];
    if(sourceVideo.width>1920)args.push('-vf','scale=1920:-2');
    args.push('-movflags','+faststart',video);execFileSync('ffmpeg',args);
  }
  execFileSync('ffmpeg',['-v','error','-ss','1','-i',video,'-frames:v','1','-vf','scale=640:-2',thumb]);
  const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_name,codec_type,width,height','-of','json',video],{encoding:'utf8'}));
  const outVideo=probe.streams.find(s=>s.codec_type==='video'),outAudio=probe.streams.find(s=>s.codec_type==='audio');
  check(outVideo&&outVideo.codec_name==='h264'&&Math.min(outVideo.width,outVideo.height)>=1080,'Invalid H264 video');
  check(outAudio&&outAudio.codec_name==='aac','Missing AAC');
  const bytes=await fs.readFile(video),thumbnail=await fs.readFile(thumb),durationMs=Math.round(Number(probe.format.duration)*1000);
  check(bytes.length<100*1024*1024&&thumbnail.length>1000&&durationMs>5000&&durationMs<60000,'Invalid output');
  prepared.push({p,bytes,thumbnail,durationMs,audioMode,sourceKind,start,duration});
  console.log(JSON.stringify({prepared:p.id,durationMs,bytes:bytes.length,sourceKind,audio:audioMode}));
 }
 if(process.argv.includes('--validate'))return;
 check(process.argv.includes('--publish'),'Use --validate or --publish');
 const admin=createRequire(path.join(root,'functions/package.json'))('firebase-admin'),sa=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}');
 check(sa.project_id===project,'Wrong project');
 admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName});
 const db=admin.firestore(),bucket=admin.storage().bucket();
 const user=db.collection('users').doc(uid),nameRef=db.collection('usernames').doc(username),template=db.collection('users').doc(templateUid),refs=data.posts.map(p=>db.collection('posts').doc(p.id));
 const [templateSnap,userSnap,nameSnap,...postSnaps]=await db.getAll(template,user,nameRef,...refs);
 check(templateSnap.exists&&templateSnap.data().isEditorial===true,'Editorial template missing');
 if(userSnap.exists)check(userSnap.data().uid===uid&&userSnap.data().isEditorial===true,'Publisher mismatch');
 if(nameSnap.exists)check(nameSnap.data().uid===uid,'Username collision');
 postSnaps.forEach(s=>check(!s.exists||(s.data().userId===uid&&s.data().editorialBatch===data.batch),'Post collision'));
 const now=admin.firestore.FieldValue.serverTimestamp();
 if(!userSnap.exists||!nameSnap.exists){const batch=db.batch();if(!userSnap.exists){const t=templateSnap.data();batch.create(user,{uid,userName:displayName,displayName,username,usernameLower:username,handle:username,email:'',photoURL:t.photoURL||t.userPhotoUrl||'',bio:'TBT’nin Türkiye’den eğlenceli ve şaşırtıcı Reels seçkisi.',isEditorial:true,editorialBatch:'tbt-eglence-20260909',createdAt:now,updatedAt:now});}if(!nameSnap.exists)batch.create(nameRef,{uid});await batch.commit();}
 async function upload(bytes,key,type){const file=bucket.file(`editorial/${data.batch}/${key}`);let meta;try{[meta]=await file.getMetadata();}catch(e){if(Number(e.code)!==404)throw e;}if(meta)check(meta.metadata?.sha256===hash(bytes),'Storage collision');else{await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:type,cacheControl:'public,max-age=31536000,immutable',metadata:{sha256:hash(bytes),firebaseStorageDownloadTokens:crypto.randomUUID()}}});[meta]=await file.getMetadata();}const token=meta.metadata?.firebaseStorageDownloadTokens?.split(',')[0];check(token,'Missing token');return {url:`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(file.name)}?alt=media&token=${token}`,path:file.name};}
 for(const e of prepared){e.video=await upload(e.bytes,e.p.key+'.mp4','video/mp4');e.thumb=await upload(e.thumbnail,e.p.key+'.jpg','image/jpeg');}
 await db.runTransaction(async tx=>{const snaps=await tx.getAll(user,nameRef,...refs);check(snaps[0].exists&&snaps[0].data().uid===uid&&snaps[1].exists&&snaps[1].data().uid===uid,'Entertainment publisher unavailable');prepared.forEach((e,i)=>{if(snaps[i+2].exists)return;const p=e.p;const sourceLabel=e.sourceKind==='image'?'Görsel':'Video';const transformNote=e.sourceKind==='image'?`TBT Eğlence için ${e.duration} saniyelik dikey hareketli Reels’e dönüştürülmüş, yabancı müzik eklenmemiştir.`:`TBT Eğlence için ${e.start}. saniyeden ${e.duration} saniyelik bölüm seçilmiş, kaynak ortam sesi korunmuştur.`;tx.create(refs[i],{id:p.id,userId:uid,userName:displayName,userPhotoUrl:snaps[0].data().photoURL||'',userEmail:'',caption:`${p.title}\n\n${p.caption}\n\n${sourceLabel}: ${p.author} / Wikimedia Commons\n${p.sourcePage}\n${sourceLabel} lisansı: ${p.license} — ${p.licenseUrl}\n${transformNote}`,spotName:'',city:'',latitude:null,longitude:null,taggedUserIds:[],taggedUserNames:[],likesCount:0,commentsCount:0,sourceType:'post',businessVenueKey:'',businessVenueName:'',businessOfficial:false,venueKey:'',mediaType:'video',imageUrl:e.thumb.url,storagePath:'',videoUrl:e.video.url,videoStoragePath:e.video.path,thumbnailUrl:e.thumb.url,thumbnailStoragePath:e.thumb.path,durationMs:e.durationMs,visibility:'public',status:'published',isEditorial:true,editorialBatch:data.batch,editorialKind:'EntertainmentVideo',videoAuthor:p.author,videoLicense:p.license,videoSourcePage:p.sourcePage,musicId:'',audioMode:e.audioMode,createdAt:now,updatedAt:now});});});
 const saved=await db.getAll(...refs);check(saved.every(s=>s.exists&&s.data().userId===uid&&s.data().mediaType==='video'),'Publication failed');
 const [explore,reels]=await Promise.all([db.collection('posts').limit(120).get(),db.collection('posts').where('mediaType','==','video').limit(100).get()]);
 const visible=q=>refs.every(r=>q.docs.some(d=>d.id===r.id));
 console.log(JSON.stringify({publisher:username,published:saved.length,exploreVisible:visible(explore),reelsVisible:visible(reels),ids:refs.map(r=>r.id)}));
 check(visible(explore)&&visible(reels),'Published but missing from client query');
}
main().catch(e=>{console.error(e.stack||e.message);process.exitCode=1});
