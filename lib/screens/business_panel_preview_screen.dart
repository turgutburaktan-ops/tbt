import 'package:flutter/material.dart';

import 'admin_business_sandbox_screen.dart';

class BusinessPanelPreviewScreen extends StatelessWidget {
  final String venueName;
  final String category;

  const BusinessPanelPreviewScreen({
    super.key,
    required this.venueName,
    required this.category,
  });

  @override
  Widget build(BuildContext context) =>
      AdminBusinessSandboxScreen(venueName: venueName, category: category);
}
