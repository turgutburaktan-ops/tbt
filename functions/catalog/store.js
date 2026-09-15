const {FieldValue} = require('firebase-admin/firestore');
const {spotRow, venueRow, partition} = require('./schema');

// Read current source documents inside the transaction, never an event payload.
// Delayed triggers cannot restore an older approved/published state.
async function project(db, type, id, {removedApprovedBusiness = false} = {}) {
  const canonical = type === 'spot' ? `spot:${id}` : `venue:${id}`;
  return db.runTransaction(async tx => {
    const linkRef = db.doc(`catalog_links/${canonical}`);
    const link = (await tx.get(linkRef)).data();
    let row, exclusionRef, clearExclusion = false, setExclusion = false;
    if (type === 'spot') row = spotRow(id, (await tx.get(db.doc(`photo_spots/${id}`))).data());
    else {
      const external = (await tx.get(db.doc(`catalog_external_venues/${id}`))).data();
      const business = (await tx.get(db.doc(`business_venues/${id}`))).data();
      exclusionRef = db.doc(`catalog_exclusions/${canonical}`);
      const excluded = (await tx.get(exclusionRef)).exists;
      clearExclusion = business?.verified === true && business.pendingListing !== true && !['hidden','deleted','rejected','suspended'].includes(business.listingStatus);
      setExclusion = removedApprovedBusiness && !clearExclusion;
      row = venueRow(id, external, business, excluded || setExclusion);
    }
    const next = row ? partition(row.city, row.kind) : null;
    const old = link?.partition || null;
    const metadata = new Map();
    for (const key of new Set([old, next].filter(Boolean))) metadata.set(key, (await tx.get(db.doc(`place_catalog/${key}`))).data() || {});
    // Avoid repeated writes/read notifications during reconciliation.
    const serialized = row ? JSON.stringify(row) : null;
    if (link?.serialized === serialized && old === next && !setExclusion && !clearExclusion) return {changed: false, published: !!row};
    if (setExclusion) tx.set(exclusionRef, {reason: 'business_unpublished', at: FieldValue.serverTimestamp()});
    if (clearExclusion) tx.delete(exclusionRef);
    if (old && old !== next) {
      tx.delete(db.doc(`place_catalog/${old}/items/${canonical}`));
      tx.set(db.doc(`place_catalog/${old}`), {count: Math.max(0, (metadata.get(old).count || 0) - 1), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    }
    if (row) {
      tx.set(db.doc(`place_catalog/${next}/items/${canonical}`), {...row, updatedAt: FieldValue.serverTimestamp()});
      const meta = metadata.get(next);
      tx.set(db.doc(`place_catalog/${next}`), {schemaVersion: 1, city: row.city, kind: row.kind,
        count: (meta.count || 0) + (old === next ? 0 : 1),
        minLatitude: Math.min(meta.minLatitude ?? row.latitude, row.latitude),
        maxLatitude: Math.max(meta.maxLatitude ?? row.latitude, row.latitude),
        minLongitude: Math.min(meta.minLongitude ?? row.longitude, row.longitude),
        maxLongitude: Math.max(meta.maxLongitude ?? row.longitude, row.longitude),
        updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      tx.set(linkRef, {partition: next, serialized});
    } else tx.delete(linkRef);
    return {changed: true, published: !!row};
  });
}
module.exports = {project};
