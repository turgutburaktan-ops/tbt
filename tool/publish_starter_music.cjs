// Small, reviewed CC BY 4.0 catalog. Never import search results automatically.
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
const {createHash,randomUUID}=require('node:crypto');
const req=require('node:module').createRequire(path.resolve(__dirname,'../functions/package.json'));
const {initializeApp,cert}=req('firebase-admin/app'),{getFirestore,FieldValue}=req('firebase-admin/firestore'),{getStorage}=req('firebase-admin/storage');
(async()=>{
 if(!process.argv.includes('--publish'))throw Error('Explicit --publish required');
 const account=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}');
 if(account.project_id!=='en-iyi-cekim-noktasi')throw Error('Wrong Firebase project');
 const bucketName='en-iyi-cekim-noktasi.firebasestorage.app';initializeApp({credential:cert(account),storageBucket:bucketName});
 const db=getFirestore(),bucket=getStorage().bucket();
 const tracks=JSON.parse(await fs.readFile(path.join(__dirname,'editorial/starter-music.json'),'utf8'));
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'tbt-catalog-'));
 try{for(const t of tracks){
  const ref=db.doc(`music_tracks/${t.id}`),existing=await ref.get();
  if(existing.exists){console.log(`${t.id}: already present`);continue;}
  if(t.license!=='CC-BY-4.0'||new URL(t.downloadUrl).hostname!=='incompetech.com')throw Error('Unreviewed source');
  const r=await fetch(t.downloadUrl,{signal:AbortSignal.timeout(60000)});if(!r.ok)throw Error(`Download failed: ${r.status}`);
  const data=Buffer.from(await r.arrayBuffer());if(createHash('sha256').update(data).digest('hex')!==t.sha256)throw Error(`Source changed: ${t.id}`);
  const file=path.join(dir,`${t.id}.mp3`);await fs.writeFile(file,data);
  const audioStoragePath=`music/catalog/${t.id}.mp3`,token=randomUUID();
  await bucket.upload(file,{destination:audioStoragePath,metadata:{contentType:'audio/mpeg',metadata:{firebaseStorageDownloadTokens:token,sourceSha256:t.sha256}}});
  const {downloadUrl,...metadata}=t;
  await ref.create({...metadata,audioStoragePath,audioUrl:`https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(audioStoragePath)}?alt=media&token=${token}`,active:true,commercialUseAllowed:true,derivativesAllowed:true,catalogDistributionAllowed:true,usageCount:0,verifiedSource:'Author catalog pieces.json and author CC BY 4.0 notice, checked 2026-09-08',verifiedAt:FieldValue.serverTimestamp(),createdAt:FieldValue.serverTimestamp()});
  console.log(`${t.id}: published ${t.title}`);
 }
 console.log(`Catalog verified: ${(await Promise.all(tracks.map(t=>db.doc('music_tracks/'+t.id).get()))).filter(x=>x.data()?.active===true).length} active tracks`);
 }finally{await fs.rm(dir,{recursive:true,force:true});}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
