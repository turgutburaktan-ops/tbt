const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {applyStrictPatches} = require('../../tool/strict_rule_patches.cjs');
test('refined rule patches accept original, intermediate and final forms without accepting drift', () => {
  const patches = [{old: 'A B C', new: 'A protected C'}, {old: 'protected', new: 'protected immutable'}];
  for (const source of ['A B C', 'A protected C', 'A protected immutable C']) {
    assert.equal(applyStrictPatches(source, patches), 'A protected immutable C');
  }
  assert.throws(() => applyStrictPatches('A unexpected C', patches), /does not match/);
  assert.throws(() => applyStrictPatches('A B C A B C', patches), /does not match/);
});
test('current security rules are an idempotent result of all reviewed patches', () => {
  const root = path.resolve(__dirname, '../..');
  const current = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');
  const patches = JSON.parse(fs.readFileSync(path.join(root, 'tool/security_rules_patch.json'), 'utf8')).firestore;
  assert.equal(applyStrictPatches(current, patches), current);
});
test('reviewed encrypted-storage addition is idempotent and rejects a missing anchor',()=>{
 const root=path.resolve(__dirname,'../..');
 const current=fs.readFileSync(path.join(root,'storage.rules'),'utf8');
 const patches=JSON.parse(fs.readFileSync(path.join(root,'tool/security_rules_patch.json'),'utf8')).e2eeStorage;
 assert.equal(applyStrictPatches(current,patches),current);
 assert.throws(()=>applyStrictPatches('unreviewed policy',patches),/does not match/);
});
