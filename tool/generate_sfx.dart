// Synthesizes the round's sound effects into assets/sfx.
//
// The effects are generated rather than sourced so the repository stays
// self-contained and every sound has an obvious provenance. Re-run with
// `merry run generate sfx` after editing a voice below.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 22050;

void main() {
  _write('select', _tone(frequency: 1180, seconds: 0.045, decay: 90));
  _write('move', _sweep(from: 620, to: 880, seconds: 0.11, decay: 26));
  _write('push', _sweep(from: 300, to: 150, seconds: 0.2, decay: 15));
  _write('win', _arpeggio(const [523.25, 659.25, 783.99], seconds: 0.14));
}

/// One decaying sine, the building block every voice is made of.
List<double> _tone({
  required double frequency,
  required double seconds,
  required double decay,
  double amplitude = 1,
}) {
  final count = (seconds * _sampleRate).round();
  return List<double>.generate(count, (index) {
    final t = index / _sampleRate;
    return amplitude *
        math.sin(2 * math.pi * frequency * t) *
        math.exp(-decay * t);
  });
}

/// A tone that slides in pitch, so a move reads as motion and a push as
/// something dropping.
List<double> _sweep({
  required double from,
  required double to,
  required double seconds,
  required double decay,
}) {
  final count = (seconds * _sampleRate).round();
  var phase = 0.0;
  return List<double>.generate(count, (index) {
    final t = index / _sampleRate;
    final frequency = from + (to - from) * (t / seconds);
    phase += 2 * math.pi * frequency / _sampleRate;
    return math.sin(phase) * math.exp(-decay * t);
  });
}

/// Three rising notes played in sequence, overlapping slightly so the win
/// lands as one gesture rather than three taps.
List<double> _arpeggio(List<double> frequencies, {required double seconds}) {
  final step = (seconds * _sampleRate * 0.7).round();
  final samples = <double>[];
  for (var note = 0; note < frequencies.length; note++) {
    final voice = _tone(
      frequency: frequencies[note],
      seconds: seconds * 2,
      decay: 12,
      amplitude: 0.8,
    );
    final offset = note * step;
    for (var index = 0; index < voice.length; index++) {
      final position = offset + index;
      while (samples.length <= position) {
        samples.add(0);
      }
      samples[position] += voice[index];
    }
  }
  return samples;
}

void _write(String name, List<double> samples) {
  final peak = samples.fold<double>(0, (best, s) => math.max(best, s.abs()));
  final scale = peak == 0 ? 0.0 : 0.86 / peak;
  final pcm = Int16List(samples.length);
  for (var index = 0; index < samples.length; index++) {
    // A short fade at the tail keeps the buffer from ending mid-cycle,
    // which would click on playback.
    final remaining = samples.length - index;
    final fade = remaining < 64 ? remaining / 64 : 1.0;
    pcm[index] = (samples[index] * scale * fade * 32767).round().clamp(
      -32768,
      32767,
    );
  }

  final body = pcm.buffer.asUint8List();
  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + body.length, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, _sampleRate, Endian.little)
    ..setUint32(28, _sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, body.length, Endian.little);

  File('assets/sfx/$name.wav')
    ..createSync(recursive: true)
    ..writeAsBytesSync([...header.buffer.asUint8List(), ...body]);
  stdout.writeln('assets/sfx/$name.wav (${body.length + 44} bytes)');
}
