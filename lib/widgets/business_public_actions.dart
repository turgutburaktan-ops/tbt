import '../screens/business_reservation_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusinessPublicActions extends StatefulWidget {
  final String venueKey;
  final bool reservationsEnabled;
  const BusinessPublicActions({
    super.key,
    required this.venueKey,
    this.reservationsEnabled = true,
  });
  @override
  State<BusinessPublicActions> createState() => _BusinessPublicActionsState();
}

class _BusinessPublicActionsState extends State<BusinessPublicActions> {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  bool _following = false,
      _loading = true,
      _busy = false,
      _serverReservations = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _functions.httpsCallable('getBusinessFollowStatus').call({
          'venueKey': widget.venueKey,
        }),
        _functions.httpsCallable('getBusinessPublicFeatures').call({
          'venueKey': widget.venueKey,
        }),
        _functions.httpsCallable('recordBusinessMetric').call({
          'venueKey': widget.venueKey,
          'metric': 'profile_view',
        }),
      ]);
      final follow = Map<String, dynamic>.from(results[0].data as Map);
      final features = Map<String, dynamic>.from(results[1].data as Map);
      if (mounted)
        setState(() {
          _following = follow['following'] == true;
          _serverReservations = features['reservationsEnabled'] == true;
        });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _follow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = !_following;
      await _functions.httpsCallable('followBusiness').call({
        'venueKey': widget.venueKey,
        'follow': next,
      });
      if (mounted) setState(() => _following = next);
    } on FirebaseFunctionsException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'İşlem tamamlanamadı.')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reservation() async {
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>BusinessReservationScreen(venueKey:widget.venueKey)));
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null)
      return const SizedBox.shrink();
    final reservationVisible =
        widget.reservationsEnabled && _serverReservations;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loading || _busy ? null : _follow,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _following
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                  ),
            label: Text(_following ? 'Takip Ediliyor' : 'Takip Et'),
          ),
        ),
        if (reservationVisible) ...[
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _reservation,
              icon: const Icon(Icons.event_seat_outlined),
              label: const Text('Rezervasyon'),
            ),
          ),
        ],
      ],
    );
  }
}
