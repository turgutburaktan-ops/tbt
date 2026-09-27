from pathlib import Path


def patch_ai_service() -> None:
    path = Path('lib/services/ai_service.dart')
    text = path.read_text()

    if 'String? customPrompt,' not in text:
        text = text.replace(
            '    String? mode,\n  }) async {',
            '    String? mode,\n    String? customPrompt,\n  }) async {',
            1,
        )

    marker = "    request.fields['action'] = action;\n"
    if "request.fields['prompt']" not in text:
        text = text.replace(
            marker,
            marker + "    if (customPrompt != null && customPrompt.trim().isNotEmpty) {\n      request.fields['prompt'] = customPrompt.trim();\n    }\n",
            1,
        )

    path.write_text(text)


def patch_ai_edit_screen() -> None:
    path = Path('lib/screens/ai_edit_screen.dart')
    text = path.read_text()

    if 'customPrompt,' not in text[text.find('enum AiEditAction'):text.find('class AiEditScreen')]:
        text = text.replace(
            '  removeObject,\n}',
            '  removeObject,\n  customPrompt,\n}',
            1,
        )

    if 'String? customPrompt,' not in text[text.find('Future<void> _runEdit'):text.find('String _actionName')]:
        text = text.replace(
            '    Offset? normalizedPoint,\n  }) async {',
            '    Offset? normalizedPoint,\n    String? customPrompt,\n  }) async {',
            1,
        )
        text = text.replace(
            '        mode: widget.captureMode,\n      );',
            '        mode: widget.captureMode,\n        customPrompt: customPrompt,\n      );',
            1,
        )

    if "return 'custom_prompt';" not in text:
        text = text.replace(
            "      case AiEditAction.removeObject:\n        return 'remove_object';\n",
            "      case AiEditAction.removeObject:\n        return 'remove_object';\n      case AiEditAction.customPrompt:\n        return 'custom_prompt';\n",
            1,
        )

    if 'Future<void> _openCustomPrompt() async {' not in text:
        insert_before = '  String _friendlyError(Object e) {'
        method = r'''  Future<void> _openCustomPrompt() async {
    if (_processing) return;
    final controller = TextEditingController();
    final prompt = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            18 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFFC107)),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Yapay Zekaya Tarif Et',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Fotoğrafta neyi değiştirmek istediğini doğal cümleyle yaz.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 600,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Örn: Gökyüzünü daha dramatik yap, beni ve binayı değiştirme.',
                  filled: true,
                  fillColor: const Color(0xFF151A22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PromptChip(text: 'Gökyüzünü güzelleştir', controller: controller),
                  _PromptChip(text: 'Arka planı sadeleştir', controller: controller),
                  _PromptChip(text: 'Daha sıcak gün batımı', controller: controller),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) return;
                    Navigator.pop(sheetContext, value);
                  },
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text(
                    'AI ile Uygula',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (!mounted || prompt == null || prompt.trim().isEmpty) return;
    await _runEdit(AiEditAction.customPrompt, customPrompt: prompt.trim());
  }

'''
        text = text.replace(insert_before, method + insert_before, 1)

    if "label: 'AI\\nTarif Et'" not in text:
        anchor = "                  _EditTool(\n                    icon: Icons.light_mode_outlined,\n                    label: 'Işık',\n                    onTap: () => _runEdit(AiEditAction.fixLight),\n                  ),\n"
        addition = anchor + "                  _EditTool(\n                    icon: Icons.chat_bubble_outline_rounded,\n                    label: 'AI\\nTarif Et',\n                    onTap: _openCustomPrompt,\n                  ),\n"
        if anchor not in text:
            raise SystemExit('AI edit tool anchor not found')
        text = text.replace(anchor, addition, 1)

    if "case AiEditAction.customPrompt:" not in text[text.find('String _processingText()'):]:
        text = text.replace(
            "      case AiEditAction.removeObject:\n        return 'Nesne kaldırılıyor...';\n",
            "      case AiEditAction.removeObject:\n        return 'Nesne kaldırılıyor...';\n      case AiEditAction.customPrompt:\n        return 'Tarifin AI ile uygulanıyor...';\n",
            1,
        )

    if 'class _PromptChip extends StatelessWidget' not in text:
        marker = 'class _TargetMarker extends StatelessWidget {'
        widget = r'''class _PromptChip extends StatelessWidget {
  final String text;
  final TextEditingController controller;

  const _PromptChip({required this.text, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      backgroundColor: const Color(0xFF151A22),
      side: const BorderSide(color: Colors.white12),
      label: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      onPressed: () {
        controller.text = text;
        controller.selection = TextSelection.collapsed(offset: controller.text.length);
      },
    );
  }
}

'''
        text = text.replace(marker, widget + marker, 1)

    path.write_text(text)


def main() -> None:
    patch_ai_service()
    patch_ai_edit_screen()
    print('Custom AI photo prompt UI applied')


if __name__ == '__main__':
    main()
