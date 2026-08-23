import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_insights_screen.dart';
import 'moderation_center_screen.dart';

class AdminPortalScreen extends StatelessWidget {
  const AdminPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TBT Yönetim'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Genel'),
              Tab(icon: Icon(Icons.shield_outlined), text: 'Moderasyon'),
              Tab(icon: Icon(Icons.monitor_heart_outlined), text: 'Sağlık'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminDashboardScreen(embedded: true),
            ModerationCenterScreen(embedded: true),
            AdminInsightsScreen(),
          ],
        ),
      ),
    );
  }
}
