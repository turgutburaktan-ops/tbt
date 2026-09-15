const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {publishApprovedCandidate} = require('./business_publication');

exports.publishVerifiedBusinessCandidate = onDocumentUpdated(
  {region: 'europe-west1', document: 'business_claims/{venueKey}', retry: true},
  async event => {
    if (event.data?.after?.data()?.status !== 'verified') return;
    // Read the current claim inside the transaction: delayed events cannot
    // publish a rejected or withdrawn claim, and incomplete listings can retry.
    await publishApprovedCandidate(getFirestore(), event.params.venueKey, FieldValue.serverTimestamp());
  },
);
