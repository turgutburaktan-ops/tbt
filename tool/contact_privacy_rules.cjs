// Apply to a reviewed live policy only after the contact-free client is available.
const fs=require('node:fs');
function patchContactRules(source) {
 let rules=source;
 for(const name of ['safeUserCreate','safeUserUpdate']) {
  const start=rules.indexOf(`    function ${name}(uid) {`);
  if(start<0)throw Error('Missing profile access helper: '+name);
  const end=rules.indexOf('\n    }',start);
  if(end<0)throw Error('Unexpected profile helper structure');
  let block=rules.slice(start,end);
  if(!block.includes("'email','phoneNumber','verifiedPhoneNumber'")) {
   const marker=name==='safeUserCreate'?"'isCreator','creatorTier'":"'uid','isCreator','creatorTier'";
   if(block.split(marker).length!==2)throw Error('Unknown protected profile field list');
   block=block.replace(marker,"'email','phoneNumber','verifiedPhoneNumber',"+marker);
   rules=rules.slice(0,start)+block+rules.slice(end);
  }
 }
 const anchor='    match /users/{uid} {';
 const privateRule='    match /private_users/{uid} { allow read: if isSelf(uid) || isAdmin(); allow write: if false; }\n';
 if(!rules.includes('match /private_users/{uid}')) {
  if(rules.split(anchor).length!==2)throw Error('Unknown profile match structure');
  rules=rules.replace(anchor,privateRule+anchor);
 }else if(!rules.includes(privateRule.trim()))throw Error('Unreviewed existing private contact rule');
 return rules;
}
module.exports={patchContactRules};
if(require.main===module)fs.writeFileSync('firestore.rules',patchContactRules(fs.readFileSync('firestore.rules','utf8')));
