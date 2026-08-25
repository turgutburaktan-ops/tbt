const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

exports.publishVerifiedBusinessCandidate = onDocumentUpdated(
  {region: 'europe-west1', document: 'business_claims/{venueKey}'},
  async event => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    if (before.status === 'verified' || after.status !== 'verified') return;
    const venueKey = event.params.venueKey;
    const db = getFirestore();
    const venueRef = db.collection('business_venues').doc(venueKey);
    const venue = await venueRef.get();
    const data = venue.data() || {};
    if (data.source !== 'user_submission') return;

    const update = {
      verified: true,
      pendingListing: false,
      listingStatus: 'published',
      ownerUid: after.applicantUid || data.ownerUid || null,
      verificationLevel: after.verificationLevel || 'manual_strong',
      publishedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    await venueRef.set(update, {merge: true});

    const venueId = String(data.venueId || after.venueId || '');
    const submissionId = venueId.startsWith('user_') ? venueId.substring(5) : '';
    if (submissionId) {
      await db.collection('business_venue_submissions').doc(submissionId).set({
        status: 'published',
        listingStatus: 'published',
        verified: true,
        pendingListing: false,
        publishedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  },
);
