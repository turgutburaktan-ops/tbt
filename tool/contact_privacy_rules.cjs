// Release-coupled rule transform: old clients still put contact fields in /users.
// Apply and test this transform, migrate existing fields, then publish these rules
// only as part of the contact-free client rollout.
const fs=require('node:fs');
let rules=fs.readFileSync('firestore.rules','utf8');
for(const marker of ["'isCreator','creatorTier'", "'uid','isCreator','creatorTier'"]){
 const replacement="'email','phoneNumber','verifiedPhoneNumber',"+marker;
 if(!rules.includes(replacement))rules=rules.replace(marker,replacement);
}
const anchor='    match /users/{uid} {';
const privateRule="    match /private_users/{uid} { allow read: if isSelf(uid) || isAdmin(); allow write: if false; }\n";
if(!rules.includes('match /private_users/{uid}'))rules=rules.replace(anchor,privateRule+anchor);
fs.writeFileSync('firestore.rules',rules);
