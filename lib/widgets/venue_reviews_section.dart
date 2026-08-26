import 'package:flutter/material.dart';

import '../services/venue_rating_service.dart';
import '../theme/app_theme.dart';

class VenueReviewsSection extends StatefulWidget {
  final String category;
  final String venueId;
  final String venueName;

  const VenueReviewsSection({
    super.key,
    required this.category,
    required this.venueId,
    required this.venueName,
  });

  @override
  State<VenueReviewsSection> createState() => _VenueReviewsSectionState();
}

class _VenueReviewsSectionState extends State<VenueReviewsSection> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _saving = false;
  bool _sortHelpful = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_rating == 0) {
      _message('Önce 1–5 arasında puan seç.');
      return;
    }
    setState(() => _saving = true);
    try {
      await VenueRatingService.instance.submitReview(
        category: widget.category,
        venueId: widget.venueId,
        venueName: widget.venueName,
        rating: _rating,
        comment: _commentController.text,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _rating = 0;
        _saving = false;
      });
      _message('Değerlendirmen yayınlandı.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteMine() async {
    try {
      await VenueRatingService.instance.deleteMyReview(
        category: widget.category,
        venueId: widget.venueId,
      );
      if (mounted) _message('Değerlendirmen silindi.');
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _helpful(VenueReview review) async {
    try {
      await VenueRatingService.instance.toggleHelpful(
        category: widget.category,
        venueId: widget.venueId,
        reviewUserId: review.userId,
      );
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _report(VenueReview review) async {
    try {
      await VenueRatingService.instance.reportReview(
        category: widget.category,
        venueId: widget.venueId,
        reviewUserId: review.userId,
      );
      if (mounted) _message('Yorum incelenmek üzere bildirildi.');
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _dateLabel(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VenueRatingSummary>(
      stream: VenueRatingService.instance.watchSummary(
        widget.category,
        widget.venueId,
      ),
      initialData: VenueRatingSummary.empty,
      builder: (context, summarySnapshot) {
        final summary = summarySnapshot.data ?? VenueRatingSummary.empty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFC857),
                  size: 24,
                ),
                const SizedBox(width: 7),
                Text(
                  summary.count == 0
                      ? 'Henüz değerlendirme yok'
                      : '${summary.average.toStringAsFixed(1)} · ${summary.count} değerlendirme',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.mine == null
                        ? 'Puan ver ve yorum yaz'
                        : 'Değerlendirmeni güncelle',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      final active =
                          star <=
                          (_rating == 0 ? (summary.mine ?? 0) : _rating);
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _rating = star),
                        icon: Icon(
                          active
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFFFC857),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 700,
                    decoration: const InputDecoration(
                      hintText: 'Deneyimini yaz…',
                      helperText: 'Ağır küfür, hakaret ve saldırgan ifadeler yayınlanmaz.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _saving ? 'Kaydediliyor…' : 'Değerlendirmeyi Yayınla',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Yorumlar',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _sortHelpful = !_sortHelpful),
                  child: Text(_sortHelpful ? 'En faydalı' : 'En yeni'),
                ),
              ],
            ),
            StreamBuilder<List<VenueReview>>(
              stream: VenueRatingService.instance.watchReviews(
                widget.category,
                widget.venueId,
              ),
              initialData: const [],
              builder: (context, snapshot) {
                final reviews = List<VenueReview>.from(
                  snapshot.data ?? const [],
                );
                if (_sortHelpful) {
                  reviews.sort(
                    (a, b) => b.helpfulCount.compareTo(a.helpfulCount),
                  );
                } else {
                  reviews.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                }
                if (reviews.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'İlk yorumu sen yaz.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return Column(
                  children: reviews.map((review) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  review.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                _dateLabel(review.updatedAt),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10.5,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'delete') _deleteMine();
                                  if (value == 'report') _report(review);
                                },
                                itemBuilder: (_) => [
                                  if (review.mine)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Yorumumu sil'),
                                    )
                                  else
                                    const PopupMenuItem(
                                      value: 'report',
                                      child: Text('Şikâyet et'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 15,
                                color: const Color(0xFFFFC857),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            review.comment,
                            style: const TextStyle(height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: review.mine
                                ? null
                                : () => _helpful(review),
                            icon: Icon(
                              review.helpfulByMe
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_outlined,
                              size: 17,
                            ),
                            label: Text(
                              review.helpfulCount == 0
                                  ? 'Faydalı'
                                  : 'Faydalı · ${review.helpfulCount}',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
