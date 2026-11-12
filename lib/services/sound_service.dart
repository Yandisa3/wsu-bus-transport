import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Generates short beep tones at runtime (no sound asset files needed)
/// and plays them through the device speaker.
class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playSuccess() =>
      _play(const [_Beep(frequency: 880, durationMs: 160)]);

  static Future<void> playError() => _play(const [
    _Beep(frequency: 280, durationMs: 180),
    _Beep(frequency: 0, durationMs: 70),
    _Beep(frequency: 280, durationMs: 180),
  ]);

  static Future<void> playWarning() =>
      _play(const [_Beep(frequency: 520, durationMs: 220)]);

  static Future<void> _play(List<_Beep> beeps) async {
    final bytes = _buildWav(beeps);
    await _player.stop();
    await _player.play(BytesSource(bytes));
  }

  static Uint8List _buildWav(List<_Beep> beeps) {
    const sampleRate = 44100;
    final samples = <int>[];

    for (final beep in beeps) {
      final count = (sampleRate * beep.durationMs / 1000).round();
      for (var i = 0; i < count; i++) {
        if (beep.frequency == 0) {
          samples.add(0);
        } else {
          final t = i / sampleRate;
          final value = (32000 * sin(2 * pi * beep.frequency * t)).round();
          samples.add(value);
        }
      }
    }

    final dataLength = samples.length * 2;
    final out = BytesBuilder();

    void u32(int v) => out.add([
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ]);
    void u16(int v) => out.add([v & 0xff, (v >> 8) & 0xff]);

    out.add('RIFF'.codeUnits);
    u32(36 + dataLength);
    out.add('WAVE'.codeUnits);
    out.add('fmt '.codeUnits);
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2);
    u16(2);
    u16(16);
    out.add('data'.codeUnits);
    u32(dataLength);

    for (final s in samples) {
      out.add([s & 0xff, (s >> 8) & 0xff]);
    }

    return out.toBytes();
  }
}

class _Beep {
  final double frequency;
  final int durationMs;
  const _Beep({required this.frequency, required this.durationMs});
}
