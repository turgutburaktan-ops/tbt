String eventStartLabel(DateTime value, {DateTime? now}) {
  final d = value.toLocal(), n = (now ?? DateTime.now()).toLocal();
  final day = DateTime(n.year, n.month, n.day);
  final tomorrow = DateTime(n.year, n.month, n.day + 1);
  final date = DateTime(d.year, d.month, d.day);
  final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final prefix = date == day ? 'Bugün' : date == tomorrow ? 'Yarın' : '${d.day}.${d.month}${d.year != n.year ? '.${d.year}' : ''}';
  return '$prefix $time';
}
