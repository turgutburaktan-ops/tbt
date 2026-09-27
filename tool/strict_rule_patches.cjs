function applyStrictPatches(source, patches) {
  for (let i = 0; i < patches.length; i++) {
    const patch = patches[i];
    // Later patches may refine a block introduced by an earlier patch.
    // Recognize that exact final block on retries without accepting drift.
    let final = patch.new;
    for (const next of patches.slice(i + 1)) final = final.replace(next.old, next.new);
    if (source.includes(final) || source.includes(patch.new)) continue;
    if (source.split(patch.old).length !== 2) throw Error('Live policy does not match reviewed patch ' + i);
    source = source.replace(patch.old, patch.new);
  }
  return source;
}
module.exports = {applyStrictPatches};
