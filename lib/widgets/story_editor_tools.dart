import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StoryEditorTool {
  const StoryEditorTool(this.icon, this.label, this.onSelected, {this.enabled = true});
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool enabled;
}

/// Select first, dismiss the panel, then open the selected editor.
Future<void> showStoryEditorTools(BuildContext context, List<StoryEditorTool> tools) async {
  final selected = await showModalBottomSheet<StoryEditorTool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .72),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Story araçları', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final tool in tools)
              ListTile(
                enabled: tool.enabled,
                leading: Icon(tool.icon),
                title: Text(tool.label),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: tool.enabled ? () => Navigator.pop(sheetContext, tool) : null,
              ),
          ]),
        ),
      ),
    ),
  );
  if (context.mounted && selected != null) selected.onSelected();
}
