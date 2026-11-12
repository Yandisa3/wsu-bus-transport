class QrCodec {
  /// Encodes a rotating code: student number + the current time.
  /// A screenshot of this goes stale after [freshnessSeconds].
  static String encode(String studentNumber) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '$studentNumber:$ts';
  }

  /// Decodes a scanned code. Plain numbers (manager-printed QR codes, or
  /// manual entry) are treated as always fresh, for backward compatibility.
  /// Returns null if the code is malformed.
  static QrDecodeResult? decode(String raw, {int freshnessSeconds = 90}) {
    if (!raw.contains(':')) {
      return QrDecodeResult(studentNumber: raw, isFresh: true);
    }
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final ts = int.tryParse(parts[1]);
    if (ts == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final fresh = (now - ts).abs() <= freshnessSeconds;
    return QrDecodeResult(studentNumber: parts[0], isFresh: fresh);
  }
}

class QrDecodeResult {
  final String studentNumber;
  final bool isFresh;
  const QrDecodeResult({required this.studentNumber, required this.isFresh});
}
