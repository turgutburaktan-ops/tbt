// Read-only production diagnosis. No contact values, tokens or credentials leave
// this process. Never grant IAM access or mutate update policy from this tool.
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
const {initializeApp} = require('../functions/node_modules/firebase-admin/app');
const {getFirestore} = require('../functions/node_modules/firebase-admin/firestore');
const fs = require('node:fs');
const project = 'en-iyi-cekim-noktasi';
async function main() {
  const identity = JSON.parse(fs.readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'));
  if (identity.project_id !== project) throw Error('Unexpected project');
  const client = await new GoogleAuth({scopes: ['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  const permissions = ['datastore.databases.getMetadata', 'datastore.databases.update', 'datastore.databases.list'];
  const report = {mode: 'read-only', productionChanged: false};
  try {
    const response = await client.request({
      url: `https://cloudresourcemanager.googleapis.com/v1/projects/${project}:testIamPermissions`,
      method: 'POST', data: {permissions},
    });
    const granted = response.data.permissions || [];
    report.databasePermissions = {granted, missing: permissions.filter(p => !granted.includes(p))};
  } catch (e) { report.databasePermissions = {verified: false, status: e.response?.status || 'unknown'}; }
  try {
    const response = await client.request({url: `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)`});
    report.recovery = {pointInTimeRecovery: response.data.pointInTimeRecoveryEnablement, deleteProtection: response.data.deleteProtectionState};
  } catch (e) { report.recovery = {verified: false, status: e.response?.status || 'unknown'}; }
  initializeApp({projectId: project});
  const db = getFirestore();
  try {
    const fields = ['email', 'phoneNumber', 'verifiedPhoneNumber'];
    let cursor, scanned = 0, withPublicContacts = 0, pages = 0;
    while (pages < 100) {
      let query = db.collection('users').orderBy('__name__').select(...fields).limit(200);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get(); pages++;
      scanned += page.size;
      withPublicContacts += page.docs.filter(d => fields.some(f => Object.hasOwn(d.data(), f))).length;
      if (page.size < 200) { report.contacts = {scanned, withPublicContacts, complete: true}; break; }
      cursor = page.docs.at(-1);
    }
    report.contacts ||= {scanned, withPublicContacts, complete: false};
  } catch (e) { report.contacts = {verified: false, status: e.code || 'unknown'}; }
  report.frozenContent = {};
  for (const collection of ['posts', 'stories', 'social_events', 'event_memories', 'travel_plans', 'communities']) {
    try {
      report.frozenContent[collection] = (await db.collection(collection).where('accountFrozen', '==', true).count().get()).data().count;
    } catch (e) { report.frozenContent[collection] = {verified: false, status: e.code || 'unknown'}; }
  }
  console.log('RELEASE_DIAGNOSTICS ' + JSON.stringify(report));
  await db.terminate();
}
main().catch(e => { console.error('Release diagnostics failed', e.response?.status || e.code || 'unknown'); process.exitCode = 1; });
