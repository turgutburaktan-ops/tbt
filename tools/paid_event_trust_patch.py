from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1))


# SocialEvent model trust fields.
replace_once(
    'lib/models/social_event.dart',
    "  final String? externalProductId;\n",
    "  final String? externalProductId;\n  final String trustStatus;\n  final String salesStatus;\n  final String riskLevel;\n  final int reportCount;\n  final String paymentReleaseStatus;\n",
)
replace_once(
    'lib/models/social_event.dart',
    "    this.externalProductId,\n  });\n",
    "    this.externalProductId,\n    this.trustStatus = 'new_host',\n    this.salesStatus = 'blocked',\n    this.riskLevel = 'low',\n    this.reportCount = 0,\n    this.paymentReleaseStatus = 'not_applicable',\n  });\n",
)
replace_once(
    'lib/models/social_event.dart',
    "      externalProductId: data['externalProductId']?.toString(),\n    );\n",
    "      externalProductId: data['externalProductId']?.toString(),\n      trustStatus: (data['trustStatus'] ?? 'new_host').toString(),\n      salesStatus: (data['salesStatus'] ?? 'blocked').toString(),\n      riskLevel: (data['riskLevel'] ?? 'low').toString(),\n      reportCount: ((data['reportCount'] as num?)?.toInt() ?? 0).clamp(0, 2147483647),\n      paymentReleaseStatus: (data['paymentReleaseStatus'] ??\n              (access == EventAccessType.paid ? 'held' : 'not_applicable'))\n          .toString(),\n    );\n",
)

# Creation checks and safe trust defaults.
replace_once(
    'lib/services/social_event_service.dart',
    "import 'event_ticket_service.dart';\n",
    "import 'event_ticket_service.dart';\nimport 'event_trust_service.dart';\n",
)
replace_once(
    'lib/services/social_event_service.dart',
    "    if (accessType == EventAccessType.paid && ticketPriceMinor <= 0)\n      throw Exception(\n          'Ücretli etkinlik için geçerli bir bilet fiyatı yazmalısın.');\n\n    final ref = _firestore.collection(collection).doc();\n",
    "    if (accessType == EventAccessType.paid && ticketPriceMinor <= 0)\n      throw Exception(\n          'Ücretli etkinlik için geçerli bir bilet fiyatı yazmalısın.');\n\n    if (accessType == EventAccessType.paid) {\n      final eligibility = await EventTrustService.instance.paidEventEligibility();\n      if (!eligibility.allowed) throw Exception(eligibility.reason);\n    }\n\n    final ref = _firestore.collection(collection).doc();\n",
)
replace_once(
    'lib/services/social_event_service.dart',
    "      'externalProductId': null,\n      'createdAt': FieldValue.serverTimestamp(),\n",
    "      'externalProductId': null,\n      'trustStatus': accessType == EventAccessType.paid\n          ? 'pending_review'\n          : 'new_host',\n      'salesStatus': accessType == EventAccessType.paid ? 'blocked' : 'not_required',\n      'riskLevel': accessType == EventAccessType.paid ? 'medium' : 'low',\n      'reportCount': 0,\n      'paymentReleaseStatus': accessType == EventAccessType.paid ? 'held' : 'not_applicable',\n      'createdAt': FieldValue.serverTimestamp(),\n",
)
replace_once(
    'lib/services/social_event_service.dart',
    "      if (accessType == EventAccessType.paid.name &&\n          paymentStatus != EventPaymentStatus.enabled.name) {\n",
    "      final trustStatus = (data['trustStatus'] ?? 'new_host').toString();\n      final salesStatus = (data['salesStatus'] ?? 'blocked').toString();\n      if (accessType == EventAccessType.paid.name &&\n          (paymentStatus != EventPaymentStatus.enabled.name ||\n              trustStatus != 'approved' ||\n              salesStatus != 'open')) {\n",
)
replace_once(
    'lib/services/social_event_service.dart',
    "        throw Exception(\n            'Bu etkinlik ücretli. Online ödeme ve bilet satışı yakında aktif olacak.');\n",
    "        throw Exception(\n            'Bu ücretli etkinlik güvenlik onayı tamamlanmadan bilet satışına açılamaz.');\n",
)

# Social events UI: eligibility notice, trust badge and report option.
replace_once(
    'lib/screens/social_events_screen.dart',
    "import '../services/social_event_service.dart';\n",
    "import '../services/social_event_service.dart';\nimport '../services/event_trust_service.dart';\n",
)
replace_once(
    'lib/screens/social_events_screen.dart',
    "                  if (accessType == EventAccessType.paid) ...[\n                    const SizedBox(height: 12),\n                    TextField(\n",
    "                  if (accessType == EventAccessType.paid) ...[\n                    const SizedBox(height: 12),\n                    Container(\n                      width: double.infinity,\n                      padding: const EdgeInsets.all(12),\n                      decoration: BoxDecoration(\n                        color: const Color(0x1416B8A6),\n                        borderRadius: BorderRadius.circular(14),\n                        border: Border.all(color: const Color(0x5516B8A6)),\n                      ),\n                      child: const Text(\n                        'Ücretli etkinlikler güvenlik incelemesinden geçer. İlk satış, etkinlik onaylanmadan açılamaz; ödeme etkinlik gerçekleşene kadar beklemede tutulur.',\n                        style: TextStyle(fontSize: 12, height: 1.35),\n                      ),\n                    ),\n                    const SizedBox(height: 12),\n                    TextField(\n",
)
replace_once(
    'lib/screens/social_events_screen.dart',
    "                                await SocialEventService.instance.create(\n",
    "                                if (accessType == EventAccessType.paid) {\n                                  final eligibility = await EventTrustService\n                                      .instance\n                                      .paidEventEligibility();\n                                  if (!eligibility.allowed) {\n                                    throw Exception(eligibility.reason);\n                                  }\n                                }\n                                await SocialEventService.instance.create(\n",
)

print('Paid event trust patch applied.')
