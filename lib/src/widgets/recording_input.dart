import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../models/chat_theme.dart';
import '../utils/permissions.dart';

/// The input bar shown while a voice note is being recorded.
class RecordingInput extends StatefulWidget {
  /// Called with the recorded file's path when the user sends it.
  final void Function(String path) onStop;

  /// Called when the user discards the recording, or it could not start.
  final VoidCallback onCancel;

  /// Colours and shapes.
  final FrappeChatTheme theme;

  const RecordingInput({
    super.key,
    required this.onStop,
    required this.onCancel,
    this.theme = const FrappeChatTheme(),
  });

  @override
  State<RecordingInput> createState() => _RecordingInputState();
}

class _RecordingInputState extends State<RecordingInput> {
  static const _fileName = 'frappe_chat_voice_note.aac';

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final Stopwatch _stopwatch = Stopwatch();
  final List<double> _levels = [];

  StreamSubscription<RecordingDisposition>? _progress;
  Timer? _ticker;
  String _elapsed = '0:00';
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!await ChatPermissions.requestMicrophone()) {
      widget.onCancel();
      return;
    }

    try {
      await _recorder.openRecorder();
      _opened = true;
      await _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 80),
      );

      await _recorder.startRecorder(toFile: _fileName, codec: Codec.aacADTS);
    } catch (e) {
      debugPrint('flutter_frappe_chat: could not start recording — $e');
      widget.onCancel();
      return;
    }

    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _format(_stopwatch.elapsed));
    });

    _progress = _recorder.onProgress?.listen((event) {
      final decibels = event.decibels;
      if (decibels == null || !mounted) return;

      setState(() {
        // Decibels run roughly -60 (silence) to 0 (loud).
        final normalized = (1 + decibels / 60).clamp(0.08, 1.0).toDouble();
        _levels.add(normalized);
        if (_levels.length > 60) _levels.removeAt(0);
      });
    });
  }

  static String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<String?> _stopRecorder() async {
    _stopwatch.stop();
    _ticker?.cancel();
    await _progress?.cancel();
    _progress = null;

    if (!_opened) return null;
    try {
      return await _recorder.stopRecorder();
    } catch (e) {
      debugPrint('flutter_frappe_chat: could not stop recording — $e');
      return null;
    }
  }

  Future<void> _send() async {
    final path = await _stopRecorder();
    if (path != null && _stopwatch.elapsed.inMilliseconds > 500) {
      widget.onStop(path);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _cancel() async {
    await _stopRecorder();
    try {
      if (_opened) await _recorder.deleteRecord(fileName: _fileName);
    } catch (_) {
      // The file may not exist yet; discarding is best effort.
    }
    widget.onCancel();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _progress?.cancel();
    if (_opened) _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: theme.inputBackground,
        child: Row(
          children: [
            Icon(Icons.fiber_manual_record, color: Colors.red[400], size: 12),
            const SizedBox(width: 8),
            Text(
              _elapsed,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.incomingText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomPaint(
                painter: _WaveformPainter(_levels, theme.metaColor),
                size: const Size(double.infinity, 30),
              ),
            ),
            IconButton(
              tooltip: 'Discard',
              icon: Icon(Icons.delete_outline, color: theme.metaColor),
              onPressed: _cancel,
            ),
            IconButton.filled(
              tooltip: 'Send',
              style: IconButton.styleFrom(backgroundColor: theme.accent),
              icon: const Icon(Icons.send, size: 18),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> levels;
  final Color color;

  const _WaveformPainter(this.levels, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const barCount = 60;
    final spacing = size.width / barCount;

    for (var i = 0; i < levels.length; i++) {
      final x = size.width - (levels.length - i) * spacing;
      if (x < 0) continue;

      final height = levels[i] * size.height;
      final top = (size.height - height) / 2;
      canvas.drawLine(Offset(x, top), Offset(x, top + height), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.levels.length != levels.length ||
      oldDelegate.color != color;
}
