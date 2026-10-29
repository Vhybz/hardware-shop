import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'app_settings_provider.dart';

class FeedbackService {
  static VideoPlayerController? _beepController;
  static bool _isInit = false;
  static File? _beepFile;

  /// Synthesize a 2.4kHz 120ms Retail POS Scanner Beep WAV audio buffer
  static Uint8List _generateScannerBeepBytes() {
    const int sampleRate = 22050;
    const double frequency = 2400.0; // 2.4kHz crisp barcode scanner pitch
    const double duration = 0.12; // 120ms
    const double volume = 0.90;

    final int numSamples = (sampleRate * duration).round();
    final int dataSize = numSamples * 2;
    final int fileSize = 44 + dataSize;

    final bytes = Uint8List(fileSize);
    final bd = ByteData.view(bytes.buffer);

    // RIFF header
    bytes.setRange(0, 4, 'RIFF'.codeUnits);
    bd.setUint32(4, fileSize - 8, Endian.little);
    bytes.setRange(8, 12, 'WAVE'.codeUnits);

    // fmt chunk
    bytes.setRange(12, 16, 'fmt '.codeUnits);
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // Mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);

    // data chunk
    bytes.setRange(36, 40, 'data'.codeUnits);
    bd.setUint32(40, dataSize, Endian.little);

    final double angularFreq = 2 * pi * frequency / sampleRate;
    for (int i = 0; i < numSamples; i++) {
      double envelope = 1.0;
      final fadeIn = numSamples * 0.08;
      final fadeOut = numSamples * 0.12;
      if (i < fadeIn) {
        envelope = i / fadeIn;
      } else if (i > numSamples - fadeOut) {
        envelope = (numSamples - i) / fadeOut;
      }

      final sample = (sin(i * angularFreq) * 32767 * volume * envelope).toInt().clamp(-32768, 32767);
      bd.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes;
  }

  static Future<void> _initBeepPlayer() async {
    if (_isInit) return;
    _isInit = true;

    try {
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        _beepFile = File('${tempDir.path}/barcode_scanner_beep.wav');
        if (!await _beepFile!.exists() || (await _beepFile!.length()) == 0) {
          final wavBytes = _generateScannerBeepBytes();
          await _beepFile!.writeAsBytes(wavBytes);
        }

        _beepController = VideoPlayerController.file(_beepFile!);
        await _beepController!.initialize();
        await _beepController!.setVolume(1.0);
      }
    } catch (e) {
      debugPrint('Scanner Beep Init Warning: $e');
    }
  }

  /// Triggers heavy haptic vibration, system alert sound, and 2.4kHz scanner beep audio
  static Future<void> playScannerBeep([WidgetRef? ref]) async {
    // 1. Trigger Heavy Haptic Vibration
    try {
      await HapticFeedback.heavyImpact();
      await HapticFeedback.vibrate();
    } catch (_) {}

    // 2. Trigger System Alert & Click Sound
    try {
      await SystemSound.play(SystemSoundType.alert);
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    // 3. Play High-Pitched Scanner Beep Audio
    try {
      if (!_isInit) {
        await _initBeepPlayer();
      }

      if (_beepController != null && _beepController!.value.isInitialized) {
        await _beepController!.seekTo(Duration.zero);
        await _beepController!.play();
      }
    } catch (e) {
      debugPrint('Error playing scanner beep audio: $e');
    }
  }

  static Future<void> success(WidgetRef ref) async {
    final settings = ref.read(appSettingsProvider);
    if (settings.hapticFeedbackEnabled) {
      await HapticFeedback.mediumImpact();
    }
    if (settings.systemSoundsEnabled) {
      await playScannerBeep(ref);
    }
  }

  static Future<void> scan(WidgetRef ref) async {
    final settings = ref.read(appSettingsProvider);
    if (settings.hapticFeedbackEnabled) {
      await HapticFeedback.heavyImpact();
    }
    if (settings.systemSoundsEnabled) {
      await playScannerBeep(ref);
    }
  }
}
