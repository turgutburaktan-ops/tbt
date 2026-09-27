import 'package:flutter/material.dart';
import '../models/route_access.dart';

class RouteAccessSettings extends StatelessWidget {
  const RouteAccessSettings({super.key, required this.value, required this.onChanged,
    required this.startAt, required this.pickDate, this.busy = false});
  final RouteAccess value;
  final ValueChanged<RouteAccess> onChanged;
  final DateTime? startAt;
  final Future<DateTime?> Function() pickDate;
  final bool busy;

  Future<void> _change(BuildContext context, RouteAccess next, {bool visibilityChanged = false}) async {
    if (!next.compatible) {
      final label = RouteAccess.labels[visibilityChanged ? next.visibility : next.audience];
      final accepted = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Görünürlük ve katılım'),
        content: Text(visibilityChanged
            ? 'Bu görünürlükte katılımı da $label olarak sınırlandırmak gerekiyor.'
            : '$label seçeneğinin katılabilmesi için görünürlüğü de $label yapman gerekiyor.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Geri dön')),
          FilledButton(onPressed: () => Navigator.pop(c, true),
            child: Text(visibilityChanged ? 'Katılımı sınırlandır' : 'Görünürlüğü $label yap'))],
      ));
      if (accepted != true || !context.mounted) return;
      next = RouteAccess(visibility: visibilityChanged ? next.visibility : next.audience,
        audience: visibilityChanged ? next.visibility : next.audience,
        enabled: next.enabled, approval: next.approval);
    }
    if (next.enabled && (startAt == null || !startAt!.isAfter(DateTime.now()))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Katılım için tarih ve saat seç.')));
      final date = await pickDate();
      if (!context.mounted || date == null || !date.isAfter(DateTime.now())) return;
    }
    onChanged(next);
  }
  Future<void> _audience(BuildContext context, bool visibility) async {
    final selected = await showModalBottomSheet<String>(context: context, useSafeArea: true,
      isScrollControlled: true, showDragHandle: true, builder: (c) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(visibility ? 'Rotayı kimler görebilir?' : 'Kimler katılabilir?',
            style: const TextStyle(fontWeight: FontWeight.bold))),
          for (final e in RouteAccess.labels.entries) ListTile(
            title: Text(e.value),
            trailing: Icon((visibility ? value.visibility : value.audience) == e.key
                ? Icons.radio_button_checked : Icons.radio_button_off),
            onTap: () => Navigator.pop(c, e.key)),
        ])));
    if (selected == null || !context.mounted) return;
    await _change(context, RouteAccess(
      visibility: visibility ? selected : value.visibility,
      audience: visibility ? value.audience : selected,
      enabled: value.enabled,
      approval: !visibility && value.audience == 'private' ? true : value.approval,
    ), visibilityChanged: visibility);
  }
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    ListTile(title: const Text('Rotayı kimler görebilir?'),
      subtitle: Text(RouteAccess.labels[value.visibility] ?? 'Davetliler'),
      trailing: const Icon(Icons.chevron_right), onTap: busy ? null : () => _audience(context, true)),
    SwitchListTile(title: const Text('Katılıma aç'),
      subtitle: const Text('Kapalıyken rota paylaşılabilir; katılım alınmaz.'),
      value: value.enabled, onChanged: busy ? null : (v) => _change(context, RouteAccess(
        visibility: value.visibility, audience: value.audience, approval: value.approval, enabled: v))),
    if (value.enabled) ...[
      ListTile(title: const Text('Kimler katılabilir?'),
        subtitle: Text(RouteAccess.labels[value.audience] ?? 'Davetliler'),
        trailing: const Icon(Icons.chevron_right), onTap: busy ? null : () => _audience(context, false)),
      if (value.audience == 'private')
        const ListTile(subtitle: Text('Davet ettiğin kişiler kabul edince katılır. Ayrıca onayın gerekmez.'))
      else SwitchListTile(title: const Text('Katılım için onayım gereksin'),
        subtitle: Text(value.approval ? 'İstekleri sen onaylarsın.' : 'Uygun kişiler doğrudan katılır.'),
        value: value.approval, onChanged: busy ? null : (v) => onChanged(RouteAccess(
          visibility: value.visibility, audience: value.audience, enabled: value.enabled, approval: v))),
    ],
  ]);
}
