String normalizeText(String input) {
  var s = input.toLowerCase();
  s = s
      .replaceAll('\u2019', "'")
      .replaceAll('\u2018', "'")
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u0640', '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

String twoDigits(int n) => n.toString().padLeft(2, '0');

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${twoDigits(h)}:${twoDigits(m)}:${twoDigits(s)}';
  return '${twoDigits(m)}:${twoDigits(s)}';
}

String formatClock(DateTime t) =>
    '${twoDigits(t.hour)}:${twoDigits(t.minute)}:${twoDigits(t.second)}';

String truncateText(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}...';

int clampInt(int value, int lo, int hi) =>
    value < lo ? lo : (value > hi ? hi : value);
