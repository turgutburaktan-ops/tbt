from pathlib import Path

# Disable paid events in the event creation UI.
p = Path('lib/screens/event_create_screen_v2.dart')
s = p.read_text()
s = s.replace("  final _price = TextEditingController();\n", '')
s = s.replace("  EventAccessType _accessType = EventAccessType.free;\n", '')
s = s.replace("      _price,\n", '')
s = s.replace("      final price = double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0;\n      if (_accessType == EventAccessType.paid) {\n        final eligibility = await EventTrustService.instance.paidEventEligibility();\n        if (!eligibility.allowed) throw Exception(eligibility.reason);\n        if (price <= 0) throw Exception('Geçerli bir bilet fiyatı yazmalısın.');\n      }\n\n", '')
s = s.replace("        accessType: _accessType,\n        ticketPriceMinor: (price * 100).round(),\n", "        accessType: EventAccessType.free,\n        ticketPriceMinor: 0,\n")
start = s.find("          SegmentedButton<EventAccessType>(")
if start >= 0:
    end_marker = "          if (_accessType == EventAccessType.paid) ...["
    paid_start = s.find(end_marker, start)
    if paid_start >= 0:
        # Find the next known field after the paid block.
        next_field = s.find("          const SizedBox(height: 12),\n          TextField(\n            controller: _city,", paid_start)
        if next_field >= 0:
            replacement = """          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.confirmation_number_outlined, color: AppColors.cyan),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ücretsiz etkinlik', style: TextStyle(fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text('Ücretli etkinlikler şimdilik kapalı.', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
"""
            s = s[:start] + replacement + s[next_field:]
p.write_text(s)

# Enforce free-only at the service layer too, so hidden/legacy callers cannot create paid events.
p = Path('lib/services/social_event_service.dart')
s = p.read_text()
old_guard = """    if (accessType == EventAccessType.paid && ticketPriceMinor <= 0) throw Exception('Ücretli etkinlik için geçerli bir bilet fiyatı yazmalısın.');
"""
new_guard = """    if (accessType == EventAccessType.paid) {
      throw Exception('Ücretli etkinlikler şimdilik kapalı.');
    }
"""
s = s.replace(old_guard, new_guard)
old_eligibility = """    if (accessType == EventAccessType.paid) {
      final eligibility = await EventTrustService.instance.paidEventEligibility();
      if (!eligibility.allowed) throw Exception(eligibility.reason);
    }

"""
s = s.replace(old_eligibility, '')
p.write_text(s)
