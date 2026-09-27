import 'package:flutter/material.dart';

import 'managed_venues_screen.dart';

// Keep existing deep links and notification routes pointing to native management.
class BusinessWebPortalScreen extends StatelessWidget {
  const BusinessWebPortalScreen({super.key});
  @override
  Widget build(BuildContext context) => const ManagedVenuesScreen();
}
