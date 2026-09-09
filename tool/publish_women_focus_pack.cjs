'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'..');
const project='en-iyi-cekim-noktasi',bucketName=`${project}.firebasestorage.app`;
const uid='tbt-editorial-eglence',username='tbt.eglence',displayName='TBT Eğlence';
const batch='tbt-women-focus-20260909-b1';
const sources={
 filiz:{title:'File:Filiz Akın v1.webm',start:1,dur:20,titleText:'Türk sinemasının zarafeti: Filiz Akın 🎬✨',caption:'Filiz Akın’ın yer aldığı gerçek video görüntüsünden kısa bir kesit. Türk sinemasının unutulmaz kadın yıldızlarından biri.'},
 hula:{title:'File:Hula hoop fire dance video Turkey 2015.webm',start:0,dur:14,titleText:'Bitez’de ateş ve hula hoop gösterisi 🔥✨',caption:'Bitez’de genç bir kadın sanatçının ateşli hula hoop performansından kısa bir kesit.'},
 ela:{title:'File:WIKITONGUES- Ela speaking Turkish.webm',start:8,dur:18,titleText:'Türkçe böyle akıyor 🎙️✨',caption:'Ela’nın Türkçe konuştuğu gerçek video kaydından kısa bir bölüm. Dilin doğal ritmini dinlemek ayrı bir keyif.'},
 basket:{title:'File:Fenerbahçe-Samsun Canik Belediyespor (1 Nisan 2018, KBSL).webm'}
};
const posts=[
 {id:'tbt-eglence-reel-22',key:'filizakin',srcKey:'filiz'},
 {id:'tbt-eglence-reel-23',key:'hulagirl',srcKey:'hula'},
 {id:'tbt-eglence-reel-24',key:'elaturkce',srcKey:'ela'},
 {id:'tbt-eglence-reel-25',key:'kadinbasket1',srcKey:'basket',start:300,dur:15,titleText:'Kadın basketbolunda tempo yükseliyor 🏀🔥',caption:'Kadınlar Basketbol Süper Ligi’nden tempolu bir oyun kesiti.'},
 {id:'tbt-eglence-reel-26',key:'elagazeteci',srcKey:'ela',start:30,dur:18,titleText:'Kadın gazetecinin ekran yolculuğu 🎙️✨',caption:'Ela’nın gazetecilik ve televizyon kariyerini anlattığı gerçek video kaydından kısa bir bölüm.'},
 {id:'tbt-eglence-reel-27',key:'elaturkce2',srcKey:'ela',start:55,dur:18,titleText:'Türkçenin görünürlüğü üzerine güzel bir an 💬✨',caption:'Ela’nın Türkçenin farklı diller arasında görünür olmasını anlattığı gerçek video kaydından kısa bir bölüm.'}
];
const check=(x,m)=>{if(!x)throw Error(m)};
const strip=s=>String(s||'').replace(/<[^>]+>/g,'').replace(/&amp;/g,'&').trim();
async function commons(title){
 const u=new URL('https://commons.wikimedia.org/w/api.php');
 for(const [k,v] of Object.entries({action:'query',prop:'imageinfo',iiprop:'url|size|mime|extmetadata',titles:title,format:'json'}))u.searchParams.set(k,v);
 const r=await fetch(u,{headers:{'user-agent':'TBTEditorial/1.0'}});check(r.ok,'Commons metadata failed');
 const j=await r.json(),p=Object.values(j.query.pages)[0],ii=p.imageinfo?.[0];check(ii&&String(ii.mime).startsWith('video/'),'Not a video');
 const md=ii.extmetadata||{},license=strip(md.LicenseShortName?.value),artist=strip(md.Artist?.value),desc=strip(md.ImageDescription?.value);
 check(/CC BY|Creative Commons|Public domain|CC0/i.test(license),'License not approved');
 return {url:ii.url,width:ii.width,height:ii.height,license,artist:artist||'Wikimedia Commons contributor',desc};
}
function probe(file){return JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration:stream=codec_type,codec_name,width,height','-of','json',file],{encoding:'utf8'}));}
async function main(){
 const dir=await fs.mkdtemp('/tmp/tbt-women-'),meta={};
 for(const [k,s] of Object.entries(sources))meta[k]=await commons(s.title);
 const prepared=[];
 for(const p of posts){
   const s=sources[p.srcKey],m=meta[p.srcKey],start=p.start??s.start??0,dur=p.dur??s.dur??15;
   const out=path.join(dir,p.key+'.mp4'),thumb=path.join(dir,p.key+'.jpg');
   const hasKnownSilent=p.srcKey==='hula';
   const vf='scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2';
   let input=m.url;
   if(p.srcKey==='basket') input=String(m.url).split('?')[0];
   if(p.srcKey==='ela'){
     input=path.join(dir,'ela-source.webm');
     try{await fs.access(input);}catch{
       execFileSync('curl',['-fL','--retry','4','--retry-all-errors','--max-time','180','-sS','-o',input,m.url]);
     }
     check((await fs.stat(input)).size>1000000,'Ela source download incomplete');
   }
   let args=['-v','error','-ss',String(start),'-i',input,'-t',String(dur)];
   if(hasKnownSilent){args.push('-f','lavfi','-i','anullsrc=channel_layout=stereo:sample_rate=48000','-map','0:v:0','-map','1:a:0','-shortest');}
   else args.push('-map','0:v:0','-map','0:a:0?');
   args.push('-vf',vf,'-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',out);
   execFileSync('ffmpeg',args,{stdio:'inherit'});
   execFileSync('ffmpeg',['-v','error','-ss','1','-i',out,'-frames:v','1','-vf','scale=640:-2',thumb]);
   const pr=probe(out),v=pr.streams.find(x=>x.codec_type==='video'),a=pr.streams.find(x=>x.codec_type==='audio');
   check(v&&v.codec_name==='h264'&&v.width===1920&&v.height===1080,'Bad video');check(a&&a.codec_name==='aac','Bad audio');
   const bytes=await fs.readFile(out),thumbnail=await fs.readFile(thumb);check(bytes.length<100*1024*1024,'Too large');
   prepared.push({...p,start,dur,m,bytes,thumbnail,durationMs:Math.round(Number(pr.format.duration)*1000),titleText:p.titleText||s.titleText,caption:p.caption||s.caption});
   console.log(JSON.stringify({prepared:p.id,bytes:bytes.length,durationMs:Math.round(Number(pr.format.duration)*1000)}));
 }
 const admin=createRequire(path.join(root,'functions/package.json'))('firebase-admin'),sa=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}');check(sa.project_id===project,'Wrong project');
 admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName});const db=admin.firestore(),bucket=admin.storage().bucket();
 const user=db.collection('users').doc(uid),us=await user.get();check(us.exists&&us.data().isEditorial===true,'Publisher missing');
 async function upload(buf,key,type){const f=bucket.file(`editorial/${batch}/${key}`),token=crypto.randomUUID();await f.save(buf,{resumable:false,metadata:{contentType:type,metadata:{firebaseStorageDownloadTokens:token}}});return {url:`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(f.name)}?alt=media&token=${token}`,path:f.name};}
 const now=admin.firestore.FieldValue.serverTimestamp();
 for(const e of prepared){
   const ref=db.collection('posts').doc(e.id),old=await ref.get();check(!old.exists,'Post collision '+e.id);
   const video=await upload(e.bytes,e.key+'.mp4','video/mp4'),th=await upload(e.thumbnail,e.key+'.jpg','image/jpeg');
   await ref.create({id:e.id,userId:uid,userName:displayName,userPhotoUrl:us.data().photoURL||'',caption:`${e.titleText}\n\n${e.caption}\n\nKaynak: ${e.m.artist} / Wikimedia Commons\n${e.m.license}\n${sources[e.srcKey].title.replace(/^File:/,'')}\nTBT Eğlence için ${e.start}. saniyeden ${e.dur} saniyelik gerçek video bölümü seçilmiştir.`,mediaType:'video',videoUrl:video.url,videoStoragePath:video.path,thumbnailUrl:th.url,thumbnailStoragePath:th.path,imageUrl:th.url,durationMs:e.durationMs,visibility:'public',status:'published',isEditorial:true,editorialBatch:batch,editorialKind:'WomenFocusVideo',audioMode:e.srcKey==='hula'?'silent':'source',likesCount:0,commentsCount:0,sourceType:'post',createdAt:now,updatedAt:now});
 }
 const refs=posts.map(p=>db.collection('posts').doc(p.id));const saved=await db.getAll(...refs);check(saved.every(s=>s.exists),'Save failed');
 const [explore,reels]=await Promise.all([db.collection('posts').limit(150).get(),db.collection('posts').where('mediaType','==','video').limit(150).get()]);const visible=q=>refs.every(r=>q.docs.some(d=>d.id===r.id));
 console.log(JSON.stringify({publisher:username,published:6,exploreVisible:visible(explore),reelsVisible:visible(reels),ids:posts.map(p=>p.id)}));check(visible(explore)&&visible(reels),'Visibility failed');
}
main().catch(e=>{console.error(e.stack||e);process.exitCode=1});
