import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordingInput extends StatefulWidget {
  final Function(String path) onStop;
  final VoidCallback onCancel;

  const RecordingInput({
    Key? key,
    required this.onStop,
    required this.onCancel,
  }) : super(key: key);

  @override
  _RecordingInputState createState() => _RecordingInputState();
}

class _RecordingInputState extends State<RecordingInput>
    with SingleTickerProviderStateMixin {
  FlutterSoundRecorder? _recorder;

  StreamSubscription? _recorderSubscription;

  // Timer
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _durationText = "0:00";

  // Waveform
  List<double> _waveforms = [];

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initAndStart();
  }

  Future<void> _initAndStart() async {
    await _recorder!.openRecorder();
    _recorder!.setSubscriptionDuration(const Duration(milliseconds: 50));

    // Check perm again just in case (should be checked by parent or before this widget shows)
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        widget.onCancel();
        return;
      }
    }

    await _recorder!.startRecorder(toFile: 'audio_message.aac');

    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        _durationText = _formatDuration(_stopwatch.elapsed);
      });
    });

    _recorderSubscription = _recorder!.onProgress!.listen((e) {
      if (e.decibels != null) {
        setState(() {
          // Normalize db (usually -160 to 0) to 0.0 - 1.0
          // Typical speech is around -30 to -50db
          // Let's take a range of -60 to 0
          double normalized = 1 - (e.decibels! / -60).clamp(0.0, 1.0);
          // Add some randomness/noise to make it look alive if silence
          if (normalized < 0.1) normalized = 0.1;

          _waveforms.add(normalized);
          if (_waveforms.length > 50) {
            _waveforms.removeAt(0);
          }
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.toString();
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<void> _stopAndSend() async {
    _stopwatch.stop();
    _timer?.cancel();
    _recorderSubscription?.cancel();

    final path = await _recorder!.stopRecorder();

    if (path != null) {
      widget.onStop(path);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _cancel() async {
    try {
      _stopwatch.stop();
      _timer?.cancel();
      _recorderSubscription?.cancel();
      await _recorder!.stopRecorder();
      await _recorder!.deleteRecord(fileName: 'audio_message.aac');
    } catch (e) {
      debugPrint("Error cancelling recording: $e");
    } finally {
      widget.onCancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder!.closeRecorder();
    _recorderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true, // Handle safe area for bottom devices
      child: Container(
        height: 60, // Match typical input height
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white,
        child: Row(
          children: [
            // Duration
            Text(
              _durationText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: [
                  FontFeature.tabularFigures()
                ], // Fixed width numbers
              ),
            ),
            const SizedBox(width: 16),

            // Waveform
            Expanded(
              child: CustomPaint(
                painter: WaveformPainter(_waveforms),
                size: const Size(double.infinity, 30),
              ),
            ),
            const SizedBox(width: 16),

            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.grey, size: 28),
              onPressed: _cancel,
            ),

            const SizedBox(width: 8),

            // Send Button
            GestureDetector(
              onTap: _stopAndSend,
              child: const CircleAvatar(
                backgroundColor: Color(0xFF075E54),
                radius: 20,
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveforms;

  WaveformPainter(this.waveforms);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    double spacing = size.width / 50; // Show 50 bars

    for (int i = 0; i < waveforms.length; i++) {
      double height = waveforms[i] * size.height;
      double x = size.width - ((waveforms.length - i) * spacing);

      if (x < 0) continue;

      // Draw centered vertically
      double startY = (size.height - height) / 2;
      canvas.drawLine(Offset(x, startY), Offset(x, startY + height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
