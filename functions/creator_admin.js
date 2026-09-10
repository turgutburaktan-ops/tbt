const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {getFirestore,FieldPath,FieldValue,Timestamp,AggregateField}=require('firebase-admin/firestore');
const {isNamedAdmin}=require('./broadcast_policy');
const fail=(code,message)=>{throw new HttpsError(code,message);};
const id=value=>{if(typeof value!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(value))fail('invalid-argument','Geçersiz kimlik.');return value;};
const ms=value=>value?.toMillis?.()||0;
const active=p=>!!p&&!p.disabled&&!p.banned&&!['frozen','deleted','deleting'].includes(p.accountStatus);
const person=(uid,p={})=>({uid,name:String(p.displayName||p.username||uid),photoUrl:String(p.photoUrl||''),active:active(p),isCreator:p.isCreator===true,tier:p.creatorTier||'creator'});
async function page(query,cursor,limit=25){
  query=query.orderBy(FieldPath.documentId());
  if(cursor)query=query.startAfter(id(cursor));
  const snap=await query.limit(limit+1).get();
  return {docs:snap.docs.slice(0,limit),nextCursor:snap.size>limit?snap.docs[limit-1].id:null};
}
async function metrics(db,uid,post,days){
  const ref=db.doc(`creator_stats/${uid}/content/${post.id}`);
  const metric=days?await ref.collection('daily').where('day','>=',new Date(Date.now()+10800000-(days-1)*86400000).toISOString().slice(0,10)).get():await ref.get();
  const data=days?metric.docs.reduce((a,d)=>({views:a.views+Number(d.data().views||0),profileVisits:a.profileVisits+Number(d.data().profileVisits||0)}),{views:0,profileVisits:0}):metric.data()||{};
  const [likes,comments,saves,reposts,stories]=await Promise.all([
    post.ref.collection('likes').count().get(),post.ref.collection('comments').count().get(),
    db.collection('post_bookmarks').where('postId','==',post.id).count().get(),db.collection('post_reposts').where('postId','==',post.id).count().get(),
    db.collection('stories').where('sharedPostId','==',post.id).where('expiresAt','>',Timestamp.now()).count().get(),
  ]);
  const p=post.data();
  return {id:post.id,title:String(p.routeTitle||p.caption||'Paylaşım').slice(0,150),mediaType:p.mediaType||'image',createdAtMs:ms(p.createdAt),views:Number(data.views||0),profileVisits:Number(data.profileVisits||0),likes:likes.data().count,comments:comments.data().count,saves:saves.data().count,reposts:reposts.data().count,activeStoryShares:stories.data().count};
}
async function creatorAdmin(request,db=getFirestore()){
  if(!request.auth?.uid)fail('unauthenticated','Giriş gerekli.');
  if(!isNamedAdmin(request.auth))fail('permission-denied','Yönetici yetkisi gerekli.');
  const d=request.data||{},action=d.action;
  if(action==='creators'){
    const result=await page(db.collection('creator_invite_redemptions'),d.cursor);
    const rows=await Promise.all(result.docs.map(async doc=>{const u=await db.doc(`users/${doc.id}`).get();return {...person(doc.id,u.data()),code:doc.data().code||'',joinedAtMs:ms(doc.data().createdAt),active:u.exists&&active(u.data())};}));
    return {items:rows,nextCursor:result.nextCursor};
  }
  if(action==='invites'){
    const result=await page(db.collection('creator_invites'),d.cursor);
    return {items:result.docs.map(doc=>{const p=doc.data();return {code:doc.id,label:p.label||'',active:p.active===true,maxUses:p.maxUses||1,usesCount:p.usesCount||0,expiresAtMs:ms(p.expiresAt),createdAtMs:ms(p.createdAt),url:`https://www.trtbt.com/creator/${doc.id}`};}),nextCursor:result.nextCursor};
  }
  if(action==='disableInvite'){
    const code=id(d.code),ref=db.doc(`creator_invites/${code}`);
    await db.runTransaction(async tx=>{const invite=await tx.get(ref);if(!invite.exists)fail('not-found','Davet bulunamadı.');tx.update(ref,{active:false,disabledBy:request.auth.uid,disabledAt:FieldValue.serverTimestamp()});});
    return {ok:true};
  }
  if(action==='redemptions'){
    const result=await page(db.collection('creator_invite_redemptions').where('code','==',id(d.code)),d.cursor);
    return {items:await Promise.all(result.docs.map(async doc=>({...person(doc.id,(await db.doc(`users/${doc.id}`).get()).data()),joinedAtMs:ms(doc.data().createdAt)}))),nextCursor:result.nextCursor};
  }
  const uid=id(d.creatorId),member=await db.doc(`creator_invite_redemptions/${uid}`).get(),profile=await db.doc(`users/${uid}`).get();
  if(!member.exists||!profile.exists)fail('not-found','Creator bulunamadı.');
  if(action==='referrals'){
    const result=await page(db.collection('creator_referrals').where('creatorId','==',uid),d.cursor);
    return {items:await Promise.all(result.docs.map(async doc=>({...person(doc.id,(await db.doc(`users/${doc.id}`).get()).data()),joinedAtMs:ms(doc.data().createdAt)}))),nextCursor:result.nextCursor};
  }
  if(action==='detail'){
    const days=Number(d.days||0);if(![0,7,30,90].includes(days))fail('invalid-argument','Geçersiz tarih aralığı.');
    const result=await page(db.collection('posts').where('userId','==',uid),d.cursor,15);
    const [posts,followers,referrals,daily]=await Promise.all([
      Promise.all(result.docs.map(doc=>metrics(db,uid,doc,days))),
      db.collection('users').doc(uid).collection('followers').count().get(),
      db.collection('creator_referrals').where('creatorId','==',uid).count().get(),
      db.doc(`creator_stats/${uid}`).get(),
    ]);
    // Top ten is ranked across all content, never just the loaded page.
    const topStats=await db.collection(`creator_stats/${uid}/content`).orderBy('views','desc').limit(10).get();
    const top=[];
    for(const stat of topStats.docs){const post=await db.doc(`posts/${stat.id}`).get();if(post.exists&&post.data().userId===uid)top.push({id:stat.id,title:String(post.data().routeTitle||post.data().caption||'Paylaşım').slice(0,150),views:Number(stat.data().views||0)});}
    const totals=days?(await db.collection(`creator_stats/${uid}/daily`).where('day','>=',new Date(Date.now()+10800000-(days-1)*86400000).toISOString().slice(0,10)).get()).docs.reduce((a,s)=>({views:a.views+Number(s.data().views||0),profileVisits:a.profileVisits+Number(s.data().profileVisits||0)}),{views:0,profileVisits:0}):(await db.collection(`creator_stats/${uid}/content`).aggregate({views:AggregateField.sum('views'),profileVisits:AggregateField.sum('profileVisits')}).get()).data();
    return {profile:{...person(uid,profile.data()),code:member.data().code||'',joinedAtMs:ms(member.data().createdAt)},posts,nextCursor:result.nextCursor,followers:followers.data().count,referrals:referrals.data().count,totals,top,dailyTrackingSinceMs:ms(daily.data()?.dailyTrackingSince),referralUrl:`https://www.trtbt.com/creator-profile/${uid}`};
  }
  fail('invalid-argument','Geçersiz işlem.');
}
exports.creatorAdmin=onCall({region:'europe-west1'},r=>creatorAdmin(r));
exports._creatorAdmin=creatorAdmin;
