const test=require('node:test');
const assert=require('node:assert/strict');
const {_publishing:publishing}=require('../social_publishing');
function fixture() {
  const records=new Map([
    ['users/reader',{displayName:'Reader'}],
    ['users/author',{displayName:'Author',email:'private@example.com'}],
    ['posts/post',{userId:'author',userName:'Forged display name',caption:'Original',mediaType:'image',imageUrl:'https://example.com/image.jpg',userEmail:'private@example.com',storagePath:'private-path'}],
  ]);
  const db={doc:path=>({get:async()=>({exists:records.has(path),data:()=>records.get(path)})})};
  const resolve=()=>publishing({auth:{uid:'reader'},data:{action:'resolve',postId:'post'}},db);
  return {records,resolve};
}
test('reference resolution uses live author identity and returns only public display fields',async()=>{
  const f=fixture();const result=await f.resolve();
  assert.equal(result.post.userName,'Author');assert.equal(result.post.caption,'Original');
  assert.equal('userEmail' in result.post,false);assert.equal('email' in result.post,false);assert.equal('storagePath' in result.post,false);
  f.records.delete('posts/post');await assert.rejects(f.resolve(),{code:'not-found'});
});
test('reference resolution rejects either direction of a block and non-active accounts',async()=>{
  for(const path of ['users/author/blocked/reader','users/reader/blocked/author']) {
    const f=fixture();f.records.set(path,{});await assert.rejects(f.resolve(),{code:'permission-denied'});
  }
  for(const status of ['frozen','deleting','deleted']) {
    const f=fixture();f.records.get('users/author').accountStatus=status;
    await assert.rejects(f.resolve(),{code:'permission-denied'});
  }
});
test('unpublished and moderated sources cannot be reshared',async()=>{
  for(const patch of [{status:'draft'},{moderationStatus:'pending'},{visibility:'private'},{allowReshare:false},{accountFrozen:true}]) {
    const f=fixture();Object.assign(f.records.get('posts/post'),patch);
    await assert.rejects(f.resolve(),{code:'not-found'});
  }
});

test('video reshare resolves playback URL only while source remains accessible', async () => {
  const f = fixture();
  Object.assign(f.records.get('posts/post'), {mediaType:'video', videoUrl:'https://example.com/video.mp4'});
  const result = await f.resolve();
  assert.equal(result.post.videoUrl, 'https://example.com/video.mp4');
  assert.equal('storagePath' in result.post, false);
  f.records.get('posts/post').allowReshare = false;
  await assert.rejects(f.resolve(), {code:'not-found'});
});
test('photo reshares never use a stale video URL', async () => {
  const f = fixture();
  f.records.get('posts/post').videoUrl = 'https://example.com/stale.mp4';
  assert.equal((await f.resolve()).post.videoUrl, '');
});

