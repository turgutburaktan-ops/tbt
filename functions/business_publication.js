// Only publish a new venue using its original, matching owner submission.
function submissionId(claim) {
  const id = String(claim.venueId || '');
  return /^user_[A-Za-z0-9_-]+$/.test(id) ? id.substring(5) : null;
}
function publicationData(claim, venue, submission, timestamp) {
  const id = submissionId(claim);
  if (!id) return null;
  if (!submission || submission.venueId !== claim.venueId ||
      submission.category !== claim.category ||
      submission.createdBy !== claim.applicantUid) {
    throw new Error('Yeni işletmenin asıl başvuru bilgileri doğrulanamadı.');
  }
  const latitude = venue.latitude ?? submission.latitude;
  const longitude = venue.longitude ?? submission.longitude;
  if (typeof latitude !== 'number' || typeof longitude !== 'number' ||
      !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
    throw new Error('İşletmenin başvurusunda geçerli konum bulunamadı.');
  }
  return {
    venueId: claim.venueId, venueKey: `${claim.category}:${claim.venueId}`,
    category: claim.category, venueName: venue.venueName || submission.venueName || claim.venueName,
    latitude, longitude, city: venue.city || submission.city || '',
    address: venue.address || submission.address || '', source: 'user_submission',
    createdBy: submission.createdBy, ownerUid: claim.applicantUid,
    verified: true, pendingListing: false, listingStatus: 'published',
    verificationLevel: 'manual_strong', publishedAt: venue.publishedAt || timestamp,
    updatedAt: timestamp,
  };
}
async function publishApprovedCandidate(db, venueKey, timestamp) {
  return db.runTransaction(async tx => {
    const claimRef = db.collection('business_claims').doc(venueKey);
    const venueRef = db.collection('business_venues').doc(venueKey);
    const claim = (await tx.get(claimRef)).data() || {};
    if (claim.status !== 'verified') return {repaired: false, reason: 'not_verified'};
    const id = submissionId(claim);
    if (!id) return {repaired: false, reason: 'not_new_business'};
    const venue = (await tx.get(venueRef)).data() || {};
    const subRef = db.collection('business_venue_submissions').doc(id);
    const submission = (await tx.get(subRef)).data();
    const payload = publicationData(claim, venue, submission, timestamp);
    tx.set(venueRef, payload, {merge: true});
    tx.set(subRef, {status: 'published', listingStatus: 'published', verified: true,
      pendingListing: false, publishedAt: submission.publishedAt || timestamp,
      updatedAt: timestamp}, {merge: true});
    return {repaired: true, venueKey, name: payload.venueName};
  });
}
module.exports = {submissionId, publicationData, publishApprovedCandidate};
