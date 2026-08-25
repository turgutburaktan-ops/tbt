import 'package:flutter/material.dart';

import '../screens/retention_hub_screen.dart';

class RetentionHubQuickEntry extends StatelessWidget {
  final Widget child;
  const RetentionHubQuickEntry({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          Positioned(
            left: 14,
            bottom: 132,
            child: SafeArea(
              top: false,
              child: Material(
                color: const Color(0xFF141821),
                elevation: 8,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RetentionHubScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF39DDE8).withValues(alpha: .45)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 17, color: Color(0xFF39DDE8)),
                        SizedBox(width: 6),
                        Text('Bugün TBT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
