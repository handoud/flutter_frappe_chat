import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorder extends StatefulWidget {
  final Function(String path) onStop;

  const AudioRecorder({Key? key, required this.onStop}) : super(key: key);

  @override
  _AudioRecorderState createState() => _AudioRecorderState();
}

class _AudioRecorderState extends State<AudioRecorder> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder!.openRecorder();
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Permission check should be done before this widget is active or inside here
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denied
      return;
    }

    await _recorder!.startRecorder(toFile: 'audio_message.aac');
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder!.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    if (path != null) {
      widget.onStop(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _startRecording,
      onLongPressUp: _stopRecording,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : Colors.blue,
          shape: BoxShape.circle,
        ),
        child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white),
      ),
    );
  }
}
