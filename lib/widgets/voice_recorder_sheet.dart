import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_waveform.dart';

/// Результат записи голосового сообщения.
class VoiceRecordingResult {
  const VoiceRecordingResult({
    required this.path,
    required this.durationSeconds,
    required this.waveform,
  });

  final String path;
  final int durationSeconds;
  final List<int> waveform;
}

/// Запись голосового сообщения с waveform.
class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key});

  static Future<VoiceRecordingResult?> show(BuildContext context) {
    return showModalBottomSheet<VoiceRecordingResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const VoiceRecorderSheet(),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  final _recorder = AudioRecorder();
  Timer? _timer;
  var _seconds = 0;
  var _isRecording = false;
  var _permissionDenied = false;
  final _waveformSamples = <int>[];
  String? _filePath;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() => _permissionDenied = true);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path = p.join(
      tempDir.path,
      'voice_${DateTime.now().millisecondsSinceEpoch}.ogg',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        numChannels: 1,
        sampleRate: 48000,
      ),
      path: path,
    );

    _filePath = path;
    _waveformSamples.clear();
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final amplitude = await _recorder.getAmplitude();
      final normalized = _normalizeAmplitude(amplitude.current);
      if (mounted) {
        setState(() {
          _seconds++;
          _waveformSamples.add(normalized);
          if (_waveformSamples.length > 100) {
            _waveformSamples.removeAt(0);
          }
        });
      }
    });

    setState(() => _isRecording = true);
  }

  Future<VoiceRecordingResult?> _stopRecording({required bool send}) async {
    if (!_isRecording) {
      return null;
    }

    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    final filePath = path ?? _filePath;
    if (!send || filePath == null || _seconds <= 0) {
      return null;
    }

    return VoiceRecordingResult(
      path: filePath,
      durationSeconds: _seconds,
      waveform: _waveformSamples.isEmpty ? [5, 8, 12, 10, 6] : _waveformSamples,
    );
  }

  int _normalizeAmplitude(double amplitude) {
    if (amplitude.isNaN || amplitude.isInfinite) {
      return 5;
    }
    final scaled = (log(max(amplitude, 1)) * 4).round();
    return scaled.clamp(0, 31);
  }

  List<double> get _previewHeights {
    if (_waveformSamples.isEmpty) {
      return const [0.2, 0.35, 0.25];
    }
    return _waveformSamples.map((v) => (v / 31).clamp(0.05, 1.0)).toList();
  }

  String get _timerLabel {
    final minutes = _seconds ~/ 60;
    final rest = _seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isRecording ? 'Запись… $_timerLabel' : 'Голосовое сообщение',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            VoiceWaveform(
              heights: _previewHeights,
              progress: _isRecording ? 1 : 0,
              height: 36,
            ),
            if (_permissionDenied) ...[
              const SizedBox(height: 12),
              Text(
                'Нет доступа к микрофону',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isRecording)
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await _stopRecording(send: false);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Отмена'),
                  ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isRecording
                      ? () async {
                          final result = await _stopRecording(send: true);
                          if (context.mounted) {
                            Navigator.pop(context, result);
                          }
                        }
                      : _startRecording,
                  icon: Icon(_isRecording ? Icons.send : Icons.mic),
                  label: Text(_isRecording ? 'Отправить' : 'Записать'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
