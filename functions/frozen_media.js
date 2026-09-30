const {createHash} = require('node:crypto');

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
    await record.set({path:file.name, generation:meta.generation,
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
module.exports = {suspendFile, suspendUserMedia, resumeUserMedia};
