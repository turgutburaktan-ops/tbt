const {createHash} = require('node:crypto');

const privateCategory = name => ['chat','business_claims'].includes(name.split('/')[2]);

// Recovery metadata is server-only. It must never be returned to a client.
function manifestRef(db, uid, name) {
  return db.doc(`frozen_media/${uid}/objects/${createHash('sha256').update(name).digest('hex')}`);
}
async function suspendFile(db, uid, file) {
  if (!file.name.startsWith(`users/${uid}/`)) throw Error('Unexpected media owner');
  const record = manifestRef(db, uid, file.name);
  for (let attempt = 0; attempt < 3; attempt++) {
    const [meta] = await file.getMetadata();
    const tokens = meta.metadata?.firebaseStorageDownloadTokens;
    if (!tokens) return;
    // Save before revoking; a failed save must not leave an unrecoverable URL.
    if (!privateCategory(file.name)) await record.set({path:file.name, generation:meta.generation,
      tokens, cacheControl:meta.cacheControl || null});
    try {
      await file.setMetadata({cacheControl:'private, no-store, max-age=0',
        metadata:{...meta.metadata, firebaseStorageDownloadTokens:null}},
      {ifMetagenerationMatch:meta.metageneration});
      const [verified] = await file.getMetadata();
      if (verified.metadata?.firebaseStorageDownloadTokens) throw Error('Media token revocation failed');
      return;
    } catch (error) {
      if (Number(error.code) !== 412 || attempt === 2) throw error;
    }
  }
}
async function suspendUserMedia({db, bucket, uid}) {
  let query = {prefix:`users/${uid}/`, maxResults:100, autoPaginate:false};
  while (query) {
    const [files, next] = await bucket.getFiles(query);
    for (const file of files) await suspendFile(db, uid, file);
    query = next;
  }
}
async function resumeUserMedia({db, bucket, uid}) {
  const profile = async () => (await db.doc(`users/${uid}`).get()).data();
  const active = p => p && (p.accountStatus || 'active') === 'active' && !p.banned && !p.disabled;
  while (true) {
    const page = await db.collection(`frozen_media/${uid}/objects`).limit(100).get();
    if (page.empty) return;
    for (const doc of page.docs) {
      if (!active(await profile())) throw Error('Account must be active before restoring media');
      const saved = doc.data();
      if (!saved.path.startsWith(`users/${uid}/`)) throw Error('Unexpected archived media owner');
      const file = bucket.file(saved.path);
      // Private chat/claim URLs must never regain a public download token.
      if (privateCategory(saved.path)) {
        try { await suspendFile(db, uid, file); } catch (error) { if (Number(error.code) !== 404) throw error; }
        await doc.ref.delete();
        continue;
      }
      let meta;
      try { [meta] = await file.getMetadata(); }
      catch (error) { if (Number(error.code) !== 404) throw error; }
      // Never attach an old token to a replacement object or recreate a deleted file.
      if (meta && meta.generation === saved.generation) {
        await file.setMetadata({cacheControl:saved.cacheControl,
          metadata:{...meta.metadata, firebaseStorageDownloadTokens:saved.tokens}},
        {ifMetagenerationMatch:meta.metageneration});
        if (!active(await profile())) {
          await suspendFile(db, uid, file);
          throw Error('Account restricted while restoring media');
        }
      }
      await doc.ref.delete();
    }
  }
}
async function guardFinishedUpload({db,bucket,name}) {
  const match = /^users\/([^/]+)\/[^/]+\/.+/.exec(name || '');
  if (!match) return;
  const uid = match[1];
  const profile = (await db.doc(`users/${uid}`).get()).data();
  const active = profile && (profile.accountStatus || 'active') === 'active' && !profile.banned && !profile.disabled;
  if (active && !privateCategory(name)) return;
  try { await suspendFile(db, uid, bucket.file(name)); }
  catch (error) { if (Number(error.code) !== 404) throw error; }
}

module.exports = {suspendFile, suspendUserMedia, resumeUserMedia, guardFinishedUpload};
