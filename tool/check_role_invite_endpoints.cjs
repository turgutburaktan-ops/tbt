const assert = require('node:assert/strict');
const base = 'https://europe-west1-en-iyi-cekim-noktasi.cloudfunctions.net/';
(async () => {
  for (const name of ['creatorAdmin', 'createRoleInvite', 'redeemRoleInvite', 'getRoleInvitePreview']) {
    const response = await fetch(base + name, {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({data: {}}), signal: AbortSignal.timeout(30000),
    });
    const body = await response.json();
    if (name === 'getRoleInvitePreview') {
      assert.equal(response.status, 200);
      assert.equal(body.result.valid, false);
      assert.equal(body.result.reason, 'invalid');
    } else {
      assert.equal(response.status, 401, name);
      assert.equal(body.error.status, 'UNAUTHENTICATED', name);
    }
    console.log(name + ': callable reachable; validation/authentication enforced');
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
