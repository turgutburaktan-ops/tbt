const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {createHash} = require('node:crypto');

const fail = (code, message) => { throw new HttpsError(code, message); };
const id = value => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) fail('invalid-argument', 'Geçersiz içerik kimliği.');
  return value;
};
const key = (...parts) => createHash('sha256').update(parts.join(':')).digest('hex');
const day = () => new Date(Date.now() + 10800000).toISOString().slice(0, 10);
const text = (v, max = 180) => String(v || '').trim().slice(0, max);
function publicContent(data) {
  return !!data && data.deleted !== true && data.hidden !== true && data.accountFrozen !== true &&
    (!data.status || ['published','active','approved','public'].includes(data.status)) &&
    (!data.moderationStatus || ['approved','visible','published'].includes(data.moderationStatus)) &&
    data.isPublic !== false && (!data.visibility || data.visibility === 'public');
}
function publicAccount(data) {
  return !!data && !['frozen','deleting','deleted'].includes(data.accountStatus) && data.disabled !== true && data.banned !== true &&
    data.isPrivate !== true && data.privateAccount !== true && (!data.visibility || data.visibility === 'public');
}
async function user(db, uid, tx = {get: ref => ref.get()}) {
  const snap = await tx.get(db.doc(`users/${uid}`));
  if (!snap.exists || ['frozen','deleting','deleted'].includes(snap.data().accountStatus) || snap.data().disabled === true || snap.data().banned === true) fail('permission-denied', 'Hesap kullanılamıyor.');
  return snap.data();
}
async function unblocked(db, a, b, tx = {get: ref => ref.get()}) {
  if (a === b) return;
  const docs = await Promise.all([tx.get(db.doc(`users/${a}/blocked/${b}`)), tx.get(db.doc(`users/${b}/blocked/${a}`))]);
  if (docs.some(d => d.exists)) fail('permission-denied', 'Bu içerik kullanılamıyor.');
}
async function source(db, postId, uid, tx = {get: ref => ref.get()}) {
  const snap = await tx.get(db.doc(`posts/${id(postId)}`));
  const post = snap.data();
  if (!publicContent(post) || post.allowReshare === false) fail('not-found', 'Gönderi kaldırılmış veya paylaşıma kapalı.');
  const ownerId = id(post.userId);
  const owner = await user(db, ownerId, tx);
  if (!publicAccount(owner)) fail('permission-denied', 'Bu gönderi herkese açık değil.');
  await unblocked(db, uid, ownerId, tx);
  if (post.mediaType === 'route') {
    const plan = await tx.get(db.doc(`travel_plans/${id(post.travelPlanId)}`));
    if (!plan.exists || plan.data().isPublic !== true || plan.data().ownerId !== ownerId) fail('not-found', 'Rota artık herkese açık değil.');
  }
  if (post.eventId) {
    const event = await tx.get(db.doc(`social_events/${id(post.eventId)}`));
    if (!event.exists || event.data().visibility !== 'public' || event.data().status === 'cancelled') fail('not-found', 'Etkinlik artık herkese açık değil.');
  }
  return {post, owner, ownerId};
}
function preview(postId, data) {
  const {post, owner, ownerId} = data;
  // Only public display fields; never return account email or storage paths.
  return {id: postId, userId: ownerId, userName: text(owner.displayName || owner.username || 'TBT kullanıcısı', 80),
    userPhotoUrl: text(owner.photoUrl, 2000), caption: text(post.caption, 500), mediaType: post.mediaType || 'image',
    imageUrl: text(post.thumbnailUrl || post.imageUrl || post.coverUrl || (post.mediaUrls || [])[0], 2000),
    title: text(post.routeTitle || post.caption || 'TBT paylaşımı', 120), travelPlanId: post.travelPlanId || '',
    eventId:post.eventId||'', guideNote:text(post.guideNote,1500), spotName: text(post.spotName, 120)};
}
async function creator(db, uid, tx = {get: ref => ref.get()}) {
  const profile = await user(db, uid, tx);
  const membership = await tx.get(db.doc(`creator_invite_redemptions/${uid}`));
  if (profile.isCreator !== true || !membership.exists) fail('permission-denied', 'Onaylı Creator hesabı gerekli.');
  return profile;
}
async function quota(db, uid, action, tx, maximum) {
  const ref = db.doc(`social_publish_limits/${key(uid, day(), action)}`);
  const snap = await tx.get(ref);
  if (Number(snap.data()?.count || 0) >= maximum) fail('resource-exhausted', 'Bugünkü paylaşım sınırına ulaştın.');
  return ref;
}
function spend(tx, ref, uid) { tx.set(ref, {userId:uid, count: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()}, {merge:true}); }
async function recordMetric(db, uid, postId, metric) {
  return db.runTransaction(async tx => {
    const data = await source(db, postId, uid, tx);
    if (data.ownerId === uid) return {recorded: false};
    const member = await tx.get(db.doc(`creator_invite_redemptions/${data.ownerId}`));
    if (data.owner.isCreator !== true || !member.exists) return {recorded: false};
    const receipt = db.doc(`creator_metric_receipts/${key(uid, postId, metric, day())}`);
    if ((await tx.get(receipt)).exists) return {recorded: false};
    const limit = await quota(db, uid, 'metrics', tx, 500);
    tx.create(receipt, {userId:uid, createdAt: FieldValue.serverTimestamp()});
    tx.set(db.doc(`creator_stats/${data.ownerId}/content/${postId}`), {
      [metric]: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp(),
    }, {merge:true});
    spend(tx, limit, uid);
    return {recorded: true};
  });
}
async function publishing(request, db = getFirestore()) {
  const uid = request.auth?.uid;
  if (!uid) fail('unauthenticated', 'Giriş yapmalısın.');
  const profile = await user(db, uid);
  const data = request.data || {}, action = data.action, postId = id(data.postId);
  if (action === 'publishRoute') {
    const planId=id(data.planId);
    if(postId!==`route_${planId}`) fail('invalid-argument','Geçersiz rota gönderisi.');
    return db.runTransaction(async tx=>{
      const current=await user(db,uid,tx);
      const planRef=db.doc(`travel_plans/${planId}`), postRef=db.doc(`posts/${postId}`);
      const [planSnap,existing]=await Promise.all([tx.get(planRef),tx.get(postRef)]);
      if(!planSnap.exists||planSnap.data().ownerId!==uid)fail('permission-denied','Yalnızca kendi rotanı paylaşabilirsin.');
      if(existing.exists && (existing.data().userId!==uid || existing.data().mediaType!=='route' || !publicContent(existing.data())))fail('permission-denied','Bu rota gönderisi kullanılamıyor.');
      const limit=await quota(db,uid,'publishRoute',tx,20), plan=planSnap.data();
      tx.update(planRef,{isPublic:true,updatedAt:FieldValue.serverTimestamp()});
      tx.set(postRef,{
        userId:uid,userName:text(current.displayName||current.username||'TBT kullanıcısı',80),userPhotoUrl:text(current.photoUrl,2000),
        mediaType:'route',contentType:'route',travelPlanId:planId,routeTitle:text(plan.title,180),routeCity:text(plan.city,100),
        routeDurationHours:plan.durationHours||0,routeBudget:plan.budget||'',routeTransport:plan.transport||'',
        routeSpotIds:plan.spotIds||[],routeSpotNames:plan.spotNames||[],routeStopSnapshots:plan.stopSnapshots||[],
        caption:`${text(plan.title,180)} rotasını paylaştı.`,spotName:text(plan.city,100),isPublic:true,
        ...(!existing.exists?{createdAt:FieldValue.serverTimestamp()}:{}),updatedAt:FieldValue.serverTimestamp(),
      },{merge:true});
      spend(tx,limit,uid);return {id:postId};
    });
  }
  if (action === 'resolve') {
    const resolved = await source(db, postId, uid);
    let sharedBy = null;
    if (data.repostId || data.storyId) {
      const ref = data.repostId ? db.doc(`post_reposts/${id(data.repostId)}`) : db.doc(`stories/${id(data.storyId)}`);
      let snap = await ref.get();
      if (!snap.exists && data.storyId) snap = await db.doc(`users/${uid}/story_archive/${id(data.storyId)}`).get();
      const share = snap.data();
      if (!share || (share.postId || share.sharedPostId) !== postId) fail('not-found', 'Paylaşım artık kullanılamıyor.');
      if (data.storyId && share.expiresAt?.toMillis() <= Date.now() && share.userId !== uid) fail('not-found', 'Hikâyenin süresi dolmuş.');
      const actorId = id(share.userId);
      const actor = await user(db, actorId);
      if (!publicAccount(actor) && actorId !== uid) fail('not-found', 'Paylaşım kullanılamıyor.');
      await unblocked(db, uid, actorId);
      await unblocked(db, actorId, resolved.ownerId);
      sharedBy = {userId: actorId, name: text(actor.displayName || actor.username || 'TBT kullanıcısı', 80)};
    }
    return {post: preview(postId, resolved), sharedBy};
  }
  if (action === 'view' || action === 'profileVisit') return recordMetric(db, uid, postId, action === 'view' ? 'views' : 'profileVisits');
  if (action === 'save') {
    if (typeof data.enabled !== 'boolean') fail('invalid-argument', 'Geçersiz seçim.');
    const ref = db.doc(`post_bookmarks/${key(uid, postId)}`);
    await db.runTransaction(async tx => {
      if (data.enabled) await source(db, postId, uid, tx);
      const existing = await tx.get(ref);
      if (data.enabled && !existing.exists) tx.create(ref, {userId:uid,postId,createdAt:FieldValue.serverTimestamp()});
      if (!data.enabled && existing.exists) tx.delete(ref);
    });
    return {saved: data.enabled};
  }
  if (action === 'repost') {
    if (typeof data.enabled !== 'boolean') fail('invalid-argument', 'Geçersiz seçim.');
    const ref = db.doc(`post_reposts/${key(uid, postId)}`);
    await db.runTransaction(async tx => {
      if (data.enabled) {
        const original = await source(db, postId, uid, tx);
        if (original.ownerId === uid) fail('failed-precondition', 'Kendi gönderini hikâyende paylaşabilirsin.');
        if (!publicAccount(await user(db,uid,tx))) fail('failed-precondition', 'Yeniden paylaşmak için herkese açık hesap gerekli.');
      }
      const existing = await tx.get(ref);
      if (data.enabled && !existing.exists) {
        const limit = await quota(db, uid, 'repost', tx, 20);
        tx.create(ref, {userId:uid,postId,createdAt:FieldValue.serverTimestamp()});
        spend(tx, limit, uid);
      }
      if (!data.enabled && existing.exists) tx.delete(ref);
    });
    return {reposted:data.enabled,id:ref.id};
  }
  if (action === 'story') {
    const requestId = id(data.requestId);
    if (typeof data.note !== 'string' || data.note.length > 180) fail('invalid-argument', 'Hikâye notu en fazla 180 karakter olabilir.');
    const ref = db.doc(`stories/${key(uid, requestId)}`);
    return db.runTransaction(async tx => {
      await user(db,uid,tx);
      await source(db, postId, uid, tx);
      const existing = await tx.get(ref);
      const archive = db.doc(`users/${uid}/story_archive/${ref.id}`);
      const saved = await tx.get(archive);
      if (existing.exists || saved.exists) return {id:ref.id,alreadyPublished:true};
      const limit = await quota(db, uid, 'story', tx, 20);
      const story = {id:ref.id,userId:uid,userName:text(profile.displayName || profile.username || 'TBT kullanıcısı',80),userPhotoUrl:text(profile.photoUrl,2000),
        sharedPostId:postId,mediaType:'image',imageUrl:'',storagePath:'',videoUrl:'',thumbnailUrl:'',
        caption:data.note.trim(),createdAt:FieldValue.serverTimestamp(),expiresAt:Timestamp.fromMillis(Date.now()+86400000)};
      tx.create(ref,story);
      tx.create(archive,{...story,archivedAt:FieldValue.serverTimestamp()});
      spend(tx,limit,uid);
      return {id:ref.id};
    });
  }
  if (action === 'state') {
    const [repost,bookmark] = await Promise.all([db.doc(`post_reposts/${key(uid,postId)}`).get(),db.doc(`post_bookmarks/${key(uid,postId)}`).get()]);
    return {reposted:repost.exists,saved:bookmark.exists};
  }
  fail('invalid-argument','Geçersiz işlem.');
}
async function studio(request, db = getFirestore()) {
  const uid = request.auth?.uid;
  if (!uid) fail('unauthenticated','Giriş yapmalısın.');
  const data=request.data||{}, action=data.action;
  await user(db,uid);
  if (action === 'welcome') {
    const creatorId=id(data.creatorId), profile=await creator(db,creatorId);
    if (!publicAccount(profile)) fail('not-found','Creator profili kullanılamıyor.');
    await unblocked(db,uid,creatorId);
    const pinned=await db.doc(`creator_profiles/${creatorId}`).get();
    const posts=[];
    for(const postId of pinned.data()?.pinnedPostIds||[]) {
      try { const resolved=await source(db,postId,uid); if(resolved.ownerId===creatorId) posts.push(preview(postId,resolved)); } catch(error) { if(!['not-found','permission-denied'].includes(error.code)) throw error; }
    }
    return {userId:creatorId,name:text(profile.displayName||profile.username,80),bio:text(profile.bio,300),photoUrl:text(profile.photoUrl,2000),tier:profile.creatorTier||'creator',posts};
  }
  if (action === 'referral') {
    const creatorId=id(data.creatorId);
    if(creatorId===uid) return {recorded:false};
    const result=await db.runTransaction(async tx=>{
      await creator(db,creatorId,tx);
      await unblocked(db,uid,creatorId,tx);
      const ref=db.doc(`creator_referrals/${uid}`);
      if((await tx.get(ref)).exists) return false;
      tx.create(ref,{creatorId,userId:uid,createdAt:FieldValue.serverTimestamp()});
      return true;
    });
    return {recorded:result};
  }
  await creator(db,uid);
  if(action==='guide') {
    const postId=id(data.postId);
    if(typeof data.note!=='string'||data.note.length>1500)fail('invalid-argument','Rehber notu en fazla 1500 karakter olabilir.');
    await db.runTransaction(async tx=>{
      await creator(db,uid,tx);
      const original=await source(db,postId,uid,tx);
      if(original.ownerId!==uid||original.post.mediaType!=='route')fail('permission-denied','Kendi rotanı seç.');
      tx.update(db.doc(`posts/${postId}`),{guideNote:data.note.trim(),updatedAt:FieldValue.serverTimestamp()});
    });
    return {ok:true};
  }
  if(action==='pin') {
    const pins=data.postIds;
    if(!Array.isArray(pins)||pins.length>3||new Set(pins).size!==pins.length) fail('invalid-argument','En fazla 3 farklı içerik sabitleyebilirsin.');
    await db.runTransaction(async tx=>{
      await creator(db,uid,tx);
      for(const postId of pins) {const resolved=await source(db,id(postId),uid,tx);if(resolved.ownerId!==uid)fail('permission-denied','Yalnızca kendi içeriğini sabitleyebilirsin.');}
      tx.set(db.doc(`creator_profiles/${uid}`),{pinnedPostIds:pins,updatedAt:FieldValue.serverTimestamp()},{merge:true});
    });
    return {pinnedPostIds:pins};
  }
  if(action==='dashboard') {
    const limit=20;
    let query=db.collection('posts').where('userId','==',uid).orderBy('__name__').limit(limit+1);
    if(data.cursor) query=query.startAfter(id(data.cursor));
    const [posts,followers,referrals,pins]=await Promise.all([query.get(),db.collection(`users/${uid}/followers`).count().get(),db.collection('creator_referrals').where('creatorId','==',uid).count().get(),db.doc(`creator_profiles/${uid}`).get()]);
    const entries=await Promise.all(posts.docs.slice(0,limit).map(async doc=>{
      const [stats,likes,comments,saves,reposts,stories]=await Promise.all([
        db.doc(`creator_stats/${uid}/content/${doc.id}`).get(),doc.ref.collection('likes').count().get(),doc.ref.collection('comments').count().get(),
        db.collection('post_bookmarks').where('postId','==',doc.id).count().get(),db.collection('post_reposts').where('postId','==',doc.id).count().get(),
        db.collection('stories').where('sharedPostId','==',doc.id).where('expiresAt','>',Timestamp.now()).count().get(),
      ]);
      return {id:doc.id,title:text(doc.data().routeTitle||doc.data().caption||'Paylaşım',100),mediaType:doc.data().mediaType||'image',guideNote:text(doc.data().guideNote,1500),
        views:Number(stats.data()?.views||0),profileVisits:Number(stats.data()?.profileVisits||0),likes:likes.data().count,comments:comments.data().count,
        saves:saves.data().count,reposts:reposts.data().count,activeStoryShares:stories.data().count};
    }));
    return {posts:entries,followers:followers.data().count,referrals:referrals.data().count,pinnedPostIds:pins.data()?.pinnedPostIds||[],nextCursor:posts.size>limit?posts.docs[limit-1].id:null};
  }
  fail('invalid-argument','Geçersiz işlem.');
}
exports.socialPublishing=onCall({region:'europe-west1'},r=>publishing(r));
exports.creatorStudio=onCall({region:'europe-west1'},r=>studio(r));
exports._publishing=publishing;
exports._studio=studio;
exports._publicContent=publicContent;
