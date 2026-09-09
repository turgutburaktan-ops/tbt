'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'..'),project='en-iyi-cekim-noktasi',bucketName=`${project}.firebasestorage.app`;
const uid='tbt-editorial-eglence',username='tbt.eglence',id='tbt-eglence-reel-21',batch='tbt-entertainment-20260909-b8';
const src='https://commons.wikimedia.org/wiki/Special:Redirect/file/T%C3%BCrkan_%C5%9Eoray_%26_Ediz_Hun%2C_2014.webm';
const sourcePage='https://commons.wikimedia.org/wiki/File:T%C3%BCrkan_%C5%9Eoray_%26_Ediz_Hun%2C_2014.webm';
const sha='9dd64ec12552321ffa698b5a9ce7363937591d9fe9c3d2bacc3d6410a24dc101';
const check=(x,m)=>{if(!x)throw Error(m)},hash=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{
 const dir=await fs.mkdtemp('/tmp/tbt-women-cinema-'),original=path.join(dir,'source.webm'),video=path.join(dir,'video.mp4'),thumb=path.join(dir,'thumb.jpg');
 execFileSync('curl',['-fL','--retry','3','--max-time','240','-sS','-o',original,src]);
 check(hash(await fs.readFile(original))===sha,'Source checksum mismatch');
 const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_type,width,height','-of','json',original],{encoding:'utf8'}));
 const v=probe.streams.find(s=>s.codec_type==='video'),a=probe.streams.find(s=>s.codec_type==='audio');
 check(v&&a,'Missing source streams'); const duration=Math.min(18,Number(probe.format.duration)); check(duration>5,'Source too short');
 execFileSync('ffmpeg',['-v','error','-i',original,'-t',String(duration),'-map','0:v:0','-map','0:a:0','-vf','scale=-2:1080','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',video]);
 execFileSync('ffmpeg',['-v','error','-ss','1','-i',video,'-frames:v','1','-vf','scale=640:-2',thumb]);
 const bytes=await fs.readFile(video),tb=await fs.readFile(thumb); check(bytes.length<100*1024*1024&&tb.length>1000,'Output invalid');
 const admin=createRequire(path.join(root,'functions/package.json'))('firebase-admin'),sa=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}'); check(sa.project_id===project,'Wrong project');
 admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName}); const db=admin.firestore(),bucket=admin.storage().bucket();
 const user=await db.collection('users').doc(uid).get(); check(user.exists,'Publisher missing'); const ref=db.collection('posts').doc(id),existing=await ref.get();
 async function upload(buf,key,type){const f=bucket.file(`editorial/${batch}/${key}`);let m;try{[m]=await f.getMetadata();}catch(e){if(Number(e.code)!==404)throw e;}if(!m){await f.save(buf,{resumable:false,metadata:{contentType:type,metadata:{sha256:hash(buf),firebaseStorageDownloadTokens:crypto.randomUUID()}}});[m]=await f.getMetadata();}const token=m.metadata.firebaseStorageDownloadTokens.split(',')[0];return {url:`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(f.name)}?alt=media&token=${token}`,path:f.name};}
 const vv=await upload(bytes,'turkansoray.mp4','video/mp4'),tt=await upload(tb,'turkansoray.jpg','image/jpeg');
 if(!existing.exists)await ref.create({id,userId:uid,userName:'TBT Eğlence',userPhotoUrl:user.data().photoURL||'',userEmail:'',caption:`Türkan Şoray’dan nostaljik bir sinema anı 🎬✨\n\n2014’te İstanbul Levent’teki imza gününden kısa bir görüntü. Türk sinemasının unutulmaz isimlerinden Türkan Şoray’ı TBT Eğlence’de daha çok kadın odaklı sinema ve sahne içeriğiyle göreceğiz.\n\nVideo: VikiPicture / Wikimedia Commons\n${sourcePage}\nVideo lisansı: CC BY-SA 4.0 — https://creativecommons.org/licenses/by-sa/4.0/\nKaynak video teknik uyumluluk için 1080p H.264/AAC çıktıya ölçeklenmiştir.`,spotName:'',city:'İstanbul',latitude:null,longitude:null,taggedUserIds:[],taggedUserNames:[],likesCount:0,commentsCount:0,sourceType:'post',mediaType:'video',imageUrl:tt.url,videoUrl:vv.url,videoStoragePath:vv.path,thumbnailUrl:tt.url,thumbnailStoragePath:tt.path,durationMs:Math.round(duration*1000),visibility:'public',status:'published',isEditorial:true,editorialBatch:batch,editorialKind:'EntertainmentVideo',videoAuthor:'VikiPicture',videoLicense:'CC BY-SA 4.0',videoSourcePage:sourcePage,musicId:'',audioMode:'source',createdAt:admin.firestore.FieldValue.serverTimestamp(),updatedAt:admin.firestore.FieldValue.serverTimestamp()});
 const saved=await ref.get(),explore=await db.collection('posts').limit(120).get(),reels=await db.collection('posts').where('mediaType','==','video').limit(100).get();
 const ev=explore.docs.some(d=>d.id===id),rv=reels.docs.some(d=>d.id===id); console.log(JSON.stringify({publisher:username,published:saved.exists?1:0,exploreVisible:ev,reelsVisible:rv,ids:[id]})); check(saved.exists&&ev&&rv,'Visibility check failed');
})().catch(e=>{console.error(e.stack||e.message);process.exitCode=1});
