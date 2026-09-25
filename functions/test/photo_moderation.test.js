const test=require('node:test'), assert=require('node:assert/strict');
const {classify,photoPath,ownedPaths,strikeChange,closureStatus}=require('../photo_moderation_policy');
const bucket='en-iyi-cekim-noktasi.firebasestorage.app';
test('explicit adult is hidden; swimwear, medical and ambiguity require human review',()=>{
  assert.equal(classify({adult:'VERY_LIKELY',racy:'VERY_LIKELY',medical:'UNLIKELY'}),'hide');
  assert.equal(classify({adult:'VERY_LIKELY',racy:'LIKELY',medical:'VERY_LIKELY'}),'review');
  assert.equal(classify({adult:'UNLIKELY',racy:'LIKELY'}),'review');
  assert.equal(classify({adult:'POSSIBLE',racy:'UNLIKELY'}),'review');
  assert.equal(classify({adult:'UNLIKELY',racy:'UNLIKELY'}),'clear');
  assert.throws(()=>classify({adult:'UNKNOWN',racy:'LIKELY'}));
  assert.throws(()=>classify(undefined));
});
test('one strike per confirmed post, retries and review do not count',()=>{
  assert.equal(strikeChange('review','confirmed'),1);
  assert.equal(strikeChange('confirmed','confirmed'),0);
  assert.equal(strikeChange('confirmed','dismissed'),-1);
  assert.equal(strikeChange('dismissed','dismissed'),0);
  assert.equal(closureStatus(4,'pending',-1),'none');
  assert.equal(closureStatus(5,'none',1),'pending');
  assert.equal(closureStatus(5,'rejected',0),'rejected');
  assert.equal(closureStatus(6,'rejected',1),'pending');
  assert.equal(closureStatus(4,'closed',-1),'closed');
});
test('only exact owned bucket paths are sent to Vision, never remote URLs',()=>{
  const p={userId:'alice',storagePath:'users/alice/posts/a.jpg'};
  p.imageUrl=`https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(p.storagePath)}?alt=media&token=token`;
  assert.equal(photoPath(p,bucket),p.storagePath);
  assert.throws(()=>photoPath({...p,imageUrl:'https://example.com/image.jpg'},bucket));
  assert.throws(()=>photoPath({...p,storagePath:'users/bob/posts/a.jpg'},bucket));
  assert.throws(()=>photoPath({...p,imageUrl:p.imageUrl.replace('a.jpg','b.jpg')},bucket));
  assert.deepEqual(ownedPaths({...p,videoStoragePath:'users/bob/secret.mp4'}),[p.storagePath]);
});
