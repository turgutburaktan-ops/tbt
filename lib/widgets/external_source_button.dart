import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/external_source_url.dart';
class ExternalSourceButton extends StatelessWidget {
  const ExternalSourceButton({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    final source = externalSourceUrl(url);
    if (source == null) return const SizedBox.shrink();
    return TextButton.icon(icon: const Icon(Icons.open_in_new, size: 18), label: Text(source.host.contains('instagram') ? 'Instagram’da aç' : 'X’te aç'), onPressed: () async {
      try {
        if (!await launchUrl(source, mode: LaunchMode.externalApplication)) throw Exception('Bağlantı açılamadı.');
      } catch (_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
      }
    });
  }
}
