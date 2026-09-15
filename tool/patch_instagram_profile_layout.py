#!/usr/bin/env python3
from pathlib import Path
import re

p = Path('lib/screens/profile_page_v2.dart')
s = p.read_text(encoding='utf-8')

if "package:flutter/services.dart" not in s:
    s = s.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n")

# Add share helper before build.
needle = "  @override\n  Widget build(BuildContext context) {\n"
helper = """  Future<void> _shareProfile(String displayName) async {\n    final handle = displayName.trim().isEmpty ? 'Fotoğrafçı' : displayName.trim();\n    await Clipboard.setData(ClipboardData(text: '@$handle'));\n    if (!mounted) return;\n    ScaffoldMessenger.of(context)\n      ..hideCurrentSnackBar()\n      ..showSnackBar(const SnackBar(content: Text('Profil adı panoya kopyalandı.')));\n  }\n\n  void _showPostPreview(String imageUrl) {\n    if (imageUrl.isEmpty) return;\n    showDialog<void>(\n      context: context,\n      barrierColor: Colors.black87,\n      builder: (dialogContext) => Dialog(\n        backgroundColor: Colors.transparent,\n        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 54),\n        child: Stack(\n          children: [\n            ClipRRect(\n              borderRadius: BorderRadius.circular(18),\n              child: AspectRatio(\n                aspectRatio: 1,\n                child: Image.network(\n                  imageUrl,\n                  fit: BoxFit.contain,\n                  errorBuilder: (_, __, ___) => const ColoredBox(\n                    color: Color(0xFF141126),\n                    child: Center(child: Icon(Icons.broken_image_outlined, size: 48)),\n                  ),\n                ),\n              ),\n            ),\n            Positioned(\n              right: 8,\n              top: 8,\n              child: IconButton.filledTonal(\n                onPressed: () => Navigator.pop(dialogContext),\n                icon: const Icon(Icons.close),\n              ),\n            ),\n          ],\n        ),\n      ),\n    );\n  }\n\n"""
if helper not in s:
    pos = s.find(needle, s.find('class _ProfileBodyState'))
    if pos != -1:
        s = s[:pos] + helper + s[pos:]

# Replace full-width edit button with Instagram-like dual compact buttons.
old = """                          const SizedBox(height: 14),\n                          SizedBox(\n                            width: double.infinity,\n                            height: 42,\n                            child: OutlinedButton.icon(\n                              onPressed: () => _editProfile(displayName, bio),\n                              icon: const Icon(Icons.edit_outlined, size: 18),\n                              label: const Text('Profili Düzenle'),\n                            ),\n                          ),\n"""
new = """                          const SizedBox(height: 14),\n                          Row(\n                            children: [\n                              Expanded(\n                                child: SizedBox(\n                                  height: 42,\n                                  child: FilledButton(\n                                    style: FilledButton.styleFrom(\n                                      backgroundColor: const Color(0xFF1B1728),\n                                      foregroundColor: Colors.white,\n                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),\n                                    ),\n                                    onPressed: () => _editProfile(displayName, bio),\n                                    child: const Text('Profili Düzenle', style: TextStyle(fontWeight: FontWeight.w800)),\n                                  ),\n                                ),\n                              ),\n                              const SizedBox(width: 8),\n                              Expanded(\n                                child: SizedBox(\n                                  height: 42,\n                                  child: FilledButton(\n                                    style: FilledButton.styleFrom(\n                                      backgroundColor: const Color(0xFF1B1728),\n                                      foregroundColor: Colors.white,\n                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),\n                                    ),\n                                    onPressed: () => _shareProfile(displayName),\n                                    child: const Text('Profili Paylaş', style: TextStyle(fontWeight: FontWeight.w800)),\n                                  ),\n                                ),\n                              ),\n                            ],\n                          ),\n"""
if old in s:
    s = s.replace(old, new, 1)

# Insert gallery tab strip before divider.
old_div = "                  const SliverToBoxAdapter(child: Divider(height: 1, color: Colors.white12)),\n"
new_div = """                  SliverToBoxAdapter(\n                    child: Container(\n                      height: 52,\n                      decoration: const BoxDecoration(\n                        border: Border(bottom: BorderSide(color: Colors.white12)),\n                      ),\n                      child: const Row(\n                        mainAxisAlignment: MainAxisAlignment.center,\n                        children: [\n                          SizedBox(\n                            width: 110,\n                            child: Column(\n                              mainAxisAlignment: MainAxisAlignment.center,\n                              children: [\n                                Icon(Icons.grid_on_rounded, color: Colors.white, size: 23),\n                                SizedBox(height: 10),\n                                SizedBox(height: 2, width: 70, child: ColoredBox(color: Color(0xFF8B5CF6))),\n                              ],\n                            ),\n                          ),\n                        ],\n                      ),\n                    ),\n                  ),\n"""
if old_div in s:
    s = s.replace(old_div, new_div, 1)

# Make the gallery square, tight and photo-only.
s = s.replace("padding: const EdgeInsets.fromLTRB(6, 6, 6, 100),", "padding: const EdgeInsets.fromLTRB(1, 2, 1, 100),", 1)
s = s.replace("crossAxisSpacing: 5,\n                          mainAxisSpacing: 5,\n                          childAspectRatio: 0.68,", "crossAxisSpacing: 2,\n                          mainAxisSpacing: 2,\n                          childAspectRatio: 1,", 1)

# Pass long-press preview callback.
old_tile_call = """                            return _PostTile(\n                              imageUrl: imageUrl,\n                              caption: caption,\n                              spotName: spotName,\n                              onTap: () => Navigator.push(\n"""
new_tile_call = """                            return _PostTile(\n                              imageUrl: imageUrl,\n                              caption: caption,\n                              spotName: spotName,\n                              onLongPress: () => _showPostPreview(imageUrl),\n                              onTap: () => Navigator.push(\n"""
if old_tile_call in s:
    s = s.replace(old_tile_call, new_tile_call, 1)

# Replace card-like post tile with clean square photo tile.
start = s.find('class _PostTile extends StatelessWidget')
end = s.find('class _Stat extends StatelessWidget')
if start != -1 and end != -1 and start < end:
    tile = """class _PostTile extends StatelessWidget {\n  final String imageUrl;\n  final String caption;\n  final String spotName;\n  final VoidCallback onTap;\n  final VoidCallback onLongPress;\n\n  const _PostTile({\n    required this.imageUrl,\n    required this.caption,\n    required this.spotName,\n    required this.onTap,\n    required this.onLongPress,\n  });\n\n  @override\n  Widget build(BuildContext context) {\n    return Material(\n      color: const Color(0xFF0F0B18),\n      clipBehavior: Clip.antiAlias,\n      child: InkWell(\n        onTap: onTap,\n        onLongPress: onLongPress,\n        child: imageUrl.isEmpty\n            ? const Center(child: Icon(Icons.image_outlined, color: Colors.white30))\n            : Image.network(\n                imageUrl,\n                width: double.infinity,\n                height: double.infinity,\n                fit: BoxFit.cover,\n                filterQuality: FilterQuality.medium,\n                errorBuilder: (_, __, ___) => const Center(\n                  child: Icon(Icons.broken_image_outlined, color: Colors.white30),\n                ),\n              ),\n      ),\n    );\n  }\n}\n\n"""
    s = s[:start] + tile + s[end:]

p.write_text(s, encoding='utf-8')
print('Patched profile_page_v2.dart')
