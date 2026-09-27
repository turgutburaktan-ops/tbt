const {Timestamp}=require('firebase-admin/firestore');
const {historySummary,DAY}=require('./reservation_policy');
exports.customerHistory=async(db,uid)=>{const snap=await db.collection('users').doc(uid).collection('reservation_history').where('preparedAt','>=',Timestamp.fromMillis(Date.now()-90*DAY)).get();return historySummary(snap.docs.map(d=>d.data()),Date.now());};
