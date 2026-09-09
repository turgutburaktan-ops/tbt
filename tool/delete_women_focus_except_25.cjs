'use strict';
const path = require('node:path');
const { createRequire } = require('node:module');

const root = path.resolve(__dirname, '..');
const project = 'en-iyi-cekim-noktasi';
const bucketName = `${project}.firebasestorage.app`;
const keepId = 'tbt-eglence-reel-25';
const deleteIds = [
  'tbt-eglence-reel-22',
  'tbt-eglence-reel-23',
  'tbt-eglence-reel-24',
  'tbt-eglence-reel-26',
  'tbt-eglence-reel-27',
];

const check = (x, m) => { if (!x) throw new Error(m); };

async function main() {
  const admin = createRequire(path.join(root, 'functions/package.json'))('firebase-admin');
  const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  check(sa.project_id === project, 'Wrong Firebase project');

  admin.initializeApp({
    credential: admin.credential.cert(sa),
    projectId: project,
    storageBucket: bucketName,
  });

  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  const keep = await db.collection('posts').doc(keepId).get();
  check(keep.exists, `${keepId} must remain published`);

  const deleted = [];
  const missing = [];
  const storageDeleted = [];

  for (const id of deleteIds) {
    const ref = db.collection('posts').doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      missing.push(id);
      continue;
    }

    const data = snap.data() || {};
    const storagePaths = [
      data.videoStoragePath,
      data.thumbnailStoragePath,
      data.imageStoragePath,
    ].filter(Boolean);

    for (const storagePath of [...new Set(storagePaths)]) {
      try {
        await bucket.file(storagePath).delete({ ignoreNotFound: true });
        storageDeleted.push(storagePath);
      } catch (err) {
        console.warn(`Storage delete warning for ${storagePath}: ${err.message}`);
      }
    }

    await ref.delete();
    deleted.push(id);
  }

  const verifyKeep = await db.collection('posts').doc(keepId).get();
  check(verifyKeep.exists, `${keepId} was unexpectedly removed`);

  for (const id of deleteIds) {
    const snap = await db.collection('posts').doc(id).get();
    check(!snap.exists, `${id} still exists after delete`);
  }

  console.log(JSON.stringify({
    kept: keepId,
    deleted,
    missing,
    storageDeletedCount: storageDeleted.length,
    success: true,
  }));
}

main().catch((err) => {
  console.error(err.stack || err);
  process.exitCode = 1;
});
