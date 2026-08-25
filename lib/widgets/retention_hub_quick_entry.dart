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
            left: 12,
            bottom: 122,
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RetentionHubScreen()),
                  ),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xE60D1118),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x5545E7F2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 15, color: Color(0xFF45E7F2)),
                        SizedBox(width: 5),
                        Text(
                          'Bugün TBT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: -.1,
                          ),
                        ),
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
