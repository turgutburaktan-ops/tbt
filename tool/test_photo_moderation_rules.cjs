const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,deleteDoc,updateDoc}=require('firebase/firestore');
const {ref,uploadBytes,getBytes,deleteObject}=require('firebase/storage');
const fs=require('node:fs');
(async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-tbt',firestore:{rules:fs.readFileSync('firestore.rules','utf8')},storage:{rules:fs.readFileSync('storage.rules','utf8')}});
 try {
 const a=env.authenticatedContext('owner'),b=env.authenticatedContext('other');const db=a.firestore();
 const path='users/owner/posts/photo.jpg';const data={userId:'owner',mediaType:'image',storagePath:path,imageUrl:'https://firebasestorage.googleapis.com/v0/b/en-iyi-cekim-noktasi.firebasestorage.app/o/users%2Fowner%2Fposts%2Fphoto.jpg?alt=media&token=abc'};
 await assertSucceeds(setDoc(doc(db,'posts/photo'),data));
 await assertFails(setDoc(doc(db,'posts/forged'),{...data,imageUrl:data.imageUrl.replace('photo.jpg','other.jpg')}));
 await assertFails(setDoc(doc(db,'photo_moderation/fake'),{userId:'owner',status:'dismissed'}));
 const media=ref(a.storage(),path);await assertSucceeds(uploadBytes(media,new Uint8Array([1,2,3]),{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(media,new Uint8Array([4,5]),{contentType:'image/jpeg'}));
 await env.withSecurityRulesDisabled(async c=>{
   await setDoc(doc(c.firestore(),'photo_moderation/photo'),{userId:'owner',status:'confirmed',desiredHidden:true});
   await setDoc(doc(c.firestore(),'photo_moderation_archive/photo'),{post:data});
   await deleteDoc(doc(c.firestore(),'posts/photo'));
   await uploadBytes(ref(c.storage(),path),new Uint8Array([1,2,3]),{contentType:'image/jpeg',customMetadata:{moderationBlocked:'true'}});
 });
 await assertSucceeds(getDoc(doc(db,'photo_moderation/photo')));
 await assertFails(getDoc(doc(b.firestore(),'photo_moderation/photo')));
 await assertFails(getDoc(doc(db,'photo_moderation_archive/photo')));
 await assertFails(setDoc(doc(db,'posts/photo'),data));
 await assertFails(getBytes(media));
 await assertFails(deleteObject(media));
 await assertFails(uploadBytes(media,new Uint8Array([1]),{contentType:'image/jpeg'}));
 // Deletion/recreation must not bypass an existing moderation record.
 await env.withSecurityRulesDisabled(async c=>deleteObject(ref(c.storage(),path)));
 await assertFails(uploadBytes(media,new Uint8Array([1]),{contentType:'image/jpeg'}));
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'photo_moderation_accounts/owner'),{userId:'owner',strikes:5,closureStatus:'closed'}));
 await assertFails(setDoc(doc(db,'posts/next'),data));
 await assertFails(uploadBytes(ref(a.storage(),'users/owner/posts/new.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
 await assertSucceeds(getDoc(doc(db,'photo_moderation_accounts/owner')));
 await assertFails(updateDoc(doc(db,'photo_moderation_accounts/owner'),{closureStatus:'none'}));
 console.log('PASS rules: public-first create, exact media URL, immutable photos, private evidence, no client strikes, revoked image access, tombstone recreation blocked, closed-account writes blocked');
 }finally{await env.cleanup();}
})().catch(e=>{console.error(e);process.exitCode=1;});
