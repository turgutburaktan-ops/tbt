import 'package:flutter/material.dart';

import 'home_discover_screen.dart';

class GlobalSearchScreen extends StatelessWidget {
  const GlobalSearchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TBT’de Ara')),
    body: const HomeDiscoverScreen(),
  );
}
