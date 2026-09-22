const admin=require('firebase-admin');
const {spotRow}=require('../catalog/schema');
(async()=>{
 const credential=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
 if(credential.project_id!=='en-iyi-cekim-noktasi')throw Error('Unexpected project');
 admin.initializeApp({credential:admin.credential.cert(credential)});
 const db=admin.firestore();
 for(const city of ['Elazığ','Malatya','Diyarbakır','Tunceli','Bingöl']){
   const docs=await db.collection('photo_spots').where('city','==',city).get();
   let count=0;
   for(const d of docs.docs){
     const data=d.data(),row=spotRow(d.id,data);
     if(!row){console.log('CANDIDATE '+JSON.stringify([city,d.id,data.name,data.latitude,data.longitude,data.status,data.coordinateVerified,data.imageVerified,data.sourceUrl||data.sourcePage||'']));continue;}count++;
     console.log('SPOT '+JSON.stringify([city,d.id,row.name,row.latitude,row.longitude,row.imageUrl||'',data.sourceUrl||data.sourcePage||'',data.district||'']));
   }
   console.log('COUNT '+city+' '+count);
 }
 const official=await db.collection('users').where('username','in',['tbt','tbtrehber','tbt_rehber']).get();
 for(const d of official.docs)console.log('OFFICIAL '+JSON.stringify([d.id,d.data().username,d.data().displayName]));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
