import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event_ticket.dart';
import '../services/event_ticket_service.dart';

class EventTicketsScreen extends StatelessWidget {
  const EventTicketsScreen({super.key});

  String _statusLabel(EventTicketStatus status) => switch (status) {
        EventTicketStatus.pendingPayment => 'Ödeme bekliyor',
        EventTicketStatus.active => 'Aktif',
        EventTicketStatus.used => 'Kullanıldı',
        EventTicketStatus.cancelled => 'İptal edildi',
        EventTicketStatus.refunded => 'İade edildi',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biletlerim')),
      body: StreamBuilder<List<EventTicket>>(
        stream: EventTicketService.instance.watchMyTickets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF16B8A6)));
          }
          final tickets = snapshot.data ?? const <EventTicket>[];
          if (tickets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.confirmation_number_outlined,
                        size: 62, color: Colors.white30),
                    SizedBox(height: 12),
                    Text('Henüz biletin yok',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Bir etkinliğe katıldığında biletin burada görünecek.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return Card(
                color: const Color(0xFF11181D),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0x228B5CF6),
                    foregroundColor: const Color(0xFF16B8A6),
                    child: const Icon(Icons.confirmation_number_outlined),
                  ),
                  title: Text(ticket.eventTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    ticket.isPaidEvent
                        ? '${(ticket.priceMinor / 100).toStringAsFixed(2)} ${ticket.currency} • ${_statusLabel(ticket.status)}'
                        : 'Ücretsiz • ${_statusLabel(ticket.status)}',
                  ),
                  trailing: ticket.isActive
                      ? const Icon(Icons.qr_code_2_rounded,
                          color: Color(0xFF16B8A6))
                      : null,
                  onTap: ticket.isActive
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TicketQrScreen(ticket: ticket)))
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TicketQrScreen extends StatelessWidget {
  final EventTicket ticket;
  const TicketQrScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biletim')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ticket.eventTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                  ticket.isPaidEvent
                      ? '${(ticket.priceMinor / 100).toStringAsFixed(2)} ${ticket.currency}'
                      : 'Ücretsiz Bilet',
                  style: const TextStyle(
                      color: Color(0xFF16B8A6), fontWeight: FontWeight.w800)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22)),
                child: QrImageView(data: ticket.qrToken, size: 240),
              ),
              const SizedBox(height: 16),
              const Text('Girişte bu QR kodu organizatöre göster.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketScannerScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  const TicketScannerScreen(
      {super.key, required this.eventId, required this.eventTitle});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  bool _processing = false;
  bool _done = false;

  Future<void> _handle(BarcodeCapture capture) async {
    if (_processing || _done) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() => _processing = true);
    try {
      await EventTicketService.instance
          .markUsed(qrToken: raw, eventId: widget.eventId);
      if (!mounted) return;
      setState(() => _done = true);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bilet doğrulandı ve giriş yapıldı.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.eventTitle} • Bilet Kontrol')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handle),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF16B8A6), width: 3),
                  borderRadius: BorderRadius.circular(22)),
            ),
          ),
          if (_processing)
            const Positioned.fill(
                child: ColoredBox(
                    color: Colors.black45,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF16B8A6))))),
          if (_done)
            Positioned(
              left: 20,
              right: 20,
              bottom: 32,
              child: FilledButton.icon(
                onPressed: () => setState(() => _done = false),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Sonraki bileti okut'),
              ),
            ),
        ],
      ),
    );
  }
}
