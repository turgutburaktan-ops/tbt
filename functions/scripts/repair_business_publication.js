const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {publishApprovedCandidate} = require('../business_publication');
const venueKey = process.argv[2];
if (venueKey !== 'dining:user_4xFEQcn0tjLktR5Cq85n') throw new Error('Repair is restricted to the reported Burak application.');
initializeApp({credential: applicationDefault(), projectId: 'en-iyi-cekim-noktasi'});
publishApprovedCandidate(getFirestore(), venueKey, FieldValue.serverTimestamp())
  .then(result => { console.log(JSON.stringify(result)); if (!result.repaired) process.exitCode = 1; })
  .catch(error => { console.error(error.message); process.exitCode = 1; });
